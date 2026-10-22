# Monthly Pro: TDD evidence

> **Dated evidence.** Commands, approvals, test totals and local paths below
> describe the original run. They are not current setup instructions or release
> status. See [current validation](../VALIDATION.md) for newer results and known gaps.

Keep the path from the owner's $2–3 monthly budget to tested access rules visible.

**Status:** GREEN for the pilot scope. [Source CI](https://github.com/thanhdanh/HiMorning/actions/runs/38409856341)
passed at `7cede1f8e942e650d1ccfc83ab6292c0f68b09a6`.
**Audience:** Reviewer and AI-engineering case-study reader. **Date:** 13 October 2026.

## Source and journeys

The owner approved proceeding with an inexpensive subscription. The working US
price is $2.99/month. [Business model](../archive/design/BUSINESS-MODEL.md) and
[subscription scope](../SUBSCRIPTIONS.md) define this bounded first version:

1. Use alarms and Stop without a purchase or subscription check.
2. View seven days of progress for free; a verified monthly Pro entitlement adds
   thirty days and a custom weekly goal.
3. Purchase or restore through Apple; return safely to Free after expiry/refund.
4. Keep honest outcomes, exclude rehearsals and preserve data across downgrade.
5. Clear history or share a short message voluntarily, in English or Vietnamese.

## Checkpoints and RED

| Checkpoint | Actual evidence |
|---|---|
| `6e12b23` | Added portable journeys before the journal existed. `sh scripts/test-swift.sh` failed with `cannot find type 'MorningJournal' in scope` and missing `MorningEntry`/`MorningAccess` |
| `c8db7b1` | Minimal journal implementation; the same harness passed all 20 original journeys |
| `5ccd1d9`, `97c46d3` | Added native StoreKit tests and corrected async test setup before the billing adapter existed |
| [Native RED run](https://github.com/thanhdanh/HiMorning/actions/runs/38348238832) | Xcode built the existing app/core, then failed in `SubscriptionTests.swift:13` because `SubscriptionStore` was missing |
| `fc6349d`, `3bbc01e` | Added native billing/progress and corrected the test's typed verification error; validation commits, not a claim that native GREEN had already run |
| `5cbe7a9` / [expiry RED](https://github.com/thanhdanh/HiMorning/actions/runs/38404079724) | Compatible runtime loaded products: purchase/restore/refund and wrong-product checks passed, but expiration still left Pro active |
| `dcaf3ab` | Portable expiry/grace boundaries failed because `MorningAccess.verifiedPeriod` was missing |
| `923f9b7` | Added signed-period checks and subscription-status updates; all 21 portable journeys passed |
| `3fc76d6` | Serialized shared refresh calls, fixed the local test clock to real time and retained explicit expiry/refund mutations |
| [Refund notification timing](https://github.com/thanhdanh/HiMorning/actions/runs/38408494007) | Restore, expiry and automatic refund updates passed; one post-refund assertion ran before asynchronous revocation arrived. The restore journey now awaits the actual access update before asserting |
| [Native restore feedback](https://github.com/thanhdanh/HiMorning/actions/runs/38405867640) | Expiry and automatic refund updates passed; the restore/refund journey had two state assertions fail. Revalidation follows serialized refresh and an explicit real-time test clock |

The final source run passed **21 portable Swift journeys, 10 Swift package tests,
5 native StoreKit tests and 6 bilingual UI tests**. Both CI jobs succeeded.
The native StoreKit suite completed in 2.446 seconds; this test-environment timing
is not a real-device purchase latency benchmark.

An initial compiler module-cache permission error was an environment preflight
failure and is not counted as RED. Retrying the approved Swift harness with cache
access produced the intended missing-feature compile failure.

## Test specification

| Guarantee | Test | Result |
|---|---|---|
| Rehearsals and duplicate callbacks do not add successful mornings | `TestsPortable/MorningTests.swift`, first journey | PASS locally |
| One success day is counted once; Stop remains distinct | Same journey | PASS locally |
| Calendar windows exclude future evidence and show the Free/Pro range | Second journey | PASS locally |
| Downgrade preserves saved history/goal; invalid goals cannot overwrite state | Third journey | PASS locally |
| Signed expiry denies access at the boundary; verified unexpired grace preserves it | `runSubscriptionPeriodTests` | PASS locally |
| Corrupt storage is not silently reset; failed writes do not change memory | Fourth/fifth journeys | PASS locally |
| Copy keys and placeholders match in English/Vietnamese | `pnpm exec vitest run tests/localization.test.ts` | 3 tests PASS locally |
| Existing backend checks remain intact | Pre-push `pnpm run typecheck` and `pnpm test` | PASS; 52 non-emulator tests |
| Purchase/restore/refund, cancellation versus expiry, pending/cancel, unverified and wrong products, automatic refund updates | `HiMorningTests/SubscriptionTests.swift` | PASS in source CI |
| Progress/Pro discovery in both languages, plus existing alarm/rehearsal recovery | `HiMorningUITests/PilotUITests.swift` | PASS in source CI |

Paths in the table are under `apps/ios/HiMorningCore` or `apps/ios` unless a command
names a root test. Native tests use StoreKitTest's local configuration, not real
charges or production receipts.

## Coverage and known gaps

Executed locally with `sh scripts/test-swift.sh`:

| Scope | Line coverage | Region coverage |
|---|---:|---:|
| New `Morning.swift` | 100% (49 lines) | 97.87% |
| Swift core total | 98.23% (283 lines) | 86.45% |

LLVM reports regions here, not branch coverage. Native coverage is a separate instrumented run: **Subscriptions.swift 98.82%
(84/85 lines)** and **HiMorning.app 78.60% overall**. The broader app remains below
80%, including hardware paths; these results do not certify a public release.
The native UI run alone covers less of the Swift core than the independent
portable harness. Do not combine their percentages or relabel core coverage as
whole-app coverage. See [coverage evidence](../evaluations/monthly-pro-coverage-2026-10-13.json).

The first native implementation run built successfully and passed all six UI
journeys, but StoreKitTest could not save its configuration on the selected iOS
26.4 simulator (`SKInternalErrorDomain Code=3`). This is setup feedback, not a
receipt-verification failure. CI now selects the installed iOS 26.2 runtime in
response to the [documented StoreKitTest CLI regression](https://developer.apple.com/forums/thread/826971).
The tests were retained rather than skipped.

Real-device alarm delivery, App Store sandbox/TestFlight billing, real pending
approvals, grace/retry handling and interrupted purchases remain release checks.
Constructing a `.pending` result tests app behavior, not the complete Ask to Buy
service. Runtime UI testing and a Swift syntax parse are separate kinds of proof.

## How the AI work was controlled

- Used ECC `tdd-workflow` and `security-review`; preserved RED/GREEN checkpoints.
- Used the codebase-memory MCP at Verify scope. Its index was from 11 October;
  changed UI files and the partial ChallengeView range were read from source.
- Used Apple documentation for StoreKit entitlements, native store views and
  verification errors; did not invent a receipt parser or cache a premium flag.
- Kept paid benefits local, avoiding an unnecessary billing service, wallet SDK
  and new package dependency. Server-paid AI is explicitly deferred.
- Used GitHub's Xcode runner because the local host only has Command Line Tools.
  This makes native compiler/test failures reviewable instead of guessing them.

Exact coding-agent token usage and dollar cost were not collected for this change.
Qwen smoke-test tokens and account usage percentages are different measurements
and must not be substituted. No savings percentage or user-retention improvement
is claimed from implementation tests.

## Merge evidence

Keep the checkpoint table and linked CI runs if this branch is squash-merged.
The report records missing APIs as intended compile-time RED, actual local GREEN,
and the separately collected native results. No production subscription product
or App Store submission was created.
