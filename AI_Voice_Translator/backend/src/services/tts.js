const OpenAI = require('openai');

const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });

async function synthesizeSpeech(text, voice = null) {
  const selectedVoice = voice || process.env.TTS_VOICE || 'nova';
  const response = await openai.audio.speech.create({
    model: 'tts-1',
    voice: selectedVoice,
    input: text.trim(),
    response_format: 'mp3',
    speed: 1.0,
  });
  return Buffer.from(await response.arrayBuffer());
}

module.exports = { synthesizeSpeech };
