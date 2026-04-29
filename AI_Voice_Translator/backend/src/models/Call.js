const mongoose = require('mongoose');

const CallSchema = new mongoose.Schema({
  roomCode: { type: String, required: true },
  participants: [{ type: String }], // Array of socket IDs or Firebase UIDs
  startTime: { type: Date, default: Date.now },
  endTime: Date,
  duration: Number, // in seconds
  status: { type: String, enum: ['active', 'completed', 'missed'], default: 'active' },
  metadata: {
    sourceLang: String,
    targetLang: String
  }
});

module.exports = mongoose.model('Call', CallSchema);
