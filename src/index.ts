import express from "express";
import bodyParser from "body-parser";
import { config } from "./config";
import { StubProvider } from "./llm/providers/StubProvider";
import { OpenAIProvider } from "./llm/providers/OpenAIProvider";
import { HuggingFaceProvider } from "./llm/providers/HuggingFaceProvider";
import { MockInventoryAdapter } from "./inventory/MockInventoryAdapter";
import { Processor } from "./pipeline/processor";
import { telegramRouter } from "./messaging/telegramAdapter";
import { whatsappRouter } from "./messaging/whatsappAdapter";
import axios from "axios";

const app = express();
app.use(bodyParser.json());

async function createProviders() {
  if (config.llmProvider === "stub") {
    return { llm: new StubProvider(), inventory: new MockInventoryAdapter() };
  }
  if (config.llmProvider === "openai") {
    return { llm: new OpenAIProvider(), inventory: new MockInventoryAdapter() };
  }
  if (config.llmProvider === "huggingface") {
    return { llm: new HuggingFaceProvider(), inventory: new MockInventoryAdapter() };
  }
  // fallback
  return { llm: new StubProvider(), inventory: new MockInventoryAdapter() };
}

(async () => {
  const { llm, inventory } = await createProviders();
  const processor = new Processor(llm as any, inventory as any);

  async function processText(text: string, replyTo: { chatId?: string; phone?: string }) {
    try {
      const reply = await processor.handleIncomingText(text);
      if (replyTo.chatId) {
        await axios.post(`http://localhost:${config.port}/send/telegram`, { chatId: replyTo.chatId, text: reply });
      } else if (replyTo.phone) {
        await axios.post(`http://localhost:${config.port}/send/whatsapp`, { phone: replyTo.phone, text: reply });
      }
    } catch (e) {
      console.error("processText error", e);
    }
  }

  app.use("/", telegramRouter(processText, config.telegramBotToken));
  app.use("/", whatsappRouter(processText, { token: config.whatsappToken, phoneId: config.whatsappPhoneId, verifyToken: config.whatsappVerifyToken }));

  app.get("/health", (_req, res) => res.send({ ok: true }));

  app.listen(config.port, () => console.log(`Server running on ${config.port}`));
})();
