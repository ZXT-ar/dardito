export type Channel = "web" | "whatsapp";
export type EvidenceLevel = "documented" | "oral_tradition" | "community";

export interface CorpusItem {
  id: string;
  title: string;
  summary: string;
  body: string;
  category: string;
  neighborhood: string;
  period?: string;
  evidence: EvidenceLevel;
  sourceName?: string;
  sourceUrl?: string;
  keywords: string[];
  status: "published" | "draft" | "archived";
}

export interface ChatTurn {
  role: "user" | "model";
  text: string;
}

export interface ChatRequest {
  message: string;
  conversationId?: string;
  participantId?: string;
  channel: Channel;
  corpus?: CorpusItem[];
}

export interface ChatSource {
  id: string;
  title: string;
  evidence: EvidenceLevel;
  sourceName?: string;
  sourceUrl?: string;
}

export interface ChatResponse {
  answer: string;
  conversationId: string;
  sources: ChatSource[];
}
