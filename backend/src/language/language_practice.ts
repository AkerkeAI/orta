import { ProviderError, type AIProvider } from '../agent/ai_provider.js';

export const PRACTICE_SKILLS = ['speaking','writing','listening','reading','vocabulary','scenario','conversation'] as const;
export const PRACTICE_SCENARIOS = ['everyday','universityInterview','intendedMajor','scholarshipInterview','personalProject','professionalIntro'] as const;

export type PracticeSkill = typeof PRACTICE_SKILLS[number];
export type PracticeScenario = typeof PRACTICE_SCENARIOS[number];

export interface ApprovedLanguageContext {
  intendedMajor?: string;
  preparingUniversity?: boolean;
  hasProject?: boolean;
}

export interface LanguagePracticeRequest {
  action: 'start' | 'evaluate' | 'chat';
  languageName: string;
  level: string;
  skill: PracticeSkill;
  scenario: PracticeScenario;
  prompt?: string;
  stimulus?: string;
  response?: string;
  transcript?: string;
  message?: string;
  interfaceLanguage?: 'en' | 'ru' | 'kk';
  chatHistory?: { role: 'user' | 'assistant'; content: string }[];
  approvedContext?: ApprovedLanguageContext;
}

export interface LanguagePracticeResult {
  prompt?: string;
  stimulus?: string;
  corrections?: string;
  explanation?: string;
  alternativePhrasing?: string;
  vocabulary?: { term: string; meaning: string }[];
  feedback?: string;
  tutorReply?: string;
  aiAvailable: boolean;
}

const LEVELS = new Set(['A1','A2','B1','B2','C1','C2']);

export function validLanguagePracticeRequest(body: unknown): body is LanguagePracticeRequest {
  if (!body || typeof body !== 'object' || Array.isArray(body)) return false;
  const value = body as Record<string, unknown>;
  if (value.action !== 'start' && value.action !== 'evaluate' && value.action !== 'chat') return false;
  if (typeof value.languageName !== 'string' || !value.languageName.trim() || value.languageName.length > 80) return false;
  if (typeof value.level !== 'string' || !LEVELS.has(value.level)) return false;
  if (!PRACTICE_SKILLS.includes(value.skill as PracticeSkill)) return false;
  if (!PRACTICE_SCENARIOS.includes(value.scenario as PracticeScenario)) return false;
  for (const field of ['prompt','stimulus','response','transcript','message']) {
    if (value[field] !== undefined && (typeof value[field] !== 'string' || (value[field] as string).length > 8000)) return false;
  }
  if (value.action === 'chat') {
    if (typeof value.message !== 'string' || !value.message.trim() || value.message.length > 2000) return false;
    if (!['en','ru','kk'].includes(value.interfaceLanguage as string)) return false;
    if (value.chatHistory !== undefined && (
      !Array.isArray(value.chatHistory) || value.chatHistory.length > 12 ||
      !value.chatHistory.every(turn => turn && typeof turn === 'object' &&
        ['user','assistant'].includes((turn as Record<string, unknown>).role as string) &&
        typeof (turn as Record<string, unknown>).content === 'string' &&
        ((turn as Record<string, unknown>).content as string).length <= 2000 &&
        Object.keys(turn as Record<string, unknown>).every(key => ['role','content'].includes(key)))
    )) return false;
  }
  if (value.action === 'evaluate' && (typeof value.response !== 'string' || !value.response.trim())) return false;
  if (value.approvedContext !== undefined) {
    if (!value.approvedContext || typeof value.approvedContext !== 'object' || Array.isArray(value.approvedContext)) return false;
    const context = value.approvedContext as Record<string, unknown>;
    if (context.intendedMajor !== undefined && (typeof context.intendedMajor !== 'string' || context.intendedMajor.length > 120)) return false;
    if (context.preparingUniversity !== undefined && typeof context.preparingUniversity !== 'boolean') return false;
    if (context.hasProject !== undefined && typeof context.hasProject !== 'boolean') return false;
    const allowed = new Set(['intendedMajor','preparingUniversity','hasProject']);
    if (Object.keys(context).some(key => !allowed.has(key))) return false;
  }
  return true;
}

export function languageSystemPrompt(): string {
  return `You are Language ORTA, a language tutor for students. Help them practise speaking, writing, listening, reading, vocabulary and conversation.

Hard boundary: Language ORTA can learn from a student's life. It cannot rewrite their life.
You must never create, edit, submit or silently change university applications, application essays, documents, emails, projects, core tasks, calendar events or student profile information. Practice content stays fictional or rehearsed and separate from real application materials.

Use only the approved limited context supplied (intended major category, whether they are preparing for university, whether they have a project). Do not ask for or invent private names, essay text, deadlines or application IDs.

Adapt difficulty to the stated CEFR level and practice objective. Return compact JSON only, with no markdown fences and no tool calls.`;
}

export function buildUserMessage(request: LanguagePracticeRequest): string {
  const context = request.approvedContext ?? {};
  const approved = JSON.stringify({
    intendedMajor: typeof context.intendedMajor === 'string' ? context.intendedMajor.trim().slice(0, 120) : '',
    preparingUniversity: Boolean(context.preparingUniversity),
    hasProject: Boolean(context.hasProject),
  });
  if (request.action === 'chat') {
    return `Answer the student's question about language learning or this ${request.skill} exercise in ${request.languageName} at ${request.level}.
Reply in the student's interface language (${request.interfaceLanguage}). When useful, include a short example in ${request.languageName} and explain it in the interface language.
Student question: ${request.message ?? ''}
Recent chat turns: ${JSON.stringify(request.chatHistory ?? []).slice(0, 10000)}
Approved context: ${approved}
Be concise, supportive, accurate, and suited to the stated level. If the student asks for help with a real application essay or document, offer practice with a fictional example instead.
JSON keys: tutorReply.`;
  }
  if (request.action === 'start') {
    const skillInstructions = request.skill === 'reading'
      ? 'Write a fresh short passage of 70–120 words entirely in the target language, then ask one comprehension question whose answer is supported by the passage. Keep the passage in stimulus and the instruction/question in prompt.'
      : request.skill === 'listening'
      ? 'Write a fresh, natural spoken script of 45–80 words entirely in the target language, then ask one listening-comprehension question whose answer is supported by the script. Put the script in stimulus; the client will play it as audio and hide its text until after the answer.'
      : request.skill === 'speaking'
      ? 'Give one specific, engaging speaking topic and a clear short prompt in the target language. Do not ask the learner to type instead of speak.'
      : 'Create one concrete, level-appropriate task with a clear response format.';
    const avoid = request.prompt?.trim()
      ? `Do not repeat this previous prompt or passage; choose a different situation and wording: ${request.prompt.slice(0, 4000)}`
      : 'Choose a varied, specific task rather than a generic “describe your day” prompt.';
    return `Create one fresh ${request.skill} exercise in ${request.languageName} at ${request.level} for scenario ${request.scenario}.
${skillInstructions}
${avoid}
Approved context: ${approved}
JSON keys: prompt, stimulus, tutorReply.
tutorReply is the first conversational line when skill is conversation. Otherwise leave tutorReply empty.
Do not include real application materials.`;
  }
  return `Evaluate this ${request.skill} practice in ${request.languageName} at ${request.level} for scenario ${request.scenario}.
Approved context: ${approved}
Exercise prompt: ${request.prompt ?? ''}
Stimulus: ${request.stimulus ?? ''}
Transcript: ${request.transcript ?? ''}
Student response: ${request.response ?? ''}
JSON keys: corrections, explanation, alternativePhrasing, vocabulary (array of {term, meaning}), feedback, tutorReply.
Be specific and actionable. If the response is empty of language, say so honestly. Never claim you changed any application or life record.`;
}

function extractJson(text: string): Record<string, unknown> | null {
  const start = text.indexOf('{');
  const end = text.lastIndexOf('}');
  if (start < 0 || end <= start) return null;
  try {
    const parsed = JSON.parse(text.slice(start, end + 1));
    return parsed && typeof parsed === 'object' && !Array.isArray(parsed) ? parsed as Record<string, unknown> : null;
  } catch {
    return null;
  }
}

function textField(value: unknown, fallback = ''): string {
  return typeof value === 'string' ? value.trim().slice(0, 4000) : fallback;
}

function vocabulary(value: unknown): { term: string; meaning: string }[] {
  if (!Array.isArray(value)) return [];
  return value.slice(0, 12).flatMap(item => {
    if (!item || typeof item !== 'object') return [];
    const row = item as Record<string, unknown>;
    const term = textField(row.term);
    const meaning = textField(row.meaning);
    return term ? [{ term, meaning }] : [];
  });
}

export class LanguageCoach {
  constructor(readonly provider: AIProvider) {}

  async handle(request: LanguagePracticeRequest): Promise<LanguagePracticeResult> {
    if (!this.provider.configured) {
      throw new ProviderError('not_configured');
    }
    const raw = await this.provider.complete([
      { role: 'system', content: languageSystemPrompt() },
      { role: 'user', content: buildUserMessage(request) },
    ]);
    const parsed = extractJson(raw);
    if (!parsed) throw new ProviderError('invalid_response');
    if (request.action === 'chat') {
      const tutorReply = textField(parsed.tutorReply);
      if (!tutorReply) throw new ProviderError('invalid_response');
      return { tutorReply, aiAvailable: true };
    }
    if (request.action === 'start') {
      const prompt = textField(parsed.prompt);
      if (!prompt) throw new ProviderError('invalid_response');
      return {
        prompt,
        stimulus: textField(parsed.stimulus),
        tutorReply: textField(parsed.tutorReply),
        aiAvailable: true,
      };
    }
    return {
      corrections: textField(parsed.corrections),
      explanation: textField(parsed.explanation),
      alternativePhrasing: textField(parsed.alternativePhrasing),
      vocabulary: vocabulary(parsed.vocabulary),
      feedback: textField(parsed.feedback),
      tutorReply: textField(parsed.tutorReply),
      aiAvailable: true,
    };
  }
}

export interface StudentGate {
  studentIdFromAuthorization(header: string | undefined): Promise<'student' | 'denied' | 'anonymous'>;
}

export async function defaultStudentGate(
  header: string | undefined,
  env = process.env,
  transport: typeof fetch = fetch,
): Promise<'student' | 'denied' | 'anonymous'> {
  const url = env.SUPABASE_URL?.trim();
  const anon = env.SUPABASE_PUBLISHABLE_KEY?.trim() || env.SUPABASE_ANON_KEY?.trim();
  // Local development may run without auth configuration. A deployed service
  // must fail closed so public callers cannot use the paid coaching endpoint.
  if (!url || !anon) return env.NODE_ENV === 'production' ? 'denied' : 'anonymous';
  const token = header?.startsWith('Bearer ') ? header.slice(7).trim() : '';
  if (!token) return 'denied';
  try {
    const userResponse = await transport(`${url.replace(/\/$/, '')}/auth/v1/user`, {
      headers: { Authorization: `Bearer ${token}`, apikey: anon },
      signal: AbortSignal.timeout(8000),
    });
    if (!userResponse.ok) return 'denied';
    const user = await userResponse.json() as { id?: string };
    if (typeof user.id !== 'string' || !user.id) return 'denied';
    const profileResponse = await transport(
    `${url.replace(/\/$/, '')}/rest/v1/profiles?id=eq.${encodeURIComponent(user.id)}&select=role,app_mode`,
      {
        headers: {
          Authorization: `Bearer ${token}`,
          apikey: anon,
        },
        signal: AbortSignal.timeout(8000),
      },
    );
    if (!profileResponse.ok) return 'denied';
    const rows = await profileResponse.json() as { role?: string; app_mode?: string }[];
    return Array.isArray(rows) && (rows[0]?.role === 'student' || rows[0]?.app_mode === 'personal') ? 'student' : 'denied';
  } catch {
    return 'denied';
  }
}
