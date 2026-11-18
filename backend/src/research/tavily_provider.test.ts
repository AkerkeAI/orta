import assert from 'node:assert/strict';
import test from 'node:test';
import { TavilyProvider } from './tavily_provider.js';
import { createSearchProvider } from './web_research.js';

test('Tavily uses official fixed endpoint, bearer key, basic one-credit settings and genuine result URLs', async () => {
  const provider = new TavilyProvider('test-only', async (url, options) => {
    assert.equal(url, 'https://api.tavily.com/search');
    assert.equal(options?.redirect, 'error');
    assert.ok(options?.signal);
    assert.equal((options?.headers as Record<string,string>).Authorization, 'Bearer test-only');
    const body = JSON.parse(options?.body as string);
    assert.equal(body.search_depth, 'basic'); assert.equal(body.auto_parameters, false);
    assert.equal(body.include_answer, false); assert.equal(body.include_raw_content, false);
    assert.equal(body.include_published_date, true); assert.equal(body.max_results, 5);
    assert.equal(body.query, 'official scholarships');
    assert.equal(Object.hasOwn(body, 'lifeContext'), false);
    return new Response(JSON.stringify({results: [
      {title: '<b>Official scholarship</b>', url: 'https://example.org/program#section', content: 'Apply by November 20.', published_date: 'Tue, 11 Mar 2025 17:00:00 GMT'},
      {title:'Duplicate',url:'https://example.org/program#second'},
      {title:'Private',url:'https://127.0.0.1/key'},
    ]}));
  });
  const result = await provider.search('official scholarships', 'en');
  assert.equal(result.length, 1); assert.equal(result[0].url, 'https://example.org/program');
  assert.equal(result[0].title, 'Official scholarship'); assert.equal(result[0].publishedAt, '2025-03-11T17:00:00.000Z');
});

test('Tavily missing/invalid keys, network, invalid response and plan limits fail without upstream/private error leakage', async () => {
  let calls = 0;
  await assert.rejects(new TavilyProvider('', async () => {calls++; throw new Error('must not connect');}).search('test','en'), {code:'not_configured'});
  assert.equal(calls, 0);
  for (const [status, code] of [[401,'authentication'], [403,'authentication'], [429,'rate_limit'], [432,'rate_limit'], [433,'rate_limit'], [500,'unavailable']] as const) {
    const provider = new TavilyProvider('test-only', async () => {calls++; return new Response('private body', {status});});
    await assert.rejects(provider.search('test','en'), {code, message:code});
    if (code === 'rate_limit') {const before:number=calls; await assert.rejects(provider.search('test','en'),{code}); assert.equal(calls,before);}
  }
  await assert.rejects(new TavilyProvider('test-only', async()=>{throw new Error('private network details');}).search('test','en'),{code:'network',message:'network'});
  for (const body of ['not json','{}', JSON.stringify({results: 'bad'}), 'x'.repeat(500001)]) {
    await assert.rejects(new TavilyProvider('test-only', async()=>new Response(body)).search('test','en'),{code:'invalid_response'});
  }
  assert.equal(createSearchProvider({TAVILY_API_KEY:'test-only'}).name,'tavily');
  assert.equal(createSearchProvider({RESEARCH_PROVIDER:'searxng'}).name,'searxng');
  await assert.rejects(createSearchProvider({RESEARCH_PROVIDER:'disabled'}).search('test','en'),{code:'unavailable'});
});
