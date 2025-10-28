# ia-materiales-bot

Prototipo modular para gestionar peticiones de materiales vÃ­a Telegram/WhatsApp con un agente IA.
- Arquitectura: Ports & Adapters (hexagonal). LLM provider y Inventory adapter intercambiables.
- Inicialmente usa providers remotos gratuitos o con free tiers (Hugging Face, Replicate, OpenAI si tienes crÃ©ditos).
- Incluye Docker, docker-compose y CI (GitHub Actions).

CaracterÃ­sticas principales
- Webhooks para Telegram y WhatsApp Cloud API.
- Pipeline: parse (LLM) -> lookup (inventory adapter) -> response.
- Mock inventory adapter por defecto, fÃ¡cil de sustituir por CSV / ERP adapter.
- LLM providers: Stub (por defecto), OpenAI, Hugging Face.

Requisitos
- Node 18+, npm
- Docker + docker-compose (opcional)
- ngrok (para exponer webhooks en dev)
- Opcional: gh (GitHub CLI) para crear el repo

CÃ³mo ejecutar (local)
1. Copia .env.example a .env y completa variables.
2. npm install
3. npm run dev
4. Exponer local: ngrok http 3000
5. Configurar webhook en Telegram:
   https://api.telegram.org/bot<TOKEN>/setWebhook?url=https://<tu-ngrok>/telegram
6. Enviar mensajes al bot y ver respuestas automÃ¡ticas.

Docker
- docker-compose up --build

CI
- GitHub Actions: lint y build en cada push al main.

Seguridad
- Revoca cualquier token expuesto.
- No enviar PII innecesaria a proveedores externos.
- Para producciÃ³n, considera modelos on-premise o proveedores con residencia EU.
