# ORTA Phase 6 verification report

12 October 2026. Existing Phase 6 work was continued and preserved. The essential user journey passed on a native iOS Simulator using real Groq inference. Broader verification gaps are listed in item 10; this report does not claim every possible conversation is verified.

## 1. Problems discovered

Conversation actions were not isolated by chat; approval could survive an intervening failed message, and changing interface language could invalidate a legitimate review. Onboarding skipped useful goal/summary steps. Several active labels, goal keys and date controls were not localized. Language practice counted button presses without saving actual writing. Chat layout and retry handling needed improvement.

Native testing exposed empty optional project placeholders, overly large inference requests, answers about an old exam while a project was visible, incorrect weekday prose, and calendar time fields rejected by Groq.

## 2. Problems fixed

Separate chats and scoped proposals now persist with schema-3 migration. Approval requires the immediately preceding review in any supported language and the active chat. Errors do not authorize old proposals.

Selected records receive bounded, relevant context; unrelated calendar/exam details are excluded from project views. Older history is limited to 12 messages, 3,000 characters and 5,000 UTF-8 bytes. The client includes exact bounded earlier user statements rather than fabricated summaries.

Groq CREATE-project empty optional text placeholders are omitted before unchanged strict validation. IDs, dates, enums, required fields and updates are not repaired. Local HH:mm clock fields use an explicit inference pattern instead of RFC 3339 time. The unchanged local validator still rejects invalid clocks. This matches the [JSON Schema time-format definition](https://json-schema.org/draft/2020-12/json-schema-validation#name-dates-times-and-duration).

Client-provided calendar ranges now supply computed weekday facts. Temporary diagnostics expose no messages, argument values, IDs, headers, keys or provider bodies, and are disabled in the running backend.

## 3. Files changed for Phase 6

These are Phase 6 edits; the repository also contains earlier uncommitted Phase 1-5 work, which was retained.

- Models and coordination: [lib/models/life_data.dart](/Users/ake/orta/lib/models/life_data.dart), [lib/services/life_repository.dart](/Users/ake/orta/lib/services/life_repository.dart), [lib/services/ai_actions.dart](/Users/ake/orta/lib/services/ai_actions.dart), [lib/services/action_agent.dart](/Users/ake/orta/lib/services/action_agent.dart), [lib/services/agent_context_builder.dart](/Users/ake/orta/lib/services/agent_context_builder.dart), [lib/services/planning_tools.dart](/Users/ake/orta/lib/services/planning_tools.dart), [lib/services/remote_orta_agent_service.dart](/Users/ake/orta/lib/services/remote_orta_agent_service.dart).
- Active interface: [lib/screens/core/orta_shell.dart](/Users/ake/orta/lib/screens/core/orta_shell.dart), [lib/app/orta_app.dart](/Users/ake/orta/lib/app/orta_app.dart), [lib/screens/onboarding/onboarding_screen.dart](/Users/ake/orta/lib/screens/onboarding/onboarding_screen.dart), [lib/widgets/planning_views.dart](/Users/ake/orta/lib/widgets/planning_views.dart), [lib/widgets/life_record_dialog.dart](/Users/ake/orta/lib/widgets/life_record_dialog.dart), [lib/widgets/language_selector.dart](/Users/ake/orta/lib/widgets/language_selector.dart).
- Language and localization: [lib/screens/language_orta/language_orta_screen.dart](/Users/ake/orta/lib/screens/language_orta/language_orta_screen.dart), [lib/services/product_strings.dart](/Users/ake/orta/lib/services/product_strings.dart), [lib/services/language_orta_strings.dart](/Users/ake/orta/lib/services/language_orta_strings.dart), [lib/services/language_practice_service.dart](/Users/ake/orta/lib/services/language_practice_service.dart), [lib/services/localization_service.dart](/Users/ake/orta/lib/services/localization_service.dart), [lib/services/orta_localization.dart](/Users/ake/orta/lib/services/orta_localization.dart), [lib/services/life_context_interpreter.dart](/Users/ake/orta/lib/services/life_context_interpreter.dart).
- Backend: [backend/src/agent/orta_agent.ts](/Users/ake/orta/backend/src/agent/orta_agent.ts), [backend/src/agent/system_prompt.ts](/Users/ake/orta/backend/src/agent/system_prompt.ts), [backend/src/agent/ai_provider.ts](/Users/ake/orta/backend/src/agent/ai_provider.ts), [backend/src/agent/conversation.test.ts](/Users/ake/orta/backend/src/agent/conversation.test.ts), [backend/src/agent/tools.test.ts](/Users/ake/orta/backend/src/agent/tools.test.ts), [backend/src/app.ts](/Users/ake/orta/backend/src/app.ts).
- Tests: [test/conversation_repository_test.dart](/Users/ake/orta/test/conversation_repository_test.dart), [test/language_orta_test.dart](/Users/ake/orta/test/language_orta_test.dart), [test/life_context_interpreter_test.dart](/Users/ake/orta/test/life_context_interpreter_test.dart), [test/localization_service_test.dart](/Users/ake/orta/test/localization_service_test.dart), [test/onboarding_localization_test.dart](/Users/ake/orta/test/onboarding_localization_test.dart), [test/planning_localization_test.dart](/Users/ake/orta/test/planning_localization_test.dart), [test/phase6_chat_test.dart](/Users/ake/orta/test/phase6_chat_test.dart), [test/phase6_context_test.dart](/Users/ake/orta/test/phase6_context_test.dart), [test/phase6_remote_error_test.dart](/Users/ake/orta/test/phase6_remote_error_test.dart), [test/phase6_approval_test.dart](/Users/ake/orta/test/phase6_approval_test.dart), [test/ai_actions_test.dart](/Users/ake/orta/test/ai_actions_test.dart), [test/scheduling_test.dart](/Users/ake/orta/test/scheduling_test.dart), [test/life_repository_test.dart](/Users/ake/orta/test/life_repository_test.dart).
- Dependencies/documentation: [pubspec.yaml](/Users/ake/orta/pubspec.yaml), [pubspec.lock](/Users/ake/orta/pubspec.lock), [backend/README.md](/Users/ake/orta/backend/README.md), [PRODUCT_REQUIREMENTS.md](/Users/ake/orta/PRODUCT_REQUIREMENTS.md), [PHASE_6_CHECKPOINT.md](/Users/ake/orta/PHASE_6_CHECKPOINT.md), [PHASE_6_REPORT.md](/Users/ake/orta/PHASE_6_REPORT.md).

No paid service was introduced; flutter_markdown_plus is free.

## 4. Conversational improvements

Casual dialogue, support, follow-ups, corrections and actual write proposals have distinct guidance. Clear changes produce reviewable actions, with explicit approval before storage. Unsupported research and external actions must be described honestly.

Real native examples: supportive conversation without tools; Russian and Kazakh replies after locale changes; a Tuesday-to-Thursday correction preserving the other sessions; a resumed project question answered about Green Lab; and “Forget that plan” cancelling a real pending proposal.

## 5. UI improvements

New conversation, history and resume are reachable. Compact/expanded chat uses a lazy message list, readable Markdown, loading feedback and retry without duplicate user messages. Model images do not fetch remote content; supported links copy with feedback. Nonfunctional voice controls were removed from the active chat.

Settings now changes the actual saved interface language. Project/exam/goal records open with visible context. Manual record validation, required event dates and translated goal selectors work. Keyboard, small-screen and long-response layouts pass widget regressions; the native portrait conversation was visually inspected.

## 6. Localization coverage

Active onboarding, Home, Life, Plan, Progress, Agent, proposals, errors, Language ORTA and settings have English/Russian/Kazakh coverage.

Native major-screen language switching and real Groq replies in all three languages were observed. Language ORTA was viewed in all three interface languages. Full onboarding journeys in Russian and Kazakh were verified with widget tests, not repeated natively. User-entered titles and historical messages retain their original language.

## 7. Language ORTA verification

Actual written responses persist under their selected target language. Italian and German each saved one entry. German initially showed zero sessions despite Italian having one. A native file comparison confirmed Core Life/tasks/events did not change during German practice. After the final restart, the Italian entry was visibly present in Russian-localized history; the saved snapshot retained one entry for each language.

Practice is explicitly self-guided. AI grading, corrections, translations and voice practice are not implemented or claimed.

## 8. Automated results

- flutter analyze: no issues.
- flutter test: 207 passed, 0 failed.
- flutter build ios --simulator --dart-define=ORTA_USE_REMOTE_AGENT=true: successful.
- npm run typecheck: passed.
- npm test: 34 passed, 0 failed.
- git diff --check: clean.

The last Flutter failure was an old context-test fixture expecting unrelated project tasks/events. It now links those records to the selected project; the repaired repository suite and full suite passed. Automated provider fixtures are regression evidence only, not proof of real AI inference.

Logs: /private/tmp/orta-phase6-final-flutter-tests.log, orta-phase6-final-backend-tests.log, orta-phase6-final-affected-tests.log and orta-phase6-repository-tests.log.

## 9. Real simulator results

The clean “ORTA Phase 6 QA” iPhone 17, iOS 26.5, completed the journey:

1. Onboarded Mira, selected study/project life areas and four goals.
2. Created and approved Green Lab through a real Groq proposal.
3. Created and approved IELTS dated 20 November 2026.
4. Requested three one-hour study sessions next week.
5. Changed Tuesday to Thursday conversationally.
6. Approved the revised schedule; Plan showed 19, 21 and 22 October, 18:00-19:00 Asia/Aqtau.
7. Added a task linked to the saved IELTS exam, completed it, and saw it in Progress and Home.
8. Restarted the final application. Plan retained all three sessions; Progress retained the task; Life retained project/exam/goals.
9. Resumed the existing conversation and received a real project-specific Groq response.
10. Created another Friday proposal. The initial request failed on the clock schema; after the fix, retry produced a real correctly dated proposal without duplicating the user message.
11. “Forget that plan” invoked real Groq rejection; the UI said “Cancelled. No data changed.” The snapshot still held exactly three saved sessions and no pending proposals.
12. Switched chats during the pending review: the proposal disappeared from the other chat and reappeared only in its owning chat.

Provider: Groq, model openai/gpt-oss-120b, official API. Startup confirmed configuration without printing the key. Native successes were correlated with backend provider/model/tool logs, including plan_sessions, modify_pending_session, create_calendar_event and reject_action. Direct real API smoke request also succeeded.

The original iPhone simulator was upgraded without resetting it. Its saved snapshot remained byte-for-byte unchanged: three goals, one project, two exams, two tasks, five events and 41 legacy messages. The new interface opened the original profile and displayed its legacy chat in history.

## 10. Remaining limitations and verification gaps

Groq responses remain nondeterministic and free-tier quotas can delay requests. Errors for invalid responses, rate limits and oversized requests were observed natively without crashes or unintended writes. Some generated advice was verbose, proposed unstated optional values, or quoted an internal goal key; prompt policy is not a deterministic prose guarantee. Review remains necessary.

The exact original history-heavy combined project-and-exam creation retry was not repeated from its original empty-record state after all fixes; project/exam creation was verified separately. Post-fix weekday prose without an explicit user-supplied weekday was not separately re-tested natively, although computed calendar facts passed all-locale tests and the Friday proposal displayed correctly.

Native university context and a fresh Russian/Kazakh onboarding journey remain unverified; their context/localization tests pass. Software-keyboard landscape behavior was tested with widget fixtures, not a fresh native landscape session.

Live web research, external calendar/email actions, voice and AI language grading are outside this version. Local storage is not application-level end-to-end encryption; relevant context goes to Groq. The backend remains a loopback development service rather than a production authenticated deployment.

Automatic approval review rejected a separate saved-context diagnostic replay. No replay was made after that rejection; authorized native requests and value-free diagnostics were used instead. No Phase 7 work was started.
