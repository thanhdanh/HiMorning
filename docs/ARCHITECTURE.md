# Architecture

HiMorning schedules alarms through iOS and checks the normal wake challenges on
the device. Optional backend experiments are separate from that local path.

**Status:** Implemented iOS pilot; reviewed against `6a1e1e7` on 22 October 2026.
**Audience:** Developers and technical reviewers.

## At a glance

[Open the current system diagram](diagrams/current-architecture.html).

| Layer | Source | Responsibility |
|---|---|---|
| UI and composition | [`HiMorningApp.swift`](../apps/ios/HiMorning/HiMorningApp.swift), [`AlarmEditor.swift`](../apps/ios/HiMorning/AlarmEditor.swift), [`ChallengeView.swift`](../apps/ios/HiMorning/ChallengeView.swift) | Draft editing, selection, practice and wake presentation |
| Pure domain | [`HiMorningCore`](../apps/ios/HiMorningCore/Sources/HiMorningCore/) | Time, journal, access, content, movement counters and coordinator rules |
| Native scheduling | [`NativeAlarmScheduler.swift`](../apps/ios/HiMorning/NativeAlarmScheduler.swift) | AlarmKit authorization, schedule, stop, cancel and inventory |
| Camera and speech | `CameraCapture`, `MovementChallengeCapture`, `GuidedRhythmCapture`, `SpeechChallengeCapture` | Foreground recognition and lifecycle control; no local challenge recording/upload |
| Persistence | `AlarmLibrary`, `WakeEnforcer`, `MorningJournal`, `PreviewStore` | Atomic JSON, backup-ring IDs, local history and Keychain preview dates |
| Content refresh | [`ChallengeContentRefresher.swift`](../apps/ios/HiMorning/ChallengeContentRefresher.swift), [`worker.ts`](../backend/worker/src/worker.ts) | Optional versioned content download with bundled/cached offline fallback |

## Follow one alarm

[Open the wake/recovery diagram](diagrams/wake-recovery.html).

1. The editor starts with the current clock time and no repeat days. The library
   anchors a one-time alarm to its next date; past times mean tomorrow. Weekly
   alarms keep their selected weekdays.
2. The library persists a pending alarm, awaits AlarmKit, then confirms it. An
   uncertain save remains visible as needing review. Native time/sound edits
   cancel and replace the registration, restoring the previous alarm if needed;
   metadata-only edits avoid unnecessary native rescheduling.
3. `WakeEnforcer` pre-schedules up to 15 backup rings at +2, +4, …, +30 minutes.
   Their IDs are persisted so later completion, disable or deletion can cancel them.
   Failed planning is surfaced on Home; finite OS capacity can limit coverage.
4. Alarm intents save a pending alarm ID and request opening the app. The system
   Stop/slide control can silence the current ring; it cannot be removed by this
   app. A dismissed system ring does not record challenge completion or cancel
   the remaining backup plan. Foreground refresh also finds unresolved wakes.
5. A completed challenge stops the native alarm and records `local_completed`.
   “I'm awake” unlocks five minutes after the occurrence and records
   `self_confirmed`. Both resolve remaining backups. Practice uses a separate
   transient alarm and neither stops a real alarm nor adds history.

System opening, sound delivery and re-ringing still need the physical-device
matrix in [release readiness](RELEASE-READINESS.md). A development install is not
proof of delivery in every lock, restart or permission state.

## Local challenges and progress

Camera adapters pass normalized joints to pure counters. The real person and
room stay in the preview; lines/face guides show current observations and disappear
when stale. Counts are heuristics, not technique, identity or liveness judgments.
The [challenge guide](MODE-CHALLENGES.md) owns framing, targets and reset behavior.

Speech recognition uses the supported on-device analyzer. Unsupported real-wake
speech falls back to Read & Choose. Content ships in the app; an optional Worker
pack can refresh it outside an active challenge, at most once per 24 hours.
Invalid/older updates do not replace the active bundled pack. Recent prompt IDs
are stored per language and content kind.

Local history stores outcome, effective mode and challenge snapshots. Editing an
alarm does not rewrite prior entries. Self-confirmation is distinct from a
completed challenge; practice is excluded. [Access rules](SUBSCRIPTIONS.md) gate
progress features without cancelling saved alarms.

## Backend experiments

| Path | Current boundary |
|---|---|
| Worker content | Public `GET`/`HEAD /content/v1/challenge-content.json`; ETag caching, no camera upload |
| Workers/Gemini demo | Firebase Auth/App Check, SQLite metadata and exact generated images only; `FirebaseCloud.isDemoOnly` prevents verified app outcomes |
| Functions/Modal | Retained async Qwen implementation; source and fixtures exist, but it is not wired into the normal local camera flow |

The retained verifier reserves quota transactionally, dispatches once, polls
without resending images and rejects late/cancelled results. Its current transport
limits live in [shared contracts](../shared/contracts/README.md), not a duplicate
budget table here. Do not deploy or enable inference merely to test a local alarm.
See [Firebase](FIREBASE.md), [free demo](FREE-REMOTE-DEMO.md) and
[remote pilot](REMOTE-PILOT.md) for separate setup and dated evidence.

## What we checked

[Validation](VALIDATION.md) separates automated checks, observed development
installs, the known StoreKit test failure and unmeasured recognition quality.
Structural graph coverage is stale/incomplete for recent code; this review used
current source and config rather than treating graph absence as missing code.

## Read next

[Running](RUNNING.md) · [Challenges](MODE-CHALLENGES.md) ·
[Release readiness](RELEASE-READINESS.md) · [Tech stack](TECH-STACK.md)
