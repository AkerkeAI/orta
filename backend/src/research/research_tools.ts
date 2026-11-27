import type { ToolDefinition } from '../agent/tool_registry.js';

// Server-only, read-only. Never placed in the Flutter write/approval registry.
export const researchTools: ToolDefinition[] = [{
  name: 'search_web', permission: 'research',
  description: 'Research current public internet information and genuine sources. Use for opportunities, scholarships, universities, events, competitions, programs, deadlines, requests to look things up, and practical advice for preparing a speech or presentation. For a speech, search trusted presentation guidance, not private project details. Call alone; local reads can precede research. Query uses only relevant non-sensitive interests, broad country/region or education needs; never names, contact details, private notes or full LifeContext. No saving or external actions.',
  parameters: {type: 'object', additionalProperties: false, required: ['query'], properties: {
    query: {type: 'string', minLength: 1, maxLength: 200},
  }},
}];
