# Adding Android when the pilot is ready

Android should reuse HiMorning's service and product rules while owning its alarm,
camera and lifecycle behavior. Keeping those boundaries clear now makes the later
port smaller and easier to test.

**Status:** Folder, contracts and extension plan are in place. There is no Android
implementation, build or device validation yet.

## What can be reused?

| Reuse directly | Port and test | Implement for Android |
|---|---|---|
| Firebase callables and server policies | Alarm/challenge state machine | Compose screens and English/Vietnamese resources |
| JSON Schema and wire fixtures | Wake-mode presets and stop races | AlarmManager, receivers and audio |
| Consent version and evidence limits | Journal/reconciliation behavior | CameraX and a separately evaluated pose pipeline |
| Reviewed outcome/cue meanings | Ordered capture-cycle selection | Auth, Functions and Play Integrity App Check adapters |

Swift source stays in `apps/ios`. TypeScript stays on the server. The small shared
JSON fixtures describe agreement between implementations; they do not make Swift
or TypeScript run on Android.

## Suggested Kotlin boundaries

```text
apps/android/                 # future Gradle root
  app/                        # Compose, navigation and composition root
  core/domain/                # rules and state; no Android/Firebase imports
  core/data/                  # local journal and repositories
  platform/alarm/             # AlarmManager, receivers and sound
  platform/camera/            # CameraX, pose adapter and bounded evidence
  platform/cloud/             # Firebase SDK and wire mapping
  feature/alarm/              # home and alarm editor
  feature/challenge/          # consent, capture and recovery UI
```

This is a proposed layout, not an empty set of Gradle modules to maintain today.
Start with a few packages and split modules when dependency control or build time
makes that useful.

| Domain port | Existing iOS example | Android responsibility |
|---|---|---|
| Alarm scheduler | `AlarmScheduler` | Schedule/cancel/stop and report uncertain registrations |
| Alarm persistence | `AlarmPersistence` | Durable pending writes and restart recovery |
| Cloud verifier | `CloudVerification` | Map shared payloads through Firebase callable SDK |
| Movement / evidence | `PushUpCounter`, `CycleCapture` | Distinguish local completion from server-verified evidence |

Keep the composition root responsible for wiring adapters into domain rules.
Never require a network request or camera permission to stop a local alarm.

## Build the port in this order

1. Decode/encode `shared/contracts/v1/wire-fixtures.json` in Kotlin. Accept additive
   response fields; reject unknown completion statuses. Check wake-mode fixtures.
2. Port pure time validation, outcome state and cancellation-generation tests.
3. Add persistence and fake scheduler tests, then the actual alarm adapter.
4. Test permissions, process death, restart, time-zone changes and battery modes.
5. Add the local challenge flow, then consented camera/cloud integration.
6. Review both languages, TalkBack, text scaling,
   shared rooms and sound comfort with Vietnamese and English-speaking users.

Android exact alarms have their own permission and scheduling rules. Review
[Android's alarm guidance](https://developer.android.com/develop/background-work/services/alarms)
when choosing `setAlarmClock` and recovery behavior. Use [CameraX](https://developer.android.com/jetpack/androidx/releases/camera)
as the camera integration candidate; evaluate the pose estimator separately.
Apple AlarmKit tests do not establish Android reliability.

## Decisions and trade-offs

We keep native apps and a shared service. This preserves direct platform access and
avoids rewriting the tested iOS pilot. The cost is two client implementations and
explicit parity tests. A Flutter, React Native or Kotlin Multiplatform rewrite is
not needed to establish these boundaries; revisit shared runtime code after the
Android prototype exposes real duplication.

[Architecture](ARCHITECTURE.md) · [Contracts](../shared/contracts/README.md) · [Setup](RUNNING.md)
