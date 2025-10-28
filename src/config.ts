import dotenv from "dotenv";
dotenv.config();

export const config = {
  port: Number(process.env.PORT || 3000),
  telegramBotToken: process.env.TELEGRAM_BOT_TOKEN,
  whatsappToken: process.env.WHATSAPP_TOKEN,
  whatsappPhoneId: process.env.WHATSAPP_PHONE_ID,
  whatsappVerifyToken: process.env.WHATSAPP_VERIFY_TOKEN,
  llmProvider: process.env.LLM_PROVIDER || "stub",
  openaiKey: process.env.OPENAI_API_KEY,
  openaiModel: process.env.OPENAI_MODEL || "gpt-4o",
  huggingfaceKey: process.env.HUGGINGFACE_API_KEY,
  huggingfaceModel: process.env.HUGGINGFACE_MODEL
};
