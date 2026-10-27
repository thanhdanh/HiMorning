# Android architecture

Build and validate HiMorning's native Android alarm and local challenge experience.
Android reuses the iOS product rules and curated content while owning its platform
permissions, camera pipeline and background delivery.

**Status:** Development implementation. **Audience:** Android maintainers.

## At a glance

| Layer | Source | Responsibility |
|---|---|---|
| UI/composition | `MainActivity.kt`, `ui/` | Custom warm palette/cards, scoped composer, home-to-sheet navigation, practice and permission recovery |
| Pure domain | `core/Models.kt` | Alarm time/repeat rules, wake session, speech word matching and journey progression |
| Local data | `core/AndroidRepository.kt` | Atomic JSON transactions shared across service, receivers and UI; fail-closed decode |
| Content | `core/ContentCatalog.kt`, `assets/` | Same reviewed bilingual prompt pack as iOS, available offline |
| Alarms | `platform/` | AlarmManager, receivers, foreground audio, snooze and occurrence recovery |
| Local sensing | `platform/` | CameraX with on-device ML Kit landmarks and Android on-device speech |

One application module keeps the initial project small. Domain rules do not import
Android APIs. Android persistence/adapters stay outside the pure model file.
Existing Swift source and server implementations remain intact.

## How it works

Saving preflights exact-alarm access, writes pending intent, then schedules an
exact `setAlarmClock` occurrence and confirms durable state. A failed save restores
the previous per-alarm settings; uncertain native registration remains visibly
`NEEDS_REVIEW`. Receivers validate enabled alarm IDs and
expected occurrences. A foreground service plays the selected alarm with alarm
audio attributes. Reboot/time-zone changes rebuild valid schedules; expired
one-time occurrences do not silently become tomorrow's alarms.

Challenges use real landmark cycles, correct content answers or recognized speech.
The 156-item reviewed English/Vietnamese content pack is copied from the iOS bundle.
Practice does not write progress. Recorded outcomes distinguish successful local
challenge completion, self-confirmation and dismissal. A seven-morning journey
counts at most one successful local day.

The first successfully scheduled alarm starts a 30-day preview. Expiry changes the
effective mode/sound/rep limit while keeping saved choices. Stop, snooze and
recovery do not depend on network access, camera permission or purchases.

## Key choices

- Native Kotlin/Compose follows the existing platform boundary instead of rewriting
  iOS or adding a shared runtime.
- Camera frames and speech remain on this device; unavailable on-device speech has
  an offline reading fallback. No video or audio archive is created.
- Alarm access, notifications and full-screen presentation are separate Android
  permissions. The UI shows unfinished setup and requests camera/microphone access
  only for the matching activity.
- Play purchases and cloud verification are disabled until Android production
  configuration exists. The current verifier authenticates the iOS App Check app
  ID; client code must not bypass that check or reuse iOS credentials.

## Try it

See the [Android README](../apps/android/README.md) for JDK/SDK setup, Gradle commands
and installation. Exact build/test and emulator results live in the
[implementation evidence](ANDROID-IMPLEMENTATION.md).

## What we checked

Domain tests cover time validation, daylight-saving gaps/overlaps, stale completion,
snooze budgets, speech matching, journey days and the shared wake-mode fixture.
Instrumented storage tests cover cross-instance updates, corruption preservation
and interrupted-write recovery. Build/test execution results are recorded separately
from implemented test cases in the [evidence guide](ANDROID-IMPLEMENTATION.md).

## Limits and next steps

Android hardware/OEM power policy needs physical-device testing. Emulator builds
cannot establish camera calibration, real locked-device alarm reliability or signed
Google Play readiness. Play product IDs and Android Firebase/App Check registration
need external configuration before those integrations can be implemented and tested.

Use [Android alarm guidance](https://developer.android.com/develop/background-work/services/alarms)
and [CameraX releases](https://developer.android.com/jetpack/androidx/releases/camera)
when changing native integration; Apple AlarmKit tests do not validate Android.

## Read next

[Build/run](../apps/android/README.md) · [Implementation](ANDROID-IMPLEMENTATION.md) ·
[Shared contracts](../shared/contracts/README.md) · [Architecture](ARCHITECTURE.md)
