const { Server } = require('socket.io');
const fs = require('fs');
const path = require('path');
const { transcribeAudio } = require('./services/stt');
const { translateText } = require('./services/translator');

function initSocketManager(server) {
  const io = new Server(server, {
    cors: {
      origin: '*',
      methods: ['GET', 'POST'],
    },
  });

  io.on('connection', (socket) => {
    console.log(`🔌 Client connected: ${socket.id}`);

    // Join a specific Walkie-Talkie room
    socket.on('join_room', (roomCode) => {
      socket.join(roomCode);
      console.log(`👥 Client ${socket.id} joined room: ${roomCode}`);
      // Notify others in room
      socket.to(roomCode).emit('peer_joined', { id: socket.id });
    });

    // Leave room
    socket.on('leave_room', (roomCode) => {
      socket.leave(roomCode);
      console.log(`👋 Client ${socket.id} left room: ${roomCode}`);
      socket.to(roomCode).emit('peer_left', { id: socket.id });
    });

    // Handle real-time voice message broadcast
    socket.on('voice_message', async (data) => {
      const { roomCode, sourceLang, targetLang, audioBase64 } = data;
      console.log(`🎤 Voice message received in room ${roomCode} from ${socket.id}`);

      // We need to save the base64 to a local file for Whisper STT
      const tempPath = path.join(__dirname, '..', 'uploads', `socket_audio_${Date.now()}_${socket.id}.webm`);
      
      try {
        const audioBuffer = Buffer.from(audioBase64, 'base64');
        fs.writeFileSync(tempPath, audioBuffer);
        
        // 1. Transcribe the audio
        console.log(`🎤 [Socket] Transcribing with Whisper (${sourceLang})...`);
        const transcript = await transcribeAudio(tempPath, sourceLang);
        if (!transcript) throw new Error('Transcription empty');
        
        // 2. Translate the transcript
        console.log(`🌐 [Socket] Translating -> ${targetLang} : "${transcript}"`);
        const translation = await translateText(transcript, sourceLang, targetLang);
        
        // 3. Broadcast only to other members in the room
        /* 
         Note: the recipient will use their own flutter_tts engine 
         to speak the 'translation' aloud instantly and freely!
        */
        const payload = {
          senderId: socket.id,
          sourceLang,
          targetLang,
          originalText: transcript,
          translatedText: translation,
          timestamp: new Date().toISOString(),
        };
        
        console.log(`📡 [Socket] Broadcasting translation to room ${roomCode}`);
        socket.to(roomCode).emit('translated_message', payload);

        // Acknowledge back to sender so they can show their own transcript
        socket.emit('message_sent_ack', payload);

      } catch (err) {
        console.error(`❌ [Socket] Pipeline error:`, err.message);
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
      console.log(`📡 WebRTC Signal from ${socket.id} in room ${roomCode}`);
      // Relay signal to other peer(s) in the room
      socket.to(roomCode).emit('webrtc_signal', {
        senderId: socket.id,
        payload: payload
      });
    });

    socket.on('call_status', (data) => {
      const { roomCode, status } = data;
      socket.to(roomCode).emit('call_status', { senderId: socket.id, status });
    });

    socket.on('disconnect', () => {
      console.log(`🔌 Client disconnected: ${socket.id}`);
    });
  });

  return io;
}

module.exports = { initSocketManager };
