import { InventoryAdapter } from "./InventoryAdapter";

const items = [
  { id: "SKU-001", name: "planchas de yeso", aliases: ["yeso", "planchas yeso"], quantity: 50, location: "almacÃ©n A" },
  { id: "SKU-002", name: "tornillos 4mm", aliases: ["tornillos","tornillo"], quantity: 200, location: "almacÃ©n B" },
  { id: "SKU-003", name: "cemento saco 25kg", aliases: ["cemento 25kg","saco cemento"], quantity: 30, location: "almacÃ©n A" }
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
