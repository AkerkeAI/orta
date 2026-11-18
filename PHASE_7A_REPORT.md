# Phase 7A report — 13 October 2026

Status: essential real research and approved-save journey implemented and verified. Phase 6 was preserved; no UI redesign or later-phase integration was started.

## Provider and free-tier limits

Tavily's official Search API (`https://api.tavily.com/search`), basic depth only, with a key supplied locally by the user. Free plan: 1,000 monthly credits, no card required; basic search uses one credit. No advanced search, paid extract API, auto-parameters, billing setup, auto-upgrade or paid fallback. Keep the Tavily account on its Free plan; the application cannot guarantee that a user independently changes no billing settings. Pricing/docs: https://www.tavily.com/pricing and https://docs.tavily.com/documentation/api-reference/endpoint/search.

Existing Groq action model: `openai/gpt-oss-120b`. Read-only research synthesis: separately configurable `openai/gpt-oss-20b`. The official account models endpoint returned both IDs active. Both are in Groq's documented Free plan; organization/model limits still apply. Separating synthesis fixed an observed minute-limit failure during the native two-step research request. No automatic quota retries or model/billing fallback. https://console.groq.com/docs/rate-limits.

Optional SearXNG adapter is configurable, but tested public endpoints returned 403/429, a security-check page, or invalid TLS. No successful SearXNG search is claimed. Public security/rate controls were respected. Tavily is the actually verified provider.

## Architecture

The existing conversation and local-action flow remains. `search_web` is server-only, read-only and separate from the shared Flutter tool registry. Groq selects a focused query using relevant supplied context; Tavily receives the query, not full LifeContext. Server retrieval returns real URLs, excerpts, accessibility/evidence labels and available publication metadata. Groq synthesizes with all action tools disabled. A server-owned source appendix and URL whitelist ground links; publication dates are explicitly labeled.

Public HTTPS retrieval pins vetted DNS, rejects private/special addresses, credentials and nonstandard ports, validates redirects, bounds time/bytes and strips scripts/forms into inert text. Retrieved website text is untrusted data. No website instructions, arbitrary scripts, account access, emails or applications are executed.

One internet query per conversational turn; at most three page fetches; ten-minute memory cache capped at twenty entries. No queries, private context, page bodies or keys are logged. POST `/api/agent/message` preserves its request/message/requestId contract; research responses add optional provenance metadata. A later save uses existing local project/task proposals and confirmation. The backend never saves user records.

## Actual test results

- Backend `npm run typecheck`: passed.
- Backend `npm test`: 62 tests passed after fixes. Includes existing conversation/tool/approval protocol regressions, SSRF guards, inert extraction, safe provider failures, source grounding in English/Russian/Kazakh and researched-save intent boundaries. Injected unit fixtures test failures; they are not evidence of live integration.
- Flutter analysis: no issues.
- Flutter tests: all 207 passed.
- Remote-enabled iOS Simulator debug build: passed.
- Native testing used existing ORTA Phase 6 QA simulator `0304AC0C-F716-4C3E-B045-80D6568941E5`, with existing data preserved. Original user simulator/data was not reset or modified.

## Real backend evidence

Initial real POST returned HTTP 200, request `6e0e5fa8-5e74-454f-8819-874cf8db17c1`, Tavily status ok, three sources, two retrieved pages. It exposed a snippet deadline incorrectly called confirmed; trusted synthesis instructions were tightened before final verification.

Final plain-contract POST (without toolsEnabled) returned HTTP 200, request `22e75dde-cf8d-4984-951b-2dfe978c6568`, Tavily status ok, three sources, two retrieved pages. Groq explained that the official Erasmus+ overview gives a typical October–January window and programme-specific deadlines, rather than one universal deadline. The genuine official page was fetched successfully:
https://erasmus-plus.ec.europa.eu/opportunities/individuals/students/erasmus-mundus-joint-masters

Non-sensitive QA response evidence is saved at `/private/tmp/orta-phase7a-final-api.json`. No key appears in that file.

## Real Flutter evidence

- User message entered and sent through the native Flutter interface: research Erasmus Mundus scholarships, use study goals and provide sources/missing deadlines.
- Initial backend connection interruption and a Groq usage-limit error appeared as clear native errors, with retry controls and no crash or saved changes. Backend was restarted and synthesis separated onto GPT-OSS 20B.
- Native request `cdc419b4-079e-461f-b116-ab7de6e4cda4` displayed a real Tavily/Groq response, labeling inaccessible pages as snippet-only and declining to confirm deadlines.
- Natural focused follow-up found the official European Commission overview. Request `766900dd-d5b0-460e-a6aa-84c376c73789` produced three successfully retrieved official Erasmus+ sources visible as links, with publication dates when supplied. It explained that individual programmes set their own deadlines. Value-free logs confirm Groq GPT-OSS 20B synthesis and GPT-OSS 120B orchestration.
- A natural save request first produced only a prose draft; this defect was fixed through narrow named proposal-tool selection for explicit researched save-as-record requests. The repeated same request produced a real `create_project` approval card (request `0ca20e95-3553-42a6-bed8-c05d232b60e1`). Saved projects stayed at one while pending.
- Source placement was corrected into description through a new proposal; request `7cbc8f99-fbd2-4332-becb-82842325d41c`. Only name/description were proposed; needs/stage were omitted.
- Clicking Confirm displayed the existing success receipt. Saved project count became two; pending proposals became zero. The new record contains the genuine official organisations-page URL in description and no invented deadline. Green Lab remained present.
- The app was terminated and relaunched. LIFE visibly still listed Green Lab and “Erasmus Mundus Joint Masters – EU Overview”. This is observed persistence after approval, not an assumption.

## Changed files for this milestone

New:
- backend/src/research/research_tools.ts
- backend/src/research/web_research.ts
- backend/src/research/web_research.test.ts
- backend/src/research/tavily_provider.ts
- backend/src/research/tavily_provider.test.ts
- backend/src/research/safe_web.ts
- backend/src/research/safe_web.test.ts
- PHASE_7A_REPORT.md
- PHASE_7A_CHECKPOINT.md

Updated:
- backend/src/agent/orta_agent.ts
- backend/src/agent/ai_provider.ts
- backend/src/agent/tool_registry.ts
- backend/src/agent/system_prompt.ts
- backend/src/agent/tools.test.ts
- backend/src/agent/conversation.test.ts
- backend/src/app.ts
- backend/src/server.ts
- backend/.env.example
- backend/README.md
- lib/services/remote_orta_agent_service.dart (30→75-second timeout for two-inference research)
- PRODUCT_REQUIREMENTS.md

The local backend/.env key was added by the user; it is not committed or printed. Prior uncommitted Phase 3–6 work was preserved.

## Remaining limitations and unverified cases

- Research is bounded public text research, not deep autonomous browsing. PDFs, JavaScript-rendered content, bot-protected pages and some large/slow sources may yield only snippets. Publication metadata can be stale and is not an application deadline.
- Source ranking may initially miss the best official page; a natural follow-up successfully narrowed it in native verification. Three sources are not an exhaustive survey.
- URL provenance is enforced, but semantic accuracy and eligibility interpretation remain model-dependent. Page retrieval is not independent fact-checking or a guarantee that an application is open.
- Groq and Tavily free quotas can interrupt requests. Provider errors and no-results paths are covered by automated tests; no every-provider outage or invalid-key failure was triggered live.
- Phase 7A native research was verified in English. Russian/Kazakh research prompts and source labels are covered by automated tests; new live native research journeys in those languages remain unverified. Phase 6 language-switch verification is unchanged.
- Save-as-project was verified live; save-as-task has backend intent/protocol coverage but no new native live journey in this milestone. Saved opportunities use existing records, without a new opportunity database schema.
- Source links preserve the existing UI clipboard-copy behavior. External-browser launching was not added or verified.
- No billing/account dashboard was accessed to independently inspect plan state. Only basic searches were issued; no paid plan was introduced by this work.
