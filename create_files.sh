#!/usr/bin/env bash
set -e

# Script: crea archivos scaffold y hace commit/push
# Úsalo solo en un repo clonado (origin ya configurado).
# Ejecuta: chmod +x create_files.sh && ./create_files.sh

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "ERROR: ejecuta este script dentro de un repositorio git clonado (remote origin debe existir)."
  exit 1
fi

BRANCH="main"
REMOTE="$(git remote -v | awk '/origin/ {print $2; exit}')"
if [ -z "$REMOTE" ]; then
  echo "ERROR: no se ha encontrado remote 'origin'. Añade el remote y vuelve a ejecutar."
  exit 1
fi

echo "Creando estructura de ficheros..."

# README.md
cat > README.md <<'EOF'
# ia-materiales-bot

Prototipo modular para gestionar peticiones de materiales vía Telegram/WhatsApp con un agente IA.
- Arquitectura: Ports & Adapters (hexagonal). LLM provider y Inventory adapter intercambiables.
- Inicialmente usa providers remotos gratuitos o con free tiers (Hugging Face, Replicate, OpenAI si tienes créditos).
- Incluye Docker, docker-compose y CI (GitHub Actions).

Características principales
- Webhooks para Telegram y WhatsApp Cloud API.
- Pipeline: parse (LLM) -> lookup (inventory adapter) -> response.
- Mock inventory adapter por defecto, fácil de sustituir por CSV / ERP adapter.
- LLM providers: Stub (por defecto), OpenAI, Hugging Face.

Requisitos
- Node 18+, npm
- Docker + docker-compose (opcional)
- ngrok (para exponer webhooks en dev)
- Opcional: gh (GitHub CLI) para crear el repo

Cómo ejecutar (local)
1. Copia .env.example a .env y completa variables.
2. npm install
3. npm run dev
4. Exponer local: ngrok http 3000
5. Configurar webhook en Telegram:
   https://api.telegram.org/bot<TOKEN>/setWebhook?url=https://<tu-ngrok>/telegram
6. Enviar mensajes al bot y ver respuestas automáticas.

Docker
- docker-compose up --build

CI
- GitHub Actions: lint y build en cada push al main.

Seguridad
- Revoca cualquier token expuesto.
- No enviar PII innecesaria a proveedores externos.
- Para producción, considera modelos on-premise o proveedores con residencia EU.
EOF

# package.json
cat > package.json <<'EOF'
{
  "name": "ia-materiales-bot",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "dev": "ts-node-dev --respawn --transpile-only src/index.ts",
    "build": "tsc",
    "start": "node dist/index.js",
    "lint": "eslint . --ext .ts"
  },
  "dependencies": {
    "axios": "^1.5.0",
    "body-parser": "^1.20.2",
    "dotenv": "^16.0.0",
    "express": "^4.18.2"
  },
  "devDependencies": {
    "@types/express": "^4.17.21",
    "@types/node": "^20.0.0",
    "ts-node-dev": "^2.0.0",
    "typescript": "^5.0.0"
  }
}
EOF

# .env.example
cat > .env.example <<'EOF'
# Configuración LLM
LLM_PROVIDER=stub
OPENAI_API_KEY=
OPENAI_MODEL=gpt-4o

# Hugging Face (opcional)
HUGGINGFACE_API_KEY=
HUGGINGFACE_MODEL=

# Telegram
TELEGRAM_BOT_TOKEN=

# WhatsApp Cloud API
WHATSAPP_TOKEN=
WHATSAPP_PHONE_ID=
WHATSAPP_VERIFY_TOKEN=your_verify_token

# Server
PORT=3000
EOF

# .gitignore
cat > .gitignore <<'EOF'
node_modules
dist
.env
.env.local
.DS_Store
coverage
EOF

# tsconfig.json
cat > tsconfig.json <<'EOF'
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "CommonJS",
    "outDir": "dist",
    "rootDir": "src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true
  },
  "exclude": ["node_modules", "dist"]
}
EOF

# Dockerfile
cat > Dockerfile <<'EOF'
FROM node:18-alpine

WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
ENV NODE_ENV=production
RUN npm run build
EXPOSE 3000
CMD ["node", "dist/index.js"]
EOF

# docker-compose.yml
cat > docker-compose.yml <<'EOF'
version: "3.8"
services:
  app:
    build: .
    ports:
      - "3000:3000"
    environment:
      - PORT=3000
    volumes:
      - ./:/app
    command: npm run dev
EOF

# GitHub Actions CI
mkdir -p .github/workflows
cat > .github/workflows/ci.yml <<'EOF'
name: CI

on:
  push:
    branches: [ "main" ]
  pull_request:
    branches: [ "main" ]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Use Node.js 18
        uses: actions/setup-node@v4
        with:
          node-version: 18
      - name: Install dependencies
        run: npm ci
      - name: TypeScript build
        run: npm run build
      - name: Run linter (if configured)
        run: npm run lint || true
EOF

# src files
mkdir -p src/llm/providers src/inventory src/messaging src/pipeline src/types

cat > src/types/index.ts <<'EOF'
export type ParsedRequest = {
  material: string | null;
  quantity: number | null;
  unit: string | null;
  location: string | null;
  needed_by: string | null;
  urgency: "low" | "medium" | "high" | null;
  notes: string;
  clarify: string[];
};
EOF

cat > src/llm/LLMProvider.ts <<'EOF'
import { ParsedRequest } from "../types";

export interface LLMProvider {
  parseRequest(text: string): Promise<ParsedRequest | null>;
  generateReply?(context: { parsed: ParsedRequest | null; itemMatch?: any }): Promise<string>;
}
EOF

cat > src/llm/providers/StubProvider.ts <<'EOF'
import { LLMProvider } from "../LLMProvider";
import { ParsedRequest } from "../../types";

export class StubProvider implements LLMProvider {
  async parseRequest(text: string): Promise<ParsedRequest | null> {
    const t = (text || "").toLowerCase();
    const qtyMatch = t.match(/(\\d+)\\s*(uds|unidades|unidad|kg|sacos|saco)?/);
    const qty = qtyMatch ? parseInt(qtyMatch[1], 10) : null;
    const materialCandidates = ["planchas de yeso", "tornillos", "cemento", "cemento saco 25kg"];
    const found = materialCandidates.find(m => t.includes(m) || (m.split(' ')[0] && t.includes(m.split(' ')[0])));
    return {
      material: found || null,
      quantity: qty,
      unit: qtyMatch ? (qtyMatch[2] || "unidades") : null,
      location: t.includes("planta 2") ? "planta 2" : null,
      needed_by: null,
      urgency: null,
      notes: "",
      clarify: qty ? [] : ["quantity"]
    };
  }

  async generateReply({ parsed, itemMatch }: { parsed: ParsedRequest | null; itemMatch?: any; }): Promise<string> {
    if (!parsed) return "No he entendido la petición, ¿puedes repetirla?";
    if (parsed.clarify && parsed.clarify.length > 0) {
      return `Necesito aclaración sobre: ${parsed.clarify.join(", ")}.`;
    }
    if (!itemMatch) {
      return `No encuentro "${parsed.material}" en el inventario. ¿Puedes confirmar el nombre?`;
    }
    if (!parsed.quantity) {
      return `He encontrado "${itemMatch.item.name}" en ${itemMatch.item.location}. ¿Qué cantidad necesitas? Hay ${itemMatch.item.quantity} disponibles.`;
    }
    const success = itemMatch.item.quantity >= parsed.quantity;
    if (success) {
      return `Reservado ${parsed.quantity} de "${itemMatch.item.name}". Quedan ${itemMatch.item.quantity - parsed.quantity}.`;
    } else {
      return `No hay suficiente stock de "${itemMatch.item.name}". Disponible: ${itemMatch.item.quantity}.`;
    }
  }
}
EOF

cat > src/llm/providers/OpenAIProvider.ts <<'EOF'
import axios from "axios";
import { LLMProvider } from "../LLMProvider";
import { ParsedRequest } from "../../types";
import { config } from "../../config";

export class OpenAIProvider implements LLMProvider {
  async parseRequest(text: string): Promise<ParsedRequest | null> {
    if (!config.openaiKey) return null;
    const system = "Eres un extractor. Devuelve SOLO JSON según el schema definido.";
    const resp = await axios.post(
      "https://api.openai.com/v1/chat/completions",
      {
        model: config.openaiModel,
        messages: [
          { role: "system", content: system },
          { role: "user", content: `Entrada: "${text}"\\n\\nSalida:` }
        ],
        temperature: 0
      },
      {
        headers: { Authorization: `Bearer ${config.openaiKey}` }
      }
    );
    const content = resp.data.choices?.[0]?.message?.content || "";
    try {
      const jsonStart = content.indexOf("{");
      const jsonText = content.slice(jsonStart);
      const data = JSON.parse(jsonText);
      return data as ParsedRequest;
    } catch (e) {
      console.error("OpenAI parse error:", e, "raw:", content);
      return null;
    }
  }

  async generateReply({ parsed, itemMatch }: { parsed: ParsedRequest | null; itemMatch?: any; }): Promise<string> {
    if (!parsed) return "No he entendido la petición. ¿Puedes reformularla?";
    if (parsed.clarify && parsed.clarify.length > 0) {
      return `Necesito aclaración sobre: ${parsed.clarify.join(", ")}.`;
    }
    if (!itemMatch) {
      return `No he encontrado el material "${parsed.material}" en el inventario. ¿Puedes confirmar el nombre?`;
    }
    if (!parsed.quantity) {
      return `He encontrado "${itemMatch.item.name}" en ${itemMatch.item.location}. ¿Qué cantidad necesitas? Actualmente hay ${itemMatch.item.quantity} disponibles.`;
    }
    const success = itemMatch.item.quantity >= parsed.quantity;
    if (success) {
      return `OK: He reservado ${parsed.quantity} de "${itemMatch.item.name}" (SKU ${itemMatch.item.id}). Quedan ${itemMatch.item.quantity - parsed.quantity} en ${itemMatch.item.location}.`;
    } else {
      return `No hay suficiente stock de "${itemMatch.item.name}". Disponible: ${itemMatch.item.quantity}. ¿Deseas reservar esa cantidad o crear un pedido de reposición?`;
    }
  }
}
EOF

cat > src/llm/providers/HuggingFaceProvider.ts <<'EOF'
import axios from "axios";
import { LLMProvider } from "../LLMProvider";
import { ParsedRequest } from "../../types";
import { config } from "../../config";

export class HuggingFaceProvider implements LLMProvider {
  private hfUrl(model: string) {
    return `https://api-inference.huggingface.co/models/${model}`;
  }

  private async callModel(model: string, prompt: string) {
    const url = this.hfUrl(model);
    const headers: any = { Authorization: `Bearer ${config.huggingfaceKey}` };
    const resp = await axios.post(url, { inputs: prompt, options: { wait_for_model: true } }, { headers });
    if (typeof resp.data === "string") return resp.data;
    if (Array.isArray(resp.data) && resp.data[0]?.generated_text) return resp.data[0].generated_text;
    if (resp.data.generated_text) return resp.data.generated_text;
    return JSON.stringify(resp.data);
  }

  async parseRequest(text: string): Promise<ParsedRequest | null> {
    if (!config.huggingfaceKey || !config.huggingfaceModel) return null;
    const prompt = `Eres un extractor. Devuelve SOLO JSON con schema:
{
  "material":"string|null","quantity":number|null,"unit":"string|null","location":"string|null",
  "needed_by":"YYYY-MM-DD|null","urgency":"low|medium|high|null","notes":"string","clarify":[]
}
Entrada: "${text}"
Salida:`;
    try {
      const out = await this.callModel(config.huggingfaceModel, prompt);
      const jsonStart = out.indexOf("{");
      const jsonText = out.slice(jsonStart);
      const data = JSON.parse(jsonText);
      return data as ParsedRequest;
    } catch (e) {
      console.error("HuggingFace parse error:", e);
      return null;
    }
  }

  async generateReply({ parsed, itemMatch }: { parsed: ParsedRequest | null; itemMatch?: any; }): Promise<string> {
    if (!parsed) return "No he entendido la petición. ¿Puedes reformularla?";
    if (parsed.clarify && parsed.clarify.length > 0) {
      return `Necesito aclaración sobre: ${parsed.clarify.join(", ')}.`;
    }
    if (!itemMatch) {
      return `No he encontrado el material "${parsed.material}" en el inventario. ¿Puedes confirmar el nombre?`;
    }
    if (!parsed.quantity) {
      return `He encontrado "${itemMatch.item.name}" en ${itemMatch.item.location}. ¿Qué cantidad necesitas? Actualmente hay ${itemMatch.item.quantity} disponibles.`;
    }
    const success = itemMatch.item.quantity >= parsed.quantity;
    if (success) {
      return `OK: He reservado ${parsed.quantity} de "${itemMatch.item.name}" (SKU ${itemMatch.item.id}). Quedan ${itemMatch.item.quantity - parsed.quantity} en ${itemMatch.item.location}.`;
    } else {
      return `No hay suficiente stock de "${itemMatch.item.name}". Disponible: ${itemMatch.item.quantity}. ¿Deseas reservar esa cantidad o crear un pedido de reposición?`;
    }
  }
}
EOF

cat > src/inventory/InventoryAdapter.ts <<'EOF'
export interface InventoryAdapter {
  getItemByName(name: string): Promise<{ item: any; score: number } | null>;
  reserveItem(id: string, qty: number): Promise<{ success: boolean; available: number }>;
}
EOF

cat > src/inventory/MockInventoryAdapter.ts <<'EOF'
import { InventoryAdapter } from "./InventoryAdapter";

const items = [
  { id: "SKU-001", name: "planchas de yeso", aliases: ["yeso", "planchas yeso"], quantity: 50, location: "almacén A" },
  { id: "SKU-002", name: "tornillos 4mm", aliases: ["tornillos","tornillo"], quantity: 200, location: "almacén B" },
  { id: "SKU-003", name: "cemento saco 25kg", aliases: ["cemento 25kg","saco cemento"], quantity: 30, location: "almacén A" }
];

function normalize(s?: string) {
  return (s||"").toLowerCase().trim();
}
function fuzzyScore(a: string, b: string) {
  a = normalize(a);
  b = normalize(b);
  if (a === b) return 1.0;
  if (a.includes(b) || b.includes(a)) return 0.8;
  return 0.0;
}

export class MockInventoryAdapter implements InventoryAdapter {
  async getItemByName(name: string) {
    if (!name) return null;
    let best: any = null;
    for (const it of items) {
      const scoreName = fuzzyScore(it.name, name);
      let bestAlias = 0;
      for (const al of it.aliases || []) {
        bestAlias = Math.max(bestAlias, fuzzyScore(al, name));
      }
      const score = Math.max(scoreName, bestAlias);
      if (!best || score > best.score) {
        best = { item: it, score };
      }
    }
    if (best && best.score >= 0.6) return best;
    return null;
  }

  async reserveItem(id: string, qty: number) {
    const it = items.find(x => x.id === id);
    if (!it) return { success: false, available: 0 };
    if (it.quantity >= qty) {
      it.quantity -= qty;
      return { success: true, available: it.quantity };
    } else {
      return { success: false, available: it.quantity };
    }
  }
}
EOF

cat > src/pipeline/processor.ts <<'EOF'
import { LLMProvider } from "../llm/LLMProvider";
import { InventoryAdapter } from "../inventory/InventoryAdapter";
import { ParsedRequest } from "../types";

export class Processor {
  constructor(private llm: LLMProvider, private inventory: InventoryAdapter) {}

  async handleIncomingText(text: string) {
    const parsed: ParsedRequest | null = await this.llm.parseRequest(text);
    const match = parsed && parsed.material ? await this.inventory.getItemByName(parsed.material) : null;
    if (this.llm.generateReply) {
      return this.llm.generateReply({ parsed, itemMatch: match });
    }
    if (!parsed) return "No he entendido la petición.";
    if (parsed.clarify && parsed.clarify.length > 0) return `Necesito aclaración: ${parsed.clarify.join(", ")}`;
    if (!match) return `No encuentro "${parsed.material}" en el inventario.`;
    if (!parsed.quantity) return `Hay ${match.item.quantity} de "${match.item.name}" en ${match.item.location}. ¿Cuántas necesitas?`;
    const reserve = await this.inventory.reserveItem(match.item.id, parsed.quantity);
    if (reserve.success) return `Reservado ${parsed.quantity} de "${match.item.name}". Quedan ${reserve.available}.`;
    return `No hay suficiente stock. Disponible: ${reserve.available}.`;
  }
}
EOF

cat > src/messaging/telegramAdapter.ts <<'EOF'
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
EOF

cat > src/messaging/whatsappAdapter.ts <<'EOF'
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
EOF

cat > src/config.ts <<'EOF'
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
EOF

cat > src/index.ts <<'EOF'
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
  # fallback
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
EOF

echo "Archivos creados."

# Add, commit and push
git checkout -b "$BRANCH" || git checkout "$BRANCH" || git checkout -B "$BRANCH"
git add .
git commit -m "Initial scaffold: TypeScript scaffold, Docker, CI, Telegram/WhatsApp adapters, mock inventory"
git push -u origin "$BRANCH"

echo "Hecho: cambios añadidos y empujados a $REMOTE (branch: $BRANCH)."
echo "Siguiente: copia .env.example a .env, instala dependencias (npm install) y ejecuta npm run dev."