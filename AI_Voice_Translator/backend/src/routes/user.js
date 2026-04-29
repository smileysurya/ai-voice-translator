const express = require('express');
const router = express.Router();
const User = require('../models/User');

// Create or Update User Profile
router.post('/profile', async (req, res) => {
  try {
    const { firebaseUid, email, displayName, avatarUrl, preferredLanguages } = req.body;
    
    let user = await User.findOne({ firebaseUid });
    if (user) {
      user.displayName = displayName || user.displayName;
      user.email = email || user.email;
      user.avatarUrl = avatarUrl || user.avatarUrl;
      user.preferredLanguages = preferredLanguages || user.preferredLanguages;
      user.lastLogin = new Date();
      await user.save();
    } else {
      user = new User({
        firebaseUid,
        email,
        displayName,
        avatarUrl,
        preferredLanguages,
        lastLogin: new Date()
      });
      await user.save();
    }
    
    res.json({ success: true, user });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

module.exports = router;
