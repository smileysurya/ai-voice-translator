const fs = require('fs');
const path = require('path');
const https = require('https');
const FormData = require('form-data');

async function transcribeAudio(filePath, sourceLang = 'auto') {
  // Read file into buffer BEFORE the route's finally block deletes it
  const fileBuffer = fs.readFileSync(filePath);
  const fileName = path.basename(filePath);

  const form = new FormData();
  form.append('file', fileBuffer, { filename: fileName, contentType: 'audio/webm' });
  form.append('model', 'whisper-large-v3-turbo'); // Groq's free fast Whisper model
  form.append('response_format', 'text');
  if (sourceLang && sourceLang !== 'auto') {
    form.append('language', sourceLang);
  }

  const apiKey = process.env.GROQ_API_KEY;
  if (!apiKey) throw new Error('GROQ_API_KEY not set in .env');

  return new Promise((resolve, reject) => {
    const options = {
      hostname: 'api.groq.com',                      // ← Groq endpoint
      path: '/openai/v1/audio/transcriptions',        // ← same path as OpenAI
      method: 'POST',
      headers: {
        ...form.getHeaders(),
        'Authorization': `Bearer ${apiKey}`,
      },
      timeout: 30000,
    };

    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', chunk => { data += chunk; });
      res.on('end', () => {
        if (res.statusCode === 200) {
          resolve(data.trim());
        } else {
          let msg = data;
          try { msg = JSON.parse(data)?.error?.message || data; } catch (_) {}
          const err = new Error(msg);
          err.status = res.statusCode;
          console.error(`❌ Groq STT error [${res.statusCode}]: ${msg}`);
          reject(err);
        }
      });
    });

    req.on('error', (e) => {
      console.error(`❌ Groq STT network error: ${e.message}`);
      reject(e);
    });

    req.on('timeout', () => {
      req.destroy();
      reject(new Error('Groq STT request timed out after 30s'));
    });

    form.pipe(req);
  });
}

module.exports = { transcribeAudio };
