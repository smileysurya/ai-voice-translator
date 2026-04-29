require('dotenv').config();
const express = require('express');
const cors = require('cors');
const path = require('path');
const fs = require('fs');
const mongoose = require('mongoose');

// Ensure uploads directory exists
const uploadsDir = path.join(__dirname, '..', 'uploads');
if (!fs.existsSync(uploadsDir)) {
  fs.mkdirSync(uploadsDir, { recursive: true });
}

const translateRouter = require('./routes/translate');
const userRouter = require('./routes/user');
const syncRouter = require('./routes/sync');
const { initSocketManager } = require('./socketManager');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors({
  origin: '*',
  methods: ['GET', 'POST', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));

app.use('/api', translateRouter);
app.use('/api/user', userRouter);
app.use('/api/sync', syncRouter);

// MongoDB Connection
const MONGODB_URI = process.env.MONGODB_URI;
if (MONGODB_URI) {
  mongoose.connect(MONGODB_URI)
    .then(() => console.log('🍃 MongoDB connected successfully'))
    .catch(err => console.error('❌ MongoDB connection error:', err));
} else {
  console.warn('⚠️ MONGODB_URI missing in .env - persistence disabled');
}

app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    version: '1.0.0',
    openai: process.env.OPENAI_API_KEY ? 'configured' : 'missing',
  });
});

app.use((err, req, res, next) => {
  console.error('Unhandled error:', err);
  res.status(500).json({ error: 'Internal server error', message: err.message });
});

const server = app.listen(PORT, () => {
  console.log(`\n🚀 AI Voice Translator Backend`);
  console.log(`   URL  : http://localhost:${PORT}`);
  console.log(`   OpenAI: ${process.env.OPENAI_API_KEY ? '✅ Configured' : '❌ Missing – set OPENAI_API_KEY in .env'}\n`);
});

initSocketManager(server);

server.on('error', (err) => {
  if (err.code === 'EADDRINUSE') {
    console.error(`\n❌ Port ${PORT} is already in use.`);
    console.error(`   Run this to free it: taskkill /F /PID $(netstat -ano | findstr :${PORT})`);
    process.exit(1);
  } else {
    throw err;
  }
});
