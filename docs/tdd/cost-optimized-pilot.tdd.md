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
