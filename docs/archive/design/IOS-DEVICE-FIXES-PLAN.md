# iPhone device fixes

> **Historical document.** This is a superseded proposal or implementation
> checkpoint, not current product behavior or instructions to execute. See the
> [current documentation](../../README.md) and [challenge guide](../../MODE-CHALLENGES.md).
> Original observations, limits and approvals below apply only to their dated scope.

Fix the six reported iPhone problems with small, reviewable changes, prioritizing Read Aloud completion and reliable alarm confirmation.

**Status:** Implemented and reviewed; simulator checks passed with the AlarmKit limitation below. Physical-device acceptance remains pending. **Audience:** iOS developers and reviewers.

## Approved revisions

The user confirmed that an existing alarm rang at the intended time. Preserve the working native scheduling flow. Add editing for saved alarm sounds, keep selected challenge descriptions inside their item border, and visibly distinguish increasing mode difficulty. Read Aloud now records a completed reading without grading word accuracy or pronunciation; allow more time for longer sentences. After implementation, exercise the actual app as a new user and resolve usability problems found during that review.

## At a glance

Development checkout: `HiMorning-pr5-integration`. Its unrelated uncommitted work was preserved. Publication uses the isolated `codex/ios-device-fixes` branch based on `origin/main`; the user authorized committing and opening a PR after reviewing the implementation. The original device failures have not been reproduced on physical hardware.

| Report | Current evidence | Intended result |
| --- | --- | --- |
| Missing app icon | No AppIcon configuration or asset catalog was found. | Supply an app icon asset and wire it into the app target. Verify an installed iPhone build. |
| Unclear Gentle / Balanced / Focused modes | Defaults are no challenge / 3 push-ups / 5 push-ups. Explicit challenge selection persists when the mode changes. Focused requires preview or Pro; free access falls back to Balanced. | Explain the actual defaults and access requirement in English and Vietnamese without implying that explicit choices are overwritten. |
| Challenge appears divided into upper and lower halves | A full-screen challenge has a scrolling hero and a separate bottom action inset. The reported appearance has not been reproduced. | Capture a visual baseline, then unify the presentation and reduce decorative space for cognitive challenges if it matches the report. |
| Unclear whether an alarm was scheduled | The editor dismisses immediately while its parent schedules asynchronously. The library awaits native scheduling and later reconciles scheduled IDs. | Keep save progress visible; show actionable errors or confirmed native scheduling with the next occurrence. |
| Alarm sounds feel crude | The original Sunrise and Soft Chime files are synthesized pilot sketches; other catalog entries use repeated game jingles. | Replace the two original sound files with subtler bell or piano-like audio while retaining their identifiers and the rest of the catalog. |
| Read Aloud sounds robotic, uses short prompts, and never completes | Generic system voice; prompts about 5–9 words. The 20-second timeout cancels analysis without graceful finalization, which may discard pending final recognition. Device root cause remains unproven. | Prefer an installed enhanced voice, provide engaging prompts about 18–25 words long, and finish recognition gracefully with clear success or retry feedback. |

## How it works

Gate 1 was approved with the revisions above. The implementation and simulator results are recorded below; visual, audio, and hardware observations have separate acceptance checks.

### Task list

- [x] **Read Aloud implementation.** Added speech-length completion without correctness grading, explicit finish, graceful finalization bounded at six seconds, retry feedback, longer prompts, proportional listening time, and best-installed English voice selection. Domain, helper, cancellation and UI checks passed. Actual microphone recognition and SDK end-of-input delivery still need device acceptance.
- [x] **Challenge layout and mode explanations.** Moved the selected description and settings inside its border, compacted the challenge header, and added difficulty bars and accurate localized defaults. Checked default-size English/Vietnamese screens and reachable stop controls. The original physical-device split and large accessibility text sizes were not reproduced or verified.
- [x] **Alarm editing and save feedback.** Added prefilled editing, stable identity, awaited save, duplicate-save prevention, failure recovery, and confirmed next-occurrence display. Core and disabled-alarm UI editing passed. Real enabled-alarm rescheduling could not be confirmed because the simulator denies alarm access.
- [x] **App icon implementation.** Added an opaque 1024px icon and configured `project.yml`. Generated target and bundle checks passed; the icon was visible on the simulator Home Screen. Physical installation is pending.
- [x] **Original sound replacements.** Replaced Sunrise and Soft Chime with softer piano/bell phrases, preserving IDs. WAV decoding, levels and silent-edge checks passed. Preview controls were exercised; subjective quality and locked-device looping still need listening on an iPhone.
- [x] **Integrated verification and delegated review.** The isolated PR branch passed 40 SwiftPM core tests, portable checks with 98.53% core line coverage, four localization tests, 38 native tests, ten UI tests and the simulator build. One additional UI test was skipped because AlarmKit access was denied. Delegated code/security review completed; the final follow-up reported no actionable P1/P2 findings. Evidence and usability observations are in [the verification report](../../tdd/ios-device-fixes.tdd.md).

### Device acceptance still open

- [ ] Install this checkout on the physical iPhone and confirm its icon.
- [ ] Create an enabled alarm, edit its sound, confirm its next ring, and hear the new sound with the phone locked.
- [ ] Read into the actual microphone through success, silence/partial retry, explicit finish, timeout, stop and background recovery.
- [ ] Listen to the sample voice and both changed alarm sounds; check layout with large accessibility text.

## Key choices

- Reuse the current capture, alarm scheduler, UI components, and audio catalog. Add no dependencies or new scheduling system.
- Use the SDK's `finalizeAndFinishThroughEndOfInput` capability to allow pending speech results to arrive before cancellation. Verify exact lifecycle behavior in tests and on a physical device; cancellation must still stop capture promptly.
- Explain only mode behavior that the app currently applies. Core `WakePolicy` snooze values are not connected to this UI, so do not advertise snoozing or add it as part of these fixes.
- Keep English learning prompts in English in both localization resources; localize the surrounding instructions, controls, and feedback.
- Treat system voice quality as dependent on voices installed on the phone. Do not promise natural speech from a voice that is unavailable.
- Restrict the sound replacement to the two original assets. Broader catalog redesign, new modes, and unrelated cleanup are outside this change.

## What we checked

Source investigation snapshot: **2026-10-15**. Existing evidence identifies likely causes and affected call paths; it does not prove the physical-device speech or layout failure.

- [`SpeechChallengeCapture.swift`](../../../apps/ios/HiMorning/SpeechChallengeCapture.swift), [`ChallengeView.swift`](../../../apps/ios/HiMorning/ChallengeView.swift), and [`SpeechAnalysisTests.swift`](../../../apps/ios/HiMorningTests/SpeechAnalysisTests.swift) cover capture integration and the existing regression surface.
- [`SpokenExample.swift`](../../../apps/ios/HiMorning/SpokenExample.swift) and [`SpokenExampleTests.swift`](../../../apps/ios/HiMorningTests/SpokenExampleTests.swift) provide the existing voice implementation and checks.
- [`AlarmEditor.swift`](../../../apps/ios/HiMorning/AlarmEditor.swift) and [`project.yml`](../../../apps/ios/project.yml) establish the editor flow and target configuration.
- [`AlarmSoundResourceTests.swift`](../../../apps/ios/HiMorningTests/AlarmSoundResourceTests.swift), [`PilotUITests.swift`](../../../apps/ios/HiMorningUITests/PilotUITests.swift), and [`CoreTests.swift`](../../../apps/ios/HiMorningCore/Tests/HiMorningCoreTests/CoreTests.swift) are existing validation entry points.
- Structural lookup used the `HiMorning-remote-pilot` graph snapshot generated at `2026-10-15T12:58:11Z`. Coverage for affected UI files was partial or metadata-changed; direct source inspection supplied the missing evidence. The graph is not an exhaustive caller inventory.

Implementation evidence is dated **2026-10-15**. The user's earlier confirmation that an alarm rang on time predates these fixes and does not establish acceptance of the changed sound/editing flow.

## Limits and next steps

**Gate 1:** approved with the revisions above. **Gate 2:** approved by the user's request to open the PR. Commit message: `fix(ios): improve alarm editing and reading challenges`.

Physical iPhone checks must cover microphone permissions and capture, explicit speech finish, successful and unsuccessful readings, cancellation and retry, available voice quality, challenge layout, native alarm confirmation, locked-device alarm playback and looping, and the installed app icon. Record device and OS details with the results. If a device is unavailable, state those checks as outstanding rather than claiming full coverage.

## Read next

- [`DOC-TEMPLATE.md`](../../DOC-TEMPLATE.md) — documentation format used for this plan.
- `orch-fix-defect` skill (historical local reference) — regression-first implementation and approval gates.
