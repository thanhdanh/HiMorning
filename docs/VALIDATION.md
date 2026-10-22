# Validation and known gaps

Keep reproducible checks separate from physical observations, dated screenshots
and release claims.

**Status:** Recorded local evidence for source revision `6a1e1e7`, 22 October 2026.
**Audience:** Contributors and release reviewers. This is a dated snapshot, not a
live CI status page or a claim that all suites pass.

## At a glance

| Check | Recorded result | Scope |
|---|---|---|
| SwiftPM core | 187 tests passed | Pure alarm, challenge, access, content and recovery rules |
| Portable Swift | Passed | Shared core test bodies plus portable integration journeys |
| Vitest | 124 tests passed across 13 files | Default `pnpm test`; excludes real Firestore integration tests |
| TypeScript typecheck | Passed by the pre-push hook | Root and Worker |
| Native unit suite | 72 passed, 1 failed out of 73 | Camera/voice/StoreKit and other native tests on iOS 26.2 |
| Signed device build | Build, install and launch succeeded | Latest Reach up tuning on iPhone 15 Pro; not a recognition benchmark |
| Targeted UI journeys | Earlier focused runs passed during this change series | Card repeat/layout, draft practice, sound selection and completion; no fresh full UI sweep claimed |

## Reproduce

Use [Running](RUNNING.md) for prerequisites and native commands.

```sh
pnpm run typecheck
pnpm test
sh scripts/test-swift.sh
swift test --package-path apps/ios/HiMorningCore
```

The [workflow](../.github/workflows/ci.yml) additionally runs real Firestore
Emulator coverage, Python checks, contract drift checks and native unit/UI tests.
A manual workflow run selects the full UI suite. The current push path selects
all native unit tests plus 15 UI tests through [`test-ios.sh`](../scripts/test-ios.sh).
The table above does not claim a new emulator, Python or full UI run.

## Known failure

`SubscriptionTests.testSignedExpiredPurchasesCannotUnlockEitherPlan` failed in
the full native suite and in isolation. It also failed on an archived copy of
published main revision `43843f9`, before the `6a1e1e7` UI/movement batch. The
subscription implementation and test were unchanged by that batch.

The assertion says a seeded expired monthly/annual transaction must not leave
Pro enabled. The root cause has not been established; do not relabel it a
simulator-only failure or claim signed expiry is fully validated. Investigate
StoreKit entitlement/status state and the test's seeding lifecycle before release.
CI's iOS 26.2 pin does not eliminate this locally reproduced failure.

## Evidence boundaries

- Synthetic joint tests can check thresholds, ordering, occlusion and duplicate
  protection; they cannot measure real people's false acceptance/rejection rates.
- A signed development install and user feedback are useful observations, not
  the full alarm-delivery or accessibility matrix.
- Temporary local logs/result bundles from the development session are not
  durable repository artifacts. Preserve new release evidence with its source
  revision, command, environment and outcome when it is collected.
- [Historical TDD reports](tdd/README.md), [old screenshots](images/ui/README.md)
  and [usage metrics](metrics/README.md) retain their original dates and totals.
  Their passed checks must not be presented as the result of a newer suite.
- Deployment observations in the backend references are historical. This review
  did not contact cloud services, make paid inference calls or inspect billing.

## Next checks

Resolve the expiry failure and complete the [release matrix](RELEASE-READINESS.md).
Keep new device/camera observations separate from automated assertions. Update
this snapshot when verification is actually rerun; do not change numbers merely
because more tests exist in source.
