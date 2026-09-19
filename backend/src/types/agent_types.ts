export type Locale = 'en' | 'ru' | 'kk';

export interface AgentMessage {
  role: 'user' | 'assistant';
  content: string;
}

export interface AgentRequest {
  message: string;
  locale?: Locale;
  lifeContext?: Record<string, unknown>;
  agentContext?: Record<string, unknown>;
  conversation?: AgentMessage[];
}
