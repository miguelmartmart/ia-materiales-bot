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
    if (!parsed) return "No he entendido la peticiÃ³n. Â¿Puedes reformularla?";
    if (parsed.clarify && parsed.clarify.length > 0) {
      return `Necesito aclaraciÃ³n sobre: ${parsed.clarify.join(", ')}.`;
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
