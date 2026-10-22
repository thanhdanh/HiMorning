# Preview, Free and Pro

A successfully saved first alarm starts a no-card preview. StoreKit purchases are
optional and separate from basic alarm delivery and recovery.

**Status:** Local implementation; production products and sandbox/TestFlight
billing acceptance remain pending. Reviewed on 22 October 2026.
**Audience:** iOS developers and release reviewers.

## At a glance

| Access | Current behavior |
|---|---|
| Before first save | Explore and create a draft; preview time has not started |
| Preview | 30 elapsed days from the first confirmed alarm save; no purchase or automatic charge |
| Preview / Pro | All catalog levels, bundled sounds, 30-day progress view and custom weekly goal |
| Free after expiry | Alarm scheduling and recovery; Gentle/Balanced editor levels, system sound for new choices; effective saved push-up target capped at 5 |
| Monthly Pro | `com.himorning.pro.monthly`, local target price US $2/month |
| Annual Pro | `com.himorning.pro.annual`, local target price US $20/year, same subscription group |

The live Apple purchase sheet owns actual localized price and renewal terms.
The local StoreKit fixture is not a production price or a live product. There is
no introductory offer in the checked-in fixture. Cloud AI quotas, referral rewards
and server-side billing are not Pro benefits implemented here.

## How access works

`PreviewPeriod` starts after a successful save, or for an existing confirmed alarm
on refresh. Failed saves and unresolved schedule errors do not start it. Keychain
stores start/latest-observed time to limit simple clock rollback; this is not a
cross-device entitlement or a guarantee against reinstall/device changes.

`SubscriptionStore` reads verified StoreKit entitlements, subscription status and
transaction updates. The two products grant the same local Pro access. The source
handles signed expiry, revocation, supersession and grace periods; see the
[known failing expiry integration test](VALIDATION.md#known-failure) before treating
that lifecycle as release-validated.

Expiration does not cancel alarms, rewrite their saved settings or remove
remaining backup rings. A saved `focused` mode is presented as an effective
Balanced fallback when Free, and push-ups are capped at 5 for execution. Other
explicit challenge kinds remain as saved. Existing native sound registrations are
preserved; choosing a new restricted sound still requires full access.
The [catalog guide](MODE-CHALLENGES.md) distinguishes display labels from storage IDs.

Local outcomes retain the effective mode/challenge at completion. Rehearsal is
excluded. A completed challenge scores 100, self-confirmation scores zero, and
missing records are unscored. History retains up to 31 local calendar days so a
31-day month's first day is available; the paid progress view covers 30 days and
shows a weekly goal. There is no history-deletion UI.

## Configure and test

Generate the Xcode project and use the checked-in
[`HiMorning.storekit`](../apps/ios/StoreKit/HiMorning.storekit) configuration.

```sh
xcodegen generate --spec apps/ios/project.yml
xcodebuild -project apps/ios/HiMorning.xcodeproj -scheme HiMorning   -destination 'platform=iOS Simulator,id=YOUR_SIMULATOR_UDID'   -only-testing:HiMorningTests/SubscriptionTests   -collect-test-diagnostics never CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test
```

StoreKitTest creates local transactions without charging a card. Keep the
ad-hoc signature for Keychain-backed preview tests. The workflow pins iOS 26.2,
but the signed-expired-purchase test also failed there in the latest local run.
Do not dismiss that result as only a newer-runtime issue.

For production, configure both IDs in one App Store Connect subscription group,
verify localized product display, restore and management, then exercise purchase,
renewal, cancellation, pending approval, refund/revocation, grace and expiry in
sandbox/TestFlight. Recheck current Apple submission requirements at release.
Paid cloud benefits would additionally need server-side signed transaction
verification and durable purchase ownership; a client `isPro` flag is insufficient.

## What we checked

[Validation](VALIDATION.md) owns the latest recorded results and known failure.
Earlier [monthly](tdd/monthly-pro.tdd.md) and [preview](tdd/no-card-preview.tdd.md)
reports remain historical checkpoints. Simulator fixtures do not prove live billing,
actual renewal delivery or migration across App Store accounts/devices.

## Read next

[Release readiness](RELEASE-READINESS.md) · [Running](RUNNING.md) ·
[Local access rules](../apps/ios/HiMorningCore/Sources/HiMorningCore/Morning.swift)
