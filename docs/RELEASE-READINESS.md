# Release readiness

Use this checklist to distinguish the working development pilot from evidence
needed for an App Store release.

**Status:** Public release not validated. Source and local evidence reviewed on
22 October 2026 against `6a1e1e7`. **Audience:** Product owner and release reviewer.

## At a glance

Signed development builds have been installed and opened on an iPhone 15 Pro.
Alarm editing, icon, local camera challenges, content packs and StoreKit source
exist. This is narrower than validated delivery across device states, measured
movement accuracy or production billing. No production account/configuration was
inspected during this documentation review.

| Area | Current evidence | Remaining gate |
|---|---|---|
| Alarms | Local persistence, scheduling/edit rollback and backup-ring rules; development device use | Lock/terminated/restart/offline/time-zone/permission matrix, overlapping alarms and OS capacity |
| Challenges | Pure counter tests, native adapter/overlay tests and iterative iPhone use | Reviewed valid/invalid real movements across distances, lighting and people; measure false counts/rejections and delay |
| Camera and speech | Foreground consent/lifecycle, local processing and availability fallback | Actual permissions, microphone/voice quality, interruptions and fallback on supported/unsupported locales |
| UI/accessibility | EN/VI journeys, card/draft/sound interactions and selected large-text checks | Complete VoiceOver, narrow/accessibility text, dark appearance and reduced-motion/transparency review |
| Billing | Preview and two-plan source; many local lifecycle checks | Resolve the known expiry test failure, configure real products and validate sandbox/TestFlight lifecycle |
| Distribution/privacy | App icon and development signing implemented | Release archive, TestFlight, support/privacy links, SDK/privacy inventory and applicable account/data deletion |
| Optional services | Bundled content; source for refresh and separate synthetic/paid backend paths | Check deployed content separately; deploy/benchmark a real verifier only if it is intentionally part of release scope |

## Device acceptance

Record device, OS, source revision, expected/observed result and date for each run.
Do not mark an untried row passed.

- One-time alarms ring on the anchored date; past clock times mean tomorrow.
  Weekly alarms keep selected weekdays, including a single-day recurrence.
- Create, edit time/sound, toggle and delete an enabled alarm; failed replacement
  retains the previous schedule. Check every bundled sound with the phone locked,
  offline, with Focus and with changed Bluetooth/audio routes.
- Test lock screen, terminated app, restart, revoked permissions, clock/time-zone
  changes and overlapping alarms. One enabled alarm can consume 16 native
  registrations including backups; exercise capacity failures and visible warnings.
- System Stop/slide can silence one ring. Confirm the +2-minute backup is still
  scheduled, unresolved wake opens when the app becomes active, and successful
  completion cancels remaining backups. Do not require iOS to open the app on
  every system dismissal. “I'm awake” unlocks after five minutes and is not a
  challenge completion. Verify the finite +30-minute backup boundary.
- Use challenge-specific framing and targets from [Challenges](MODE-CHALLENGES.md),
  not one distance or three-rep rule for every exercise. Test Reach up close to
  the phone with wrists outside the image, one arm only, held arms and tracking
  loss; test whole-body challenges at usable distances separately.
- Exercise real EN/VI speech success, partial reading, silence, explicit finish,
  timeout, permission denial and background/route interruptions. Unsupported
  real-wake speech should offer Read & Choose without network recognition.
- Confirm trials keep drafts and never change a scheduled alarm or progress.
  Ask a Vietnamese speaker to review the [content checklist](../shared/content/challenges/REVIEW.md).

## Billing and service gates

The [subscription guide](SUBSCRIPTIONS.md) owns access behavior and setup.
The currently failing signed-expired-purchase test reproduces on the prior source
revision too; it remains an open gate, not a green billing result. Verify real
products, restore, renewal, cancellation, pending approval, refund/revocation,
grace and expiry before selling Pro.

The normal camera path does not upload video. The synthetic Gemini demo cannot
verify real movement. A paid Functions/Modal launch would need separate provider
runtime, privacy/consent, ownership, quota, accuracy, latency and cost evidence.
Do not make that optional experiment a prerequisite for local alarm testing.

Recheck current platform/store requirements when preparing the release archive;
historical research and successful local builds are not approval evidence.

## What we checked

[Validation](VALIDATION.md) records the latest available local results and their
scope. This review updates documentation; it does not claim a new device matrix,
cloud deployment, purchase, App Store submission or exercise benchmark.

## Read next

[Validation](VALIDATION.md) · [Subscriptions](SUBSCRIPTIONS.md) ·
[Architecture](ARCHITECTURE.md) · [Running](RUNNING.md)
