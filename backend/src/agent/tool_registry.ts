interface Schema {type:string; properties?:Record<string,Schema>; required?:string[]; additionalProperties?:boolean; enum?:unknown[]; format?:string; minimum?:number; maximum?:number; minLength?:number; maxLength?:number; maxItems?:number; uniqueItems?:boolean; items?:Schema}
import { readFileSync } from 'node:fs';
export interface ToolDefinition { name: string; description: string; permission: string; parameters: Schema; }
export const registry: ToolDefinition[] = JSON.parse(readFileSync(new URL('../../../assets/orta_tools.json', import.meta.url), 'utf8'));
export interface ToolCall { id:string; name:string; arguments:Record<string,unknown> }
export function validateCall(name:string, args:unknown, definitions:ToolDefinition[]=registry): Record<string,unknown> {
  const definition=definitions.find(t=>t.name===name);
  if(!definition) throw new Error('unknown_tool');
  if(!args || typeof args!=='object' || Array.isArray(args)) throw new Error('invalid_arguments');
  const values=args as Record<string,unknown>;
  function check(value:unknown,rule:Schema):void {
    if(rule.type==='object') {
      if(!value || typeof value!=='object' || Array.isArray(value)) throw new Error('invalid_arguments');
      const item=value as Record<string,unknown>,props=rule.properties??{};
      if(Object.keys(item).some(k=>!Object.hasOwn(props,k))) throw new Error('invalid_arguments');
      if((rule.required??[]).some(k=>!Object.hasOwn(item,k))) throw new Error('missing_information');
      for(const [key,v] of Object.entries(item)) check(v,props[key]);
    } else if(rule.type==='array') {
      if(!Array.isArray(value) || value.length>(rule.maxItems??60) || (rule.uniqueItems && new Set(value.map(v=>JSON.stringify(v))).size!==value.length)) throw new Error('invalid_arguments');
      value.forEach(v=>check(v,rule.items!));
    } else if(rule.type==='integer') {
      if(typeof value!=='number' || !Number.isInteger(value) || value<(rule.minimum??0) || value>(rule.maximum??10080)) throw new Error('invalid_arguments');
    } else {
      if(typeof value!==rule.type || (typeof value==='string' && (!value.trim() || value.length>(rule.maxLength??500)))) throw new Error('invalid_arguments');
      if(rule.enum && !rule.enum.includes(value)) throw new Error('invalid_arguments');
      if(rule.format==='date' && (typeof value!=='string' || !/^\d{4}-\d{2}-\d{2}$/.test(value) || !Number.isFinite(Date.parse(value)) || new Date(value).toISOString().slice(0,10)!==value)) throw new Error('invalid_date');
      if(rule.format==='time' && (typeof value!=='string' || !/^(?:[01]\d|2[0-3]):[0-5]\d$/.test(value))) throw new Error('invalid_time');
    }
  }
  check(values,definition.parameters);
  if(name.startsWith('update_') && name!=='update_planning_preferences' && Object.keys(values).length<2) throw new Error('missing_information');
  if(name==='update_planning_preferences' && !Object.keys(values).length) throw new Error('missing_information');
  if(name==='create_calendar_event' && values.isAllDay!==true && (!values.startTime || !values.endTime)) throw new Error('missing_information');
  return values;
}
export function parseCalls(raw:unknown, definitions:ToolDefinition[]=registry): ToolCall[] {
  if(!Array.isArray(raw) || !raw.length || raw.length>8) throw new Error('invalid_tool_calls');
  const ids=new Set<string>();
  return raw.map(call=>{
    if(!call || typeof call.id!=='string' || !/^[A-Za-z0-9_-]{1,100}$/.test(call.id) || ids.has(call.id) || call.type!=='function' || typeof call.function?.name!=='string' || typeof call.function.arguments!=='string') throw new Error('invalid_tool_calls');
    ids.add(call.id);
    return {id:call.id,name:call.function.name,arguments:validateCall(call.function.name,JSON.parse(call.function.arguments),definitions)};
  });
}
