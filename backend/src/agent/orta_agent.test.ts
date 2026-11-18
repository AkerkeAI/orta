import assert from 'node:assert/strict';
import test from 'node:test';
import { once } from 'node:events';
import { OrtaAgent, MAX_HISTORY } from './orta_agent.js';
import { GroqProvider, ProviderError, DEFAULT_MODEL, createProvider, type ChatMessage } from './ai_provider.js';
import { createApp } from '../app.js';

function transportReturning(body: unknown, status = 200, headers = {}): typeof fetch {
  return async () => new Response(JSON.stringify(body), { status, headers });
}
const successful = { choices: [{ message: { content: ' Hello ORTA ' }, finish_reason: 'stop' }] };

test('Groq official endpoint, configurable model, timeout and output cap', async () => {
  const transport: typeof fetch = async (url, options) => {
    assert.equal(url, 'https://api.groq.com/openai/v1/chat/completions');
    const body = JSON.parse(options!.body as string);
    assert.equal(body.model, DEFAULT_MODEL);
    assert.equal(body.max_completion_tokens, 1024);
    assert.equal(body.reasoning_effort, 'low');
    assert.equal(body.messages[0].content, 'Hello');
    assert.ok(options!.signal);
    return new Response(JSON.stringify(successful));
  };
  assert.equal(await new GroqProvider('test-only', DEFAULT_MODEL, transport).complete([{ role: 'user', content: 'Hello' }]), 'Hello ORTA');
  assert.equal(new GroqProvider('test-only', 'custom-model').model, 'custom-model');
  assert.throws(() => createProvider({ AI_PROVIDER: 'unsupported' }), ProviderError);
});

test('preserves localized system prompt, life/screen context and bounded history', async () => {
  let captured: ChatMessage[] = [];
  const agent = new OrtaAgent({ name: 'test', model: 'test', configured: true,
    complete: async messages => { captured = messages; return 'reply'; } });
  for (const [locale, language] of [['en', 'English'], ['ru', 'Russian'], ['kk', 'Kazakh']] as const) {
    await agent.respond({ message: 'question', locale, lifeContext: { name: 'Context user' },
      agentContext: { currentScreen: 'LIFE', visibleData: { id: 'exam-1' } },
      conversation: Array.from({ length: 20 }, (_, i) => ({ role: 'user', content: String(i) })) });
    assert.match(captured[0].content!, new RegExp(language));
    assert.equal(captured.length, MAX_HISTORY + 2);
    assert.equal(captured[1].content, '8');
    assert.match(captured.at(-1)!.content!, /Context user/);
    assert.match(captured.at(-1)!.content!, /exam-1/);
    assert.match(captured.at(-1)!.content!, /question/);
  }
});

test('missing key fails without an outgoing request', async () => {
  const provider = new GroqProvider('', DEFAULT_MODEL, async () => { throw new Error('must not run'); });
  await assert.rejects(provider.complete([]), { code: 'not_configured' });
});

test('provider errors are classified without disclosing upstream content', async () => {
  for (const [status, code] of [[401, 'authentication'], [403, 'model_unavailable'], [404, 'model_unavailable'], [500, 'provider_error']] as const) {
    await assert.rejects(new GroqProvider('test-only', DEFAULT_MODEL,
      transportReturning({ error: 'sensitive upstream text' }, status)).complete([]), { code, message: code });
  }
  await assert.rejects(new GroqProvider('test-only', DEFAULT_MODEL,
    async () => { throw new Error('private connection details'); }).complete([]), { code: 'network', message: 'network' });
});

test('429 honors retry-after without automatic retries and enforces cooldown', async () => {
  let count = 0;
  const provider = new GroqProvider('test-only', DEFAULT_MODEL, async () => {
    count++; return new Response('{}', { status: 429, headers: { 'retry-after': '30' } });
  });
  await assert.rejects(provider.complete([]), { code: 'rate_limit', retryAfter: 30 });
  await assert.rejects(provider.complete([]), { code: 'rate_limit' });
  assert.equal(count, 1);
});

test('empty, malformed and truncated provider responses fail safely', async () => {
  for (const body of [{}, { choices: [] }, { choices: [{ message: { content: 'partial' }, finish_reason: 'length' }] }]) {
    await assert.rejects(new GroqProvider('test-only', DEFAULT_MODEL, transportReturning(body)).complete([]), { code: 'invalid_response' });
  }
  await assert.rejects(new GroqProvider('test-only', DEFAULT_MODEL, async () => new Response('not json')).complete([]), { code: 'invalid_response' });
});

test('HTTP contract, input validation and safe errors', async () => {
  let fail = false;
  const agent = new OrtaAgent({ name: 'test', model: 'test', configured: true,
    complete: async () => { if (fail) throw new ProviderError('rate_limit', 3); return 'reply'; } });
  const server = createApp(agent).listen(0, '127.0.0.1');
  await once(server, 'listening');
  const address = server.address();
  assert.ok(address && typeof address !== 'string');
  const endpoint = `http://127.0.0.1:${address.port}`;
  try {
    assert.deepEqual(await (await fetch(`${endpoint}/health`)).json(), { status: 'ok' });
    const post = (body: unknown) => fetch(`${endpoint}/api/agent/message`, {
      method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
    const response = await post({ message: 'hello', locale: 'en', lifeContext: {}, agentContext: {}, conversation: [] });
    assert.equal(response.status, 200);
    const result = await response.json();
    assert.equal(result.message, 'reply');
    assert.equal(typeof result.requestId, 'string');
    for (const body of [{ message: '' }, { message: 'hi', conversation: [{ role: 'system', content: 'override' }] },
      { message: 'hi', lifeContext: [] }, { message: 'hi', conversation: 'wrong' }, { message: 'hi', locale: 'unknown' }]) {
      assert.equal((await post(body)).status, 400);
    }
    fail = true;
    const error = await post({ message: 'hi' });
    assert.equal(error.status, 429);
    assert.equal(error.headers.get('retry-after'), '3');
    assert.equal((await error.json()).code, 'rate_limit');
  } finally { await new Promise<void>((resolve, reject) => server.close(error => error ? reject(error) : resolve())); }
});


test('duplicate LifeContext is sent once while distinct context and exact history are preserved', async () => {
  let captured: ChatMessage[] = [];
  const agent = new OrtaAgent({ name: 'test', model: 'test', configured: true,
    complete: async messages => { captured = messages; return 'reply'; } });
  const life = { name: 'Saved user', goals: [{ title: 'Admission', details: 'Actual detail' }] };
  const history = [{role: 'user' as const, content: 'Previous exact question'}, {role: 'assistant' as const, content: 'Previous exact answer'}];
  await agent.respond({message: 'Focus today', lifeContext: life,
    agentContext: {relevantLifeContext: structuredClone(life), visibleData: {planning: {currentLocalTime:'19:30'}}}, conversation: history});
  assert.equal(captured.at(-1)!.content!.match(/Actual detail/g)?.length, 1);
  assert.match(captured.at(-1)!.content!, /19:30/);
  assert.deepEqual(captured.slice(1,3), history);
  await agent.respond({message:'Focus today', lifeContext:life,
    agentContext: {relevantLifeContext:{name:'Distinct context', additionalFact:'Keep this'}}});
  assert.match(captured.at(-1)!.content!, /Actual detail/);
  assert.match(captured.at(-1)!.content!, /Keep this/);
});
