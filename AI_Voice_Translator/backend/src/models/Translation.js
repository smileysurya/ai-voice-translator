const mongoose = require('mongoose');

const TranslationSchema = new mongoose.Schema({
  userId: { type: String, required: true }, // Firebase UID
  transcript: { type: String, required: true },
  translation: { type: String, required: true },
  sourceLang: { type: String, required: true },
  targetLang: { type: String, required: true },
  mode: { type: String, enum: ['voice', 'text', 'call'], default: 'voice' },
  timestamp: { type: Date, default: Date.now }
});

module.exports = mongoose.model('Translation', TranslationSchema);
