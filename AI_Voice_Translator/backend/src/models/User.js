const mongoose = require('mongoose');

const UserSchema = new mongoose.Schema({
  firebaseUid: { type: String, required: true, unique: true },
  email: { type: String, required: true },
  displayName: String,
  preferredLanguages: {
    source: { type: String, default: 'auto' },
    target: { type: String, default: 'en' }
  },
  avatarUrl: String,
  createdAt: { type: Date, default: Date.now },
  lastLogin: Date
});

module.exports = mongoose.model('User', UserSchema);
