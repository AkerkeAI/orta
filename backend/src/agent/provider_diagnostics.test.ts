import assert from 'node:assert/strict';
import test from 'node:test';
import {GroqProvider, DEFAULT_MODEL} from './ai_provider.js';
import {buildSystemPrompt} from './system_prompt.js';

async function captureDiagnostics(enabled: boolean, run: () => Promise<void>) {
  const previous = process.env.ORTA_DEBUG_PROVIDER;
  const original = console.error;
  const logs: string[] = [];
  process.env.ORTA_DEBUG_PROVIDER = String(enabled);
  console.error = (...values: unknown[]) => logs.push(values.map(String).join(' '));
  try { await run(); } finally {
    console.error = original;
    if (previous === undefined) delete process.env.ORTA_DEBUG_PROVIDER;
    else process.env.ORTA_DEBUG_PROVIDER = previous;
  }
  return logs.join('\n');
}

const failedTool = {
  error: {
    type: 'invalid_request_error', code: 'tool_use_failed',
    message: 'parameters for tool create_exam did not match schema: errors: [`/importance`: enum: PRIVATE_UPSTREAM_TEXT]',
    failed_generation: JSON.stringify({name: 'create_exam', arguments: {
      name: 'PRIVATE_NAME', date: 'PRIVATE_DATE', importance: '', preparationWanted: null,
    }}),
  },
};
function provider(body: unknown, status: number) {
  return new GroqProvider('PRIVATE_API_KEY', DEFAULT_MODEL, async () => new Response(JSON.stringify(body), {status}));
}

test('provider diagnosis is opt-in and HTTP 400 retains only the safe status', async () => {
  const logs = await captureDiagnostics(false, async () => {
    await assert.rejects(provider(failedTool, 400).turn([{role: 'user', content: 'PRIVATE_MESSAGE'}], true),
      {code: 'invalid_response', httpStatus: 400});
  });
  assert.equal(logs, '');
});

test('upstream diagnostic contains schema keys and function names, never private values', async () => {
  const logs = await captureDiagnostics(true, async () => {
    await assert.rejects(provider(failedTool, 400).turn([{role: 'user', content: 'PRIVATE_MESSAGE'}], true),
      {code: 'invalid_response'});
  });
  assert.match(logs, /"status":400/);
  assert.match(logs, /create_exam/);
  assert.match(logs, /"emptyKeys":\["importance"\]/);
  assert.match(logs, /"nullKeys":\["preparationWanted"\]/);
  assert.doesNotMatch(logs, /PRIVATE_|failed_generation|Authorization|Bearer|message/);
});

test('local parsing diagnostic identifies invalid optional updates without exposing arguments or IDs', async () => {
  const body = {choices: [{finish_reason: 'tool_calls', message: {tool_calls: [
    {id: 'PRIVATE_CALL_ID', type: 'function', function: {name: 'update_project',
      arguments: JSON.stringify({id: 'PRIVATE_RECORD_ID', description: null})}},
  ]}}]};
  const logs = await captureDiagnostics(true, async () => {
    await assert.rejects(provider(body, 200).turn([], true), {code: 'invalid_response'});
  });
  assert.match(logs, /invalid_arguments/);
  assert.match(logs, /update_project/);
  assert.match(logs, /"nullKeys":\["description"\]/);
  assert.doesNotMatch(logs, /PRIVATE_/);
});

test('truncation diagnosis includes finish reason but no partial response text', async () => {
  const logs = await captureDiagnostics(true, async () => {
    await assert.rejects(provider({choices: [{finish_reason: 'length', message: {content: 'PRIVATE_PARTIAL_RESPONSE'}}]}, 200).turn([], true),
      {code: 'invalid_response'});
  });
  assert.match(logs, /"finishReason":"length"/);
  assert.doesNotMatch(logs, /PRIVATE_/);
});

test('direct writes and pending corrections request actual proposals before the single approval step', () => {
  for (const locale of ['en', 'ru', 'kk'] as const) {
    const prompt = buildSystemPrompt(locale);
    assert.match(prompt, /MUST call the matching registered write tool now/);
    assert.match(prompt, /user approves once after reviewing that proposal/);
    assert.match(prompt, /Pending project, exam, task and goal proposals are not saved records/);
    assert.match(prompt, /matching CREATE tool with the complete corrected required fields/);
    assert.match(prompt, /correction is never an approval or rejection/);
    assert.match(prompt, /modify_pending_session/);
  }
});


test('implicit visible-record questions prioritize the selected entity over unrelated chat and proposals', () => {
  for (const locale of ['en', 'ru', 'kk'] as const) {
    const prompt = buildSystemPrompt(locale);
    assert.match(prompt, /AgentContext\.visibleData\.selectedEntity/);
    assert.match(prompt, /Prioritize that currently visible record over unrelated recent chat or pendingActions/);
    assert.match(prompt, /visible project means discuss that project, not an unrelated pending exam/);
    assert.match(prompt, /Do not invent the project's purpose, stage or needs when absent/);
  }
});
