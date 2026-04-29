const express = require('express');
const router = express.Router();
const Translation = require('../models/Translation');
const Call = require('../models/Call');

// Sync Translation History
router.post('/history', async (req, res) => {
  try {
    const { userId, records } = req.body; // records is an array
    
    // Efficiently insert multiple records
    const results = await Translation.insertMany(
      records.map(r => ({
        userId,
        transcript: r.transcript,
        translation: r.translation,
        sourceLang: r.sourceLang,
        targetLang: r.targetLang,
        mode: r.mode || 'voice',
        timestamp: r.timestamp || new Date()
      }))
    );
    
    res.json({ success: true, count: results.length });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// Get History
router.get('/history/:userId', async (req, res) => {
  try {
    const history = await Translation.find({ userId: req.params.userId })
      .sort({ timestamp: -1 })
      .limit(100);
    res.json({ success: true, history });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

module.exports = router;
