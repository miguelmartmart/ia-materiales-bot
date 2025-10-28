import express from "express";
import axios from "axios";

export function telegramRouter(processText: (text: string, replyTo: { chatId: string }) => Promise<void>, botToken?: string) {
  const router = express.Router();

  router.post("/telegram", async (req, res) => {
    const body = req.body;
    const message = body.message || body.edited_message;
    if (!message) return res.sendStatus(200);
    const chatId = message.chat.id;
    const text = message.text || "";
    await processText(text, { chatId: String(chatId) });
    res.sendStatus(200);
  });

  router.post("/send/telegram", async (req, res) => {
    const { chatId, text } = req.body;
    if (!botToken) return res.status(500).send("No TELEGRAM_BOT_TOKEN configured");
    const url = `https://api.telegram.org/bot${botToken}/sendMessage`;
    await axios.post(url, { chat_id: chatId, text });
    res.sendStatus(200);
  });

  return router;
}
