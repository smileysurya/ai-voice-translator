const { PollyClient, SynthesizeSpeechCommand } = require("@aws-sdk/client-polly");

async function synthesizeWithPolly(text, targetLang) {
  const apiKey = process.env.AWS_ACCESS_KEY_ID;
  if (!apiKey) {
    console.warn('⚠️ AWS credentials not set, skipping Polly TTS');
    return null;
  }

  const client = new PollyClient({
    region: process.env.AWS_REGION || "us-east-1",
    credentials: {
      accessKeyId: process.env.AWS_ACCESS_KEY_ID,
      secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
    },
  });

  // Map our language codes to Polly VoiceIds (simplified mapping)
  const voiceMapping = {
    'en': 'Joanna',
    'es': 'Lucia',
    'fr': 'Lea',
    'de': 'Vicki',
    'it': 'Bianca',
    'pt': 'Camila',
    'ja': 'Mizuki',
    'ko': 'Seoyeon',
    'hi': 'Aditi',
    'ru': 'Tatyana'
  };

  const params = {
    Text: text,
    OutputFormat: "mp3",
    VoiceId: voiceMapping[targetLang] || "Joanna", // Fallback to Joanna
    Engine: "neural" // Use high-quality neural engine
  };

  try {
    const command = new SynthesizeSpeechCommand(params);
    const response = await client.send(command);
    
    // Convert stream to Buffer
    const chunks = [];
    for await (let chunk of response.AudioStream) {
      chunks.push(chunk);
    }
    const buffer = Buffer.concat(chunks);
    return buffer.toString('base64');
  } catch (error) {
    console.error('❌ Amazon Polly Error:', error);
    return null;
  }
}

module.exports = { synthesizeWithPolly };
