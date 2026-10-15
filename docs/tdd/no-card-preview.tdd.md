# No-card preview and two subscription plans

Let people judge HiMorning across 30 days before deciding whether to pay. This
report preserves the approved behavior, test evidence and remaining release work.

**Status:** Implemented and checked locally on 15 October 2026. Store and device
validation remain pending.
**Audience:** Developers, reviewers and interview readers.

## Approved journey

The owner approved the revised plan on 15 October 2026. All current features are
available without a card. The first successfully saved alarm starts 30 elapsed
days; cancelling the editor and failed scheduling do not start the period.
Existing confirmed alarms start the period on the first refresh after migration.
The preview never charges or starts an Apple subscription automatically.

After preview, Free retains alarm scheduling, Gentle, Balanced (three push-ups),
self-confirmation and Stop. Focused (five push-ups), custom sounds on new alarms,
history and custom goals require Pro. Stored alarm preferences remain intact;
an active challenge freezes its target so access changes cannot change the
camera/coordinator contract halfway through the session. Existing alarm sounds
remain unchanged for reliability.

Monthly and annual plans use one Apple subscription group, with local test prices
of $2 and $20. Both require verified Apple transactions. There is no introductory
StoreKit offer; the no-card preview is a separate app feature.

## RED evidence

Tests were changed before their production implementation. Checkpoint commits
were deferred until the owner approved Gate 2 on 15 October 2026. The final code
and tests are committed as `4148a28`; documentation follows in its own commit.
The RED/GREEN excerpts below preserve the sequence without presenting the final
commit as an earlier RED-only checkpoint.

| Behavior | Test target | Observed RED |
|---|---|---|
| Preview lifecycle and Free capabilities | `sh scripts/test-swift.sh` | Missing `PreviewPeriod` and access APIs; exit 1 |
| Native preview persistence/failure handling | `HiMorningTests/PreviewStoreTests` | Compile failed: `cannot find PreviewStore in scope` |
| Both subscription plans | `HiMorningTests/SubscriptionTests` | Compile failed: missing `productIDs` and `annualProductID` |
| Deterministic signed expiry | Native cancellation tests | Compile failed: missing clock initializer, then verified expiry boundary passed |
| Real Keychain storage | Native isolated storage test | Missing service overload, then runtime `status(-34018)` exposed unsigned host/entitlement configuration |

Native RED command:

```sh
xcodebuild -project apps/ios/HiMorning.xcodeproj -scheme HiMorning \
  -destination 'platform=iOS Simulator,id=<available device ID>' \
  -only-testing:HiMorningTests test
```

The local RED log is `/private/tmp/himorning-preview-red.log`. Missing APIs are
the intended compile-time RED signal, rather than an unrelated dependency failure.

## Checks completed

| Guarantee | Evidence | Result |
|---|---|---|
| Starts once; exact 30-day boundary; observed clock rollback cannot restore expired time | Core portable and XCTest preview tests | PASS |
| Free allows basic choices; Preview and Pro unlock current features; fallbacks preserve saved preferences | Core capability tests | PASS |
| Preview persists between instances; corrupt or failed storage cannot restart/grant preview; real Keychain add/read/update works | `PreviewStoreTests` | 4 PASS |
| Verified annual access overrides expired/corrupt preview; refund restores the appropriate preview/Free state | Native annual composition test | PASS |
| Both plans restore/refund correctly; cancellation preserves paid time; signed expiry removes access at the exact boundary; unrelated/unverified transactions are rejected | `SubscriptionTests` | 11 PASS |
| Basic choices and private history clearing remain after expiry; both languages, brand colors, rehearsal recovery and sound preview work | `PilotUITests` | 8 PASS; signed bilingual expiry rerun also PASS |
| English and Vietnamese keys/placeholders match; all native copy has translations | `pnpm test` | 52 tests PASS across 7 files |

Core validation ran 22 portable journeys and 15 SwiftPM XCTest tests. Portable
coverage reports **97.74% core lines** and **97.37% Morning.swift lines**. These
figures describe domain code, not whole-app UI coverage.

Signed native coverage separately measures **94.12% PreviewStore.swift lines**
(64/68) and **98.85% Subscriptions.swift lines** (86/87). The actual Keychain test
uses a UUID-named service and removes only its own test item.

Final native command used `-only-testing:HiMorningTests`,
`CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=-` and
`-collect-test-diagnostics never`: **15 tests, 0 failures**, `TEST SUCCEEDED`.
Result: `/private/tmp/himorning-preview-signed-native.xcresult`.
The eight-test UI suite passed in
`/private/tmp/himorning-preview-final-v2.xcresult`; that earlier combined bundle
still records the unsigned Keychain failure, which the subsequent signed native
run resolves. A signed rerun of the bilingual expiry journey also succeeded in
`/private/tmp/himorning-preview-signed-ui.xcresult`. No tests were skipped.

The local Release build passed; its binary contains none of the DEBUG UI fixture
flags (`--ui-testing`, `--preview-expired`, `--ui-language-vi`). Screenshots from
passing UI journeys are linked in the subscription guide.

## Simulator findings

`SKTestSession.expireSubscription` changed the test transaction's expiry, but both
signed transaction APIs still returned a future expiry and subscribed status in
the observed iOS 27 run. Rather than make production trust a test-only record,
the native adapter now accepts a clock whose default is `Date()`. Tests advance
that clock to the real verified signed expiry and also purchase past-dated,
non-renewing subscriptions. This proves the signed boundary, not delivery of an
expiry event. Logs from the contradictory mutation remain at
`/private/tmp/himorning-billing-green-v4.log` and
`/private/tmp/himorning-billing-green-v5.log`.

Real Keychain operations failed with `-34018` under unsigned simulator builds.
The app now declares one app-specific Keychain access group and uses ad-hoc
signing for simulator runs. CI tests enable signing too; unsigned compile-only
checks remain valid. The signed storage test passed without a fallback or bypass.

## Review

An independent code and security review found a mismatch when an open Focused
challenge outlived preview expiry: live UI targets could change while its
coordinator retained the original target. The fix freezes one session mode for
the UI, camera and coordinator. Source re-review found no remaining HIGH/MED issues.

Keychain state uses device-only accessibility. Read/decode/write errors fail
closed for preview while preserving basic alarms and valid paid access. UI fixtures
are guarded by `#if DEBUG`; no preview flag authorizes backend cloud inference.

## Limits and next steps

StoreKit expiry-event propagation remains a sandbox/device follow-up. Production
App Store Connect products, sandbox/TestFlight purchases,
real renewal/grace behavior and physical-device alarm/audio checks are pending.
Keychain and observed local time are a beta defense, not a trusted server clock
or a guaranteed defense against reinstall/device reset. Cloud AI retains its
existing consent and quotas; paid cloud authorization is outside this change.

Exact task/phase token counts are unavailable from the current tools. No usage
numbers are inferred from output size. See the AI engineering guide for the
available telemetry and the distinction between observed and proposed metrics.

## Read next

- [Subscriptions](../SUBSCRIPTIONS.md)
- [Business model](../BUSINESS-MODEL.md)
- [AI engineering evidence](../AI-ENGINEERING.md)
- [Historical monthly-only implementation](monthly-pro.tdd.md)
