# Alarm Enforcement Implementation Plan

> **Historical document.** This is a superseded proposal or implementation
> checkpoint, not current product behavior or instructions to execute. See the
> [current documentation](../../../README.md) and [challenge guide](../../../MODE-CHALLENGES.md).
> Original observations, limits and approvals below apply only to their dated scope.

**Goal:** A ringing alarm keeps ringing again every 2 minutes for up to 30 minutes until the challenge is finished or the delayed "I'm awake" is used, and the in-app Stop exit is gone.

**Architecture:** A pure planner (`WakePlanner`) and an actor (`WakeEnforcer`) in HiMorningCore decide and persist 15 backup AlarmKit alarms for each enabled alarm's next or live occurrence. `NativeAlarmScheduler` schedules them as fixed-date alarms. `PilotModel` re-plans after every alarm change and every resolving outcome, and on launch it opens an unresolved wake as a challenge the user can't dismiss.

**Tech Stack:** Swift 6 (HiMorningCore package), SwiftUI, AlarmKit (iOS 26.4 SDK), XCTest plus the portable harness.

**Spec:** `docs/superpowers/specs/2026-10-17-alarm-enforcement-design.md`

**Plan anchor:** commands run from the worktree root, `/Users/andyvo/Projects/HiMorning/.claude/worktrees/vibe-demo-production-issues-b37818`.

## Global Constraints

- Backup interval is 120 s and count is 15 (T+2 … T+30 min). The live window is the occurrence through occurrence + 1800 s, inclusive.
- "I'm awake" unlocks at occurrence + 300 s. In practice mode it unlocks 300 s after the view opens.
- Resolving outcomes are `.localCompleted`, `.selfConfirmed`, `.openaiVerified` and `.aiVerified`. `.dismissed` never resolves a wake.
- New user-facing copy ships in `apps/ios/Resources/en.lproj/Localizable.strings` and `vi.lproj/Localizable.strings` in the same task.
- Every new core test file is also registered in `apps/ios/HiMorningCore/TestsPortable/main.swift`.
- Swift and Xcode commands must run **outside the Bash sandbox**, because the sandbox blocks the per-user temp directory. Run them with sandbox disabled.
- **Do not commit.** The repo's AppSec hook blocks commits to this remote until the owner fixes the org. Each task ends with a `git status --short` checkpoint instead.
- Follow `~/.claude/CLAUDE.md` comment policy: no comments unless they state a non-obvious why or a warning.

## Review Focus

1. A one-time alarm that the system removed after Stop is `enabled` with state `.needsReview`. Its live occurrence must keep its backups, but no future backups may be planned for it (Task 1 test `testOneTimeAlarmWithoutConfirmedScheduleGetsNoFutureBackups`).
2. A device clock or time zone change mid-window. The planner works only from `now` and `AlarmTime.next(after:)`, so a jump forward past the window must end the wake rather than crash (Task 1 test `testWindowEdges`).
3. Two alarms whose windows overlap. `unresolvedWake` returns the earliest occurrence, and resolving it must not cancel the other alarm's rings (Task 2 test `testResolveCancelsOnlyThatAlarmsRings`).
4. Relaunching the app during a live wake must not re-create rings that are already scheduled (Task 2 test `testPlanIsIdempotentAcrossRestart`).
5. The scheduler failing part-way (device limit). Rings already scheduled stay persisted, and the warning flag is set (Task 2 test `testScheduleFailureKeepsEarlierRingsAndReportsLimited`).

---

### Task 1: `WakePlanner` (pure planning rules)

**Files:**
- Create: `apps/ios/HiMorningCore/Sources/HiMorningCore/WakeEnforcement.swift`
- Create: `apps/ios/HiMorningCore/Tests/HiMorningCoreTests/WakeEnforcementTests.swift`
- Modify: `apps/ios/HiMorningCore/TestsPortable/main.swift` (register the tests next to the `PushUpTests` block near line 215)

**Interfaces:**
- Consumes: `SavedAlarm` (Pilot.swift:9), `AlarmTime.next(after:calendar:)` (Module.swift:21), `MorningEntry` (Morning.swift:54; `alarmID`, `date`, `outcome`), `WakeOutcome` (Module.swift:26).
- Produces:
  - `public struct BackupRing: Codable, Equatable, Sendable { public let id: UUID; public let alarmID: UUID; public let occurrence: Date; public let fireDate: Date }`
  - `public enum WakeEnforcementPolicy { public static let backupInterval: TimeInterval = 120; public static let backupCount = 15; public static let window: TimeInterval = 1800; public static let selfConfirmDelay: TimeInterval = 300 }`
  - `public struct UnresolvedWake: Equatable, Sendable { public let alarmID: UUID; public let occurrence: Date; public var selfConfirmAvailableAt: Date { occurrence + WakeEnforcementPolicy.selfConfirmDelay } }`
  - `public enum WakePlanner`:
    - `static func liveOccurrence(of alarm: SavedAlarm, entries: [MorningEntry], now: Date, calendar: Calendar) -> Date?` returns `o = alarm.time.next(after: now - window - 1)` when `o <= now`, `now <= o + window`, `alarm.enabled`, and no entry has `alarmID == alarm.id`, `date >= o` and a resolving outcome.
    - `static func plannedOccurrence(of alarm: SavedAlarm, entries: [MorningEntry], now: Date, calendar: Calendar) -> Date?` returns the live occurrence if there is one. Otherwise it returns `alarm.time.next(after: now)` only when `alarm.enabled && alarm.state == .confirmed`, else nil.
    - `static func fireDates(for occurrence: Date) -> [Date]` returns `(1...15).map { occurrence + Double($0) * 120 }`.
    - `static func unresolvedWake(alarms: [SavedAlarm], entries: [MorningEntry], now: Date, calendar: Calendar) -> UnresolvedWake?` returns the earliest live occurrence.
    - `static func resolves(_ outcome: WakeOutcome) -> Bool`

- [ ] **Step 1: Write the failing tests** in `WakeEnforcementTests.swift` (class `WakeEnforcementTests: XCTestCase`, same `#if !PORTABLE_TESTS` header as PushUpTests.swift:1-5). Use `Calendar(identifier: .gregorian)` with `TimeZone(identifier: "Asia/Ho_Chi_Minh")`, and a one-time alarm at 06:30 whose first occurrence is `o`.
  - `testFireDatesAreFifteenRingsTwoMinutesApart`: count is 15, the first is `o+120`, the last is `o+1800`, and each gap is 120.
  - `testWindowEdges`: `liveOccurrence` is nil at `o-1`, equals `o` at `o` and at `o+1800`, and is nil at `o+1801`.
  - `testResolvingOutcomeEndsTheWakeButDismissedDoesNot`: an entry with `.localCompleted` at `o+60` makes it nil. Repeat for `.selfConfirmed`. An entry with `.dismissed` at `o+60` keeps `o`. An entry with `.localCompleted` at `o-60`, i.e. yesterday's, keeps `o`.
  - `testSelfConfirmAvailableFiveMinutesAfterFirstRing`: `unresolvedWake(...).selfConfirmAvailableAt == o+300`.
  - `testOneTimeAlarmWithoutConfirmedScheduleGetsNoFutureBackups`: with state `.needsReview`, `plannedOccurrence` at `o+60` is `o`, and at `o+1801` it is nil.
  - `testEarliestOverlappingWakeWins`: alarms at 06:30 and 06:40 at time 06:45 give `unresolvedWake.alarmID ==` the 06:30 alarm.

- [ ] **Step 2: Run to verify they fail**
Run: `swift test --package-path apps/ios/HiMorningCore --filter WakeEnforcementTests`
Expected: build failure, `cannot find 'WakePlanner' in scope`.

- [ ] **Step 3: Implement the `Produces` types in `WakeEnforcement.swift`.**

- [ ] **Step 4: Run to verify they pass**
Run the same command. Expected: `Executed 6 tests, with 0 failures`. Then run `sh scripts/test-swift.sh`. Expected: last line `PASS: shared Swift core tests and portable integration journeys`.

- [ ] **Step 5: Checkpoint.** `git status --short` lists only the three files above.

### Task 2: `WakeEnforcer` (schedule, cancel, persist rings)

**Files:**
- Modify: `apps/ios/HiMorningCore/Sources/HiMorningCore/WakeEnforcement.swift`
- Modify: `apps/ios/HiMorningCore/Tests/HiMorningCoreTests/WakeEnforcementTests.swift`
- Modify: `apps/ios/HiMorningCore/TestsPortable/main.swift`

**Interfaces:**
- Consumes: Task 1 types.
- Produces:
  - `public protocol BackupRingScheduler: Sendable { func scheduleBackup(_ ring: BackupRing, for alarm: SavedAlarm) async throws; func cancel(id: UUID) async throws }`. This is a separate protocol so the eight existing `AlarmScheduler` mocks stay unchanged.
  - `public protocol BackupRingPersistence: Sendable { func load() throws -> [BackupRing]; func save(_ rings: [BackupRing]) throws }`
  - `public struct FileBackupRingPersistence: BackupRingPersistence`, mirroring `FileAlarmPersistence` (Pilot.swift:46-57).
  - `public struct WakePlanResult: Equatable, Sendable { public let scheduled: Int; public let limited: Bool }`
  - `public actor WakeEnforcer`:
    - `init(persistence: any BackupRingPersistence, scheduler: any BackupRingScheduler) throws`
    - `func rings() -> [BackupRing]`
    - `@discardableResult func plan(alarms: [SavedAlarm], entries: [MorningEntry], now: Date, calendar: Calendar) async -> WakePlanResult`
    - `func resolve(alarmID: UUID) async`

`plan` algorithm:
1. Desired set: for each alarm, take `plannedOccurrence`, then each fire date in `fireDates` that is `> now`, giving `(alarmID, occurrence, fireDate)`. Sort ascending by `occurrence`, then `fireDate`.
2. Cancel and drop every stored ring with no desired match on `(alarmID, occurrence, fireDate)`. Errors from `cancel` are ignored, because the ring may already have fired.
3. Schedule each desired entry not already stored as a `BackupRing` with a new `UUID()`, in sorted order. On the first thrown error, stop and set `limited = true`.
4. Save after each successful schedule, so a crash never loses track of a scheduled ring.

`resolve` cancels and drops every stored ring with that `alarmID`.

- [ ] **Step 1: Write the failing tests.** Use a test-local `actor RingSchedulerSpy: BackupRingScheduler` that records scheduled and cancelled ids and can be told `failAfter(n)`, plus `FileBackupRingPersistence` on a temp file.
  - `testPlanSchedulesFifteenRingsForNextConfirmedOccurrence`: one confirmed weekly alarm gives 15 scheduled rings, `rings()` has 15, and `result == WakePlanResult(scheduled: 15, limited: false)`.
  - `testPlanIsIdempotentAcrossRestart`: plan, create a new `WakeEnforcer` on the same file, plan again at the same `now`, and the spy count stays 15.
  - `testDisablingAlarmCancelsItsRings`: plan, set `enabled = false`, plan, and the spy cancelled all 15 and `rings()` is empty.
  - `testResolveCancelsOnlyThatAlarmsRings`: two alarms, `resolve(alarmID: a)`, and only `a`'s 15 are cancelled while 15 remain.
  - `testLiveWakeKeepsRemainingRingsOnly`: plan at `o-60`, then plan again at `o+300` with no entries, and `rings().count == 13`. The fire dates `o+120` and `o+240` are now in the past and are dropped; nothing is re-scheduled.
  - `testScheduleFailureKeepsEarlierRingsAndReportsLimited`: `failAfter(20)` with two alarms gives `limited == true`, `rings().count == 20`, and all 15 of the earlier occurrence are present.

- [ ] **Step 2: Run to verify they fail**
Run: `swift test --package-path apps/ios/HiMorningCore --filter WakeEnforcementTests`
Expected: build failure, `cannot find 'WakeEnforcer' in scope`.

- [ ] **Step 3: Implement the `Produces` types.**

- [ ] **Step 4: Run to verify they pass**
Run the same command, expecting `Executed 12 tests, with 0 failures`. Then run `sh scripts/test-swift.sh`, expecting the PASS line.

- [ ] **Step 5: Checkpoint.** `git status --short` lists only the Task 1 and Task 2 files.

### Task 3: AlarmKit backup rings and stop intent

**Files:**
- Modify: `apps/ios/HiMorning/NativeAlarmScheduler.swift`

**Interfaces:**
- Consumes: `BackupRingScheduler`, `BackupRing` (Task 2).
- Produces: `extension NativeAlarmScheduler: BackupRingScheduler`. The existing `cancel(id:)` satisfies the protocol's cancel.

- [ ] **Step 1: Refactor `schedule(_:)`.** Move the attributes and sound construction into `private func attributes(for alarm: SavedAlarm) -> AlarmAttributes<MorningMetadata>` and `private func sound(for alarm: SavedAlarm) -> AlertConfiguration.AlertSound`. Switch the alert to `AlarmPresentation.Alert(title:secondaryButton:secondaryButtonBehavior:)`, because the `stopButton:` initializer is deprecated in iOS 26.1 and the system owns Stop. Delete the now-unused `stopButton` constant and its comment.

- [ ] **Step 2: Pass `stopIntent: OpenMorningIntent(id: alarm.id)`** to `.alarm(schedule:attributes:stopIntent:secondaryIntent:sound:)` for the main alarm. This is best-effort: it writes `pendingAlarmID` and opens the app (ledger L2).

- [ ] **Step 3: Implement `func scheduleBackup(_ ring: BackupRing, for alarm: SavedAlarm) async throws`.** Require authorization like `schedule`, then call `manager.schedule(id: ring.id, configuration: .alarm(schedule: .fixed(ring.fireDate), attributes: attributes(for: alarm), stopIntent: OpenMorningIntent(id: alarm.id), secondaryIntent: OpenMorningIntent(id: alarm.id), sound: sound(for: alarm)))`.

- [ ] **Step 4: Verify.** Build the app target if `xcodegen` is available (see Task 5 Step 5). Otherwise record "app build not run: xcodegen missing" in the task report. Do not install it without the owner's approval.

- [ ] **Step 5: Checkpoint.** `git status --short`.

### Task 4: Wire enforcement into `PilotModel` and `ChallengeView`

**Files:**
- Modify: `apps/ios/HiMorning/HiMorningApp.swift`
  - `PilotModel` stored properties near line 24.
  - `init` near line 53, where `library` is created.
  - `recordMorning` at :98-102.
  - `refresh` at :108-122.
  - `save`, `toggle` and `remove` at :123-157.
  - `openPending` at :158-161.
  - The `.fullScreenCover` at :306.
  - The Home list, where the warning is added.
- Modify: `apps/ios/HiMorning/ChallengeView.swift`
  - `awakeAvailableAt` at :42.
  - The UI-test overrides at :201-202.
  - The Stop button at :164-166.
- Modify: `apps/ios/Resources/en.lproj/Localizable.strings` and `apps/ios/Resources/vi.lproj/Localizable.strings`
- Modify: `apps/ios/HiMorningUITests/ChallengeCelebrationUITests.swift:174-178`

**Interfaces:**
- Consumes: `WakeEnforcer`, `WakePlanner.unresolvedWake`, `UnresolvedWake`, `FileBackupRingPersistence` (Tasks 1-2), `NativeAlarmScheduler: BackupRingScheduler` (Task 3).
- Produces:
  - `PilotModel.enforcer: WakeEnforcer?`, created next to `library` with `FileBackupRingPersistence(url: <Application Support>/backup-rings.json)`.
  - `@Published var backupWarning = false`
  - `@Published var activeWake: UnresolvedWake?`
  - `func replanBackups() async`

Steps:
- [ ] **Step 1: `replanBackups()`.** It calls `enforcer.plan(alarms: alarms, entries: journal?.recent(days: 2) ?? [], now: Date(), calendar: .current)` and sets `backupWarning = result.limited`. Call it at the end of `refresh()` (after `alarms` is loaded, before `openPending()`), and at the end of `save`, `toggle` and `remove`.

- [ ] **Step 2: `recordMorning`.** When `!rehearsal && WakePlanner.resolves(outcome)`, start `Task { await enforcer?.resolve(alarmID: alarm.id); await replanBackups() }` and set `activeWake = nil`.

- [ ] **Step 3: Open the unresolved wake.** At the end of `refresh()`, after `openPending()`: if `selected == nil`, compute `WakePlanner.unresolvedWake(alarms:entries:now:calendar:)`. If it matches an alarm, set `activeWake`, `rehearsal = false` and `selected = alarm`. `openPending()` also sets `activeWake` when its alarm has a live occurrence.

- [ ] **Step 4: `ChallengeView`.**
  - Initialize `awakeAvailableAt` from `model.activeWake?.selfConfirmAvailableAt ?? Date().addingTimeInterval(WakeEnforcementPolicy.selfConfirmDelay)` in the existing setup, near the `coordinator` creation at :187-190. Keep the `--ui-awake-ready` and `--ui-awake-countdown-near-end` overrides.
  - Delete the `else` branch that renders the "Stop alarm" button (`accessibilityIdentifier("stopAlarm")`). Practice keeps its "Back to home".
  - Add `.interactiveDismissDisabled(!practicing)` to the root view.

- [ ] **Step 5: Home warning.** When `model.backupWarning` is true, show `Text(appText("Some backup rings could not be set."))` as `.footnote` in `MorningTheme.muted` under the alarm list. Add strings: en `"Some backup rings could not be set." = "Some backup rings could not be set.";` and vi `"Some backup rings could not be set." = "Một số lần báo lại chưa được đặt.";`. Remove the now-unused `"Stop alarm"` keys from both files only if `grep -rn '"Stop alarm"' apps/ios/HiMorning` finds no other use.

- [ ] **Step 6: Update the UI test.** In `ChallengeCelebrationUITests.swift:177`, change the assertion to `awake.label.contains("Available in 4:") || awake.label.contains("Available in 5:00")`. In the same test, add `XCTAssertFalse(app.buttons["stopAlarm"].exists)`.

- [ ] **Step 7: Verify.**
  - Run `pnpm test tests/localization.test.ts`, expecting all pass. Run `sh scripts/test-swift.sh`, expecting the PASS line.
  - App build and UI test only if `xcodegen` exists: `xcodegen generate --spec apps/ios/project.yml && xcodebuild test -project apps/ios/HiMorning.xcodeproj -scheme HiMorning -destination "platform=iOS Simulator,name=<first iPhone from xcrun simctl list devices available>" -only-testing:HiMorningUITests/ChallengeCelebrationUITests/testAwakeConfirmationCountsDownBeforeEnabling`, expecting `** TEST SUCCEEDED **`. Otherwise report it as not run (ledger L8).

- [ ] **Step 8: Checkpoint.** `git status --short`.

### Task 5: Docs and device acceptance checklist

**Files:**
- Modify: `docs/ARCHITECTURE.md:86-100,143`, `docs/BUSINESS-MODEL.md:52,66`, `docs/UI-DESIGN.md:70` and `docs/RELEASE-READINESS.md`

- [ ] **Step 1: Replace each "Stop stays available / dismissal is a recovery exit" statement** with the enforcement behavior from the spec's "At a glance" table, two to four sentences each.
- [ ] **Step 2: In RELEASE-READINESS.md, add an unchecked device item:** "Tap system Stop on the lock screen; a backup ring sounds 2 min later; finishing the challenge silences all remaining rings (ledger L2, L6)."
- [ ] **Step 3: Verify.** `grep -rn "Stop action stays available\|recovery exit" docs` returns only lines that now describe "I'm awake".
- [ ] **Step 4: Checkpoint.** `git status --short`.
