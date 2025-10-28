export interface InventoryAdapter {
  getItemByName(name: string): Promise<{ item: any; score: number } | null>;
  reserveItem(id: string, qty: number): Promise<{ success: boolean; available: number }>;
}
