import type { Locale } from '../types/agent_types.js';
import { ResearchError, type SearchProvider, type SearchRecord } from './web_research.js';
import { publicURL, extractPage } from './safe_web.js';

// Official API, basic search only (one credit). No advanced search, generated
// answers, paid extraction, auto-parameters, auto-upgrade or billing endpoints.
export class TavilyProvider implements SearchProvider {
  readonly name = 'tavily';
  readonly configured: boolean;
  private cooldownUntil = 0;
  constructor(private readonly apiKey = process.env.TAVILY_API_KEY, private readonly transport: typeof fetch = fetch) {
    this.configured = Boolean(apiKey?.trim());
  }
  async search(query: string, _locale: Locale): Promise<SearchRecord[]> {
    if (!this.configured) throw new ResearchError('not_configured');
    if (Date.now() < this.cooldownUntil) throw new ResearchError('rate_limit');
    try {
      const response = await this.transport('https://api.tavily.com/search', {
        method: 'POST', redirect: 'error', signal: AbortSignal.timeout(8000),
        headers: {Authorization: `Bearer ${this.apiKey}`, 'Content-Type': 'application/json'},
        body: JSON.stringify({query, search_depth: 'basic', auto_parameters: false, max_results: 5,
          include_answer: false, include_raw_content: false, include_published_date: true, include_usage: true, topic: 'general'}),
      });
      if (response.status === 401 || response.status === 403) throw new ResearchError('authentication');
      if (response.status === 429 || response.status === 432 || response.status === 433) {
        const delay = Number(response.headers.get('retry-after'));
        this.cooldownUntil = Date.now() + (Number.isFinite(delay) && delay > 0 ? Math.min(delay, 300) : 60) * 1000;
        throw new ResearchError('rate_limit');
      }
      if (!response.ok) throw new ResearchError('unavailable');
      if (!response.body) throw new ResearchError('invalid_response');
      const reader = response.body.getReader();
      const chunks: Uint8Array[] = []; let bytes = 0;
      while (true) {
        const {value, done} = await reader.read(); if (done) break;
        bytes += value.length;
        if (bytes > 500000) { await reader.cancel(); throw new ResearchError('invalid_response'); }
        chunks.push(value);
      }
      let body;
      try { body = JSON.parse(Buffer.concat(chunks).toString('utf8')); } catch { throw new ResearchError('invalid_response'); }
      if (!Array.isArray(body.results)) throw new ResearchError('invalid_response');
      const seen = new Set<string>();
      return body.results.flatMap((row: unknown) => {
        if (!row || typeof row !== 'object') return [];
        const item = row as Record<string, unknown>;
        if (typeof item.url !== 'string' || !publicURL(item.url) || typeof item.title !== 'string') return [];
        const url = new URL(item.url); url.hash = '';
        if (seen.has(url.href)) return []; seen.add(url.href);
        return [{url: url.href, title: extractPage(item.title).text.slice(0, 160),
          snippet: typeof item.content === 'string' ? extractPage(item.content).text.slice(0, 700) : '',
          ...(typeof item.published_date === 'string' && item.published_date.length <= 100 && Number.isFinite(Date.parse(item.published_date)) ? {publishedAt: new Date(item.published_date).toISOString()} : {})}];
      }).slice(0, 5);
    } catch (error) {
      if (error instanceof ResearchError) throw error;
      throw new ResearchError('network');
    }
  }
}
