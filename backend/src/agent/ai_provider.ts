import { parseCalls, registry, type ToolCall } from './tool_registry.js';
import { researchTools } from '../research/research_tools.js';
export const providerRegistry = [...registry, ...researchTools];
export const DEFAULT_MODEL = 'openai/gpt-oss-120b';
export const MAX_INFERENCE_BYTES = 48_000;
export type ErrorCode = 'not_configured' | 'authentication' | 'model_unavailable' | 'rate_limit' | 'network' | 'invalid_response' | 'provider_error' | 'request_too_large';
export class ProviderError extends Error {
  constructor(readonly code: ErrorCode, readonly retryAfter?: number, readonly httpStatus?:number) { super(code); }
}
export interface ChatMessage { role: 'system' | 'user' | 'assistant' | 'tool'; content: string | null; tool_call_id?: string; tool_calls?: unknown[] }
export interface ToolTurn { message:string; toolCalls:ToolCall[]; rawCalls?:unknown[]; research?: import('../research/web_research.js').ResearchResult }
export interface AIProvider {
  readonly name: string;
  readonly model: string;
  readonly configured: boolean;
  complete(messages: ChatMessage[]): Promise<string>;
  turn?(messages: ChatMessage[], tools:boolean, options?:{researchOnly?:boolean;requiredTool?:string}):Promise<ToolTurn>;
}

// GPT-OSS sometimes fills absent project details with empty placeholders despite
// omission instructions. CREATE-only text defaults may safely stay unspecified.
// Required fields, IDs, dates, enums and updates never receive this treatment.
const OMIT_EMPTY_CREATE_TEXT: Readonly<Record<string, readonly string[]>> = {
  create_project: ['description', 'stage', 'needs'],
};

// Upper string-length caps remain enforced by the full registry on server and client.
// Other non-empty constraints stay in inference. Unstated optional fields should
// be omitted; the narrow CREATE exception below never weakens shared validation.
function inferenceSchema(value: unknown, omitEmpty: readonly string[] = []): unknown {
  if (Array.isArray(value)) return value.map(child => inferenceSchema(child));
  if (value && typeof value === 'object') {
    const schema = value as Record<string, unknown>;
    const encodedSchema = Object.fromEntries(Object.entries(schema)
      .filter(([key]) => schema.type !== 'string' ||
        (key !== 'maxLength' && !(key === 'format' && schema.format === 'time')))
      .map(([key, child]) => {
        if (schema.type === 'object' && key === 'properties' && child && typeof child === 'object') {
          const required = Array.isArray(schema.required) ? schema.required : [];
          return [key, Object.fromEntries(Object.entries(child).map(([name, property]) => {
            const inferred = inferenceSchema(property) as Record<string, unknown>;
            if (inferred.type === 'string' && !required.includes(name)) {
              // Permit only known CREATE placeholders through Groq's response
              // validator; omit them before the unchanged shared validation.
              if (omitEmpty.includes(name) && !inferred.format && !inferred.enum) delete inferred.minLength;
              return [name, inferred];
            }
            return [name, inferred];
          }))];
        }
        return [key, inferenceSchema(child)];
      }));
    // ORTA's local wall clock is HH:mm, not RFC 3339 full-time.
    // The shared registry still validates the exact same range on both sides.
    if (schema.type === 'string' && schema.format === 'time') {
      encodedSchema.pattern = '^(?:[01][0-9]|2[0-3]):[0-5][0-9]$';
    }
    return encodedSchema;
  }
  return value;
}

function omitCreatePlaceholders(raw: unknown): unknown {
  if (!Array.isArray(raw)) return raw;
  return raw.map(value => {
    if (!value || typeof value !== 'object') return value;
    const call = value as Record<string, unknown>;
    if (!call.function || typeof call.function !== 'object') return value;
    const fn = call.function as Record<string, unknown>;
    const fields = typeof fn.name === 'string' ? OMIT_EMPTY_CREATE_TEXT[fn.name] : undefined;
    if (!fields || typeof fn.arguments !== 'string') return value;
    const args = JSON.parse(fn.arguments);
    if (!args || typeof args !== 'object' || Array.isArray(args)) return value;
    for (const key of fields) {
      // Exactly empty model placeholders only; whitespace and every other
      // malformed value are still rejected. No existing record is changed.
      if (args[key] === '') delete args[key];
    }
    return {...call, function: {...fn, arguments: JSON.stringify(args)}};
  });
}

// Opt-in diagnosis contains only registry identifiers and response shape. Never
// log messages, context, IDs, argument values, credentials or upstream bodies.
function safeCallShape(raw: unknown): unknown[] {
  if (!Array.isArray(raw)) return [];
  return raw.map(value => {
    const call = value && typeof value === 'object' ? value as Record<string, unknown> : {};
    const fn = call.function && typeof call.function === 'object' ? call.function as Record<string, unknown> : {};
    const definition = providerRegistry.find(tool => tool.name === fn.name);
    let args: unknown;
    try { args = typeof fn.arguments === 'string' ? JSON.parse(fn.arguments) : undefined; } catch {}
    const fields = args && typeof args === 'object' && !Array.isArray(args) ? args as Record<string, unknown> : {};
    const known = Object.keys(definition?.parameters.properties ?? {});
    return {name: definition?.name ?? 'unknown_tool',
      emptyKeys: known.filter(key => fields[key] === ''),
      nullKeys: known.filter(key => fields[key] === null),
      invalidJson: args === undefined};
  });
}
function validationCode(error: unknown): string {
  const known = ['invalid_arguments', 'missing_information', 'invalid_date', 'invalid_time', 'unknown_tool', 'invalid_tool_calls'];
  return error instanceof Error && known.includes(error.message) ? error.message : error instanceof SyntaxError ? 'invalid_json' : 'malformed_response';
}
function diagnostic(details: Record<string, unknown>): void {
  if (process.env.ORTA_DEBUG_PROVIDER === 'true') console.error(`[groq-diagnostic] ${JSON.stringify(details)}`);
}
async function diagnoseUpstream(response: Response): Promise<void> {
  if (process.env.ORTA_DEBUG_PROVIDER !== 'true') return;
  try {
    const body = await response.clone().json();
    const message = typeof body?.error?.message === 'string' ? body.error.message : '';
    const name = message.match(/parameters for tool ([a-z_]+)/)?.[1];
    const definition = providerRegistry.find(tool => tool.name === name);
    const knownKeys = Object.keys(definition?.parameters.properties ?? {});
    const invalidKeys = [...message.matchAll(/`\/([A-Za-z][A-Za-z0-9_]*)`/g)]
      .map(match => match[1]).filter(key => knownKeys.includes(key));
    let failed: unknown;
    try { failed = JSON.parse(body?.error?.failed_generation); } catch {}
    const attempt = failed && typeof failed === 'object' ? failed as Record<string, unknown> : {};
    const calls = attempt.name && attempt.arguments
      ? [{function: {name: attempt.name, arguments: JSON.stringify(attempt.arguments)}}]
      : [];
    const errorCodes = ['tool_use_failed', 'rate_limit_exceeded', 'invalid_api_key', 'model_not_found'];
    const errorTypes = ['invalid_request_error', 'tokens', 'requests', 'server_error', 'authentication_error'];
    diagnostic({status: response.status,
      errorCode: errorCodes.includes(body?.error?.code) ? body.error.code : 'unknown',
      errorType: errorTypes.includes(body?.error?.type) ? body.error.type : 'unknown',
      functionName: definition?.name, invalidKeys, calls: safeCallShape(calls)});
  } catch { diagnostic({status: response.status, validation: 'invalid_upstream_json'}); }
}

// Native HTTP against Groq's official API. Other providers implement AIProvider.
export class GroqProvider implements AIProvider {
  readonly name = 'groq';
  readonly configured: boolean;
  private cooldownUntil = 0;
  private inFlight = false;
  constructor(
    private readonly apiKey = process.env.GROQ_API_KEY,
    readonly model = process.env.GROQ_MODEL || DEFAULT_MODEL,
    private readonly transport: typeof fetch = fetch,
  ) { this.configured = Boolean(apiKey?.trim()); }

  async complete(messages: ChatMessage[]): Promise<string> { return (await this.turn(messages,false)).message; }

  async turn(messages: ChatMessage[], tools=false, options:{researchOnly?:boolean;requiredTool?:string}={}): Promise<ToolTurn> {
    if (!this.configured) throw new ProviderError('not_configured');
    if (options.requiredTool && (options.researchOnly || !registry.some(tool => tool.name === options.requiredTool && tool.permission === 'approval'))) throw new ProviderError('invalid_response');
    const remaining = Math.ceil((this.cooldownUntil - Date.now()) / 1000);
    if (remaining > 0 || this.inFlight) throw new ProviderError('rate_limit', Math.max(remaining, 1));
    this.inFlight = true;
    try {
      const payload = JSON.stringify({ model: this.model, messages, max_completion_tokens: tools?2048:1024,
        ...(tools?{tools:(options.researchOnly?researchTools:providerRegistry).map(t=>({type:'function',function:{name:t.name,description:t.description,parameters:inferenceSchema(t.parameters, OMIT_EMPTY_CREATE_TEXT[t.name])}})),tool_choice:options.requiredTool?{type:'function',function:{name:options.requiredTool}}:'auto',parallel_tool_calls:true}:{}),
        ...(this.model.startsWith('openai/gpt-oss-') ? { reasoning_effort: 'low' } : {}) });
      // A byte guard bounds traffic; it is not a tokenizer or a guarantee of account quota.
      // Never silently rewrite current facts, pending actions or tool results to fit.
      if (Buffer.byteLength(payload, 'utf8') > MAX_INFERENCE_BYTES) throw new ProviderError('request_too_large');
      const response = await this.transport('https://api.groq.com/openai/v1/chat/completions', {
        method: 'POST',
        headers: { Authorization: `Bearer ${this.apiKey}`, 'Content-Type': 'application/json' },
        body: payload,
        signal: AbortSignal.timeout(20000),
      });
      if (!response.ok) {
        await diagnoseUpstream(response);
        if (response.status === 401) throw new ProviderError('authentication');
        if (response.status === 403 || response.status === 404) throw new ProviderError('model_unavailable');
        if (response.status === 429) {
          const raw = response.headers.get('retry-after');
          const delay = raw && Number.isFinite(Number(raw)) ? Number(raw)
            : raw ? Math.ceil((Date.parse(raw) - Date.now()) / 1000) : 60;
          const retryAfter = Number.isFinite(delay) ? Math.max(1, Math.min(delay, 86400)) : 60;
          this.cooldownUntil = Date.now() + retryAfter * 1000;
          throw new ProviderError('rate_limit', retryAfter);
        }
        if(response.status===400) throw new ProviderError('invalid_response', undefined, 400);
        if(response.status===413) throw new ProviderError('request_too_large', undefined, 413);
        // Never surface raw provider bodies: they may contain private input.
        throw new ProviderError('provider_error',undefined,response.status);
      }
      let body;
      try { body = await response.json(); } catch { throw new ProviderError('invalid_response'); }
      const output=body?.choices?.[0]?.message;
      if(tools && body?.choices?.[0]?.finish_reason==='tool_calls') {
        try {
          const rawCalls = omitCreatePlaceholders(output?.tool_calls);
          return {message:typeof output?.content==='string'?output.content.trim():'',toolCalls:parseCalls(rawCalls, options.researchOnly?researchTools:providerRegistry),rawCalls:rawCalls as unknown[]};
        }
        catch (error) { diagnostic({status: response.status, validation: validationCode(error), calls: safeCallShape(output?.tool_calls)}); throw new ProviderError('invalid_response'); }
      }
      const content = output?.content;
      if (typeof content !== 'string' || !content.trim() || body.choices[0].finish_reason !== 'stop') {
        diagnostic({status: response.status, validation: 'invalid_content_or_finish', finishReason: ['stop','tool_calls','length','content_filter'].includes(body?.choices?.[0]?.finish_reason) ? body.choices[0].finish_reason : 'unknown', contentType: typeof content});
        throw new ProviderError('invalid_response');
      }
      return {message:content.trim(),toolCalls:[]};
    } catch (error) {
      if (error instanceof ProviderError) throw error;
      throw new ProviderError('network');
    } finally { this.inFlight = false; }
  }
}

export function createProvider(env = process.env): AIProvider {
  if ((env.AI_PROVIDER || 'groq') !== 'groq') throw new ProviderError('not_configured');
  return new GroqProvider(env.GROQ_API_KEY, env.GROQ_MODEL || DEFAULT_MODEL);
}
