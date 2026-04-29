const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const { transcribeAudio } = require('../services/stt');
const { translateText } = require('../services/translator');
const { synthesizeSpeech } = require('../services/tts');

const router = express.Router();

const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, path.join(__dirname, '..', '..', 'uploads'));
  },
  filename: (req, file, cb) => {
    // Determine extension from original name or mimetype
    let ext = path.extname(file.originalname).toLowerCase();
    if (!ext || ext === '.') {
      if (file.mimetype.includes('webm')) ext = '.webm';
      else if (file.mimetype.includes('ogg') || file.mimetype.includes('opus')) ext = '.webm';
      else if (file.mimetype.includes('wav')) ext = '.wav';
      else if (file.mimetype.includes('mp3') || file.mimetype.includes('mpeg')) ext = '.mp3';
      else ext = '.webm';
    }
    cb(null, `audio_${Date.now()}${ext}`);
  },
});

const upload = multer({
  storage,
  limits: { fileSize: 25 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    const allowed = ['.wav', '.mp3', '.m4a', '.ogg', '.webm', '.flac', '.opus'];
    const ext = path.extname(file.originalname).toLowerCase();
    const mimeOk = file.mimetype.startsWith('audio/') || file.mimetype.includes('webm') || file.mimetype.includes('ogg');
    if (mimeOk || allowed.includes(ext)) {
      cb(null, true);
    } else {
      cb(new Error('Only audio files are allowed'));
    }
  },
});

router.post('/translate', upload.single('audio'), async (req, res) => {
  let filePath = null;
  const requestId = Date.now().toString().slice(-6);
  try {
    if (!req.file) {
      console.log(`[${requestId}] ⚠️ No audio file provided`);
      return res.status(400).json({ success: false, error: 'No audio file provided' });
    }

    filePath = req.file.path;
    const { sourceLang = 'auto', targetLang = 'en', outputMode = 'text' } = req.body;

    console.log(`[${requestId}] 📥 Audio: ${req.file.originalname} (${(req.file.size / 1024).toFixed(1)}KB) | ${sourceLang} → ${targetLang} | ${outputMode}`);

    // 1. Transcribe
    console.log(`[${requestId}] 🎤 STT Start (Whisper)...`);
    const transcript = await transcribeAudio(filePath, sourceLang);
    if (!transcript || !transcript.trim()) {
      console.log(`[${requestId}] ⚠️ Transcription empty`);
      return res.status(422).json({ success: false, error: 'Could not transcribe. Please speak clearly and try again.' });
    }
    console.log(`[${requestId}] 📝 Transcript: "${transcript}"`);

    // 2. Translate
    console.log(`[${requestId}] 🌐 Translation Start...`);
    const translation = await translateText(transcript, sourceLang, targetLang);
    console.log(`[${requestId}] ✅ Translation: "${translation}"`);

    // 3. TTS (speaker mode only)
    let audioBase64 = null;
    if (outputMode === 'speaker') {
      console.log(`[${requestId}] 🔊 TTS Start...`);
      const buf = await synthesizeSpeech(translation);
      audioBase64 = buf.toString('base64');
      console.log(`[${requestId}] 🔊 Audio: ${(buf.length / 1024).toFixed(1)}KB`);
    }

    res.json({ success: true, transcript, translation, audioBase64, sourceLang, targetLang, timestamp: new Date().toISOString() });
  } catch (err) {
    console.error(`[${requestId}] ❌ Pipeline error:`, err.message);
    res.status(500).json({ success: false, error: err.message || 'Translation failed. Please try again.' });
  } finally {
    if (filePath && fs.existsSync(filePath)) {
      try { fs.unlinkSync(filePath); } catch (_) {}
    }
  }
});

// ── Text-only translation (no audio) ─────────────────────────────────
router.post('/translate-text', express.json(), async (req, res) => {
  const requestId = Date.now().toString().slice(-6);
  try {
    const { text, sourceLang = 'auto', targetLang = 'en' } = req.body;
    if (!text || !text.trim()) {
      return res.status(400).json({ success: false, error: 'No text provided' });
    }
    console.log(`[${requestId}] 📝 Text translate: "${text.substring(0, 60)}…" | ${sourceLang} → ${targetLang}`);
    const translation = await translateText(text.trim(), sourceLang, targetLang);
    console.log(`[${requestId}] ✅ Translation: "${translation}"`);
    res.json({ success: true, transcript: text.trim(), translation, sourceLang, targetLang, timestamp: new Date().toISOString() });
  } catch (err) {
    console.error(`[${requestId}] ❌ Text translate error:`, err.message);
    res.status(500).json({ success: false, error: err.message || 'Translation failed' });
  }
});

module.exports = router;
