import cors from 'cors';
import dotenv from 'dotenv';
import express from 'express';
import { randomUUID } from 'node:crypto';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { OrtaAgent } from './agent/orta_agent.js';
import type { AgentRequest } from './types/agent_types.js';

const backendRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const envPath = resolve(backendRoot, '.env');
dotenv.config({ path: envPath });

const app = express();
const port = Number(process.env.PORT ?? 3000);
const openAiConfigured = Boolean(process.env.OPENAI_API_KEY);
const agent = new OrtaAgent(process.env.OPENAI_API_KEY);

app.use(cors());
app.use(express.json({ limit: '256kb' }));

app.get('/health', (_request, response) => response.json({ status: 'ok' }));

app.post('/api/agent/message', async (request, response) => {
  const requestId = randomUUID();
  const body = request.body as Partial<AgentRequest> | undefined;
  if (!body || typeof body.message !== 'string' || body.message.trim().length === 0) {
    return response.status(400).json({ error: 'message is required', requestId });
  }

  try {
    const message = await agent.respond({
      message: body.message.trim(),
      locale: body.locale,
      lifeContext: body.lifeContext,
      agentContext: body.agentContext,
      conversation: body.conversation,
    });
    return response.json({ message, requestId });
  } catch (error) {
    const safeMessage = classifyProviderError(error);
    console.error(`[${requestId}] ${safeMessage}`);
    return response.status(503).json({ error: safeMessage, requestId });
  }
});

app.listen(port, () => {
  console.log(`ORTA backend listening on http://localhost:${port}`);
  console.log(`OpenAI configured: ${openAiConfigured ? 'yes' : 'no'}`);
});

function classifyProviderError(error: unknown): string {
  if (error instanceof Error && error.message === 'OPENAI_API_KEY is not configured') {
    return 'AI backend is not configured';
  }

  const status = typeof error === 'object' && error !== null && 'status' in error
    ? (error as { status?: unknown }).status
    : undefined;
  if (status === 401) return 'OpenAI authentication failed';
  if (status === 404) return 'OpenAI model or endpoint was not found';
  if (status === 429) return 'OpenAI rate limit or quota exceeded';
  if (error instanceof Error && (error.name === 'APIConnectionError' || error.name === 'APIConnectionTimeoutError')) {
    return 'OpenAI provider connection failed';
  }
  return 'OpenAI provider request failed';
}
