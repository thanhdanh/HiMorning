# HiMorning iOS subscription completion

Status: Local implementation verified. App Store Connect and TestFlight pending.
Updated 2026-11-08 (UTC+07:00).

## Lead brief

HiMorning users should be able to choose a monthly or annual Pro plan, restore
an existing subscription, and manage it through Apple. Verified Pro access
must follow the signed paid or grace period while basic alarms stay available.

Keep the existing StoreKit 2 products, level, and local 30-day preview. Native
StoreKit controls own price, renewal terms, and checkout. Adding a billing
server or provider would add operating cost without a benefit that needs
server-side authorization. Using only the current native purchase view leaves
no explicit recovery for a missing storefront catalog or failed restore.
Use app-owned status and recovery around the native controls. This adds no
separate subscription service or recurring infrastructure cost.

The Pro sheet opens from Home and existing Pro discovery links. Show benefits,
current access and secondary actions above Apple's plans and checkout. Active
subscribers can open Apple's subscription settings. When plans are unavailable,
put retry and restore above the benefits. Restore reports its outcome. Use
MorningTheme, native navigation and controls, and scrollable content in English
and Vietnamese at accessibility text sizes.

## Acceptance

- [x] L1: Pro comes from verified StoreKit products only. Purchase, restoration,
  refund, cancellation and signed expiry exercise both plans in StoreKitTest.
- [x] L3: The Pro sheet exposes checkout when the local catalog loads and
  gives a way to retry and restore when it is unavailable. Review simulator
  screenshots of the affected screen.
- [ ] L5: App Store Connect products work in a distributed TestFlight build.

## Milestones

1. Reproduce the documented expiry failure. Record the signed transaction
   and fixture behavior before changing access rules or the test.
2. Complete the Pro sheet and subscription recovery. Verify the targeted
   StoreKit and UI suites, then review billing code and screenshots independently.
3. Record local proof and App Store Connect handoff steps.

## Decision Log

- 2026-11-08: Keep both existing StoreKit IDs and the preview policy. Restore
  via App Store sync and manage via Apple's sheet. The Pro sheet can be
  rolled back without a data migration or a storefront change.

## Progress

- 2026-11-08: Located the current release checkout, an existing StoreKit
  fixture, a documented expiry test failure, and deferred purchase UX work.
- 2026-11-08: iOS 26.2 on iPhone 17 could not start `launchd_sim`. The
  existing signed-expired test passed on iOS 27.0 (iPhone 18 Pro Max) with
  both seeded expired products and the existing entitlement rules.
  See `.build/artifacts/ui.XUvwXa/test.log`. The cause of the older 26.2
  failure remains unverified.
- 2026-11-08: On base `b7ed013`, `make ios-uitest IOS_SIM=3A88FBF4-21A0-452B-9CB9-7E2224971734 ONLY=HiMorningTests/SubscriptionTests`
  exited 0 on iOS 27.0. All 13 tests passed, including network-error retry,
  restore outcomes, both product IDs, refunds, and signed expiry.
  See `.build/artifacts/ui.bN06TF/test.log`.
- 2026-11-08: Historical log review found the October failure at the final
  `isPro` assertion for both product IDs. The fixture expiry precondition did
  not fail. A subsequent 23 October run passed on iOS 26.2. The older failed
  runs lack the signed entitlement/status values needed to isolate the cause.
- 2026-11-08: Independent billing review caught stale restore feedback on
  revocation. The fix clears feedback on a paid-access change and a restore
  regression test asserts the message clears after refund. The follow-up review
  approved it. `make ios-uitest IOS_SIM=3A88FBF4-21A0-452B-9CB9-7E2224971734 ONLY=HiMorningTests`
  exited 0 with 83 native tests passed, including the 13 subscription tests.
  See `.build/artifacts/ui.llGWFt/test.log`. `make ios-core-test` exited 0.
- 2026-11-08: `make ios-uitest IOS_SIM=3A88FBF4-21A0-452B-9CB9-7E2224971734 ONLY=HiMorningUITests/SubscriptionUITests`
  exited 0. Two journeys passed on iOS 27.0: purchase through native checkout
  unlocks Pro and returns to Home, and Vietnamese dark mode at the largest
  text size can restore and retry after a simulated catalog network error.
  See `.build/artifacts/ui.dlOBZq/test.log` and the images exported by
  `make ios-shot IOS_RESULT=.build/artifacts/ui.dlOBZq/himorning-ui.xcresult ONLY=SubscriptionUITests`
  to `.build/artifacts/shots/run.VtKswY/`.
- 2026-11-08: Independent visual review approved the updated dark-mode
  recovery button. At the largest text size the native plan cards shorten
  Apple's product description. The sheet lists the benefits separately.
- 2026-11-08: Both existing discovery tests passed. The Home journey covers
  English and Vietnamese, and the routine journey opens Pro and returns to the
  free purpose picker. See `.build/artifacts/ui.l549Ti/test.log` and
  `.build/artifacts/ui.ZcunnS/test.log`.
- 2026-11-08: `make ios-release-check` exited 0. See
  `.build/artifacts/ios-release-check.log`.

## Risks

StoreKitTest validates a local catalog and local transactions. Production
availability, real account restoration, and delivery of renewal state depend
on the App Store and need an Apple sandbox account and a physical iPhone.

## NEEDS_HUMAN

- Confirm the matching app record, paid agreement, both products and their
  storefront prices in App Store Connect.
- Archive the updated source with `make ios-archive TEAM_ID=3JG2QB4549 VERSION=1.0 BUILD_NUMBER=<unused-build-number>`,
  upload to internal TestFlight and run the [iPhone billing checklist](../SUBSCRIPTIONS.md#app-store-connect-and-testflight).
  The existing `1.0 (1)` archive predates this implementation.
- Submit the first subscription group and both products with the app version
  after sandbox/TestFlight acceptance.
