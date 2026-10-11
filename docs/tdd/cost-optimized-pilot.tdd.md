# TDD evidence — cost optimized pilot

Source journeys: [implementation plan](../IMPLEMENTATION-PLAN.md), derived from existing architecture and user instructions.

## RED checkpoint, 11 October 2026

Runner detector selected npm; repository had no runner. Added npm/Vitest and Swift XCTest test infrastructure before production code.

Actual command: `npm test`. Exit 1: three suites could not import the intentionally absent business modules `functions/src/evidence.js`, `service.js`, `openai.js`. Vitest 5.0.3 ran successfully; dependencies (including sharp) resolved. This is the skill's compile/import-time RED for missing implementation; it is not a runtime assertion RED. New tests exercise ordered evidence, conservative model policy, idempotent sessions, atomic quotas, cancellation/expiry and bounded provider calls. No business implementation existed at this checkpoint.

Further GREEN, integration, Swift evidence and coverage will be appended after execution. No real model calls or deployments are used in development tests.

Second RED validation included `tests/api.test.ts`: `npm test` exited 1 with four suites referencing missing implementation. Swift XCTest was unavailable in Command Line Tools (infrastructure failure; not counted as RED). A portable equivalent compiled with `swiftc ios/HiMorningCore/Sources/HiMorningCore/Module.swift ios/HiMorningCore/TestsPortable/main.swift -o /private/tmp/himorning-core-tests` exited 1 with `cannot find WakeMode`, `WakeSession`, `AlarmTime`, `RepCounter`, `EvidenceBuffer` in scope: valid compile-time RED for absent domain types.

## Backend GREEN

`npm test`: 36 tests passed; `npm run typecheck` and `npm run build`: exit 0. GREEN commit b2a8d24. Real Firestore integration: `npm run test:emulator` with a checksum-verified portable Temurin JRE21: 4 tests passed. Added actual callable-handler auth tests; combined `npm run test:coverage` under the emulator: 41 tests passed, statements 97.89%, branches 96.37%, functions 97.36%, lines 100%. No excluded production TypeScript modules. The earlier unit-only coverage failed functions threshold (76.31%); it is not the final coverage claim.

## Native integration RED

Portable compiler command exited 1 for absent `AlarmScheduler`, `SavedAlarm`, `FileAlarmPersistence`, `AlarmLibrary`, `CycleCapture`. The new journeys require persistence before native scheduling, confirmed state only after receipt, restart recovery, honest failure state, complete five-phase capture, per-frame budget and decoded-time validation.

## Final local verification, 11 October 2026

`npm run typecheck` and `npm run build`: exit 0. Combined emulator coverage after adding bounded reasoning and token metering: **41 tests passed**, statements **97.53%**, branches **95.80%**, functions **92.50%**, lines **100%**. All production TypeScript modules are included. Test images are synthetic JPEGs; OpenAI is mocked, so this proves contracts and controls, not exercise-recognition accuracy.

`sh scripts/test-swift.sh`: **13 portable journeys passed** with Swift 6 mode and real atomic file persistence. LLVM coverage of `HiMorningCore` before the final native adapter wiring: regions **84.02%**, functions **98.53%**, lines **97.69%**. LLVM reports zero instrumentable branch counters for these Swift files, so no Swift branch-coverage percentage is claimed. SwiftUI/AlarmKit/AVFoundation/Firebase adapters are outside this portable coverage measurement. Local XCTest and native app builds are unavailable because full Xcode is not installed. Hosted CI native build/UI status is recorded separately below once known.

| Journey / task | Actual test target | Type | Guarantee |
|---|---|---|---|
| Ordered, bounded camera evidence | `tests/evidence.test.ts` | unit | JPEG decode/dimensions/bytes/frame caps, unique IDs/images, ordered times, current consent, insufficient coverage stays uncertain |
| Conservative AI decision | `tests/evidence.test.ts` | unit | Only full ordered cycles with known evidence IDs can verify; model uncertainty, unknown cues and overlapping/reversed cycles cannot |
| Session identity and replay | `tests/service.test.ts` | unit + transaction double | Auth/App Check, owner, nonce, TTL, target snapshot, matching duplicate cache, changed-payload conflict |
| Inference cost cap | `tests/service.test.ts` | unit | One paid attempt/session, no automatic provider retry, per-user/global quotas, session-creation limits, default-off path |
| Stop, expiry and crash | `tests/service.test.ts` | unit | Cancel/expiry wins, stale attempt never reclaimed, late results never turn into success |
| OpenAI contract/token budget | `tests/provider.test.ts` | SDK mock | Ordered image inputs, strict schema, store false, 800 output tokens, reasoning none, low verbosity, maxRetries 0, sanitized numeric usage metrics |
| Callable boundary | `tests/api.test.ts` | handler integration | Context supplies identity, actual exported handlers reject missing auth/attestation, safe errors, zero warm instances |
| Database authority and races | `tests/firestore.test.ts` | real Firestore Emulator | Owner preference schema, deny server-state reads/writes, two-worker claim/cache, concurrent global quota cap, no saved image bytes |
| Local alarms and persistence | `TestsPortable/main.swift` | Swift domain + file integration | Gentle defaults, time validation including decode, Vietnam weekdays/DST, schedule receipt before confirmed, restart, on/off/delete and honest failure state |
| Local evidence | `TestsPortable/main.swift` | Swift unit | Provisional counts do not imply cloud success; incomplete cycles reset, completed cycles and bytes stay bounded |
| Native cloud lifecycle | `TestsPortable/main.swift` | Swift protocol integration | Consent required, unavailable fallback, stop during pending response rejects success; suspension cancels cloud without stopping the OS alarm |
| Native UI | `ios/HiMorningUITests/PilotUITests.swift` | XCUITest | Written for gentle default and cancel before any permission/cloud request; hosted execution status below |

## Checkpoint index

All checkpoints remain reachable on `codex/cost-optimized-pilot`; none were squashed.

| Cycle | RED | GREEN | Evidence |
|---|---|---|---|
| Backend + initial Swift domain | `205f7c2`, `4b2cd55` | `b2a8d24` | Relative business-module import failures; portable missing domain types; then 36 backend + 9 Swift journeys passed |
| Local native integration | `89636ce` | `738bd57` | Missing scheduler/library/capture APIs; then 12 Swift journeys passed |
| Cloud client lifecycle | `40c9c82` | `02f6ad2` | Missing coordinator/cloud contract; then 13 Swift journeys passed |
| Enable/delete | `8ca1ab4` | `a9f1bf1` | Missing methods; same portable suite passed after implementation |
| Background suspension | `3a6c12e` | `3957a69` | Missing suspend; same portable suite passed and confirmed no native stop |
| Explicit token controls | `8d4f469` | `c306af7` | Runtime RED: meter called zero times; then all five provider tests passed with explicit reasoning/verbosity assertions |

Known limits: no real paid inference, no calibrated model accuracy/latency/cost result, no physical-device alarm/camera/audio test, no native adapter coverage percentage. Native thin-adapter source was added as an integration spike around the tested core; it has not itself completed a local RED/GREEN cycle. QR, native snooze/countdown, existing-alarm editing, weekly history, expert form coaching and Android are not implemented. Test code does not certify those features.

`npm audit --omit=dev`: zero production advisories. Full audit reports 16 advisories in development Firebase SDK/CLI dependencies (4 moderate, 12 high); no forced major downgrades were applied. This is recorded, not claimed clean. Development services bind loopback and use the demo project.


## Follow-up fixes and metrics, 11 October 2026

| Cycle | RED | GREEN | Actual evidence |
|---|---|---|---|
| Repeated cloud consent | `ae04bd6` | `0bd50e0` | Runtime assertion found two sessions; same 13-journey portable suite passed after reusing the unexpired session |
| Repeated cancellation | `7f9e286` | `2237e98` | Runtime RED `expected 5 to be 4` database writes; same service test target then passed 13/13 |
| Token evidence collector | `bd975e1` | `9e975d6` | Intended absent business-module import RED; then 7 tests passed. Refactor `e6b1a35` added typecheck-safe assertion, an eighth case and library coverage gate |

At this follow-up checkpoint, `npm run test:coverage`: **50 tests passed** (42 backend + 8 engineering metrics). Backend alone: statements **97.54%**, branches **95.86%**, functions **92.50%**, lines **100%**. Collector library: statements/functions/lines **100%**, branches **98.14%**, with its own 80% threshold. Combined: statements **98.05%**, branches **96.48%**, functions **94.33%**, lines **100%**. Including the collector does not replace the separately reported backend scope. The small CLI wrapper is exercised on the real local rollout but is outside instrumented coverage.

At this follow-up checkpoint, portable Swift: **13 journeys passed**, regions **83.67%**, functions **98.55%**, lines **97.76%**, no instrumentable branch counters. `npm run typecheck`, `npm run build`, production audit and Swift source syntax parsing passed.

Hosted [run 38131960302](https://github.com/thanhdanh/HiMorning/actions/runs/38131960302), head `39ecc17`: backend and iOS jobs **SUCCESS**. This includes Swift package XCTest, native simulator SDK build and the gentle-default XCUITest. Earlier runs correctly failed on a multiline string syntax mistake and catch-bound `error` shadowing UI state; `1694652` and `39ecc17` fixed those compile failures. These are recorded as SDK integration feedback, not claimed runtime behavior TDD cycles. The camera also uses monotonic uptime and defers session stop until the frame delegate returns; hardware behavior still needs device validation.

[AI engineering case study](../AI-ENGINEERING.md) and [metrics baseline](../metrics/README.md) preserve token methodology, tool/skill provenance, local Git hook, CI history and scope limitations. All checkpoints above remain reachable on the current task branch.


## English code/docs and bilingual native app

Request: use simple, natural English for coding and documentation; support English
and Vietnamese in the app. New guides use [the documentation template](../DOC-TEMPLATE.md)
and separate implemented behavior from planned work. Historical metrics remain
frozen; later tokens are recorded in a separate snapshot.

| Journey | RED evidence | GREEN evidence | Checkpoints |
|---|---|---|---|
| Both app languages have complete text and matching placeholders | Three executed resource tests failed with ENOENT for intentionally absent language resources | Same three tests passed; four `.strings` files passed `plutil -lint` | `be321d2` → `357e952` |
| Device language and explicit choice resolve predictably | Portable Swift compile failed because `AppLanguage` was absent | Same harness passed all 14 journeys; language policy is 100% covered | `be321d2` → `357e952` |
| Language choice persists; native editors work in both languages | Hosted run 38134897283 executed the tests: English passed, Vietnamese and saved-language journeys failed | Same three UI tests passed after resources were bundled; no local native runtime result claimed | `f75166e` → `dc6ddce` |

Latest local validation: **53 Vitest tests passed** (42 backend, 8 metrics, 3
localization). Combined instrumented coverage remains 98.05% statements, 96.48%
branches, 94.33% functions and 100% lines; it covers backend + collector library,
not native adapters or locale text quality. Backend scope is unchanged.

Portable Swift: **14 journeys passed**; 84.41% regions (263 total, 41 missed),
98.63% functions (73 total, 1 missed), 97.86% lines (234 total, 5 missed), no
instrumentable branch counters. Typecheck, Functions build, native syntax parsing
and the four native string-file lint checks passed.

Hosted run 38132958590 caught a duplicate XCTest method introduced while adding
coverage. Commit `fad7ef9` removes it. This is a test compilation correction, not
a behavior RED. Both production locale resources and language fallback tests had
already passed locally.

Hosted [run 38134897283](https://github.com/thanhdanh/HiMorning/actions/runs/38134897283)
at `fad7ef9` passed backend checks, 10 Swift package tests and the native build.
It executed all three UI tests: English passed; Vietnamese and saved-language
journeys failed. The build omitted app resources because `resources` was not a
supported target property. The executed RED is preserved in `f75166e`; `dc6ddce`
includes `Resources` in the target sources.

GREEN: [run 38135338781](https://github.com/thanhdanh/HiMorning/actions/runs/38135338781)
at `dc6ddce` passed both jobs, including **10 Swift package XCTest cases**, native
simulator build and **all 3 UI journeys** with zero failures. The log confirms
English/Vietnamese `Localizable.strings`, `InfoPlist.strings` and both WAV sounds
were copied into the app bundle. This validates packaging and tested UI behavior,
not physical-device sound playback or alarm delivery.

Known limits: system permission dialogs still follow iOS language settings; existing
OS alarm labels keep their scheduled language. The web design study remains a
separate Vietnamese concept. Device permission copy, VoiceOver, long text and actual
alarm/camera/audio behavior still require review. Translation parity does not prove
natural wording or layout fit.
