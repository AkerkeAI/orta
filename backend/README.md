# ORTA backend — real Groq conversation

Run `npm install`, then configure `GROQ_API_KEY` exclusively in `backend/.env`.
Never paste the key into chat, client code or logs, and never commit `.env`.
`.env.example` contains names and defaults only.

`AI_PROVIDER` defaults to `groq`. `GROQ_MODEL` defaults to `openai/gpt-oss-120b`.
Inference uses Groq's official `https://api.groq.com/openai/v1/chat/completions`
endpoint through native HTTP. The `AIProvider` interface allows future provider
adapters without changing Flutter or ORTA context handling. Unsupported provider
configuration fails explicitly; there is no automatic paid-provider fallback.

Start with `npm start` from `backend/`. The server binds to local loopback.
Startup prints provider, model and key presence, never the key.

- `GET /health` returns `{ "status": "ok" }`.
- `POST /api/agent/message` accepts message, locale (`en`, `ru`, `kk`),
  LifeContext, AgentContext and user/assistant conversation history.
- Success preserves `{ "message": "...", "requestId": "..." }`.
- Errors return a safe `error`, `code`, and `requestId`. Rate limits return 429
  and `Retry-After`; oversized requests return 413 with `request_too_large`; configuration/provider errors return 503.

Requests retain the ORTA prompt and last 12 conversation messages. Output is
capped at 1024 tokens for conversation and 2048 for tool turns. Provider requests time out after 20 seconds. Only one
inference request runs at once; provider 429 responses impose a cooldown.
There are no automatic retries. Account limits still govern total usage.

Verify model availability through Groq's authenticated models endpoint before
changing `GROQ_MODEL`. See https://console.groq.com/docs/models and
https://console.groq.com/docs/rate-limits. Free-plan quotas are finite; this
implementation does not activate paid plans or guarantee unlimited free usage.

Run `npm run typecheck` and `npm test`.
For the iOS simulator, run from the app root:

```
flutter run -d <simulator-id> --dart-define=ORTA_USE_REMOTE_AGENT=true --dart-define=ORTA_BACKEND_URL=http://127.0.0.1:3000
```

### Phase 4 local tools and approval

The existing `/api/agent/message` contract remains available. The Flutter action client adds `toolsEnabled: true`, bounded `toolTurns` (assistant function calls followed by matching local tool results) and `pendingActions`. Responses add validated `toolCalls` and their protocol `rawCalls`; `message` can be empty when Groq selects a tool.

`assets/orta_tools.json` is the shared registry schema source. Groq selects registered functions through its official local tool-calling interface. The backend validates calls and runs inference only: it has no user database or write executor. Flutter executes read tools against LifeRepository, returns structured results for up to four inference rounds, and persists write proposals without applying them.

Confirm/Cancel controls resolve a specific pending proposal locally. Conversational confirmation requires one nonexpired proposal, an explicit confirmation phrase, a preceding proposal review and a matching model-selected action ID. Revisions require fresh approval. Updates compare the current record to the proposed base snapshot. Approval commits the mutation and execution receipt together; repeated approval returns the receipt rather than running again. Proposals expire after 15 minutes. Independent multi-action requests support up to eight proposals, each separately approved and reported; newly created records must be saved before later actions can reference their IDs.

No credentials belong in Flutter. The backend still loads `GROQ_API_KEY` from `.env`, and logs only request IDs, provider/model, locale, registered tool names and safe errors. Groq built-in tools, external integrations and arbitrary code execution are not enabled.

### Phase 5 planning

The shared registry now contains 29 tools, including planning context, approved
preference changes, deterministic session planning, event rescheduling, pending
session edits, explicit completion and grouped approval/rejection. The model
interprets intentions; Flutter calculates slots from the current local repository.

Configure Planning preferences in the app before requesting study/work sessions.
The scheduler requires confirmed IANA timezone, weekdays and activity hours. It
subtracts existing commitments, all-day events, unavailable intervals and breaks;
it enforces daily planning minutes, end-time limits and linked deadlines. An empty
calendar does not imply availability. Recurrence and overnight creation are not
supported.

Proposals appear separately from saved events. Approve all validates and saves a
group atomically with execution receipts. Reject all makes no calendar changes.
Pending edits supersede old versions and require fresh approval. Approval checks
current records, preferences, conflicts and expiry. No background scheduling or
notifications run.

Home and Plan compute recommendations from saved facts on opening. Completion is
recorded explicitly; elapsed time never completes sessions automatically. Daily
focus can use the fresh planning snapshot already supplied by Flutter, avoiding a
redundant read round. Missing/truncated context still requires a local read tool.
Free-tier rate limits can interrupt a multi-round request; errors are shown safely
and there is no automatic retry or paid fallback.

### Phase 6 conversational behavior and bounded requests

The assistant distinguishes ordinary conversation, support, advice, planning and
requested actions. It uses relevant current facts and follow-up history, asks one
essential clarification, and avoids turning casual conversation into tools or
productivity recommendations. Corrections refer to the active proposal or visible
record; ambiguous references require clarification. Proposed changes remain subject
to the existing Flutter approval checks. All 29 registered tools and full argument
validation remain available; the backend still executes no user-data writes.

Phase 7A now connects read-only public web research through the server-only search_web tool. Search failures must be explained honestly; no fabricated searches, sources or external actions are allowed. The prompt directs localized prose to avoid internal record IDs, function names and enum values; this is not a deterministic model guarantee. Model behavior still requires
live verification; protocol tests alone do not establish conversational quality.

Inference keeps at most 12 recent messages and 3,000 history characters / 5,000 UTF-8 history bytes, dropping
only whole older messages and marking omission in model context. Current facts,
active proposals and paired tool results are retained intact. Byte-identical duplicate
LifeContext is sent once. A 48,000 UTF-8 byte guard bounds the serialized provider
request before transport; it is not exact token counting or a quota guarantee. A
request that cannot fit fails explicitly rather than silently rewriting those facts.

Groq currently lists 8,000 tokens/minute for free `openai/gpt-oss-120b`; actual
organization limits can differ: https://console.groq.com/docs/rate-limits. Existing
output caps, one in-flight request, provider cooldown, no automatic retries and no
paid fallback remain. Both provider 413 and oversized HTTP bodies return the safe
`request_too_large` code so the client can offer a shorter request or a new
conversation. Logs contain correlation/status metadata, not private request bodies,
provider error bodies or keys. User context is still sent to Groq for inference; no
end-to-end encryption or complete-privacy claim is made.


Browser requests are allowed only from canonical HTTP/HTTPS origins on `localhost`
or `127.0.0.1`. Untrusted and lookalike origins are rejected with a generic 403
`access_denied` before body parsing or inference, including preflight requests.
Native requests without an Origin header remain allowed. Origin/private payload
text is not logged. This origin gate complements loopback binding; it does not
authenticate arbitrary native HTTP clients or introduce a production auth service.

ORTA uses local HH:mm clocks. Inference converts the shared custom time format to an explicit 24-hour HH:mm pattern so Groq does not apply RFC 3339 full-time validation. Shared client/server clock validation remains unchanged. CREATE-project empty optional description/stage/needs placeholders are omitted before strict validation; other invalid fields are not repaired. Optional provider diagnostics are disabled by default and log only fixed metadata, never private values.


### Phase 7A: real public internet research

Configure `TAVILY_API_KEY` locally in `backend/.env`. `RESEARCH_PROVIDER=tavily` is the default. Tavily basic search uses one credit per request; its Free plan provides 1,000 credits/month without a card. Keep that account on the Free plan. This application does not configure billing, auto-upgrades, advanced search, paid extraction or any paid fallback. Provider-side quotas still apply. Official references: https://www.tavily.com/pricing and https://docs.tavily.com/documentation/api-reference/endpoint/search.

The Groq conversational/action model remains configurable through `GROQ_MODEL` (default `openai/gpt-oss-120b`). Research summaries use `GROQ_RESEARCH_MODEL` (default `openai/gpt-oss-20b`), also listed in Groq's free tier. Both IDs were confirmed active through the account's official models API. Separate model adapters prevent a two-inference research request from immediately exhausting the action model's minute budget; they do not remove organization/model quotas. References: https://console.groq.com/docs/models and https://console.groq.com/docs/rate-limits.

`SearchProvider` is replaceable. `RESEARCH_PROVIDER=searxng` and `SEARXNG_URL` select the documented no-key SearXNG JSON API. Public instances tested during verification were API-disabled, rate-limited or behind security checks; this alternative has no successful live verification or availability guarantee. `RESEARCH_PROVIDER=disabled` safely disables research.

The existing POST `/api/agent/message` contract stays intact, with optional `research` provenance metadata added to research responses. Server-only search calls never enter Flutter's local tool registry. The agent can first use existing local reads; mixed calls return only paired local calls and defer research. One search per conversational turn returns up to five genuine URLs; at most three pages are fetched. Results are cached in memory for ten minutes, with at most twenty entries. No search query, page body, personal context, upstream error body or API key is logged. Relevant interests/education needs can inform the query; full LifeContext is not sent to Tavily.

Page retrieval permits public HTTPS only, rejects credentials/nonstandard ports/private or special IPs, resolves and pins vetted DNS answers, revalidates up to three redirects, bounds time and bytes, and sends no cookies or authorization headers. Scripts/forms are stripped as inert text; structured JSON contributes explicit publication metadata only. No browser automation, script execution, account access, email or application submission is provided. PDFs, JavaScript-only pages, bot challenges and unsupported/oversized responses remain snippet-only evidence. No challenges are solved or bypassed.

Groq synthesizes the research with tools disabled. Trusted instructions distinguish supported page facts, unverified snippets and missing dates/eligibility. Server-owned source lists and URL filtering remove invented link targets and unknown citation IDs. Publication dates are labeled as such, not deadlines. A fetched page is evidence of what that page states, not independent verification that the user qualifies or an opportunity remains open.

A follow-up explicit save-as-project/task request uses the existing real proposal and approval flow. A narrow named tool choice prevents researched save requests from producing only prose drafts; it cannot approve or execute a write. Project source URLs and notes go into description. A requested correction replaces the pending proposal and requires fresh approval. Saving and persisted data remain owned by Flutter. Research and saving are separate conversational turns.

Latest verification and limitations: `../PHASE_7A_REPORT.md`, `../PHASE_7A_CHECKPOINT.md`.
