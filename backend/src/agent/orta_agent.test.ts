import assert from 'node:assert/strict';
import test from 'node:test';
import { MAX_HISTORY, MODEL, OrtaAgent } from './orta_agent.js';
import { buildSystemPrompt } from './system_prompt.js';

test('uses the requested Responses API model and bounds history', () => {
  assert.equal(MODEL, 'gpt-5.6-terra');
  assert.equal(MAX_HISTORY, 12);
  assert.match(buildSystemPrompt('ru'), /Russian/);
});

test('does not require an API key at construction time', async () => {
  const agent = new OrtaAgent('');
  await assert.rejects(agent.respond({ message: 'hello' }), /OPENAI_API_KEY is not configured/);
});
