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
    if (!parsed) return "No he entendido la peticiÃ³n.";
    if (parsed.clarify && parsed.clarify.length > 0) return `Necesito aclaraciÃ³n: ${parsed.clarify.join(", ")}`;
    if (!match) return `No encuentro "${parsed.material}" en el inventario.`;
    if (!parsed.quantity) return `Hay ${match.item.quantity} de "${match.item.name}" en ${match.item.location}. Â¿CuÃ¡ntas necesitas?`;
    const reserve = await this.inventory.reserveItem(match.item.id, parsed.quantity);
    if (reserve.success) return `Reservado ${parsed.quantity} de "${match.item.name}". Quedan ${reserve.available}.`;
    return `No hay suficiente stock. Disponible: ${reserve.available}.`;
  }
}
