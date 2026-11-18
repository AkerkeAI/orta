import { TavilyProvider } from './tavily_provider.js';
import type { Locale } from '../types/agent_types.js';
import { safeGet, publicURL, extractPage } from './safe_web.js';

export interface SearchRecord { title: string; url: string; snippet: string; publishedAt?: string }
export interface SearchProvider { readonly name: string; search(query: string, locale: Locale): Promise<SearchRecord[]> }
export class ResearchError extends Error {
  constructor(readonly code: 'not_configured' | 'authentication' | 'unavailable' | 'rate_limit' | 'network' | 'invalid_response') { super(code); }
}
type Getter = typeof safeGet;
export class SearxngProvider implements SearchProvider {
  readonly name = 'searxng';
  private cooldownUntil = 0;
  constructor(readonly endpoint = process.env.SEARXNG_URL || 'https://searx.tiekoetter.com/', private readonly get: Getter = safeGet) {}
  async search(query: string, locale: Locale): Promise<SearchRecord[]> {
    if (Date.now() < this.cooldownUntil) throw new ResearchError('rate_limit');
    try {
      if (!publicURL(this.endpoint)) throw new ResearchError('unavailable');
      const url = new URL('search', this.endpoint.endsWith('/') ? this.endpoint : this.endpoint + '/');
      url.search = new URLSearchParams({q: query, format: 'json', categories: 'general', safesearch: '1', language: locale === 'kk' ? 'all' : locale}).toString();
      const response = await this.get(url.href, {timeoutMs: 8000, maxBytes: 500000});
      if (response.status === 429) {
        const delay = Number(response.headers['retry-after']);
        this.cooldownUntil = Date.now() + (Number.isFinite(delay) && delay > 0 ? Math.min(delay, 300) : 60) * 1000;
        throw new ResearchError('rate_limit');
      }
      if (response.status !== 200) throw new ResearchError('unavailable');
      let body: unknown;
      try { body = JSON.parse(response.body); } catch { throw new ResearchError('invalid_response'); }
      if (!body || typeof body !== 'object' || !Array.isArray((body as {results?: unknown}).results)) throw new ResearchError('invalid_response');
      const seen = new Set<string>();
      return (body as {results: unknown[]}).results.flatMap(item => {
        if (!item || typeof item !== 'object') return [];
        const row = item as Record<string, unknown>;
        if (typeof row.url !== 'string' || !publicURL(row.url) || typeof row.title !== 'string') return [];
        const url = new URL(row.url); url.hash = '';
        if (seen.has(url.href)) return [];
        seen.add(url.href);
        return [{url: url.href, title: extractPage(row.title).text.slice(0, 160),
          snippet: typeof row.content === 'string' ? extractPage(row.content).text.slice(0, 700) : '',
          ...(typeof row.publishedDate === 'string' && /^\d{4}-\d{2}-\d{2}/.test(row.publishedDate) ? {publishedAt: row.publishedDate.slice(0, 30)} : {})}];
      }).slice(0, 5);
    } catch (error) {
      if (error instanceof ResearchError) throw error;
      throw new ResearchError('network');
    }
  }
}
export function createSearchProvider(env = process.env): SearchProvider {
  if ((env.RESEARCH_PROVIDER || 'tavily') === 'tavily') return new TavilyProvider(env.TAVILY_API_KEY);
  if (env.RESEARCH_PROVIDER === 'searxng') return new SearxngProvider(env.SEARXNG_URL);
  return {name: 'disabled', search: async () => {throw new ResearchError('unavailable');}};
}
export interface ResearchSource extends SearchRecord {
  id: string; retrievedAt: string; evidence: 'page' | 'snippet'; excerpt: string;
  accessible: boolean; accessIssue?: string; originalUrl?: string; modifiedAt?: string;
}
export interface ResearchResult {
  provider: string; status: 'ok' | 'no_results' | 'not_configured' | 'authentication' | 'unavailable' | 'rate_limit' | 'network' | 'invalid_response';
  researchedAt: string; sources: ResearchSource[];
}
export interface ResearchService { research(query: string, locale: Locale): Promise<ResearchResult> }
function excerpt(text: string): string {
  const dates = [...text.matchAll(/.{0,100}(?:deadline|closing date|apply by|applications? (?:open|close)|срок|дедлайн|өтініш).{0,250}/gi)].slice(0, 4).map(match => match[0]);
  return [text.slice(0, 1100), ...dates].join('\n…\n').slice(0, 2200);
}
export class WebResearch implements ResearchService {
  private cache = new Map<string, {until: number; result: ResearchResult}>();
  private inFlight = false;
  constructor(readonly provider: SearchProvider = createSearchProvider(), private readonly get: Getter = safeGet) {}
  async research(query: string, locale: Locale): Promise<ResearchResult> {
    const researchedAt = new Date().toISOString();
    const empty = (status: ResearchResult['status']): ResearchResult => ({provider: this.provider.name, status, researchedAt, sources: []});
    if (!query.trim() || query.length > 200) return empty('invalid_response');
    const key = `${locale}:${query.trim()}`;
    const cached = this.cache.get(key);
    if (cached && cached.until > Date.now()) return structuredClone(cached.result);
    if (this.inFlight) return empty('rate_limit');
    this.inFlight = true;
    try {
      const rows = await this.provider.search(query.trim(), locale);
      const sources = await Promise.all(rows.slice(0, 3).map(async (row, index): Promise<ResearchSource> => {
        const source: ResearchSource = {...row, id: `S${index + 1}`, retrievedAt: researchedAt, accessible: false, evidence: 'snippet', excerpt: row.snippet};
        try {
          const page = await this.get(row.url, {timeoutMs: 6000, maxBytes: 500000});
          if (page.status !== 200) { source.accessIssue = 'page_unavailable'; return source; }
          const type = page.headers['content-type'] || '';
          if (!type.includes('text/html') && !type.includes('text/plain')) { source.accessIssue = 'unsupported_page'; return source; }
          const content = extractPage(page.body);
          // Bot challenges are not page evidence and are never solved or bypassed.
          if (/verify (?:you are|you're) human|just a moment|checking your browser|access denied|captcha/i.test(content.title || '')) {
            source.accessIssue = 'page_blocked'; return source;
          }
          source.accessible = true;
          source.originalUrl = row.url;
          source.url = page.url;
          if (content.text.length > 80) {
            source.evidence = 'page'; source.excerpt = excerpt(content.text);
            source.publishedAt = content.publishedAt || row.publishedAt;
            source.modifiedAt = content.modifiedAt;
          } else { source.accessIssue = 'limited_page_text'; }
        } catch { source.accessIssue = 'page_unavailable'; }
        return source;
      }));
      const result: ResearchResult = {provider: this.provider.name, status: sources.length ? 'ok' : 'no_results', researchedAt, sources};
      if (this.cache.size >= 20) this.cache.delete(this.cache.keys().next().value!);
      this.cache.set(key, {until: Date.now() + 600000, result});
      return structuredClone(result);
    } catch (error) {
      return empty(error instanceof ResearchError ? error.code : 'network');
    } finally { this.inFlight = false; }
  }
}

// Final citation URLs come only from actual provider results/fetches. Model text
// cannot add a plausible invented URL, even when it occurs inside Markdown.
export function groundedAnswer(answer: string, result: ResearchResult, locale: Locale): string {
  const labels = locale === 'ru' ? ['Источники', 'страница проверена', 'только поисковый фрагмент; страница не подтверждена', 'непроверенная ссылка удалена', 'опубликовано']
    : locale === 'kk' ? ['Дереккөздер', 'бет ашылып тексерілді', 'тек іздеу үзіндісі; бет расталмады', 'тексерілмеген сілтеме алынды', 'жарияланған күні']
    : ['Sources', 'page retrieved', 'search snippet only; page not confirmed', 'unverified link removed', 'published'];
  const allowed = new Set(result.sources.flatMap(source => [source.url, source.originalUrl].filter((value): value is string => !!value)));
  let safe = answer.replace(/^\s{0,3}\[[^\]\n]+\]:.*$/gm, '').replace(/\b(?:javascript|data|file|mailto|ftp):[^\s<>]*/gi, labels[3]).replace(/https?:\/\/[^\s<>"'\[\]()]+/gi, value => {
    const suffix = value.match(/[.,;!?]+$/)?.[0] || '';
    const url = suffix ? value.slice(0, -suffix.length) : value;
    return allowed.has(url) ? value : labels[3];
  }).replace(/\[S\d+\]/g, value => result.sources.some(source => `[${source.id}]` === value) ? value : '[?]');
  // Relative, encoded or non-http Markdown targets are also untrusted.
  safe = safe.replace(/(!?\[[^\]\n]*\])\(([^()\n]*)\)/g, (whole, title, target) => allowed.has(target) && !title.startsWith('!') ? whole : title.replace(/^!/, ''));
  if (!result.sources.length) return safe;
  return `${safe}\n\n${labels[0]} (${result.researchedAt.slice(0, 10)}):\n` + result.sources.map(source => {
    const title = source.title.replace(/[\[\]()<>\n]/g, ' ').slice(0, 120) || source.id;
    return `- [${source.id}: ${title}](${source.url}) — ${source.evidence === 'page' ? labels[1] : labels[2]}${source.publishedAt ? `; ${labels[4]} ${source.publishedAt}` : ''}`;
  }).join('\n');
}
