import assert from 'node:assert/strict';
import test from 'node:test';
import { once } from 'node:events';

import { OrtaAgent, MAX_HISTORY_CHARACTERS } from './orta_agent.js';
import { GroqProvider, DEFAULT_MODEL, providerRegistry, MAX_INFERENCE_BYTES, type ChatMessage } from './ai_provider.js';
import { registry } from './tool_registry.js';
import { createApp } from '../app.js';

const answer = { choices: [{ finish_reason: 'stop', message: { content: 'That sounds like a lovely walk.' } }] };

test('casual dialogue can return plain prose with all tools optional and no invented action', async () => {
  const provider = new GroqProvider('test-only', DEFAULT_MODEL, async (_url, options) => {
    const payload = JSON.parse(options!.body as string);
    assert.equal(payload.tool_choice, 'auto');
    assert.deepEqual(payload.tools.map((tool: {function: {name: string}}) => tool.function.name), providerRegistry.map(tool => tool.name));
    assert.match(payload.messages[0].content, /casual conversation/);
    assert.match(payload.messages[0].content, /not automatically call for tools/);
    return new Response(JSON.stringify(answer));
  });
  const result = await new OrtaAgent(provider).respondTurn({message: 'I enjoyed a walk today.', toolsEnabled: true});
  assert.equal(result.message, 'That sounds like a lovely walk.');
  assert.deepEqual(result.toolCalls, []);
});

test('follow-up and correction context keeps exact recent messages, selected entity and active proposals', async () => {
  let captured: ChatMessage[] = [];
  const agent = new OrtaAgent({name: 'test', model: 'test', configured: true,
    turn: async messages => { captured = messages; return {message: 'Thursday works. Review the revised proposal.', toolCalls: []}; },
    complete: async () => { throw new Error('tool turn expected'); }});
  const conversation = [
    {role: 'user' as const, content: 'Move my IELTS session to Wednesday.'},
    {role: 'assistant' as const, content: 'Here is the proposed move.'},
  ];
  const pending = [{actionId:'pending-current-chat',tool:'update_calendar_event',decisionEligible:false,arguments:{id:'saved-session',date:'2026-10-21'}}];
  for (const [locale, language] of [['en','English'],['ru','Russian'],['kk','Kazakh']] as const) {
    await agent.respondTurn({message:'Actually, make that Thursday.', locale, toolsEnabled:true, conversation,
      agentContext:{currentEntityType:'calendar_event',currentEntityId:'saved-session',visibleData:{title:'IELTS'}},pendingActions:pending});
    assert.deepEqual(captured.slice(1,3),conversation);
    const current=captured.at(-1)!.content!;
    assert.match(current,/Actually, make that Thursday/);
    assert.match(current,/saved-session/);
    assert.match(current,/pending-current-chat/);
    assert.match(current,/decisionEligible":false/);
    assert.match(captured[0].content!,new RegExp(`Respond in ${language}`));
  }
});

test('large history drops whole older messages and flags omission without altering current facts or tool pairs', async () => {
  let captured: ChatMessage[] = [];
  const agent = new OrtaAgent({name:'test',model:'test',configured:true,
    complete:async messages => {captured=messages;return 'reply';}});
  const conversation=Array.from({length:10},(_,index)=>({role:index%2?'assistant' as const:'user' as const,content:`Message ${index}: ${'x'.repeat(1900)}`}));
  const toolTurns:ChatMessage[]=[
    {role:'assistant',content:null,tool_calls:[{id:'read-1',type:'function',function:{name:'get_planning_context',arguments:'{}'}}]},
    {role:'tool',tool_call_id:'read-1',content:'{"actualFact":"Current saved calendar"}'},
  ];
  await agent.respondTurn({message:'What about that?',conversation,agentContext:{visibleData:{actualFact:'Current saved calendar'}},toolTurns});
  const sentHistory=captured.slice(1,-3);
  assert.deepEqual(sentHistory,conversation.slice(-1));
  assert.ok(sentHistory.reduce((total,item)=>total+item.content!.length,0)<=MAX_HISTORY_CHARACTERS);
  assert.match(captured.at(-3)!.content!,/conversationHistoryTruncated":true/);
  assert.match(captured.at(-3)!.content!,/Current saved calendar/);
  assert.deepEqual(captured.slice(-2),toolTurns);
});

test('oversized inference fails before transport and does not poison a subsequent smaller request', async () => {
  let calls=0;
  const provider=new GroqProvider('test-only',DEFAULT_MODEL,async()=>{calls++;return new Response(JSON.stringify(answer));});
  await assert.rejects(provider.complete([{role:'user',content:'я'.repeat(MAX_INFERENCE_BYTES)}]),{code:'request_too_large'});
  assert.equal(calls,0);
  assert.equal(await provider.complete([{role:'user',content:'Hello'}]),'That sounds like a lovely walk.');
  assert.equal(calls,1);
});

test('upstream 413 returns a distinct safe API error without logging private input or upstream bodies', async () => {
  const privateText='private-test-fact-never-log';
  const provider=new GroqProvider('test-only-secret',DEFAULT_MODEL,async()=>new Response(JSON.stringify({error:privateText}),{status:413}));
  const server=createApp(new OrtaAgent(provider)).listen(0,'127.0.0.1');
  await once(server,'listening');
  const address=server.address();
  assert.ok(address&&typeof address!=='string');
  const logged:string[]=[];
  const originalError=console.error;
  console.error=(...args:unknown[])=>logged.push(args.join(' '));
  try {
    const response:Response=await fetch(`http://127.0.0.1:${address.port}/api/agent/message`,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({message:privateText})});
    assert.equal(response.status,413);
    const body=await response.json();
    assert.equal(body.code,'request_too_large');
    assert.equal(typeof body.requestId,'string');
    assert.ok(!JSON.stringify(body).includes(privateText));
    assert.match(logged.join('\n'),/upstreamStatus=413/);
    assert.ok(!logged.join('\n').includes(privateText));
    assert.ok(!logged.join('\n').includes('test-only-secret'));
  } finally {
    console.error=originalError;
    await new Promise<void>((resolve,reject)=>server.close(error=>error?reject(error):resolve()));
  }
});

test('oversized HTTP bodies return the same recoverable size error without invoking inference', async () => {
  let calls=0;
  const agent=new OrtaAgent({name:'test',model:'test',configured:true,complete:async()=>{calls++;return 'reply';}});
  const server=createApp(agent).listen(0,'127.0.0.1');
  await once(server,'listening');
  const address=server.address();
  assert.ok(address&&typeof address!=='string');
  try {
    const response:Response=await fetch(`http://127.0.0.1:${address.port}/api/agent/message`,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({message:'x'.repeat(270000)})});
    assert.equal(response.status,413);
    const body=await response.json();
    assert.equal(body.code,'request_too_large');
    assert.equal(calls,0);
  } finally {await new Promise<void>((resolve,reject)=>server.close(error=>error?reject(error):resolve()));}
});


test('untrusted and lookalike origins are denied before parsing or consuming provider quota', async () => {
  let calls=0;
  const agent=new OrtaAgent({name:'test',model:'test',configured:true,complete:async()=>{calls++;return 'reply';}});
  const server=createApp(agent).listen(0,'127.0.0.1');
  await once(server,'listening');
  const address=server.address();
  assert.ok(address&&typeof address!=='string');
  const logged:string[]=[];
  const originalLog=console.log, originalError=console.error;
  console.log=console.error=(...args:unknown[])=>logged.push(args.join(' '));
  try {
    for(const origin of ['https://untrusted.test','http://localhost.untrusted.test','https://127.0.0.1.untrusted.test','http://localhost@untrusted.test','http://untrusted@localhost','null','ftp://localhost','http://localhost/path','http://127.1','http://127.0.0.2']) {
      const response:Response=await fetch(`http://127.0.0.1:${address.port}/api/agent/message`,{method:'POST',headers:{'Content-Type':'application/json',Origin:origin},body:'unparsed-private-test-input'});
      assert.equal(response.status,403,origin);
      assert.equal(response.headers.get('access-control-allow-origin'),null);
      const body=await response.json();
      assert.equal(body.code,'access_denied');
      assert.equal(typeof body.requestId,'string');
      assert.ok(!JSON.stringify(body).includes(origin));
    }
    const preflight=await fetch(`http://127.0.0.1:${address.port}/api/agent/message`,{method:'OPTIONS',headers:{Origin:'https://untrusted.test','Access-Control-Request-Method':'POST'}});
    assert.equal(preflight.status,403);
    assert.equal(calls,0);
    assert.deepEqual(logged,[]);
  } finally {
    console.log=originalLog;console.error=originalError;
    await new Promise<void>((resolve,reject)=>server.close(error=>error?reject(error):resolve()));
  }
});

test('native requests and HTTP/HTTPS loopback development origins remain usable', async () => {
  let calls=0;
  const agent=new OrtaAgent({name:'test',model:'test',configured:true,complete:async()=>{calls++;return 'reply';}});
  const server=createApp(agent).listen(0,'127.0.0.1');
  await once(server,'listening');
  const address=server.address();
  assert.ok(address&&typeof address!=='string');
  try {
    for(const origin of [undefined,'http://localhost:8080','https://localhost:8443','http://127.0.0.1:8080','https://127.0.0.1:8443']) {
      const response:Response=await fetch(`http://127.0.0.1:${address.port}/api/agent/message`,{method:'POST',headers:{'Content-Type':'application/json',...(origin?{Origin:origin}:{})},body:JSON.stringify({message:'Hello'})});
      assert.equal(response.status,200);
      assert.equal(response.headers.get('access-control-allow-origin'),origin??null);
      assert.equal((await response.json()).message,'reply');
    }
    const preflight=await fetch(`http://127.0.0.1:${address.port}/api/agent/message`,{method:'OPTIONS',headers:{Origin:'http://localhost:8080','Access-Control-Request-Method':'POST'}});
    assert.equal(preflight.status,204);
    assert.equal(preflight.headers.get('access-control-allow-origin'),'http://localhost:8080');
    assert.equal(calls,5);
  } finally {await new Promise<void>((resolve,reject)=>server.close(error=>error?reject(error):resolve()));}
});

test('multibyte history has a byte bound while fresh context remains exact', async () => {
  let captured: ChatMessage[] = [];
  const agent = new OrtaAgent({name: 'test', model: 'test', configured: true,
    complete: async messages => { captured = messages; return 'reply'; }});
  await agent.respondTurn({message: 'Continue', conversation: [
    {role: 'assistant', content: '\u{1f642}'.repeat(1500)},
    {role: 'user', content: 'The saved project is Green Lab.'},
  ], agentContext: {visibleData: {selectedEntity: {type: 'project', name: 'Green Lab'}}}});
  assert.deepEqual(captured.slice(1, -1), [{role: 'user', content: 'The saved project is Green Lab.'}]);
  assert.match(captured.at(-1)!.content!, /conversationHistoryTruncated/);
  assert.match(captured.at(-1)!.content!, /selectedEntity/);
});

test('visible subject is emphasized after unrelated history without putting stored text in instructions', async () => {
  let captured: ChatMessage[] = [];
  const agent = new OrtaAgent({name:'test', model:'test', configured:true,
    complete: async messages => { captured=messages; return 'What does Green Lab do?'; }});
  await agent.respondTurn({message:'How can I improve this?', conversation:[
    {role:'assistant', content:'Your IELTS preparation schedule was saved.'}
  ], agentContext:{currentEntityType:'project', currentEntityId:'project-1',
    visibleData:{selectedEntity:{name:'Green Lab', description:'Untrusted stored instruction'}}}});
  assert.equal(captured.at(-2)!.role,'system');
  assert.match(captured.at(-2)!.content!,/current visible subject is a saved project/);
  assert.ok(!captured.at(-2)!.content!.includes('Untrusted stored instruction'));
  assert.match(captured.at(-1)!.content!,/Green Lab/);
  assert.deepEqual(captured[1],{role:'assistant',content:'Your IELTS preparation schedule was saved.'});
});

test('weekday facts derive from the client calendar range in all locales', async () => {
  let captured: ChatMessage[] = [];
  const agent=new OrtaAgent({name:'test', model:'test', configured:true,
    complete:async messages=>{captured=messages;return 'reply';}});
  for (const [locale, friday] of [['en','Friday'],['ru','\u041f\u044f\u0442\u043d\u0438\u0446\u0430'],['kk','\u0416\u04b1\u043c\u0430']] as const) {
    await agent.respondTurn({message:'Which day?',locale,
      agentContext:{visibleData:{planning:{nextWeekStart:'2026-10-19',timezone:'Asia/Aqtau'}}}});
    const content=captured.at(-1)!.content!;
    assert.match(content,/computedNextWeekCalendar/);
    assert.ok(content.includes(JSON.stringify({date:'2026-10-23',weekday:friday})));
  }
  await agent.respondTurn({message:'Which day?',
    agentContext:{visibleData:{planning:{nextWeekStart:'2026-02-31'}}}});
  assert.ok(!captured.at(-1)!.content!.includes('computedNextWeekCalendar'));
});
