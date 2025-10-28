import { ParsedRequest } from "../types";

export interface LLMProvider {
  parseRequest(text: string): Promise<ParsedRequest | null>;
  generateReply?(context: { parsed: ParsedRequest | null; itemMatch?: any }): Promise<string>;
}
