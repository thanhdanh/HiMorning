# Release readiness and subscriptions

Use this review to choose the first App Store scope and the work needed to ship it.

**Status:** Public release blocked; subscription scope revised on 15 October 2026
to a no-card preview and monthly/annual Pro. Production setup and sandbox/TestFlight
validation remain pending.
**Audience:** Product owner, iOS/backend developers and release reviewer.

## At a glance

The native iOS 26+ pilot has a tested foundation. It is not yet a signed,
device-validated App Store release. A green simulator build does not establish
that an alarm will ring reliably on a locked or terminated iPhone.

The original audit snapshot covers commit `ca06de425fd81de3b94313c326871e8319ebf80b`.
The subscription row now includes the approved preview and two-plan revision;
its current scope and validation are recorded in [the subscription guide](SUBSCRIPTIONS.md).
[PR #3](https://github.com/thanhdanh/HiMorning/pull/3) is merged and its
[backend and iOS CI run](https://github.com/thanhdanh/HiMorning/actions/runs/38334319009)
succeeded. No App Store Connect account or deployed production environment was
inspected for this review.

| Area | Current evidence | Work before release |
|---|---|---|
| Native alarms | AlarmKit scheduling, persistence and Stop are implemented; core and simulator checks pass | Record physical-device delivery, dismissal, permission and interruption results |
| AI challenge | Push-up capture and an OpenAI backend adapter exist; cloud AI is off by default | For an AI launch, integrate the selected provider, update consent and validate real movement clips end to end |
| Local Qwen | Ordered-image API smoke checks passed on synthetic fixtures | Connect it through the backend; provide an authenticated, reachable service and measure real challenge accuracy and latency |
| Distribution | Simulator Release build passes; native tests use ad-hoc simulator signing | Add device/distribution signing, app icon and versioning; validate an archive and upload a TestFlight build |
| Privacy and support | Camera consent exists; anonymous Firebase accounts are created when cloud features are used | Add accessible privacy/support links, account/data deletion and a privacy/API inventory for the release archive |
| Subscriptions | No-card preview and monthly/annual implementation; signed native suite and bilingual UI suite pass locally; see [setup](SUBSCRIPTIONS.md) | Configure both real products without an introductory offer, test sandbox/TestFlight lifecycle and simulator expiry propagation; add server verification before selling paid cloud AI |

AI integration is a blocker for an **AI-enabled** launch. Subscriptions are a
blocker for a **paid** launch. A smaller free release can defer both, provided the
UI and store description accurately describe the features that work.

## How the first release should work

1. Set an alarm, choose a mode and preview a sound in English or Vietnamese.
   The first successful save starts thirty elapsed days of full access with no
   card or subscription signup. Failed saves do not consume the preview.
2. The alarm rings through AlarmKit without needing a purchase or network request.
3. Start a supported challenge, confirm being awake or stop. Keep those recovery
   choices available if the camera, AI service or subscription check fails.
4. Offer Pro voluntarily from a calm screen, with nonblocking discovery after
   three completed mornings. The preview ends without a charge; Free retains
   scheduling, a basic challenge and recovery.
5. After a verified purchase, unlock the paid benefits. Restore them on reinstall
   or another device using the same eligible App Store account.

Editing an existing alarm and native snooze are still planned. Decide whether
they belong in version 1; do not describe them as available until they are wired
and tested. Dance, spoken English, detailed pose coaching and
Android can follow a complete first challenge.

## Subscription choices

Use **StoreKit 2** directly for the iOS pilot. The approved model has one Pro
entitlement with monthly and annual products in one subscription group, targeting
US $2/month and $20/year. The no-card preview is managed locally and does
not start an Apple subscription or renew at expiry. Do not add an introductory
offer to this model. Apple explains that customers can
hold one subscription in a group at a time. The first subscription submission
must accompany a new app version. See [Apple's subscription setup guide](https://developer.apple.com/help/app-store-connect/manage-subscriptions/offer-auto-renewable-subscriptions/).

Keep basic alarm scheduling, Stop and recovery free. Pro should offer ongoing
value, such as regularly maintained activity content or a bounded AI service.
Only sell benefits that are implemented: Focused mode, extra sounds and richer
local progress in this pilot. Actual storefront prices require App Store setup.
Paid AI quotas remain a future decision. For the Vietnam iOS launch,
use Apple's in-app purchase flow for in-app digital features; review any future
alternative payment proposal against the relevant storefront rules.
[App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)

The server responsibilities below apply when paid cloud benefits are introduced.
The current local progress subscription only needs the StoreKit layer.

| Layer | Responsibility |
|---|---|
| SwiftUI + StoreKit 2 | Load localized products, purchase, observe verified transactions, restore and show subscription management |
| Local feature access | Combine the Keychain preview window with verified current entitlements/status; refresh at launch, foreground and transaction changes |
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

Expiration must not cancel saved alarms, rewrite their modes/sounds or block
dismissal. A saved Focused alarm uses a clearly explained Balanced fallback while
Free; new Free alarms use system sound. Progress has no history deletion action. Keychain
time protection limits simple rollback but is not a server entitlement or a
guaranteed defense against reinstall/device changes. Cancellation of
auto-renewal normally leaves access until the current paid period ends; refunds,
revocations and configured billing grace periods need their own handling.

## Release gates and evidence to collect

| Gate | Required evidence |
|---|---|
| Alarm reliability | Real iPhone tests for one-shot/repeating alarms, lock screen, terminated app, offline use, restart, time changes, permission denial/revocation and each sound |
| Challenge quality | Consented real clips, including valid/invalid movement, poor light and camera placement; record false acceptance/rejection, uncertain outcomes and end-to-end latency |
| Billing | Preview starts only after confirmed alarm save; exact thirty-day expiry and clock rollback; monthly/annual purchase, cancellation, pending approval, restore, renewal, refund/revocation, grace and interrupted delivery in local tests, sandbox and TestFlight |
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
- Original audit searches found no billing flow. Monthly StoreKit billing and
  local progress have since been added; server billing is still absent. In-app
  account deletion, an app icon asset and an app-owned privacy manifest were not
  found in the audited source. SDK manifests were not assessed in an archive.
- Latest CI: backend and simulator iOS jobs succeeded. UI tests cover both
  languages and rehearsal/recovery states; they do not prove physical alarm
  delivery, successful live camera verification or purchases.
- [Qwen smoke evidence](evaluations/lmstudio-smoke-2026-10-13.json): image API
  compatibility checks only, not real exercise or video-stream validation.

No new test suite was run for the original documentation-only audit. The later
monthly implementation has separate [TDD evidence](tdd/monthly-pro.tdd.md).
The [no-card preview revision](tdd/no-card-preview.tdd.md) records newer core,
native and UI checks separately. Its signed native suite has 15 passing tests,
and its UI suite has 8 passing tests. An earlier unsigned bundle also contains a
Keychain failure; the whole historical bundle is not described as passing.
Both bilingual expiry UI tests also pass in a separate signed run.
Release build checks also confirm debug-only UI fixture flags are absent.
Expiry decisions are tested against verified signed periods with an injected
clock; simulator expiry-event propagation still needs manual validation.
Missing release evidence is an open gate, not a claim that a runtime test failed.

## Next steps

1. Complete one release-quality alarm/challenge journey and physical-device checks.
2. If AI ships, finish the Qwen/provider migration, consent and service validation.
3. Configure and test both App Store products in sandbox/TestFlight, including
   lifecycle events beyond the local checks. Add server entitlements
   before including cloud AI as a paid benefit.
4. Complete privacy, deletion, signing and store metadata; run a TestFlight pilot
   with sandbox billing before submitting the paid release.

No production subscription products, prices, offers, paid agreements, deployment
or App Store submission were created or changed in this review. App Store approval
remains Apple's decision.

## Read next

- [Full preview and Pro setup](SUBSCRIPTIONS.md)
- [Free, Pro, retention and friend invitations](BUSINESS-MODEL.md)
- [Run the pilot](RUNNING.md)
- [AI and challenge plan](AI-AND-CHALLENGES-PLAN.md)
- [LM Studio setup and measured limits](LM-STUDIO.md)
- [Product direction](PRODUCT-BRIEF.md)
- [Apple sandbox testing](https://developer.apple.com/help/app-store-connect/test-in-app-purchases/overview-of-testing-in-sandbox)
