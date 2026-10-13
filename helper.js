const SYSTEM = `You are CivicLens Helper, a careful civic-information assistant for Maharashtra, India. Help people describe civic issues, choose sensible next steps, and stay safe. Be concise, practical, and kind. Do not claim to file official complaints or contact authorities. Do not invent phone numbers, department links, laws, or current government processes. For immediate danger, tell the user to move to safety and contact India's emergency number 112. For electrical wires, flooding, open manholes, unstable roads, fire, or hazardous waste, do not advise approaching or touching the hazard. Explain that advice is general and not an official municipal response. Answer in the language the user uses when feasible.`;
module.exports = async (req, res) => {
  res.setHeader('Content-Type', 'application/json; charset=utf-8');
  res.setHeader('Cache-Control', 'no-store');
  if (req.method !== 'POST') { res.setHeader('Allow', 'POST'); return res.status(405).json({ error: 'Use POST.' }); }
  const message = typeof req.body?.message === 'string' ? req.body.message.trim().slice(0, 1200) : '';
  if (!message) return res.status(400).json({ error: 'Please enter a question.' });
  const key = process.env.OPENAI_API_KEY;
  if (!key) return res.status(503).json({ error: 'AI helper is not configured yet. Add OPENAI_API_KEY in Vercel Environment Variables and redeploy. You can still browse and submit civic reports.' });
  try {
    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST', headers: { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ model: process.env.OPENAI_MODEL || 'gpt-4o-mini', temperature: 0.3, max_tokens: 450,
        messages: [{ role: 'system', content: SYSTEM }, { role: 'user', content: message }] })
    });
    const data = await response.json();
    if (!response.ok) return res.status(502).json({ error: 'The AI service could not answer just now. Please try again later.' });
    return res.status(200).json({ answer: data.choices?.[0]?.message?.content || 'Sorry, I could not prepare an answer.' });
  } catch (e) { return res.status(502).json({ error: 'Could not reach the AI service. Please try again.' }); }
};
