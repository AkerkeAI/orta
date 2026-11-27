import dotenv from 'dotenv';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { WebResearch } from './research/web_research.js';
import { OrtaAgent } from './agent/orta_agent.js';
import { createApp } from './app.js';
import { createProvider, GroqProvider } from './agent/ai_provider.js';

const backendRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..');
dotenv.config({ path: resolve(backendRoot, '.env') });
let provider;
try { provider = createProvider(); }
catch { console.error('Unsupported AI_PROVIDER. Configure a supported provider adapter.'); process.exit(1); }
const port = Number(process.env.PORT ?? 3000);
const research = new WebResearch();
const researchAI = createProvider({...process.env, GROQ_MODEL: process.env.GROQ_RESEARCH_MODEL || 'openai/gpt-oss-20b'});
const agent = new OrtaAgent(provider, research, researchAI);
const visionAI = new GroqProvider(process.env.GROQ_API_KEY, process.env.GROQ_VISION_MODEL || 'qwen/qwen3.8-27b');
createApp(agent, { visionAI }).listen(port, '127.0.0.1', () => {
  console.log(`ORTA backend listening on http://127.0.0.1:${port}`);
  console.log(`Research provider: ${research.provider.name}; configured: ${'configured' in research.provider ? (research.provider.configured ? 'yes' : 'no') : 'no key required'}; public web only`);
  console.log(`Research synthesis model: ${researchAI.model}`);
  console.log(`AI provider: ${provider.name}; model: ${provider.model}`);
  console.log(`Image analysis model: ${visionAI.model}; configured: ${visionAI.configured ? 'yes' : 'no'}`);
  console.log(`Groq configured: ${provider instanceof GroqProvider && provider.configured ? 'yes' : 'no'}`);
});
