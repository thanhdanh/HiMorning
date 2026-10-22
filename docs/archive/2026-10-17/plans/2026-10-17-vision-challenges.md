# Reliable Camera Challenges Implementation Plan

> **Historical document.** This is a superseded proposal or implementation
> checkpoint, not current product behavior or instructions to execute. See the
> [current documentation](../../../README.md) and [challenge guide](../../../MODE-CHALLENGES.md).
> Original observations, limits and approvals below apply only to their dated scope.

**Goal:** Wave hello, neck turn, push-up, guided rhythm and jumping jacks count correctly from the iPhone front camera. Full-body challenges must also be usable from about 2 m away.

**Architecture:** Counting moves into pure, time-based counters in HiMorningCore: `OneEuroFilter`, `WaveCounter`, `NeckTurnCounter`, the reworked `PushUpCounter` and `GuidedRhythmSession`, and `BodyFraming`. Each one is replay-tested at 33 ms and 133 ms sample spacing. The capture classes only map Vision observations to samples, now on every frame. A `VoiceCoach` and a large-type layout in `ChallengeView` give spoken and visual guidance.

**Tech Stack:** Swift 6, Vision (`VNDetectHumanHandPoseRequest`, `VNDetectFaceRectanglesRequest`, `VNDetectHumanBodyPoseRequest`), AVFoundation, SwiftUI, XCTest plus the portable harness.

**Spec:** `docs/superpowers/specs/2026-10-17-vision-challenges-design.md`

**Plan anchor:** commands run from the worktree root, `/Users/andyvo/Projects/HiMorning/.claude/worktrees/vibe-demo-production-issues-b37818`.

## Global Constraints

- All thresholds are in milliseconds or physical units, never frame counts:
  - Loss grace is 600 ms for wave, neck-at-centre, push-up and rhythm.
  - Pose hold is 150 ms for neck and rhythm.
  - The wave pair window is 2000 ms.
  - The neck "held turn" during face loss lasts 1500 ms.
- `OneEuroFilter` parameters:
  - Wave: `minCutoff: 1.0, beta: 0.3, derivativeCutoff: 1.0`.
  - Neck: `minCutoff: 1.0, beta: 0.05, derivativeCutoff: 1.0`.
- New user-facing and spoken copy ships in both `apps/ios/Resources/en.lproj/Localizable.strings` and `vi.lproj/Localizable.strings` in the same task.
- Every new core test is registered in `apps/ios/HiMorningCore/TestsPortable/main.swift`, and every deleted test is unregistered there.
- Swift and Xcode commands must run **outside the Bash sandbox**, because it blocks the per-user temp directory.
- **Do not commit.** The repo-org commit hook blocks this remote. Each task ends with a `git status --short` checkpoint.
- Comment policy from `~/.claude/CLAUDE.md`: no comments unless they give a non-obvious why or a warning. Delete the `// shortcut: 4% frame travel…` comment along with `WaveHandMotion`.

## Review Focus

1. A small, fast wave at 4 Hz. At 33 ms sampling it must still count. At 133 ms it may not, and the test documents that limit (Task 2, `testFourHertzWaveAtThirtyFramesCounts`).
2. A user who turns right first, or turns only one way. Right-first must count. Repeating one side must never count (Task 3).
3. The face disappears at a full turn and comes back facing the centre. This completes the turn (Task 3, `testFaceLostAtFullTurnStillCompletesOnReturn`).
4. A push-up descent fast enough to skip the 100–150° band entirely. It must count (Task 4).
5. A person standing so close that the ankles are cut off at the frame edge. The hint must say "step back", not "show your feet" (Task 6, `testCutOffAtBottomEdgeSaysStepBack`).

---

### Task 1: `OneEuroFilter`

**Files:**
- Modify: `apps/ios/HiMorningCore/Sources/HiMorningCore/SignalSmoothing.swift`
- Create: `apps/ios/HiMorningCore/Tests/HiMorningCoreTests/MotionCounterTests.swift` (class `MotionCounterTests`, using the PushUpTests.swift:1-5 header)
- Modify: `apps/ios/HiMorningCore/TestsPortable/main.swift`

**Interfaces:**
- Produces: `public struct OneEuroFilter: Sendable { public init(minCutoff: Double, beta: Double, derivativeCutoff: Double = 1.0); public mutating func filter(_ value: Double, timestampMs: Int) -> Double; public mutating func reset() }`. This is the standard Casiez 1€ filter. A non-finite value resets the filter and returns `.nan`. A timestamp that is not later than the previous one returns the previous output unchanged.

- [ ] **Step 1: Write the failing tests:**
  - `testOneEuroPassesConstantSignalUnchanged`
  - `testOneEuroSuppressesJitterAtRest`: alternate ±1.0 every 33 ms for 2 s. The max |output| over the last second is < 0.5.
  - `testOneEuroBetaReducesLagOnFastRamp`: ramp 0→10 over 300 ms at 33 ms. The final output with `beta: 0.3` is greater than with `beta: 0`.
  - `testOneEuroResetsOnNonFinite`: output is nan, and the next value is returned as-is.
- [ ] **Step 2: Run** `swift test --package-path apps/ios/HiMorningCore --filter MotionCounterTests`. Expected: build failure, `cannot find 'OneEuroFilter'`.
- [ ] **Step 3: Implement `OneEuroFilter` in `SignalSmoothing.swift`.**
- [ ] **Step 4: Run** the same command, expecting `Executed 4 tests, with 0 failures`. Then run `sh scripts/test-swift.sh`, expecting the `PASS:` line.
- [ ] **Step 5: Checkpoint.** Run `git status --short`.

### Task 2: `WaveCounter` replaces `WaveHandMotion`

**Files:**
- Modify: `apps/ios/HiMorningCore/Sources/HiMorningCore/Movement.swift`:
  - Delete `WaveHandMotion` (:13-34).
  - Delete the `.wave` case from `MovementObservation`.
  - Delete the wave branches in `MovementChallengeProgress` (:79-89, :99-100 and the `.waveHand` case in `consume`).
  - Delete `lastWaveDirection`, `waveReversals` and `lastWaveChange`.
- Modify: `apps/ios/HiMorningCore/Tests/HiMorningCoreTests/CoreTests.swift`. Delete `testWaveHandAccumulatesSparseCameraMotionAndCountsReversals` (:185-197) and unregister it in `main.swift`.
- Modify: `MotionCounterTests.swift` and `main.swift`

**Interfaces:**
- Consumes: `OneEuroFilter` (Task 1).
- Produces: `public struct WaveCounter: Sendable { public init(target: Int); public private(set) var completed: Int; public var ready: Bool; @discardableResult public mutating func observe(centerX: Double, handWidth: Double, timestampMs: Int) -> Int; public mutating func observeLoss(timestampMs: Int); public mutating func reset() }`

Algorithm:
- The tracked signal is `u = filter(centerX / handWidth)`, measured in hand widths. When `handWidth <= 0` or a value is non-finite, treat the sample as a loss.
- Track the running extreme of `u` in the current direction. A **swing** happens when `u` moves back from that extreme by at least `0.35`. On a swing, the direction flips and the extreme resets to `u`. The first swing from rest counts too.
- Two swings whose timestamps are at most 2000 ms apart make one rep. A pending swing older than 2000 ms is replaced by the new one.
- Loss handling: losses that add up to no more than 600 ms keep all state. Past 600 ms, clear the extreme, the direction, the pending swing and the filter. `completed` is kept.

- [ ] **Step 1: Write the failing tests.** Use a helper `wave(hz:, amplitude:, spacingMs:, durationMs:)` that feeds `centerX = 100 + amplitude*100*sin(2πft)` with `handWidth = 100`.
  - `testTwoHertzWaveCountsAtThirtyAndSevenFramesPerSecond`: 2 Hz, amplitude 1.0, 3 s, target 3. `ready` at spacing 33 and at spacing 133.
  - `testFourHertzWaveAtThirtyFramesCounts`: 4 Hz, amplitude 0.6, 2 s, target 3, spacing 33. Expect `ready`.
  - `testJitterNeverCounts`: ±0.1 hand widths alternating every 33 ms for 5 s. Expect `completed == 0`.
  - `testSwingsMoreThanTwoSecondsApartDoNotPair`: one swing every 2500 ms, 4 swings. Expect `completed == 0`.
  - `testBriefLossKeepsProgressAndLongLossClearsPendingSwing`. A 400 ms loss in the middle of a 2 Hz wave: it still reaches `ready` at the same sample count ±3. Swing, then an 800 ms loss, then one swing: `completed == 0`.
- [ ] **Step 2: Run** `swift test --package-path apps/ios/HiMorningCore --filter MotionCounterTests`. Expected: build failure on `WaveCounter`.
- [ ] **Step 3: Implement `WaveCounter`, and delete the wave code listed under Files.**
- [ ] **Step 4: Run** the filter command, expecting 0 failures. Then run `swift test --package-path apps/ios/HiMorningCore`, expecting 0 failures, and `sh scripts/test-swift.sh`, expecting the PASS line.
- [ ] **Step 5: Checkpoint.**

### Task 3: `NeckTurnCounter` replaces the neck branch

**Files:**
- Modify: `apps/ios/HiMorningCore/Sources/HiMorningCore/Movement.swift`:
  - Delete the `.headYaw` case.
  - Delete the neck cases in `observe` (:101-103) and `consume` (:123-127).
  - Restrict the `MovementChallengeProgress.init` precondition to `kind == .jumpingJacks || kind == .stretching`.
- Modify: `CoreTests.swift`. Remove the `head` block at :152-156 and the `neck` block at :178-182.
- Modify: `MotionCounterTests.swift` and `main.swift`

**Interfaces:**
- Consumes: `OneEuroFilter`.
- Produces: `public struct NeckTurnCounter: Sendable { public init(target: Int); public private(set) var completed: Int; public var ready: Bool; @discardableResult public mutating func observe(yawDegrees: Double, timestampMs: Int) -> Int; public mutating func observeLoss(timestampMs: Int) }`

Algorithm:
- **Zones** of the filtered yaw `y`:
  - `y >= 20` is right.
  - `y <= -20` is left.
  - `|y| <= 8` is centre.
  - Otherwise it is in between and does not change the candidate zone.
- **Committing a zone:** a zone commits after it has been the candidate for at least 150 ms.
- **Turns and reps:** a committed side followed by a committed centre is one completed turn on that side. When both sides have completed turns, `completed += 1` and the set clears.
- **Face loss:**
  - If the committed zone is a side and the last `|y| >= 15`, that side is held for up to 1500 ms. After that, clear the committed zone.
  - Any other loss over 600 ms clears the committed zone and resets the filter.

- [ ] **Step 1: Write the failing tests.** Use a helper `hold(_ yaw: Double, ms: Int, from: Int)` that feeds samples every 33 ms.
  - `testLeftFirstAndRightFirstBothCount`: c, L(−30), c, R(+30), c gives 1. A fresh counter with c, R, c, L, c also gives 1. Each hold is 300 ms.
  - `testSameSideTwiceDoesNotCount`: c, L, c, L, c gives 0.
  - `testNoiseAroundCentreNeverCountsATurn`: ±10° alternating for 3 s gives 0.
  - `testFaceLostAtFullTurnStillCompletesOnReturn`: c 300 ms, R +35 for 300 ms, `observeLoss` every 33 ms for 1000 ms, c 300 ms, L −30 for 300 ms, c 300 ms. Result is 1.
  - `testHoldExpiresAfterLongLossAtTurn`: the same, but with a 1700 ms loss. The right turn is not completed, so the result is 0 after c, L, c.
  - `testThreeRepsAtSevenFramesPerSecond`: three c/L/c/R/c cycles sampled every 133 ms give `ready` for target 3.
- [ ] **Step 2: Run** `swift test --package-path apps/ios/HiMorningCore --filter MotionCounterTests`. Expected: build failure on `NeckTurnCounter`.
- [ ] **Step 3: Implement it, and delete the neck code listed under Files.**
- [ ] **Step 4: Run** the filter command, then the full `swift test --package-path apps/ios/HiMorningCore`, then `sh scripts/test-swift.sh`. Expected: 0 failures and the PASS line.
- [ ] **Step 5: Checkpoint.**

### Task 4: `PushUpCounter` without the middle band, with loss grace

**Files:**
- Modify: `apps/ios/HiMorningCore/Sources/HiMorningCore/PushUps.swift`
- Modify: `apps/ios/HiMorningCore/Tests/HiMorningCoreTests/PushUpTests.swift` and `main.swift`

**Interfaces:**
- Produces: the same public API, `observe(elbowAngle:bodyAngle:incline:visible:timestampMs:)`, with new semantics:
  - Phases are: wait for `>= 160`, then `<= 90`, then `>= 160`, giving one rep if at least 800 ms passed since the first phase.
  - The 15 s window and the 1500 ms gap interrupt stay. The 120 ms phase spacing is removed.
  - `visible == false` within 600 ms of the first invisible sample keeps the current phase; past that it interrupts.
  - An out-of-range body angle or incline on a visible sample still interrupts immediately.
  - `CycleCapture` (Cloud.swift) is unchanged.

- [ ] **Step 1: Write the failing tests:**
  - `testFastDescentWithoutMiddleBandSamplesCounts`: (0, 165), (400, 80), (900, 165) gives 1.
  - `testBriefOcclusionKeepsTheRep`: (0, 165), (300, 80), (500, hidden), (900, 165) gives 1.
  - `testLongOcclusionResets`: (0, 165), (300, 80), hidden at 400 and 1100, then (1200, 165) gives 0.
  - The existing PushUpTests must stay green unchanged.
- [ ] **Step 2: Run** `swift test --package-path apps/ios/HiMorningCore --filter PushUpTests`. Expected: the 3 new tests FAIL.
- [ ] **Step 3: Implement the new semantics.**
- [ ] **Step 4: Run** the filter, expecting `Executed 8 tests, with 0 failures`. Then run `sh scripts/test-swift.sh`, expecting the PASS line.
- [ ] **Step 5: Checkpoint.**

### Task 5: `GuidedRhythmSession` grace and hold

**Files:**
- Modify: `apps/ios/HiMorningCore/Sources/HiMorningCore/Challenge.swift` (`GuidedRhythmSession`, :233-272)
- Modify: `CoreTests.swift` (:264-300) and `main.swift`

**Interfaces:**
- Produces: the same API, with new semantics:
  - A pose is accepted only after it has been observed continuously, visible, for at least 150 ms. That means its first sample is at `t0` and an accepting sample comes at or after `t0 + 150`.
  - `visible == false` keeps state while the loss lasts no more than 600 ms. A longer loss calls `interrupt()`.

- [ ] **Step 1: Update the tests.**
  - Rewrite `testGuidedRhythmSupportsStandingAndSeatedWithoutImageEvidence` so each pose is sampled twice, 200 ms apart:
    - standing at 0 and 200, lowered at 400 and 600, standing at 800 and 1000. Only the last observe returns true.
    - The same for seated arms.
  - Replace `testGuidedRhythmResetsOnOcclusionOutOfOrderAndExpiredWindow` with three tests:
    - `testGuidedRhythmKeepsProgressThroughBriefOcclusion`: a 300 ms hidden gap between lowered and standing still completes.
    - `testGuidedRhythmResetsAfterSustainedOcclusion`: a 700 ms gap does not complete.
    - `testGuidedRhythmSingleFramePoseIsIgnored`: one 33 ms lowered sample does not advance.
  - Keep the existing out-of-order and expired-window assertions, using holds.
- [ ] **Step 2: Run** `swift test --package-path apps/ios/HiMorningCore --filter CoreTests`. Expected: the new tests FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the filter, then the full `swift test …` and `sh scripts/test-swift.sh`. Expected: 0 failures and the PASS line.
- [ ] **Step 5: Checkpoint.**

### Task 6: `BodyFraming`

**Files:**
- Create: `apps/ios/HiMorningCore/Sources/HiMorningCore/BodyFraming.swift`
- Modify: `MotionCounterTests.swift` and `main.swift`

**Interfaces:**
- Produces:
  - `public enum BodyJoint: String, CaseIterable, Sendable { case nose, leftShoulder, rightShoulder, leftElbow, rightElbow, leftWrist, rightWrist, leftHip, rightHip, leftKnee, rightKnee, leftAnkle, rightAnkle }`
  - `public struct JointSample: Equatable, Sendable { public let x: Double; public let y: Double; public let confidence: Double; public init(x:y:confidence:) }` (Vision normalised coordinates, origin at bottom-left)
  - `public enum FramingHint: Equatable, Sendable { case ok, stepBack, showFeet, comeCloser, noPerson }`
  - `public enum BodyFraming { public static func hint(_ joints: [BodyJoint: JointSample], needsFeet: Bool) -> FramingHint }`
- Rules, applied in order, where "detected" means confidence ≥ 0.3:
  1. Fewer than 3 detected joints gives `noPerson`.
  2. Any detected joint with x or y below 0.02 or above 0.98 gives `stepBack`.
  3. If `needsFeet` and both ankles are undetected, `showFeet`.
  4. If the detected y-extent (max y − min y) is below 1/3, `comeCloser`.
  5. Otherwise `ok`.

- [ ] **Step 1: Write the failing tests:**
  - `testFullBodyInFrameIsOk`
  - `testNoJointsIsNoPerson`
  - `testCutOffAtBottomEdgeSaysStepBack`: knees at y 0.01, ankles undetected, `needsFeet` true. Expect `stepBack`.
  - `testMissingFeetAwayFromEdgeSaysShowFeet`
  - `testSmallBodySaysComeCloser`: y-extent 0.25.
  - `testUpperBodyOnlyIsOkWhenFeetNotNeeded`
- [ ] **Step 2: Run** `swift test --package-path apps/ios/HiMorningCore --filter MotionCounterTests`. Expected: build failure on `BodyFraming`.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the filter and `sh scripts/test-swift.sh`. Expected: 0 failures and the PASS line.
- [ ] **Step 5: Checkpoint.**

### Task 7: Capture wiring on every frame

**Files:**
- Modify: `apps/ios/HiMorning/MovementChallengeCapture.swift`, `apps/ios/HiMorning/CameraCapture.swift`, `apps/ios/HiMorning/GuidedRhythmCapture.swift` and `apps/ios/HiMorning/PoseGeometry.swift`
- Modify: `apps/ios/HiMorningCore/Sources/HiMorningCore/SignalSmoothing.swift`. Delete `ExpMovingAverage` once `grep -rn ExpMovingAverage apps/ios --include='*.swift'` shows no app use, and delete its test at CoreTests.swift:198 plus its registration.
- Modify: both `Localizable.strings` files

**Interfaces:**
- Consumes: `WaveCounter`, `NeckTurnCounter`, `PushUpCounter`, `GuidedRhythmSession`, `BodyFraming` (Tasks 2-6).
- Produces:
  - `LocalMovementUpdate` gains `let hint: FramingHint`.
  - `RhythmUpdate` (GuidedRhythmCapture.swift:5) gains `let hint: FramingHint`.
  - `PoseGeometry.jointSamples(_ points: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint]) -> [BodyJoint: JointSample]`
  - `FramingHint.message: String?` lives in an app-target extension in `PoseGeometry.swift`, and returns `appText` copy, or nil for `.ok`.

Steps:
- [ ] **Step 1: Remove the sampling throttles.**
  - Delete `now-lastSample>=0.1` (MovementChallengeCapture:66), `now-lastSample>=0.12` (CameraCapture:65), `uptime-lastSample>=0.12` (GuidedRhythmCapture:94) and their `lastSample` fields.
  - Keep `alwaysDiscardsLateVideoFrames = true`.
  - Reuse a stored `VNDetectHumanBodyPoseRequest` in CameraCapture and GuidedRhythmCapture instead of creating one per frame.
- [ ] **Step 2: Wave.**
  - Require `.wrist`, `.indexMCP`, `.middleMCP`, `.ringMCP` and `.littleMCP`, each at confidence ≥ 0.5.
  - `centerX` is the mean x × oriented width.
  - `handWidth = hypot((wrist.x − middleMCP.x) × W, (wrist.y − middleMCP.y) × H)`, where W and H are the oriented buffer size as in CameraCapture:80.
  - If any joint is missing, call `observeLoss`.
- [ ] **Step 3: Neck.**
  - Replace `VNDetectFaceLandmarksRequest` with `VNDetectFaceRectanglesRequest`, setting `revision = VNDetectFaceRectanglesRequestRevision3`.
  - Feed `yaw × 180/π` to `NeckTurnCounter`. A missing face or yaw calls `observeLoss`.
  - The progress message becomes `"Turn your head to each side, then back to the middle."`, with vi `"Quay đầu sang mỗi bên, rồi trở về giữa."`.
- [ ] **Step 4: Push-up.** In CameraCapture, a missing body or unselected side now calls `counter.observe(… visible: false …)` instead of `counter.interrupt()`.
- [ ] **Step 5: Framing hints.**
  - Jumping jacks and standing rhythm compute `BodyFraming.hint(PoseGeometry.jointSamples(points), needsFeet: true)`. Seated rhythm and stretching use `needsFeet: false`.
  - With no body observation, the hint is `.noPerson`.
  - When the hint is not `.ok`, the published message is `hint.message`.
- [ ] **Step 6: Add the four hint strings, en = vi:**
  - `"Step back so your whole body fits." = "Lùi lại để camera thấy toàn thân.";`
  - `"Show your feet in the camera." = "Để camera thấy cả bàn chân.";`
  - `"Come a little closer." = "Lại gần thêm một chút.";`
  - `"Stand where the camera can see you." = "Hãy đứng trong khung hình camera.";`
- [ ] **Step 7: Verify.**
  - Run `pnpm test tests/localization.test.ts` (pass), `swift test --package-path apps/ios/HiMorningCore` (0 failures) and `sh scripts/test-swift.sh` (PASS).
  - If `xcodegen` exists, build the app: `xcodegen generate --spec apps/ios/project.yml && xcodebuild build -project apps/ios/HiMorning.xcodeproj -scheme HiMorning -destination "generic/platform=iOS Simulator"`, expecting `** BUILD SUCCEEDED **`. Otherwise report it as not run (ledger L8).
- [ ] **Step 8: Checkpoint.**

### Task 8: `VoiceCoach` and the distance layout

**Files:**
- Create: `apps/ios/HiMorning/VoiceCoach.swift`
- Create: `apps/ios/HiMorningTests/VoiceCoachTests.swift`
- Modify: `apps/ios/HiMorning/ChallengeView.swift` (`CameraPreview` :8-19, the camera blocks :74-84, the message text :96, and the update handlers near :333 and :346)
- Modify: both `Localizable.strings` files

**Interfaces:**
- Produces: `@MainActor final class VoiceCoach { init(languageCode: String = appLocale().identifier, say: ((String) -> Void)? = nil, tick: (() -> Void)? = nil); func speak(_ text: String); func hint(_ text: String, at now: Date = .now); func rep(_ count: Int); func stop() }`
  - With nil closures, `say` uses one `AVSpeechSynthesizer` with `AVSpeechSynthesisVoice(language: languageCode == "vi" ? "vi-VN" : "en-US")` and calls `stopSpeaking(at: .word)` before each utterance.
  - `tick` is `AudioServicesPlaySystemSound(1057)`.
  - `hint` speaks only when `text` differs from the last hint **and** at least 3 s have passed since the last spoken hint.
  - `rep(n)` ticks, then says `"\(n)"`.

- [ ] **Step 1: Write the failing tests** in `VoiceCoachTests`, using injected `say` and `tick` spies:
  - `testHintIsRateLimitedAndDeduplicated`: the same hint twice at t and t+5 is spoken once. A different hint at t+1 is not spoken. A different hint at t+3.1 is spoken.
  - `testRepTicksThenSpeaksCount`
- [ ] **Step 2: Run** the test, only if `xcodegen` exists: `xcodegen generate --spec apps/ios/project.yml && xcodebuild test -project apps/ios/HiMorning.xcodeproj -scheme HiMorning -destination "platform=iOS Simulator,name=<first iPhone in xcrun simctl list devices available>" -only-testing:HiMorningTests/VoiceCoachTests`. Expected: build failure on `VoiceCoach`. Without xcodegen, report it as not run.
- [ ] **Step 3: Implement `VoiceCoach`.**
- [ ] **Step 4: Wire it into `ChallengeView`.**
  - Create one `VoiceCoach` when any camera challenge starts, and speak `challengeInstructions`.
  - On each update, if `reps` or `rhythmCycles` increased, call `rep(n)`. If the message changed, call `hint(message)`. On completion, `speak(result)`. Call `stop()` when the camera stops.
  - Add `.sensoryFeedback(.increase, trigger: reps)` and the same for `rhythmCycles`.
- [ ] **Step 5: Distance layout.**
  - `CameraPreview` uses `.resizeAspect`.
  - When the running challenge is `.jumpingJacks` or `.guidedRhythm` with variant `.standing`:
    - The preview takes `.frame(maxHeight: 360)`.
    - The counter uses `.font(.system(size: 96, weight: .bold, design: .rounded))`.
    - The message uses `.font(.system(size: 34, weight: .semibold))` with `.minimumScaleFactor(0.6)`.
  - Every other challenge keeps the current layout.
- [ ] **Step 6: Verify.**
  - Run `pnpm test tests/localization.test.ts` (pass).
  - If xcodegen exists, run the Step 2 command, expecting `** TEST SUCCEEDED **`, then run `sh scripts/test-ios.sh <simulator UDID> push` outside the sandbox with `RUNNER_WORKSPACE=$TMPDIR RUNNER_TEMP=$TMPDIR`.
  - Otherwise report "app tests not run (L8)".
- [ ] **Step 7: Add the device acceptance line** to `docs/RELEASE-READINESS.md`, unchecked: "Each camera challenge counts 3 reps correctly for a person about 2 m from the phone; wave at normal speed; neck right-first (ledger L3, L4)."
- [ ] **Step 8: Checkpoint.**
