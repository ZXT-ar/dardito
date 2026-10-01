export type Channel = "web" | "whatsapp";
export type EvidenceLevel = string;

export interface CorpusItem {
  id: string;
  title: string;
  summary: string;
  body: string;
  category: string;
  neighborhood: string;
  period?: string;
  subtitle?: string;
  latitude?: number;
  longitude?: number;
  featured?: boolean;
  readingMinutes?: number;
  evidence: EvidenceLevel;
  evidenceLabel?: string;
  sourceName?: string;
  sourceUrl?: string;
  keywords: string[];
  status: "published" | "draft" | "archived";
}

export interface ChatTurn {
  role: "user" | "model";
  text: string;
  /** Published stories actually used by the previous answer; never a user claim. */
  sourceIds?: string[];
}

export interface ChatRequest {
  message: string;
  conversationId?: string;
  participantId?: string;
  userId?: string;
  sessionId?: string;
  moderationScopeIds?: string[];
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
  moderation: ModerationResult;
}

export type ModerationAction = "none" | "yellow" | "red" | "blocked";
export type ModerationCategory =
  | "harassment"
  | "sexual_anatomy"
  | "obscene_request"
  | "weapons_instructions"
  | "graphic_violence"
  | "credible_threat"
  | "sexual_minors";

export interface ModerationResult {
  action: ModerationAction;
  yellowCount: number;
  yellowLimit: 3;
  categories: ModerationCategory[];
  blockedUntil?: string;
}
