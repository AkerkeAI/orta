import cors from 'cors';
import express from 'express';
import { randomUUID } from 'node:crypto';
import { OrtaAgent } from './agent/orta_agent.js';
import { ProviderError, type GroqProvider } from './agent/ai_provider.js';
import { registry } from './agent/tool_registry.js';
import type { AgentRequest } from './types/agent_types.js';
import { LanguageCoach, defaultStudentGate, validLanguagePracticeRequest } from './language/language_practice.js';

export interface AppDependencies {
  coach?: LanguageCoach;
  studentGate?: typeof defaultStudentGate;
  visionAI?: GroqProvider;
}

const safeErrors = {
  not_configured: 'AI backend is not configured. Check the backend provider settings.',
  authentication: 'Groq authentication failed. Check the key in backend/.env.',
  model_unavailable: 'The configured Groq model is unavailable for this account.',
  rate_limit: 'Groq usage limit reached. Wait before trying again.',
  network: 'Could not reach the AI provider. Check the connection and try again.',
  invalid_response: 'The AI provider returned an invalid or incomplete response. Try again.',
  provider_error: 'The AI provider could not complete the request. Try again.',
  request_too_large: 'This request is too large for the current AI limit. Try a shorter request or a new conversation.',
};

function trustedOrigin(origin: string): boolean {
  try {
    const url = new URL(origin);
    return (url.protocol === 'http:' || url.protocol === 'https:') &&
      (url.hostname === 'localhost' || url.hostname === '127.0.0.1') &&
      url.origin === origin;
  } catch { return false; }
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}
function validRequest(body: unknown): body is AgentRequest {
  if (!isRecord(body) || typeof body.message !== 'string' || !body.message.trim() || body.message.length > 8000) return false;
  if (body.locale !== undefined && !['en', 'ru', 'kk'].includes(body.locale as string)) return false;
  for (const field of ['lifeContext', 'agentContext']) {
    if (body[field] !== undefined && !isRecord(body[field])) return false;
  }
  if(body.toolsEnabled!==undefined && typeof body.toolsEnabled!=='boolean') return false;
  if(body.pendingActions!==undefined && (!Array.isArray(body.pendingActions) || body.pendingActions.length>8 || JSON.stringify(body.pendingActions).length>12000)) return false;
  if(body.toolTurns!==undefined) {
    if(!Array.isArray(body.toolTurns) || body.toolTurns.length>36 || JSON.stringify(body.toolTurns).length>80000) return false;
    const awaiting=new Set<string>();
    for(const item of body.toolTurns) {
      if(!isRecord(item)) return false;
      if(item.role==='assistant' && Array.isArray(item.tool_calls) && awaiting.size===0) {
        if(item.tool_calls.length<1 || item.tool_calls.length>8) return false;
        for(const call of item.tool_calls) {
          if(!isRecord(call) || typeof call.id!=='string' || awaiting.has(call.id) || call.type!=='function' || !isRecord(call.function) || typeof call.function.name!=='string' || typeof call.function.arguments!=='string' || !registry.some(tool=>tool.name===(call.function as Record<string, unknown>).name)) return false;
          awaiting.add(call.id);
        }
        if(item.content!==null && typeof item.content!=='string') return false;
      } else if(item.role==='tool' && typeof item.tool_call_id==='string' && awaiting.delete(item.tool_call_id) && typeof item.content==='string' && item.content.length<=20000) { /* scoped client tool result */ }
      else return false;
    }
    if(awaiting.size) return false;
  }
  if (body.conversation !== undefined && (!Array.isArray(body.conversation) || body.conversation.length > 100 ||
    !body.conversation.every(item => isRecord(item) && ['user', 'assistant'].includes(item.role as string) &&
      typeof item.content === 'string' && item.content.length <= 8000))) return false;
  return true;
}

export function createApp(agent: OrtaAgent, dependencies: AppDependencies = {}) {
  const app = express();
  // Reject untrusted browser origins before body parsing or paid/quota-consuming inference.
  // Native requests have no Origin header; this is a local-development boundary, not authentication.
  app.use((request, response, next) => {
    const origin = request.get('Origin');
    if (origin !== undefined && !trustedOrigin(origin)) {
      return response.status(403).json({ error: 'This request is not allowed.', code: 'access_denied', requestId: randomUUID() });
    }
    next();
  });
  app.use(cors({ origin: (origin, callback) => callback(null, origin !== undefined && trustedOrigin(origin)) }));
  app.use(express.json({ limit: '10mb' }));
  app.get('/health', (_request, response) => response.json({ status: 'ok' }));
  app.post('/api/agent/image', async (request, response) => {
    const requestId = randomUUID();
    const body = request.body;
    if (!isRecord(body) || typeof body.message !== 'string' || body.message.length > 4000 ||
        typeof body.mimeType !== 'string' || !/^image\/(?:jpeg|png|webp)$/.test(body.mimeType) ||
        typeof body.imageBase64 !== 'string' || body.imageBase64.length > 7_000_000 ||
        (body.locale !== undefined && !['en', 'ru', 'kk'].includes(body.locale as string))) {
      return response.status(400).json({ error: 'Invalid image request.', code: 'invalid_request', requestId });
    }
    const decoded = Buffer.from(body.imageBase64, 'base64');
    if (!decoded.length || decoded.length > 5_000_000 || decoded.toString('base64') !== body.imageBase64) {
      return response.status(400).json({ error: 'Image is too large or invalid.', code: 'invalid_request', requestId });
    }
    if (!dependencies.visionAI?.configured) {
      return response.status(503).json({ error: 'Image understanding is not configured.', code: 'not_configured', requestId });
    }
    try {
      const description = await dependencies.visionAI.analyzeImage(body.message, body.mimeType, body.imageBase64, String(body.locale ?? 'en'));
      console.log(`[${requestId}] image-analysis provider=${dependencies.visionAI.name} model=${dependencies.visionAI.model} success`);
      return response.json({ description, requestId });
    } catch (error) {
      const safe = error instanceof ProviderError ? error : new ProviderError('provider_error');
      console.error(`[${requestId}] image-analysis ${safe.code} upstreamStatus=${safe.httpStatus ?? 'none'}`);
      if (safe.retryAfter) response.setHeader('Retry-After', safe.retryAfter);
      return response.status(safe.code === 'rate_limit' ? 429 : safe.code === 'request_too_large' ? 413 : 503).json({
        error: safeErrors[safe.code], code: safe.code, requestId,
      });
    }
  });
  const coach = dependencies.coach ?? new LanguageCoach(agent.provider);
  const studentGate = dependencies.studentGate ?? defaultStudentGate;
  app.post('/api/language/practice', async (request, response) => {
    const requestId = randomUUID();
    const access = await studentGate(request.get('Authorization'));
    if (access === 'denied') {
      return response.status(403).json({ error: 'Language ORTA coaching is limited to signed-in students.', code: 'access_denied', requestId });
    }
    if (!validLanguagePracticeRequest(request.body)) {
      return response.status(400).json({ error: 'Invalid language practice request.', code: 'invalid_request', requestId });
    }
    try {
      const result = await coach.handle(request.body);
      console.log(`[${requestId}] language-practice provider=${agent.provider.name} model=${agent.provider.model} action=${request.body.action} success`);
      return response.json({ ...result, requestId });
    } catch (error) {
      const safe = error instanceof ProviderError ? error : new ProviderError('provider_error');
      console.error(`[${requestId}] language-practice ${safe.code} upstreamStatus=${safe.httpStatus??'none'}`);
      if (safe.retryAfter) response.setHeader('Retry-After', safe.retryAfter);
      return response.status(safe.code === 'rate_limit' ? 429 : safe.code === 'request_too_large' ? 413 : 503).json({
        error: safeErrors[safe.code], code: safe.code, requestId,
      });
    }
  });
  app.post('/api/agent/message', async (request, response) => {
    const requestId = randomUUID();
    if (!validRequest(request.body)) return response.status(400).json({ error: 'Invalid agent request.', code: 'invalid_request', requestId });
    try {
      const body = request.body;
      const turn = await agent.respondTurn({ message: body.message.trim(), locale: body.locale,
        lifeContext: body.lifeContext, agentContext: body.agentContext, conversation: body.conversation,
        toolsEnabled:body.toolsEnabled,toolTurns:body.toolTurns,pendingActions:body.pendingActions });
      // Correlate real requests without logging messages, personal context or credentials.
      console.log(`[${requestId}] provider=${agent.provider.name} model=${agent.provider.model} success locale=${body.locale ?? 'en'} tools=${turn.toolCalls.map(t=>t.name).join(',') || 'none'}`);
      return response.json({ message:turn.message, requestId, ...(turn.research?{research:turn.research}:{}), ...(body.toolsEnabled?{toolCalls:turn.toolCalls,rawCalls:turn.rawCalls}: {}) });
    } catch (error) {
      const safe = error instanceof ProviderError ? error : new ProviderError('provider_error');
      console.error(`[${requestId}] ${safe.code} upstreamStatus=${safe.httpStatus??'none'} internalType=${error instanceof ProviderError?'none':error instanceof TypeError?'TypeError':error instanceof SyntaxError?'SyntaxError':'other'}`);
      if (safe.retryAfter) response.setHeader('Retry-After', safe.retryAfter);
      return response.status(safe.code === 'rate_limit' ? 429 : safe.code === 'request_too_large' ? 413 : 503).json({
        error: safeErrors[safe.code], code: safe.code, requestId,
      });
    }
  });
  app.use((error: unknown, _request: express.Request, response: express.Response, _next: express.NextFunction) => {
    const tooLarge = isRecord(error) && error.type === 'entity.too.large';
    response.status(tooLarge ? 413 : 400).json({ error: tooLarge ? safeErrors.request_too_large : 'Invalid agent request.', code: tooLarge ? 'request_too_large' : 'invalid_request', requestId: randomUUID() });
  });
  return app;
}
