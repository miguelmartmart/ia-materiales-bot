import express from "express";
import axios from "axios";

export function whatsappRouter(processText: (text: string, replyTo: { phone: string }) => Promise<void>, config: { token?: string; phoneId?: string; verifyToken?: string } = {}) {
  const router = express.Router();

  router.get("/whatsapp", (req, res) => {
    const mode = req.query["hub.mode"];
    const token = req.query["hub.verify_token"];
    const challenge = req.query["hub.challenge"];
    if (mode && token) {
      if (token === config.verifyToken) {
        return res.status(200).send(challenge);
      } else {
        return res.sendStatus(403);
      }
    }
    res.sendStatus(200);
  });

  router.post("/whatsapp", async (req, res) => {
    const entry = req.body.entry?.[0];
    const changes = entry?.changes?.[0];
    const messageObj = changes?.value?.messages?.[0];
    if (!messageObj) return res.sendStatus(200);
    const from = messageObj.from;
    const text = messageObj.text?.body || "";
    await processText(text, { phone: from });
    res.sendStatus(200);
  });

  router.post("/send/whatsapp", async (req, res) => {
    if (!config.token || !config.phoneId) return res.status(500).send("No WHATSAPP config");
    const { phone, text } = req.body;
    const url = `https://graph.facebook.com/v17.0/${config.phoneId}/messages`;
    await axios.post(url, {
      messaging_product: "whatsapp",
      to: phone,
      text: { body: text }
    }, {
      headers: { Authorization: `Bearer ${config.token}` }
    });
    res.sendStatus(200);
  });

  return router;
}
