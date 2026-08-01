// Vercel serverless function — holds the API key server-side.
// The browser never sees it. Set ANTHROPIC_API_KEY in Vercel → Settings → Environment Variables.

export default async function handler(req, res) {
  if (req.method !== "POST") {
    return res.status(405).json({ error: "POST only" });
  }

  const key = process.env.ANTHROPIC_API_KEY;
  if (!key) {
    return res.status(500).json({
      error: "ANTHROPIC_API_KEY is not set on the server."
    });
  }

  const { prompt, max_tokens } = req.body || {};
  if (!prompt || typeof prompt !== "string") {
    return res.status(400).json({ error: "Missing prompt." });
  }
  if (prompt.length > 60000) {
    return res.status(413).json({ error: "Dictation is too long. Split it in half." });
  }

  try {
    const r = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": key,
        "anthropic-version": "2023-06-01"
      },
      body: JSON.stringify({
        model: "claude-sonnet-4-6",
        max_tokens: Math.min(Math.max(parseInt(max_tokens) || 2000, 256), 4000),
        messages: [{ role: "user", content: prompt }]
      })
    });

    const data = await r.json();

    if (!r.ok) {
      // surface the model API's own message, not a generic 500
      return res.status(r.status).json({
        error: (data && data.error && data.error.message) || `Upstream error ${r.status}`
      });
    }

    // Return only the text. No dictation, no output, nothing logged.
    const text = (data.content || [])
      .filter(b => b.type === "text")
      .map(b => b.text)
      .join("");

    return res.status(200).json({ text });
  } catch (err) {
    return res.status(502).json({ error: "Could not reach the model API." });
  }
}
