const { Server } = require('socket.io');
const fs = require('fs');
const path = require('path');
const { transcribeAudio } = require('./services/stt');
const { translateText } = require('./services/translator');

function initSocketManager(server) {
  const io = new Server(server, {
    cors: {
      origin: [
        'https://remarkable-gumdrop-b256de.netlify.app',
        'http://localhost:3000',
        'http://localhost:5000',
        'http://localhost:19006'
      ],
      methods: ['GET', 'POST'],
      credentials: true
    },
    transports: ['websocket', 'polling']
  });

  io.on('connection', (socket) => {
    console.log(`🔌 [Socket] New connection: ${socket.id}`);

    // Join a specific Walkie-Talkie room
    socket.on('join_room', (roomCode) => {
      if (!roomCode) {
        console.log(`⚠️ [Socket] ${socket.id} tried to join with no roomCode`);
        return;
      }
      socket.join(roomCode);
      console.log(`👥 [Socket] ${socket.id} joined room: ${roomCode}`);
      // Notify others in room
      socket.to(roomCode).emit('peer_joined', { id: socket.id });
    });

    // Leave room
    socket.on('leave_room', (roomCode) => {
      socket.leave(roomCode);
      console.log(`👋 [Socket] ${socket.id} left room: ${roomCode}`);
      socket.to(roomCode).emit('peer_left', { id: socket.id });
    });

    // Handle real-time voice message broadcast
    socket.on('voice_message', async (data) => {
      const { roomCode, sourceLang, targetLang, audioBase64 } = data;
      console.log(`🎤 [Socket] Voice received from ${socket.id} for room ${roomCode} (${sourceLang} → ${targetLang})`);

      if (!audioBase64) {
        console.error(`❌ [Socket] No audio data in voice_message from ${socket.id}`);
        return;
      }

      // We need to save the base64 to a local file for Whisper STT
      const tempPath = path.join(__dirname, '..', 'uploads', `socket_audio_${Date.now()}_${socket.id}.webm`);
      
      try {
        const audioBuffer = Buffer.from(audioBase64, 'base64');
        fs.writeFileSync(tempPath, audioBuffer);
        
        // 1. Transcribe the audio
        console.log(`🎤 [Socket] STT Start for ${socket.id}...`);
        const transcript = await transcribeAudio(tempPath, sourceLang);
        if (!transcript) {
          console.log(`⚠️ [Socket] STT returned empty for ${socket.id}`);
          throw new Error('Transcription empty');
        }
        console.log(`📝 [Socket] Transcript: "${transcript}"`);
        
        // 2. Translate the transcript
        console.log(`🌐 [Socket] Translation Start...`);
        const translation = await translateText(transcript, sourceLang, targetLang);
        console.log(`✅ [Socket] Translation Success: "${translation}"`);
        
        // 3. Broadcast only to other members in the room
        const payload = {
          senderId: socket.id,
          sourceLang,
          targetLang,
          originalText: transcript,
          translatedText: translation,
          timestamp: new Date().toISOString(),
        };
        
        console.log(`📡 [Socket] Emitting translated_message to room ${roomCode}`);
        socket.to(roomCode).emit('translated_message', payload);

        // Acknowledge back to sender
        socket.emit('message_sent_ack', payload);

      } catch (err) {
        console.error(`❌ [Socket] Pipeline error for ${socket.id}:`, err.message);
        socket.emit('socket_error', { message: err.message });
      } finally {
        // Clean up temp file
        if (fs.existsSync(tempPath)) {
          try { fs.unlinkSync(tempPath); } catch (e) {}
        }
      }
    });

    // --- WebRTC Signaling ---
    socket.on('webrtc_signal', (data) => {
      const { roomCode, payload } = data;
      console.log(`📡 [Socket] WebRTC Signal relay from ${socket.id} in ${roomCode}`);
      socket.to(roomCode).emit('webrtc_signal', {
        senderId: socket.id,
        payload: payload
      });
    });

    socket.on('call_status', (data) => {
      const { roomCode, status } = data;
      console.log(`📞 [Socket] Call status: ${status} from ${socket.id} in ${roomCode}`);
      socket.to(roomCode).emit('call_status', { senderId: socket.id, status });
    });

    socket.on('disconnect', (reason) => {
      console.log(`🔌 [Socket] Client disconnected: ${socket.id} (${reason})`);
    });
  });

  return io;
}

module.exports = { initSocketManager };
