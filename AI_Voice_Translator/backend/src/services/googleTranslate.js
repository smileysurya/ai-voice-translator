const axios = require('axios');

async function translateWithGoogle(text, sourceLang, targetLang) {
  const apiKey = process.env.GOOGLE_TRANSLATE_API_KEY;
  if (!apiKey) {
    console.warn('⚠️ GOOGLE_TRANSLATE_API_KEY not set, falling back to original translator');
    // We could fall back to our existing GPT-based translator if needed
    const { translateText } = require('./translator');
    return translateText(text, sourceLang, targetLang);
  }

  try {
    // sourceLang 'auto' is handled by Google automatically if we omit it or set it to null
    const url = `https://translation.googleapis.com/language/translate/v2?key=${apiKey}`;
    const response = await axios.post(url, {
      q: text,
      source: sourceLang === 'auto' ? null : sourceLang,
      target: targetLang,
      format: 'text'
    });

    return response.data.data.translations[0].translatedText;
  } catch (error) {
    console.error('❌ Google Translate Error:', error.response?.data || error.message);
    // Fallback
    const { translateText } = require('./translator');
    return translateText(text, sourceLang, targetLang);
  }
}

module.exports = { translateWithGoogle };
