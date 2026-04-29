const OpenAI = require('openai');

// Groq is OpenAI-compatible — just swap the base URL and key
const groq = new OpenAI({
  apiKey: process.env.GROQ_API_KEY,
  baseURL: 'https://api.groq.com/openai/v1',
});

const LANG_NAMES = {
  auto:'detected language', en:'English', es:'Spanish', fr:'French', de:'German',
  it:'Italian', pt:'Portuguese', ru:'Russian', ja:'Japanese', ko:'Korean',
  zh:'Chinese (Simplified)', ar:'Arabic', hi:'Hindi', tr:'Turkish', pl:'Polish',
  nl:'Dutch', sv:'Swedish', da:'Danish', fi:'Finnish', cs:'Czech', hu:'Hungarian',
  ro:'Romanian', uk:'Ukrainian', el:'Greek', he:'Hebrew', th:'Thai', vi:'Vietnamese',
  id:'Indonesian', ms:'Malay', fa:'Persian', ur:'Urdu', bn:'Bengali', ta:'Tamil',
  te:'Telugu', ml:'Malayalam', kn:'Kannada', gu:'Gujarati', pa:'Punjabi',
  mr:'Marathi', sw:'Swahili', ne:'Nepali', si:'Sinhala', my:'Burmese',
  km:'Khmer', ka:'Georgian', am:'Amharic',
};

async function translateText(text, sourceLang, targetLang) {
  const tgt = LANG_NAMES[targetLang] || targetLang;
  const src = LANG_NAMES[sourceLang] || sourceLang;
  const userPrompt = sourceLang === 'auto'
    ? `Translate to ${tgt}:\n${text}`
    : `Translate from ${src} to ${tgt}:\n${text}`;

  const resp = await groq.chat.completions.create({
    model: 'llama-3.3-70b-versatile',  // Groq's free fast LLM
    messages: [
      { role: 'system', content: 'You are a professional translator. Return ONLY the translated text, no explanations, no quotes.' },
      { role: 'user', content: userPrompt },
    ],
    temperature: 0.2,
    max_tokens: 2048,
  });
  return resp.choices[0].message.content.trim();
}

module.exports = { translateText, LANG_NAMES };
