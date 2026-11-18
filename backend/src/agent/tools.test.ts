import assert from 'node:assert/strict';
import test from 'node:test';
import { GroqProvider, DEFAULT_MODEL, providerRegistry } from './ai_provider.js';
import { parseCalls, validateCall, registry } from './tool_registry.js';
test('A B C D: Groq tool-call parsing validates names, arguments, duplicates and real dates',()=>{
  const call={id:'call1',type:'function',function:{name:'create_exam',arguments:'{"name":"IELTS","date":"2027-06-12"}'}};
  assert.equal(parseCalls([call])[0].name,'create_exam');
  assert.throws(()=>parseCalls([call,call]));
  for(const args of [{name:'IELTS'},{name:'IELTS',date:'2027-02-30'},{name:'IELTS',date:'2027-06-12',evil:true}]) assert.throws(()=>validateCall('create_exam',args));
  assert.throws(()=>validateCall('run_code',{}));
  assert.throws(()=>parseCalls([{...call,function:{name:'create_exam',arguments:'broken'}}]));
  assert.ok(registry.some(t=>t.name==='get_free_time'));
});
test('official Groq request sends structured schemas and parses tool_calls without natural-language JSON',async()=>{
  const provider=new GroqProvider('test-only',DEFAULT_MODEL,async (_url,options)=>{
    const body=JSON.parse(options!.body as string);
    assert.equal(body.tool_choice,'auto');assert.equal(body.tools.length, providerRegistry.length);
    assert.equal(body.tools[0].function.parameters.additionalProperties,false);
    return new Response(JSON.stringify({choices:[{finish_reason:'tool_calls',message:{content:null,tool_calls:[{id:'call1',type:'function',function:{name:'create_project',arguments:'{"name":"GreenCity"}'}}]}}]}));
  });
  const turn=await provider.turn([{role:'user',content:'Create GreenCity'}],true);
  assert.deepEqual(turn.toolCalls[0].arguments,{name:'GreenCity'});
  assert.equal(turn.message,'');
});
test('unknown or invalid Groq calls yield structured safe provider failure',async()=>{
  const provider=new GroqProvider('test-only',DEFAULT_MODEL,async()=>new Response(JSON.stringify({choices:[{finish_reason:'tool_calls',message:{tool_calls:[{id:'x',type:'function',function:{name:'shell',arguments:'{}'}}]}}]})));
  await assert.rejects(provider.turn([],true),{code:'invalid_response'});
});

test('planning schemas validate constraints, numeric session counts and exact group IDs',()=>{
  assert.equal(validateCall('plan_sessions',{title:'IELTS study',kind:'study',period:'next_week',count:3,notAfter:'21:00'}).count,3);
  assert.equal(validateCall('reschedule_calendar_event',{id:'event-1',weekday:4}).weekday,4);
  assert.deepEqual(validateCall('approve_actions',{actionIds:['a','b']}).actionIds,['a','b']);
  for(const args of [{weekdays:[1,1]},{weekdays:[0]},{breakMinutes:-1},{unavailable:[{date:'2027-02-30',startTime:'18:00',endTime:'19:00'}]}]) assert.throws(()=>validateCall('update_planning_preferences',args));
  assert.throws(()=>validateCall('plan_sessions',{title:'IELTS',kind:'study',period:'next_week',count:9}));
  assert.throws(()=>validateCall('approve_actions',{actionIds:['a','a']}));
});

test('all-day schema omits times; timed creation still requires explicit times and rejects unsupported recurrence',()=>{
  assert.equal(validateCall('create_calendar_event',{title:'Day off',date:'2027-01-04',isAllDay:true}).isAllDay,true);
  assert.throws(()=>validateCall('create_calendar_event',{title:'Missing times',date:'2027-01-04'}));
  assert.throws(()=>validateCall('create_calendar_event',{title:'Recurring',date:'2027-01-04',isAllDay:true,recurrence:'weekly'}));
});


test('compact inference retains every tool and critical schema while full validation still rejects long text', async () => {
  const provider = new GroqProvider('test-only', 'openai/gpt-oss-120b', async (_url, options) => {
    const body = JSON.parse(options!.body as string);
    assert.deepEqual(body.tools.map((t: {function:{name:string}}) => t.function.name), providerRegistry.map(t => t.name));
    const exam = body.tools.find((t: {function:{name:string}}) => t.function.name === 'create_exam').function.parameters;
    assert.equal(exam.properties.name.type, 'string');
    assert.equal(exam.properties.name.maxLength, undefined);
    assert.equal(exam.properties.name.minLength, 1);
    const project = body.tools.find((t: {function:{name:string}}) => t.function.name === 'create_project').function.parameters;
    assert.equal(project.properties.description.minLength, undefined);
    assert.equal(registry.find(tool => tool.name === 'create_project')!.parameters.properties!.description.minLength, 1);
    const update = body.tools.find((t: {function:{name:string}}) => t.function.name === 'update_project').function.parameters;
    assert.equal(update.properties.description.minLength, 1);
    assert.equal(project.properties.description.type, 'string');
    assert.equal(project.properties.description.maxLength, undefined);
    assert.deepEqual(project.required, ['name']);
    assert.equal(exam.properties.date.format, 'date');
    assert.equal(exam.additionalProperties, false);
    assert.deepEqual(exam.required, ['name','date']);
    const planning = body.tools.find((t: {function:{name:string}}) => t.function.name === 'plan_sessions').function.parameters;
    assert.equal(planning.properties.count.maximum, 8);
    assert.deepEqual(planning.properties.kind.enum, ['study','work']);
    assert.throws(() => validateCall('create_exam', {name: 'x'.repeat(501), date:'2027-06-12'}));
    return new Response(JSON.stringify({choices:[{finish_reason:'stop',message:{content:'Actual answer'}}]}));
  });
  assert.equal((await provider.turn([], true)).message, 'Actual answer');
});


test('known empty CREATE project placeholders are omitted before strict validation', async () => {
  const original = {name: 'Green Lab', description: '', stage: '', needs: ''};
  assert.throws(() => validateCall('create_project', original), /invalid_arguments/);
  const provider = new GroqProvider('test-only', DEFAULT_MODEL, async () => new Response(JSON.stringify({
    choices: [{finish_reason: 'tool_calls', message: {tool_calls: [
      {id: 'project-qa', type: 'function', function: {name: 'create_project', arguments: JSON.stringify(original)}},
    ]}}],
  })));
  const result = await provider.turn([{role: 'user', content: 'Save Green Lab'}], true);
  assert.deepEqual(result.toolCalls[0].arguments, {name: 'Green Lab'});
  assert.deepEqual(validateCall('create_project', result.toolCalls[0].arguments), {name: 'Green Lab'});
  assert.deepEqual(JSON.parse((result.rawCalls![0] as {function:{arguments:string}}).function.arguments), {name: 'Green Lab'});
  assert.deepEqual(original, {name: 'Green Lab', description: '', stage: '', needs: ''});
});

test('placeholder omission preserves actual details and never repairs invalid names, dates, IDs, enums or updates', async () => {
  async function turn(name: string, args: Record<string, unknown>) {
    const provider = new GroqProvider('test-only', DEFAULT_MODEL, async () => new Response(JSON.stringify({
      choices: [{finish_reason: 'tool_calls', message: {tool_calls: [
        {id: 'qa', type: 'function', function: {name, arguments: JSON.stringify(args)}},
      ]}}],
    })));
    return provider.turn([], true);
  }
  assert.deepEqual((await turn('create_project', {name: 'Green Lab', description: 'Community garden', stage: ''})).toolCalls[0].arguments,
    {name: 'Green Lab', description: 'Community garden'});
  for (const [name, args] of [
    ['create_project', {name: '', description: ''}],
    ['create_project', {name: 'Green Lab', description: ' '}],
    ['create_project', {name: 'Green Lab', unexpected: ''}],
    ['update_project', {id: 'saved-project', description: ''}],
    ['update_project', {id: '', name: 'Green Lab'}],
    ['create_exam', {name: 'IELTS', date: ''}],
    ['create_exam', {name: 'IELTS', date: '2026-11-20', importance: ''}],
    ['create_task', {title: 'Study', projectId: ''}],
    ['create_goal', {titleKey: 'Study', areaKey: ''}],
  ] as [string, Record<string, unknown>][]) {
    await assert.rejects(turn(name, args), {code: 'invalid_response'});
  }
});

test('Groq inference uses the ORTA HH:mm pattern instead of RFC3339 time while local validation stays strict', async () => {
  const provider = new GroqProvider('test-only', 'openai/gpt-oss-120b', async (_url, options) => {
    const payload = JSON.parse(options!.body as string);
    for (const tool of payload.tools) {
      for (const [key, property] of Object.entries(tool.function.parameters.properties) as [string, Record<string, unknown>][]) {
        const original = providerRegistry.find(definition => definition.name === tool.function.name)!.parameters.properties![key];
        if (original.format === 'time') {
          assert.equal(property.format, undefined);
          const pattern = new RegExp(property.pattern as string);
          assert.ok(pattern.test('18:00'));
          assert.ok(!pattern.test('18:00:00Z'));
          assert.ok(!pattern.test('25:00'));
        }
      }
    }
    return new Response(JSON.stringify({choices:[{finish_reason:'tool_calls', message:{content:null,
      tool_calls:[{id:'calendar-1',type:'function',function:{name:'create_calendar_event',
        arguments:JSON.stringify({title:'IELTS study',date:'2026-10-23',startTime:'18:00',endTime:'19:00'})}}]}}]}));
  });
  const turn = await provider.turn([{role:'user',content:'Friday from 18:00 to 19:00'}],true);
  assert.equal(turn.toolCalls[0].arguments.startTime,'18:00');
  assert.throws(()=>validateCall('create_calendar_event',{title:'IELTS study',date:'2026-10-23',startTime:'18:00:00Z',endTime:'19:00'}));
});


test('research save uses an explicit proposal tool choice while local approval remains outside the backend', async()=> {
  const provider=new GroqProvider('test-only',DEFAULT_MODEL,async(_url,options)=>{
    const body=JSON.parse(options!.body as string);
    assert.deepEqual(body.tool_choice,{type:'function',function:{name:'create_project'}});
    return new Response(JSON.stringify({choices:[{finish_reason:'tool_calls',message:{tool_calls:[{id:'save-finding',type:'function',function:{name:'create_project',arguments:'{"name":"Erasmus Mundus research","description":"Source: https://example.org/program"}'}}]}}]}));
  });
  assert.equal((await provider.turn([],true,{requiredTool:'create_project'})).toolCalls[0].name,'create_project');
  await assert.rejects(provider.turn([],true,{requiredTool:'approve_action'}),{code:'invalid_response'});
  await assert.rejects(provider.turn([],true,{researchOnly:true,requiredTool:'create_project'}),{code:'invalid_response'});
});
