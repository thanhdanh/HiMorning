# Release readiness and subscriptions

Use this review to choose the first App Store scope and the work needed to ship it.

**Status:** Public release blocked as of 13 October 2026; subscriptions are planned.
**Audience:** Product owner, iOS/backend developers and release reviewer.

## At a glance

The native iOS 26+ pilot has a tested foundation. It is not yet a signed,
device-validated App Store release. A green simulator build does not establish
that an alarm will ring reliably on a locked or terminated iPhone.

This snapshot covers commit `ca06de425fd81de3b94313c326871e8319ebf80b`.
[PR #3](https://github.com/thanhdanh/HiMorning/pull/3) is merged and its
[backend and iOS CI run](https://github.com/thanhdanh/HiMorning/actions/runs/38334319009)
succeeded. No App Store Connect account or deployed production environment was
inspected for this review.

| Area | Current evidence | Work before release |
|---|---|---|
| Native alarms | AlarmKit scheduling, persistence and Stop are implemented; core and simulator checks pass | Record physical-device delivery, dismissal, permission and interruption results |
| AI challenge | Push-up capture and an OpenAI backend adapter exist; cloud AI is off by default | For an AI launch, integrate the selected provider, update consent and validate real movement clips end to end |
| Local Qwen | Ordered-image API smoke checks passed on synthetic fixtures | Connect it through the backend; provide an authenticated, reachable service and measure real challenge accuracy and latency |
| Distribution | CI builds with code signing disabled | Add release signing configuration, app icon and versioning; validate an archive and upload a TestFlight build |
| Privacy and support | Camera consent exists; anonymous Firebase accounts are created when cloud features are used | Add accessible privacy/support links, account/data deletion and a privacy/API inventory for the release archive |
| Subscriptions | No StoreKit purchase, restore, entitlement or server-notification implementation was found | Required only if the first release includes paid features; implement and test the complete purchase lifecycle |

AI integration is a blocker for an **AI-enabled** launch. Subscriptions are a
blocker for a **paid** launch. A smaller free release can defer both, provided the
UI and store description accurately describe the features that work.

## How the first release should work

1. Set an alarm, choose a mode and preview a sound in English or Vietnamese.
2. The alarm rings through AlarmKit without needing a purchase or network request.
3. Start a supported challenge, confirm being awake or stop. Keep those recovery
   choices available if the camera, AI service or subscription check fails.
4. Offer Pro from a calm settings or discovery screen, outside the active alarm.
5. After a verified purchase, unlock the paid benefits. Restore them on reinstall
   or another device using the same eligible App Store account.

Editing an existing alarm and native snooze are still planned. Decide whether
they belong in version 1; do not describe them as available until they are wired
and tested. Dance, spoken English, weekly history, detailed pose coaching and
Android can follow a complete first challenge.

## Subscription choices

Use **StoreKit 2** directly for the iOS pilot. Keep one Pro entitlement with monthly
and annual products in one subscription group. Apple explains that customers can
hold one subscription in a group at a time. The first subscription submission
must accompany a new app version. See [Apple's subscription setup guide](https://developer.apple.com/help/app-store-connect/manage-subscriptions/offer-auto-renewable-subscriptions/).

Keep basic alarm scheduling, Stop and recovery free. Pro should offer ongoing
value, such as regularly maintained activity content or a bounded AI service.
Only sell benefits that are implemented. Prices, trial eligibility, included AI
usage and renewal terms remain product decisions. For the Vietnam iOS launch,
use Apple's in-app purchase flow for in-app digital features; review any future
alternative payment proposal against the relevant storefront rules.
[App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)

| Layer | Responsibility |
|---|---|
| SwiftUI + StoreKit 2 | Load localized products, purchase, observe verified transactions, restore and show subscription management |
| Local feature access | Use verified current entitlements and subscription status; refresh at launch and when transactions change |
| Firebase Functions | Verify Apple's signed transactions before granting paid cloud access; reject mismatched app, product and environment |
| Firestore | Store server-owned entitlement/ownership records; clients cannot set their own Pro status |
| App Store Server Notifications V2 | Reconcile renewal, expiration, refund, revocation and grace-period changes; handle duplicates and delayed events |

For local access, use [current entitlements](https://developer.apple.com/documentation/storekit/transaction/currententitlements)
and transaction updates. Provide a user-initiated restore action using
[AppStore.sync](https://developer.apple.com/documentation/storekit/appstore/sync()).
For cloud access, use Apple's
[App Store Server Library](https://developer.apple.com/documentation/appstoreserverapi/simplifying-your-implementation-by-using-the-app-store-server-library)
to validate signed data instead of trusting a client `isPro` flag.

An anonymous Firebase UID can change after reinstall. Define verified purchase
ownership and recovery before charging for cloud AI: one purchase must not grant
separate service quotas to arbitrary new UIDs. Do not make a new password account
a prerequisite for basic alarms. Keep receipt validation and the Pro entitlement
separate from the iOS UI so a future Android adapter can use Google Play billing.

Expiration must not silently cancel saved alarms or block dismissal. If a saved
alarm uses an unavailable paid challenge, offer a free fallback. Cancellation of
auto-renewal normally leaves access until the current paid period ends; refunds,
revocations and configured billing grace periods need their own handling.

## Release gates and evidence to collect

| Gate | Required evidence |
|---|---|
| Alarm reliability | Real iPhone tests for one-shot/repeating alarms, lock screen, terminated app, offline use, restart, time changes, permission denial/revocation and each sound |
| Challenge quality | Consented real clips, including valid/invalid movement, poor light and camera placement; record false acceptance/rejection, uncertain outcomes and end-to-end latency |
| Billing | StoreKit local tests, sandbox and TestFlight results for purchase, cancellation, pending approval, restore, renewal, expiry, refund/revocation, grace and interrupted delivery |
| Billing security | Invalid signatures/products/environments, duplicate or out-of-order notifications, ownership conflicts and non-subscriber cloud requests are rejected safely |
| Usability | EN/VI paywall and recovery copy, VoiceOver, larger text, purchase failures and offline behavior; no paywall interrupts an active alarm |
| Privacy | Published policy, in-app links, accurate provider consent, account/data deletion, declared retention and an archive privacy report matching app/SDK behavior |
| Distribution and operations | Signed archive validation, TestFlight installation, production configuration, reviewer access, monitored failures/quotas, cleanup and a tested way to disable AI without affecting alarms |

Apple's account-deletion guidance explicitly includes automatically generated
guest accounts. Deletion should cover associated data, explain any required
retention and make subscription management available. Deleting a Firebase account
does not cancel App Store billing; immediate account deletion must remain an option.
[Apple account-deletion guidance](https://developer.apple.com/help/app-review/guideline-reference/5-1-1-account-deletion)

The production AI service must be reachable during review and normal use. A model
running only on the developer's `localhost:1235` is development infrastructure.
Apple asks for a complete app and accessible backend services during review.
[App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)

## What we checked

- Source inspection: native alarm flow, editor, camera/challenge lifecycle,
  Firebase adapter, callable configuration, contracts, Firestore rules and CI.
- Scoped source searches: no current purchase/restore/server-billing flow,
  in-app account-deletion flow, app icon asset or app-owned privacy manifest was
  found. SDK-provided privacy manifests were not assessed in an archive.
- Latest CI: backend and simulator iOS jobs succeeded. UI tests cover both
  languages and rehearsal/recovery states; they do not prove physical alarm
  delivery, successful live camera verification or purchases.
- [Qwen smoke evidence](evaluations/lmstudio-smoke-2026-10-13.json): image API
  compatibility checks only, not real exercise or video-stream validation.

No new test suite was run for this documentation-only review. Missing evidence is
an open release gate, not a claim that the corresponding runtime test failed.

## Next steps

1. Complete one release-quality alarm/challenge journey and physical-device checks.
2. If AI ships, finish the Qwen/provider migration, consent and service validation.
3. Implement StoreKit purchases and server entitlements for the agreed Pro benefits.
4. Complete privacy, deletion, signing and store metadata; run a TestFlight pilot
   with sandbox billing before submitting the paid release.

No subscription products, prices, trials, paid agreements, production deployment
or App Store submission were created or changed in this review. App Store approval
remains Apple's decision.

## Read next

- [Free, Pro, retention and friend invitations](BUSINESS-MODEL.md)
- [Run the pilot](RUNNING.md)
- [AI and challenge plan](AI-AND-CHALLENGES-PLAN.md)
- [LM Studio setup and measured limits](LM-STUDIO.md)
- [Product direction](PRODUCT-BRIEF.md)
- [Apple sandbox testing](https://developer.apple.com/help/app-store-connect/test-in-app-purchases/overview-of-testing-in-sandbox)
