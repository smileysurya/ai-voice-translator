require('dotenv').config();
const express = require('express');
const cors = require('cors');
const path = require('path');
const fs = require('fs');

// Ensure uploads directory exists
const uploadsDir = path.join(__dirname, '..', 'uploads');
if (!fs.existsSync(uploadsDir)) {
  fs.mkdirSync(uploadsDir, { recursive: true });
}

const translateRouter = require('./routes/translate');
const { initSocketManager } = require('./socketManager');

const app = express();
const PORT = process.env.PORT || 3000;

// Task F: Simple Request Logger
app.use((req, res, next) => {
  console.log(`${new Date().toISOString()} - ${req.method} ${req.url}`);
  next();
});

// Task D: Fix CORS for Production
app.use(cors({
  origin: process.env.FRONTEND_URL || "*",
  methods: ['GET', 'POST', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));

app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));

// Task A: Root Route
app.get('/', (req, res) => {
  res.json({
    message: "AI Voice Translator Backend is running",
    status: "success"
  });
});

// Task B: Health Check Route
app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    uptime: process.uptime(),
    timestamp: new Date().toISOString()
  });
});

app.use('/api', translateRouter);

// Task E: Global Error Handler
app.use((err, req, res, next) => {
  console.error('Unhandled error:', err);
  res.status(err.status || 500).json({ 
    success: false, 
    message: "Internal Server Error" 
  });
});

const server = app.listen(PORT, () => {
  console.log(`\n🚀 AI Voice Translator Backend`);
  console.log(`   URL  : http://localhost:${PORT}`);
  console.log(`   OpenAI: ${process.env.OPENAI_API_KEY ? '✅ Configured' : '❌ Missing'}\n`);
});

// Task I: Ensure Socket.io Still Works
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
