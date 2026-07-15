// MYASSISTANT backend — Month 1 stub
// Run: npm install && ANTHROPIC_API_KEY=sk-... node server.js
// Deploy to an India region (AWS Mumbai / GCP Mumbai) per Section 5.1.

const express = require("express");
const app = express();
app.use(express.json({ limit: "2mb" }));

// ---------------------------------------------------------------
// /config — THE UPDATE SWITCHBOARD.
// Edit this object (or move it to a database) and every installed
// app sees the change on next launch. New AI features go live here
// with zero Play Store releases, because the AI itself runs below
// in /chat — the app is just the window to it.
// ---------------------------------------------------------------
const REMOTE_CONFIG = {
  latestVersionCode: 1,
  latestVersionName: "0.1.0",
  forceUpdateBelow: 0,
  changelog: ["First internal build — chat with live AI"],
  announcement: null, // e.g. "New: Hindi voice replies are live!"
  features: {
    voice_mode: false,     // flip true when A2 ships
    morning_briefing: false,
    photo_questions: false,
  },
};

app.get("/config", (req, res) => res.json(REMOTE_CONFIG));

// ---------------------------------------------------------------
// /chat — all AI traffic flows through here. The app never sees
// provider keys. Add the second provider + safety rules here.
// ---------------------------------------------------------------
app.post("/chat", async (req, res) => {
  try {
    const { messages } = req.body;
    const r = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-api-key": process.env.ANTHROPIC_API_KEY,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify({
        model: "claude-sonnet-4-6",
        max_tokens: 1024,
        system:
          "You are MyAssistant, a helpful personal assistant for Indian users. " +
          "Reply in the user's language (English, Hindi, Malayalam or others). Be concise and warm.",
        messages: messages.map((m) => ({ role: m.role, content: m.content })),
      }),
    });
    const data = await r.json();
    const reply = (data.content || [])
      .filter((b) => b.type === "text")
      .map((b) => b.text)
      .join("\n");
    res.json({ reply: reply || "Sorry, I couldn't answer that.", sources: [] });
  } catch (e) {
    console.error(e);
    res.status(500).json({ reply: "Server error", sources: [] });
  }
});

app.listen(process.env.PORT || 3000, () =>
  console.log("MYASSISTANT backend running")
);
