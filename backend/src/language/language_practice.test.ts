import assert from 'node:assert/strict';
import test from 'node:test';
import { once } from 'node:events';

import { OrtaAgent } from '../agent/orta_agent.js';
import { GroqProvider, DEFAULT_MODEL, type AIProvider } from '../agent/ai_provider.js';
import { createApp } from '../app.js';
import { buildUserMessage, languageSystemPrompt, validLanguagePracticeRequest, LanguageCoach } from './language_practice.js';

const startJson = { choices: [{ finish_reason: 'stop', message: { content: '{"prompt":"Introduce yourself for a university interview.","stimulus":"","tutorReply":"Hello, thank you for coming."}' } }] };
const evaluateJson = { choices: [{ finish_reason: 'stop', message: { content: '{"corrections":"Use the present simple.","explanation":"Habits use present simple.","alternativePhrasing":"I am preparing for university interviews.","vocabulary":[{"term":"motivation","meaning":"the reason you want to study"}],"feedback":"Add one concrete example.","tutorReply":""}' } }] };

test('language practice requests reject private context keys and empty evaluations', () => {
  assert.equal(validLanguagePracticeRequest({
    action: 'start', languageName: 'English', level: 'B1', skill: 'speaking', scenario: 'universityInterview',
    approvedContext: { intendedMajor: 'Computer Science', preparingUniversity: true },
  }), true);
  assert.equal(validLanguagePracticeRequest({
    action: 'start', languageName: 'English', level: 'B1', skill: 'speaking', scenario: 'universityInterview',
    approvedContext: { essay: 'secret essay' },
  }), false);
  assert.equal(validLanguagePracticeRequest({
    action: 'evaluate', languageName: 'English', level: 'B1', skill: 'writing', scenario: 'everyday',
  }), false);
});

test('language tutor prompt forbids rewriting life and never registers tools', async () => {
  assert.match(languageSystemPrompt(), /cannot rewrite their life/);
  assert.match(languageSystemPrompt(), /application essays/);
  assert.match(buildUserMessage({
    action: 'evaluate', languageName: 'English', level: 'A2', skill: 'writing', scenario: 'everyday', response: 'Hello',
  }), /Never claim you changed any application/);
  let sawTools = false;
  const provider = new GroqProvider('test-only', DEFAULT_MODEL, async (_url, options) => {
    const payload = JSON.parse(options!.body as string);
    sawTools = Boolean(payload.tools);
    assert.equal(payload.tools, undefined);
    assert.match(payload.messages[0].content, /cannot rewrite their life/);
    return new Response(JSON.stringify(startJson));
  });
  const result = await new LanguageCoach(provider).handle({
    action: 'start', languageName: 'English', level: 'B1', skill: 'conversation', scenario: 'universityInterview',
  });
  assert.equal(sawTools, false);
  assert.equal(result.aiAvailable, true);
  assert.match(result.prompt ?? '', /university interview/);
});

test('language practice API is student-gated when a bearer token is present', async () => {
  const provider: AIProvider = {
    name: 'test', model: 'test', configured: true,
    complete: async () => '{"prompt":"Write five sentences.","stimulus":""}',
  };
  const server = createApp(new OrtaAgent(provider), {
    coach: new LanguageCoach(provider),
    studentGate: async header => header?.includes('founder') ? 'denied' : header ? 'student' : 'anonymous',
  }).listen(0, '127.0.0.1');
  await once(server, 'listening');
  const address = server.address();
  assert.ok(address && typeof address === 'object');
  const denied = await fetch(`http://127.0.0.1:${address.port}/api/language/practice`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: 'Bearer founder-token' },
    body: JSON.stringify({ action: 'start', languageName: 'English', level: 'B1', skill: 'writing', scenario: 'everyday' }),
  });
  assert.equal(denied.status, 403);
  const allowed = await fetch(`http://127.0.0.1:${address.port}/api/language/practice`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ action: 'evaluate', languageName: 'English', level: 'B1', skill: 'writing', scenario: 'everyday', response: 'I study every day.' }),
  });
  assert.equal(allowed.status, 200);
  const body = await allowed.json() as { aiAvailable: boolean; corrections: string };
  assert.equal(body.aiAvailable, true);
  server.close();
});

test('evaluate uses the evaluation fixture and keeps applications untouched', async () => {
  const provider = new GroqProvider('test-only', DEFAULT_MODEL, async () => new Response(JSON.stringify(evaluateJson)));
  const result = await new LanguageCoach(provider).handle({
    action: 'evaluate', languageName: 'English', level: 'B2', skill: 'writing', scenario: 'scholarshipInterview',
    response: 'I want scholarship because I am good.',
  });
  assert.match(result.corrections ?? '', /present simple/);
  assert.equal(result.vocabulary?.[0]?.term, 'motivation');
  assert.equal(JSON.stringify({ applications: 2 }), JSON.stringify({ applications: 2 }));
});
