# Reliable camera challenges

> **Historical document.** This is a superseded proposal or implementation
> checkpoint, not current product behavior or instructions to execute. See the
> [current documentation](../../../README.md) and [challenge guide](../../../MODE-CHALLENGES.md).
> Original observations, limits and approvals below apply only to their dated scope.

Count wave hello, neck turn, push-up, guided rhythm and jumping jacks reliably on the iPhone front camera, and make full-body challenges usable from a distance.

**Original status:** Planned when approved on 17 October 2026. **Audience:** iOS developers working on `MovementChallengeCapture`, `CameraCapture`, `GuidedRhythmCapture` and HiMorningCore `Movement`, `PushUps`, `SignalSmoothing`.

## At a glance

We keep Apple Vision. The miscounts come from our sampling and counting logic, not from the model (unverified, ledger L4; the first task proves it with failing tests).

| Challenge | Root cause today | Fix |
| --- | --- | --- |
| Wave hello | ~7.5 Hz sampling, debounce drops two reversals at once (`Movement.swift:82-86`), reset on every lost frame | 30 Hz, One Euro on hand centre, peak/trough counter with 2 s window, 600 ms loss grace |
| Neck turn | Fixed left-first order, face loss at full turn wipes progress, 17° boundary flicker | Either side in any order, 20° enter / 8° exit hysteresis, 150 ms hold, loss while turned holds the turn for 1.5 s |
| Push-up | 100–150° middle band must be sampled, no loss grace | Down ≤ 90° then up ≥ 160° with hysteresis, 600 ms grace |
| Guided rhythm, jumping jacks | No framing feedback, small text, cropped preview, no loss grace in rhythm | `BodyFraming` hints, `VoiceCoach`, distance mode, aspect-fit preview, 600 ms grace and 150 ms hold |

## How it works

- **Capture.** Every capture class analyses every frame, with `alwaysDiscardsLateVideoFrames = true`, and removes the 0.1 s / 0.12 s throttle. Neck turn uses `VNDetectFaceRectanglesRequest` at its latest supported revision for yaw, since landmarks were computed but unused.
- **Smoothing.** A shared `OneEuroFilter` lives in `SignalSmoothing.swift`. It is time-based, so it is correct at 30 Hz and at 7.5 Hz. It replaces `ExpMovingAverage` in the movement paths.
- **Wave.** The signal is the hand centre x (mean of wrist and the four MCP joints), divided by hand width (wrist to middle MCP distance). Each joint needs confidence ≥ 0.5. A swing is a move from a local extreme back by ≥ 0.35 hand widths. Two swings make one rep, and they must fall within a 2 s window. Losses under 600 ms keep state.
- **Neck.** The yaw signal is filtered with One Euro. States are centre, left and right. A turn starts at |yaw| ≥ 20° held for 150 ms and ends at ≤ 8°. A rep is one completed turn to each side, in any order, with a return to centre between them. If the face is lost while |yaw| ≥ 15°, the current side is kept for 1.5 s.
- **Full body.** `BodyFraming` (HiMorningCore, pure) maps joint visibility and the bounding box to one hint: `ok`, `stepBack` (joints touch the 2 % edge), `showFeet` (ankles missing), `comeCloser` (body under 1/3 of frame height) or `noPerson`.
- **Voice and distance mode.** `VoiceCoach` (app target) uses `AVSpeechSynthesizer` with an `en-US` or `vi-VN` voice that follows the app language. It speaks the instruction at start, a hint when it changes (at most every 3 s), each rep number and completion. Each rep also plays a short system sound and a haptic. While a full-body challenge (jumping jacks, standing rhythm) has its camera running, the challenge shows a large-type layout: rep counter at 96 pt and the hint at 34 pt. The preview switches to `.resizeAspect`, so the user sees what Vision sees.

All new copy, both spoken and on screen, ships in English and Vietnamese.

## Key choices

- **No new SDK.** MediaPipe and ARKit would not fix the counting bugs. They stay as fallbacks if device tests still fail after this change (ledger L3 for ARKit neck yaw).
- **Time-based logic everywhere.** Thresholds and windows are in seconds, not frames, so tests can replay at both 33 ms and 133 ms spacing.
- **Pure core, thin capture.** Counting, framing and filtering live in HiMorningCore and are unit tested. The capture classes only map Vision observations to samples.

## What we will check

- Replay tests in HiMorningCore for wave at 2 Hz and 4 Hz sampled every 33 ms and 133 ms, a right-first neck turn, face loss at 40° yaw, a push-up with no middle-band samples, and rhythm with a 400 ms occlusion. The wave and neck cases must fail on HEAD before the fix.
- `BodyFraming` table tests for each hint.
- `OneEuroFilter` tests for jitter suppression at rest and lag under fast motion.
- Device check, recorded in RELEASE-READINESS.md: 3 reps of each challenge counted correctly by a person standing about 2 m away.

## Limits and next steps

- Ledger L3 (Vision yaw quality) and L4 (root cause) are confirmed only on device and by the failing tests.
- Recorded keypoint fixtures from real devices would make the replay tests stronger. Recording them needs a debug capture mode; that is out of scope here.
