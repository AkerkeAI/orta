import { lookup } from 'node:dns/promises';
import { isIP } from 'node:net';
import { request } from 'node:https';

export type WebErrorCode = 'network' | 'unsafe_url' | 'response_too_large' | 'invalid_response';
export class WebError extends Error {
  constructor(readonly code: WebErrorCode) { super(code); }
}

/** Conservative public-address allowlist. Special-use, transition and mapped addresses are excluded. */
export function isPublicAddress(address: string): boolean {
  const version = isIP(address);
  if (version === 4) {
    const [a, b, c] = address.split('.').map(Number);
    return !(a === 0 || a === 10 || a === 127 || a >= 224 ||
      (a === 100 && b >= 64 && b <= 127) ||
      (a === 169 && b === 254) || (a === 172 && b >= 16 && b <= 31) ||
      (a === 192 && (b === 0 || b === 168 || (b === 88 && c === 99))) ||
      (a === 198 && (b === 18 || b === 19 || (b === 51 && c === 100))) ||
      (a === 203 && b === 0 && c === 113));
  }
  if (version === 6) {
    // Allow only native global unicast. IPv4 embeddings and NAT64 never enter this range.
    if (address.includes('.')) return false;
    const parts = address.toLowerCase().split('::');
    const left = parts[0] ? parts[0].split(':').map(n => parseInt(n, 16)) : [];
    const right = parts[1] ? parts[1].split(':').map(n => parseInt(n, 16)) : [];
    const words = parts.length === 2 ? [...left, ...Array(8 - left.length - right.length).fill(0), ...right] : left;
    const [first, second] = words;
    return first >= 0x2000 && first <= 0x3fff &&
      !(first === 0x2001 && (second < 0x200 || second === 0xdb8)) &&
      first !== 0x2002 && !(first === 0x3fff && second < 0x1000);
  }
  return false;
}

/** Syntactic check only; safeGet additionally resolves and pins every destination. */
export function publicURL(value: string): boolean {
  try {
    if (!value || value.length > 4096) return false;
    const url = new URL(value);
    if (url.protocol !== 'https:' || url.username || url.password || (url.port && url.port !== '443')) return false;
    const host = url.hostname.replace(/^\[|\]$/g, '').toLowerCase();
    if (isIP(host)) return isPublicAddress(host);
    return host.includes('.') && !host.endsWith('.') &&
      !/(^|\.)(localhost|local|internal|home|test|invalid|example)$/.test(host);
  } catch { return false; }
}

export interface WebResponse { url: string; status: number; headers: Record<string, string>; body: string; }

async function vettedAddress(hostname: string, signal: AbortSignal): Promise<{address:string;family:number}> {
  const host = hostname.replace(/^\[|\]$/g, '');
  if (isIP(host)) {
    if (!isPublicAddress(host)) throw new WebError('unsafe_url');
    return {address: host, family: isIP(host)};
  }
  let abort: (() => void) | undefined;
  try {
    const answers = await Promise.race([
      lookup(host, {all: true, verbatim: true}),
      new Promise<never>((_, reject) => {
        abort = () => reject(new WebError('network'));
        if (signal.aborted) abort(); else signal.addEventListener('abort', abort, {once:true});
      }),
    ]);
    if (!answers.length || answers.some(answer => !isPublicAddress(answer.address))) throw new WebError('unsafe_url');
    return answers[0];
  } catch (error) {
    if (error instanceof WebError) throw error;
    throw new WebError('network');
  } finally { if (abort) signal.removeEventListener('abort', abort); }
}

export async function safeGet(value: string, options: {timeoutMs?:number;maxBytes?:number} = {}): Promise<WebResponse> {
  const timeoutMs = Math.max(1, Math.min(options.timeoutMs ?? 6000, 20000));
  const maxBytes = Math.max(1, Math.min(options.maxBytes ?? 200000, 1000000));
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    let current = value;
    const visited = new Set<string>();
    for (let redirects = 0; redirects <= 3; redirects++) {
      if (!publicURL(current)) throw new WebError('unsafe_url');
      const url = new URL(current);
      url.hash = '';
      if (visited.has(url.href)) throw new WebError('invalid_response');
      visited.add(url.href);
      const pinned = await vettedAddress(url.hostname, controller.signal);
      if (controller.signal.aborted) throw new WebError('network');
      const result = await new Promise<WebResponse>((resolve, reject) => {
        const req = request(url, {
          method: 'GET', signal: controller.signal, family: pinned.family,
          // Native TLS verification still uses the original URL host. DNS cannot rebind between vetting and connection.
          lookup: (_hostname, _options, callback) => callback(null, pinned.address, pinned.family),
          headers: {'User-Agent':'ORTA/1.0 (public web research)', 'Accept':'text/html,application/xhtml+xml,text/plain;q=0.8', 'Accept-Encoding':'identity'},
        }, response => {
          const status = response.statusCode ?? 0;
          const headers: Record<string,string> = {};
          for (const name of ['content-type','content-length','last-modified','date','retry-after','location']) {
            const raw = response.headers[name];
            if (raw !== undefined) headers[name] = Array.isArray(raw) ? raw.join(', ') : raw;
          }
          if ([301,302,303,307,308].includes(status)) {
            response.destroy();
            resolve({url:url.href,status,headers,body:''});
            return;
          }
          const encoding = response.headers['content-encoding'];
          if (encoding && encoding !== 'identity') {
            response.destroy(); reject(new WebError('invalid_response')); return;
          }
          const declared = Number(response.headers['content-length']);
          if (Number.isFinite(declared) && declared > maxBytes) {
            response.destroy(); reject(new WebError('response_too_large')); return;
          }
          const chunks: Buffer[] = [];
          let size = 0;
          response.on('data', (chunk: Buffer) => {
            size += chunk.length;
            if (size > maxBytes) {
              response.destroy(); reject(new WebError('response_too_large'));
            } else chunks.push(Buffer.from(chunk));
          });
          response.on('end', () => resolve({url:url.href,status,headers,body:Buffer.concat(chunks).toString('utf8')}));
          response.on('error', () => reject(new WebError('network')));
          response.on('aborted', () => reject(new WebError('network')));
        });
        req.on('error', () => reject(new WebError('network')));
        req.end();
      });
      if (![301,302,303,307,308].includes(result.status)) return result;
      if (redirects === 3 || !result.headers.location) throw new WebError('invalid_response');
      current = new URL(result.headers.location, url).href;
    }
    throw new WebError('invalid_response');
  } catch (error) {
    if (error instanceof WebError) throw error;
    throw new WebError('network');
  } finally { clearTimeout(timer); }
}

const entities: Record<string,string> = {amp:'&',lt:'<',gt:'>',quot:'"',apos:"'",nbsp:' ',ndash:'–',mdash:'—',hellip:'…',copy:'©',reg:'®',rsquo:'’',lsquo:'‘',rdquo:'”',ldquo:'“',bull:'•',middot:'·'};
function decode(value: string): string {
  return value.replace(/&(#x[0-9a-f]+|#\d+|[a-z]+);/gi, (whole, entity: string) => {
    if (entity[0] !== '#') return entities[entity.toLowerCase()] ?? whole;
    const code = entity[1]?.toLowerCase() === 'x' ? parseInt(entity.slice(2),16) : parseInt(entity.slice(1),10);
    return code > 0 && code <= 0x10ffff && !(code >= 0xd800 && code <= 0xdfff) ? String.fromCodePoint(code) : ' ';
  });
}
function plain(value: string): string {
  return decode(value.replace(/<[^<>]*>/g, ' ')).replace(/[\u0000-\u001f\u007f]+/g,' ').replace(/\s+/g,' ').trim();
}
function attributes(tag: string): Record<string,string> {
  const result: Record<string,string> = {};
  for (const item of tag.matchAll(/([a-z][\w:-]*)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+))/gi)) {
    result[item[1].toLowerCase()] = decode(item[2] ?? item[3] ?? item[4]);
  }
  return result;
}
function date(value: unknown): string | undefined {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}(?:T[^\s]+)?$/.test(value.trim()) || !Number.isFinite(Date.parse(value))) return undefined;
  const result = value.trim();
  // Date-only values must be real calendar dates, not normalized overflow.
  if (result.length === 10 && new Date(result).toISOString().slice(0,10) !== result) return undefined;
  return result;
}

/** Parse bounded HTML as inert text, never executing scripts or retaining forms. */
export function extractPage(html: string): {title?:string;text:string;publishedAt?:string;modifiedAt?:string} {
  const bounded = html.slice(0,1000000);
  let publishedAt: string | undefined;
  let modifiedAt: string | undefined;
  let metaTitle: string | undefined;
  for (const match of bounded.matchAll(/<meta\b[^>]{0,4096}>/gi)) {
    const attrs = attributes(match[0]);
    const name = (attrs.property ?? attrs.name ?? attrs.itemprop ?? '').toLowerCase();
    if (['article:published_time','datepublished','publication_date','pubdate','date','dc.date','dcterms.created'].includes(name)) publishedAt ??= date(attrs.content);
    if (['article:modified_time','datemodified','dcterms.modified','last-modified'].includes(name)) modifiedAt ??= date(attrs.content);
    if (name === 'og:title') metaTitle ??= plain(attrs.content ?? '');
  }
  // Read only date fields from structured JSON. No code evaluation, deep recursive traversal, or page instructions.
  for (const match of bounded.matchAll(/<script\b([^>]{0,4096})>([\s\S]*?)<\/script\s*>/gi)) {
    if (attributes(match[1]).type?.toLowerCase() !== 'application/ld+json' || match[2].length > 100000) continue;
    try {
      const queue: unknown[] = [JSON.parse(match[2])];
      for (let count = 0; queue.length && count < 100; count++) {
        const item = queue.shift();
        if (Array.isArray(item)) queue.push(...item.slice(0,100));
        else if (item && typeof item === 'object') {
          const values = item as Record<string,unknown>;
          publishedAt ??= date(values.datePublished); modifiedAt ??= date(values.dateModified);
          queue.push(...Object.values(values).filter(v => v && typeof v === 'object').slice(0,100));
        }
      }
    } catch { /* Invalid structured metadata provides no date. */ }
  }
  const inert = bounded.replace(/<!--[\s\S]*?(?:-->|$)/g,' ')
    .replace(/<(script|style|form|noscript|template)\b[^>]*>[\s\S]*?(?:<\/\1\s*>|$)/gi,' ')
    .replace(/<head\b[^>]*>[\s\S]*?(?:<\/head\s*>|$)/gi,' ');
  const titleMatch = bounded.match(/<title\b[^>]*>([\s\S]*?)<\/title\s*>/i);
  const title = (titleMatch ? plain(titleMatch[1]) : metaTitle)?.slice(0,300);
  return { ...(title ? {title}:{}), text:plain(inert).slice(0,20000),
    ...(publishedAt ? {publishedAt}:{}), ...(modifiedAt ? {modifiedAt}:{}), };
}
