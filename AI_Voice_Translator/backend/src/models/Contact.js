const mongoose = require('mongoose');

const ContactSchema = new mongoose.Schema({
  userId: { type: String, required: true }, // Owner of the contact (Firebase UID)
  contactName: { type: String, required: true },
  contactId: { type: String, required: true }, // Could be another Firebase UID or room code
  type: { type: String, enum: ['user', 'room'], default: 'user' },
  createdAt: { type: Date, default: Date.now }
});

module.exports = mongoose.model('Contact', ContactSchema);
