import { LLMProvider } from "../LLMProvider";
import { ParsedRequest } from "../../types";

export class StubProvider implements LLMProvider {
  async parseRequest(text: string): Promise<ParsedRequest | null> {
    const t = (text || "").toLowerCase();
    const qtyMatch = t.match(/(\d+)\s*(uds|unidades|unidad|kg|sacos|saco)?/);
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
    if (!parsed) return "No he entendido la peticiÃ³n, Â¿puedes repetirla?";
    if (parsed.clarify && parsed.clarify.length > 0) {
      return `Necesito aclaraciÃ³n sobre: ${parsed.clarify.join(", ")}.`;
    }
    if (!itemMatch) {
      return `No encuentro "${parsed.material}" en el inventario. Â¿Puedes confirmar el nombre?`;
    }
    if (!parsed.quantity) {
      return `He encontrado "${itemMatch.item.name}" en ${itemMatch.item.location}. Â¿QuÃ© cantidad necesitas? Hay ${itemMatch.item.quantity} disponibles.`;
    }
    const success = itemMatch.item.quantity >= parsed.quantity;
    if (success) {
      return `Reservado ${parsed.quantity} de "${itemMatch.item.name}". Quedan ${itemMatch.item.quantity - parsed.quantity}.`;
    } else {
      return `No hay suficiente stock de "${itemMatch.item.name}". Disponible: ${itemMatch.item.quantity}.`;
    }
  }
}
