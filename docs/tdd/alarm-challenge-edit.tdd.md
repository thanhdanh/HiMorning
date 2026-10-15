# Saving a changed alarm challenge

Record the fix for challenge edits that unnecessarily entered native alarm
scheduling and could leave the editor open with the old choice.

**Status:** Implemented and reviewed on 15 October 2026; simulator regressions
passed. Physical-device acceptance is pending. **Audience:** iOS maintainers and reviewers.

## At a glance

`AlarmLibrary.update` now persists mode/challenge edits without scheduling again
when time and sound are unchanged. It preserves the alarm ID, enabled flag and
existing scheduling state. The editor still closes only after saving succeeds.

## How it works

AlarmKit configuration consumes the alarm ID, time and sound. Its app-opening
intent stores the ID; the app looks up the latest saved challenge when opened.
Changing the challenge therefore requires updating local persistence only.

The update compares time and sound with the saved record. When either changes,
the existing native scheduling and error handling still apply. Otherwise it
persists the new choice and returns. A persistence failure restores the previous
record, and an uncertain schedule remains uncertain.

## What we checked

- RED: five of fourteen focused `AlarmEditingTests` failed against the old code
  because the strict fake scheduler rejected unexpected scheduling for metadata
  edits. The original time/sound and rollback tests remained passing.
- RED UI: changing an enabled saved alarm's challenge left Edit open after Save.
  The simulator returned denied AlarmKit access. The test was not skipped.
- The original button already responded at its left, right and centre positions
  in the UI check; no shared button-style change was needed.
- GREEN core: all 54 SwiftPM tests and the portable runner passed. Portable core
  line coverage was 98.57%; this excludes native adapters and app UI.
- GREEN native/UI: the build succeeded and all 39 native tests plus four focused
  UI tests passed on iPhone 17 Pro / iOS 26.2 Simulator. The new enabled-alarm
  challenge edit and unchanged-save checks passed in both languages, without a
  permission skip. Existing disabled-sound editing and save-failure checks passed.
- Seven localization/CI-script tests passed. Delegated code/security review
  reported no actionable P1/P2 findings.
- The enabled-alarm edit regression is included in push CI. Existing script
  selection checks validate that the selected test method exists.

The UI fixtures use isolated temporary saved records and do not create native
alarms. The enabled record may reconcile to `needsReview`, which must remain
truthful after an edit. The tests select another challenge, save, verify that
Edit disappears, reopen the same alarm and check the new selection. Both English
and Vietnamese are covered, including saving without another change.

Session evidence is in `/private/tmp/himorning-alarm-edit-core-red.log`,
`/private/tmp/himorning-alarm-edit-core-green.log`,
`/private/tmp/himorning-alarm-edit-portable-green.log`, and
`/private/tmp/himorning-alarm-save-{red,green}.log` with matching UI result bundles.
Temporary logs are not durable release artifacts.

## Limits and next steps

The user reported no error and a Save label that remained unchanged. That exact
physical-device symptom has not been reproduced. The tests demonstrate a
failing shared save path and verify the corrected challenge-only flow.
Actual iPhone acceptance remains pending. Time/sound edits still require native
alarm access, and no new real enabled-alarm rescheduling result is claimed here.

## Read next

[Original iPhone fixes](ios-device-fixes.tdd.md) ·
[Core editing regressions](../../apps/ios/HiMorningCore/Tests/HiMorningCoreTests/AlarmEditingTests.swift) ·
[UI regressions](../../apps/ios/HiMorningUITests/DeviceFixesUITests.swift)
