import axios from "axios";
import { LLMProvider } from "../LLMProvider";
import { ParsedRequest } from "../../types";
import { config } from "../../config";

export class OpenAIProvider implements LLMProvider {
  async parseRequest(text: string): Promise<ParsedRequest | null> {
    if (!config.openaiKey) return null;
    const system = "Eres un extractor. Devuelve SOLO JSON segÃºn el schema definido.";
    const resp = await axios.post(
      "https://api.openai.com/v1/chat/completions",
      {
        model: config.openaiModel,
        messages: [
          { role: "system", content: system },
          { role: "user", content: `Entrada: "${text}\n\nSalida:` }
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
    if (!parsed) return "No he entendido la peticiÃ³n. Â¿Puedes reformularla?";
    if (parsed.clarify && parsed.clarify.length > 0) {
      return `Necesito aclaraciÃ³n sobre: ${parsed.clarify.join(", ")}.`;
    }
    if (!itemMatch) {
      return `No he encontrado el material "${parsed.material}" en el inventario. Â¿Puedes confirmar el nombre?`;
    }
    if (!parsed.quantity) {
      return `He encontrado "${itemMatch.item.name}" en ${itemMatch.item.location}. Â¿QuÃ© cantidad necesitas? Actualmente hay ${itemMatch.item.quantity} disponibles.`;
    }
    const success = itemMatch.item.quantity >= parsed.quantity;
    if (success) {
      return `OK: He reservado ${parsed.quantity} de "${itemMatch.item.name}" (SKU ${itemMatch.item.id}). Quedan ${itemMatch.item.quantity - parsed.quantity} en ${itemMatch.item.location}.`;
    } else {
      return `No hay suficiente stock de "${itemMatch.item.name}". Disponible: ${itemMatch.item.quantity}. Â¿Deseas reservar esa cantidad o crear un pedido de reposiciÃ³n?`;
    }
  }
}
