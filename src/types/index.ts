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
