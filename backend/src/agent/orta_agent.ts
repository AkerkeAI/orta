import OpenAI from 'openai';
import { buildSystemPrompt } from './system_prompt.js';
import type { AgentRequest, Locale } from '../types/agent_types.js';

const MODEL = 'gpt-5.6-terra';
const MAX_HISTORY = 12;

export class OrtaAgent {
  private readonly client?: OpenAI;

  constructor(apiKey = process.env.OPENAI_API_KEY) {
    this.client = apiKey ? new OpenAI({ apiKey }) : undefined;
  }

  async respond(request: AgentRequest): Promise<string> {
    if (!this.client) throw new Error('OPENAI_API_KEY is not configured');
    const locale: Locale = request.locale === 'ru' || request.locale === 'kk' ? request.locale : 'en';
    const history = (request.conversation ?? []).slice(-MAX_HISTORY);
    const context = JSON.stringify({ lifeContext: request.lifeContext ?? {}, agentContext: request.agentContext ?? {} });
    const input = [
      ...history.map((item) => ({ role: item.role, content: item.content })),
      { role: 'user' as const, content: `Structured context:\n${context}\n\nUser message:\n${request.message}` },
    ];
    const response = await this.client.responses.create({ model: MODEL, instructions: buildSystemPrompt(locale), input });
    const text = response.output_text?.trim();
    if (!text) throw new Error('OpenAI returned no response text');
    return text;
  }
}

export { MAX_HISTORY, MODEL };
