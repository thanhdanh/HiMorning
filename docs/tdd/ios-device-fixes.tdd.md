# iPhone fixes and usability verification

Record the implemented alarm, challenge and asset fixes, the checks they passed,
and what remains to be tried on a physical iPhone.

**Status:** Implemented and reviewed on 15 October 2026; simulator verification
passed with one AlarmKit skip. Physical-device acceptance is pending.
**Audience:** iOS maintainers and reviewers.

The Read Aloud sections below record the initial speech-length implementation.
The later request for live word scoring supersedes that behavior; see
[Read Aloud word feedback](read-aloud-word-feedback.tdd.md) for the current
implementation, device installation and remaining acceptance check.

## At a glance

Development took place in `HiMorning-pr5-integration` alongside unrelated
uncommitted work. Publication uses the isolated `codex/ios-device-fixes` branch
based on `835840a` from `origin/main`. Only the iOS fixes and their tests, assets
and documentation were copied; the development checkout was left intact. The
user authorized committing and opening the PR after reviewing the changes.

| Area | Implemented behavior | Evidence and limit |
| --- | --- | --- |
| Saved alarm | Edit reopens its time, mode, challenge and sound; saving preserves identity and enabled state. | Core failure-path tests and disabled-alarm UI editing passed. Enabled native rescheduling remains unverified. |
| Save confirmation | Saving stays visible, blocks duplicate submission/dismissal, and keeps the editor open on failure. Confirmed alarms show the next ring. | UI busy/error checks passed; denied native access offers Settings and retry. |
| Modes | Gentle defaults to no challenge, Balanced to 3 push-ups, Focused to 5. Difficulty bars show increasing effort. Explicit choices persist across mode changes. | English/Vietnamese UI checks passed. Focused retains its existing preview/Pro requirement. |
| Challenge layout | Selected descriptions and controls share the item's border. Cognitive challenges use a compact header and inline primary action. | Frame containment assertions and manual simulator inspection passed at default text size. |
| Read Aloud | On-device speech recognition records enough speech without grading words or pronunciation; longer prompts receive more time. | Core completion, timing and cancellation checks passed. Actual microphone completion is pending. |
| Icon and sounds | Added the sun icon and replaced Sunrise/Soft Chime while preserving their IDs. | Bundle/icon and WAV checks passed; simulator icon seen. Sound quality still needs listening on the phone. |

## How it works

Open **Edit** on an existing alarm, choose a sound, and save. The editor awaits the
library's persistence and native scheduling result. It dismisses on success and
shows a recoverable explanation on failure. Disabled alarms stay disabled. A
failed or uncertain operation retains a review state rather than showing a false
confirmation. Deleting an alarm whose native ID is already absent now succeeds;
real native-query errors still propagate.

For Read Aloud, play the example or start reading separately. The example cannot
complete the challenge or request microphone permission. Recognition remains on
the device; this path adds no cloud audio upload or transcript storage. A reading
is recorded after recognized speech reaches about 80% of the target's word count;
the words do not have to match. Automatic finish waits for stable recognition,
and **Finish reading** explicitly requests finalization. Silence and short speech
produce retry feedback. Stop and background cancellation invalidate late results.

The listening allowance is `max(45, wordCount * 3 + 15)` seconds. The current
20-word prompts receive 75 seconds. Ending input allows up to six additional
seconds for pending recognition results before bounded cleanup.

## Key choices

Use Apple's existing speech and synthesis APIs instead of adding a cloud model or
dependency. Speech-length completion follows the requested scope: it recognizes
a reading attempt but cannot establish that the displayed sentence was read.
The code marks this limit with a `shortcut:` comment. Voice selection prefers
the best installed English voice, with en-US as a tie-breaker; quality depends on
installed voices.

Keep sound identifiers stable so existing alarms retain their selections. Only
the two original WAV files changed; the other catalog sounds are unchanged.
[The asset generator](../../scripts/generate-morning-assets.swift) reproduces the
PCM audio and validates the opaque icon. The selected AI-generated rising-sun
logo now replaces the earlier drawn icon. Audio tests establish format, duration and headroom,
not whether the melody is pleasant.

## Try it

Use Xcode with the iOS 26+ SDK, XcodeGen, and the project's pinned pnpm version.
Run from this checkout. Generate the Xcode project if it is not already present:

```sh
xcodegen generate --spec apps/ios/project.yml
swift test --package-path apps/ios/HiMorningCore
sh scripts/test-swift.sh
pnpm exec vitest run tests/localization.test.ts
```

Choose an available simulator UUID for the native and focused editor tests:

```sh
HIMORNING_QA_SIMULATOR=77378678-FFEE-4276-82B6-4B082AA8862A
xcodebuild -project apps/ios/HiMorning.xcodeproj -scheme HiMorning \
  -configuration Debug \
  -destination "platform=iOS Simulator,id=$HIMORNING_QA_SIMULATOR" \
  -parallel-testing-enabled NO \
  -only-testing:HiMorningTests \
  -only-testing:HiMorningUITests/DeviceFixesUITests test
```

The enabled-alarm UI test skips only after asserting the exact permission-denied
feedback, visible Settings recovery and available retry. Any other save failure
fails the test. Use a device with alarm access allowed to exercise its remaining
same-ID rescheduling assertions.

## What we checked

### Selected logo update

The selected rising-sun PNG is now the opaque 1024×1024 `AppIcon.png`.
The asset generator passed its assertions without changing the icon or either
original WAV file (SHA-256 compared before and after). A Debug build and
`HiMorningTests/AppIconResourceTests` passed on the iOS 26.2 QA simulator.
The compiled 120×120 iPhone icon was visually checked. This update has not been
installed or checked on a physical iPhone.

### Regression and review evidence

- RED: the new alarm editing regression could not compile before
  `AlarmLibrary.update` existed; prompt-length assertions failed on the original
  short sentences. These reproduce code-level gaps, not the physical speech hang.
- GREEN: [AlarmEditingTests](../../apps/ios/HiMorningCore/Tests/HiMorningCoreTests/AlarmEditingTests.swift)
  passed seven cases covering identity, disabled editing, persistence/scheduler
  failure, uncertainty and concurrent reconciliation.
- GREEN: [ReadAloudTests](../../apps/ios/HiMorningCore/Tests/HiMorningCoreTests/ReadAloudTests.swift)
  passed six cases covering prompt length, completion without word accuracy,
  silence/partial rejection, duration and stop/late-result guards.
- Native tests cover transcript accumulation, conversion, stopped capture,
  voice preference, icon metadata, WAV decoding/levels and real AlarmKit
  cancellation of an absent ID. The isolated PR branch's native suite passed
  **38 tests**.
- The isolated PR branch's SwiftPM suite passed **40 tests**. Portable core
  verification passed with **98.53% line coverage** for its configured domain scope. This percentage
  excludes the app UI, microphone adapter and AlarmKit adapter.
- The isolated PR branch's UI run passed **ten of eleven tests**, with the
  enabled-alarm test skipped for denied AlarmKit access and zero failures.
- Localization validation passed four tests and both `.strings` files passed
  `plutil` lint. The simulator build succeeded.
- Delegated code/security review was completed. The final follow-up reported no
  actionable P1/P2 findings after correcting voice selection, item-based editor
  presentation, startup busy handling and native absent-ID cancellation.

UI checks found and prompted fixes for the first Edit opening default values,
an inaccessible retry path after permission denial, and failed-create cleanup
when an alarm had no native ID. All affected checks were rerun after correction.

### New-user walkthrough

The actual installed app was operated through Device Hub on the
`HiMorning Run 20261015` and clean `HiMorning Device Fixes QA` simulators, both
running iOS 26.2. The clean simulator is an iPhone 17 Pro. This was a manual
walkthrough of ordinary controls, separate from injected UI-test outcomes.

| Journey | Observation |
| --- | --- |
| Find and launch the app | The sun icon was visible on the simulator Home Screen. |
| Edit a saved alarm | Time and mode were prefilled. Challenge details were inside the selected card. |
| Compare modes | Default challenge counts and increasing difficulty were visible; English and Vietnamese screens were checked. |
| Find and preview a sound | Scrolling revealed Sound, the picker opened and Sunrise preview was triggered. Exploratory changes were cancelled. |
| Try Read Aloud | The full 20-word sentence, 75-second allowance, example and start controls fit at default text size. |
| Play the example | Start was blocked during playback and became available afterward. Playback alone did not complete the challenge. |
| Start recognition for the first time | Permission led to a speech-support download. Completion was not attempted while that download was pending. |
| Stop during setup | Stop responded and returned a clear practice-ended state with a route home. No hang was observed in this path. |

The disposable 06:30 alarm left by an earlier failed test was removed through the
UI after the native-cancel fix. The pre-existing 06:31 Focused alarm was preserved.
No physical iPhone was modified.

Screenshots: [Vietnamese mode differences](../images/ui/device-fixes/mode-difficulty-vi.png)
and [Vietnamese Read Aloud](../images/ui/device-fixes/read-aloud-vi.png).

Remaining usability friction found during this walkthrough:

1. **Sound is deep in the editor.** A newcomer must scroll past challenge choices
   before discovering how to change it. Consider moving the existing Sound row
   nearer the time and mode controls in a later layout pass.
2. **The first speech download has no progress or duration estimate.** The status
   explains preparation and Stop works, but a newcomer cannot judge the wait.
   Device measurements and the platform's available progress information should
   guide any estimate rather than displaying invented progress.

Temporary development logs and result bundles:

- `/private/tmp/himorning-device-fixes-core.log`
- `/private/tmp/himorning-device-fixes-swiftpm-final.log`
- `/private/tmp/himorning-device-fixes-final.log` and `.xcresult`
- `/private/tmp/himorning-device-fixes-usability.log` and `.xcresult`
- `/private/tmp/himorning-device-fixes-clean-alarmkit.log`

The isolated PR branch was rebuilt with SwiftPM and rechecked with the portable
runner and localization suite. Its logs are
`/private/tmp/himorning-ios-pr-swiftpm.log` and
`/private/tmp/himorning-ios-pr-portable.log`. The successful native build and UI
run are recorded in `/private/tmp/himorning-ios-pr-native.log` and `.xcresult`.
These logs are session evidence, not durable release artifacts.

## Limits and next steps

The simulator denied AlarmKit access immediately, including on a newly created
simulator. The built usage description was present. Permission recovery was
tested, but enabled same-ID rescheduling, changed native ringing and successful
native confirmation were not verified. The user's earlier on-time alarm report
applies to the previous build.

Actual microphone speech recognition through success, finalization, timeout and
retry still needs testing on the iPhone. Core completion checks use supplied
transcripts. UI checks cover Read Aloud setup, example playback and cancellation;
offline UI completion exercises Read and Choose. These checks do not establish
real microphone or model behavior.
The physical-device listening hang's root cause therefore remains unproven.
Voice naturalness, alarm melody/looping, fresh physical icon installation and
large accessibility text also remain pending.

Gate 2 was approved by the user's request to open the PR. The scoped commit is
`fix(ios): improve alarm editing and reading challenges`; unrelated cloud,
backend and configuration changes are excluded, including mixed-file hunks.

## Read next

[Approved plan](../IOS-DEVICE-FIXES-PLAN.md) ·
[Run the app](../RUNNING.md) ·
[Resource provenance](../../apps/ios/Resources/README.md)
