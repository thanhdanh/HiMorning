# TDD evidence — cost optimized pilot

Source journeys: [implementation plan](../IMPLEMENTATION-PLAN.md), derived from existing architecture and user instructions.

## RED checkpoint, 11 October 2026

Runner detector selected npm; repository had no runner. Added npm/Vitest and Swift XCTest test infrastructure before production code.

Actual command: `npm test`. Exit 1: three suites could not import the intentionally absent business modules `functions/src/evidence.js`, `service.js`, `openai.js`. Vitest 5.0.3 ran successfully; dependencies (including sharp) resolved. This is the skill's compile/import-time RED for missing implementation; it is not a runtime assertion RED. New tests exercise ordered evidence, conservative model policy, idempotent sessions, atomic quotas, cancellation/expiry and bounded provider calls. No business implementation existed at this checkpoint.

Further GREEN, integration, Swift evidence and coverage will be appended after execution. No real model calls or deployments are used in development tests.

Second RED validation included `tests/api.test.ts`: `npm test` exited 1 with four suites referencing missing implementation. Swift XCTest was unavailable in Command Line Tools (infrastructure failure; not counted as RED). A portable equivalent compiled with `swiftc ios/HiMorningCore/Sources/HiMorningCore/Module.swift ios/HiMorningCore/TestsPortable/main.swift -o /private/tmp/himorning-core-tests` exited 1 with `cannot find WakeMode`, `WakeSession`, `AlarmTime`, `RepCounter`, `EvidenceBuffer` in scope: valid compile-time RED for absent domain types.
