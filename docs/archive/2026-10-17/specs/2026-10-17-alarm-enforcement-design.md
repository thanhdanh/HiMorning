# Alarm enforcement

> **Historical document.** This is a superseded proposal or implementation
> checkpoint, not current product behavior or instructions to execute. See the
> [current documentation](../../../README.md) and [challenge guide](../../../MODE-CHALLENGES.md).
> Original observations, limits and approvals below apply only to their dated scope.

Make a ringing HiMorning alarm stop for good only when the wake challenge is finished, or when the user uses the delayed "I'm awake" recovery exit.

**Original status:** Planned when approved on 17 October 2026. **Audience:** iOS developers working on scheduling, `ChallengeView` and `ChallengeCoordinator`.

## At a glance

| Exit today | Today | After this change |
| --- | --- | --- |
| System Stop on the AlarmKit alert | Ends the alarm, app never runs | Alarm rings again every 2 min for up to 30 min |
| In-app "Stop alarm" (`ChallengeView.swift:165`) | Ends the alarm, logs `.dismissed` | Removed |
| In-app "I'm awake" (`ChallengeView.swift:154`) | Enabled after 120 s | Enabled 5 min after the first ring; cancels the backups; logged `.selfConfirmed`, not counted as completed |
| Finished challenge | Stops the alarm | Stops the alarm and cancels every backup |

AlarmKit requires a system Stop button on `AlarmPresentation.Alert`, and no API hides or redirects it (unverified, ledger L1). So enforcement re-rings instead of blocking Stop.

## How it works

1. When `PilotModel` schedules an enabled alarm, `WakeEnforcement` (new, HiMorningCore) also plans 15 one-shot backup alarms for that alarm's next occurrence, at T+2, T+4 … T+30 min. Each backup has the same sound, the same "Open HiMorning" secondary button. Each backup gets a fresh UUID, and `WakeEnforcer` persists every backup to `backup-rings.json` (alarm id, occurrence, fire date), so backups can be found and cancelled after a relaunch.
2. The main alarm and each backup carry `OpenMorningIntent` as their `stopIntent`. It writes a `PendingWake` record (alarm id, occurrence date) to `UserDefaults`, as `OpenMorningIntent` does today and asks to open the app. This is best-effort: a reported iOS 26.2 bug can skip it (ledger L2). The pre-scheduled backups are what make enforcement work.
3. On app launch or foreground, `PilotModel.refresh()` asks `WakeEnforcement` for an unresolved wake. One is unresolved when now is between the occurrence time and its last backup, and no completion or self-confirm is journaled for it. If there is one, `ChallengeView` opens as a full-screen cover with `interactiveDismissDisabled(true)`, and no in-app Stop button is shown.
4. When the challenge finishes, `ChallengeCoordinator` stops the main alarm and cancels all remaining backups. It then re-plans backups for the next occurrence. "I'm awake" does the same, and is logged `.selfConfirmed`.
5. When an alarm is edited, disabled or deleted, its backups are cancelled and, if it is still enabled, re-planned.

`WakeEnforcement` is a pure value type. Given the alarms, `now`, a calendar and the journal, it returns the backup plan and the unresolved wake. Only `NativeAlarmScheduler` touches AlarmKit.

## Key choices

- **Pre-schedule instead of scheduling at Stop time.** The app is usually not running when the alarm fires, and `stopIntent` is not reliable. Pre-scheduled backups ring even if no app code runs.
- **Plan only the next occurrence.** This bounds the alarm count to 16 per enabled alarm. The device limit is unverified (ledger L6). If `maximumLimitReached` is thrown, the planner keeps the main alarms and drops backups from the latest occurrences first. The home screen then shows "Some backup rings could not be set." in English and Vietnamese.
- **Bounded at 30 minutes.** A phone left at home must not ring all day.
- **Keep "I'm awake".** A delayed recovery exit avoids an App Review 2.5.9 concern and keeps a way out for real emergencies. It moves from 120 s to 5 min.
- **Docs that change.** BUSINESS-MODEL.md, UI-DESIGN.md and ARCHITECTURE.md currently promise an always-available Stop. They are updated to describe this design.

## What we will check

- Core unit tests for `WakeEnforcement`: backup offsets and ids, unresolved-wake detection at the window edges, cancel on completion and self-confirm, re-plan after edit or disable, and limit fallback ordering.
- Core tests for `ChallengeCoordinator` with the mock scheduler: completion cancels all backups, and self-confirm before 5 min is rejected.
- A UI test where launching with an unresolved wake presents a challenge that cannot be dismissed and has no Stop button.
- Device-only, recorded in RELEASE-READINESS.md: tap system Stop on the lock screen and confirm a ring 2 min later (L1, L2, L6).

## Limits and next steps

- Ledger L1, L2 and L6 need a physical iOS 26 device.
- Out of scope for now: journaling a wake whose 30-min window passed with no completion as a new `.missed` outcome.
