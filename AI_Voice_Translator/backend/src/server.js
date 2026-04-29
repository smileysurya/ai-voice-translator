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

// Task A & F: Enhanced Request Logger
app.use((req, res, next) => {
  const start = Date.now();
  res.on('finish', () => {
    const duration = Date.now() - start;
    console.log(`${new Date().toISOString()} - ${req.method} ${req.originalUrl} [${res.statusCode}] - ${duration}ms`);
  });
  next();
});

// Task B & C: CORS Fix
const allowedOrigins = [
  'https://remarkable-gumdrop-b256de.netlify.app',
  'http://localhost:3000',
  'http://localhost:5000',
  'http://localhost:19006' // Standard Flutter web dev port
];

app.use(cors({
  origin: (origin, callback) => {
    // Allow requests with no origin (like mobile apps or curl requests)
    if (!origin) return callback(null, true);
    if (allowedOrigins.indexOf(origin) !== -1 || process.env.FRONTEND_URL === origin || process.env.NODE_ENV !== 'production') {
      callback(null, true);
    } else {
      console.log(`CORS blocked for origin: ${origin}`);
      // For demo, if CORS blocks, temporarily allow everything if requested
      callback(null, true); 
    }
  },
  methods: ['GET', 'POST', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
  credentials: true
}));

app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));

// Task A: Root Route
app.get('/', (req, res) => {
  res.json({
    message: "AI Voice Translator Backend is running",
    status: "success",
    version: "1.0.1"
  });
});

// Task B: Health Check Route
app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    uptime: process.uptime(),
    timestamp: new Date().toISOString(),
    env: {
      OPENAI_API_KEY_EXISTS: !!process.env.OPENAI_API_KEY,
      GROQ_API_KEY_EXISTS: !!process.env.GROQ_API_KEY,
      PORT: process.env.PORT
    }
  });
});

app.use('/api', translateRouter);

// Task E: Global Error Handler
app.use((err, req, res, next) => {
  console.error('❌ Unhandled error:', err);
  res.status(err.status || 500).json({ 
    success: false, 
    message: err.message || "Internal Server Error",
    stack: process.env.NODE_ENV === 'development' ? err.stack : undefined
  });
});

const server = app.listen(PORT, '0.0.0.0', () => {
  console.log(`\n🚀 AI Voice Translator Backend Started`);
  console.log(`   URL      : http://0.0.0.0:${PORT}`);
  console.log(`   NODE_ENV : ${process.env.NODE_ENV || 'development'}`);
  console.log(`   OPENAI_API_KEY exists: ${!!process.env.OPENAI_API_KEY}`);
  console.log(`   GROQ_API_KEY exists: ${!!process.env.GROQ_API_KEY}`);
  console.log(`   FRONTEND_URL: ${process.env.FRONTEND_URL || 'Not set (allowing all for demo)'}`);
  console.log(`   Socket.io: 📡 Initialized\n`);
});

// Task I: Ensure Socket.io Still Works
initSocketManager(server);

server.on('error', (err) => {
  if (err.code === 'EADDRINUSE') {
    console.error(`\n❌ Port ${PORT} is already in use.`);
    process.exit(1);
  } else {
    throw err;
  }
});
