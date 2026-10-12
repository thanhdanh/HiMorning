# Native design parity evidence

Restore the original warm visual direction and show the supported morning flow.
Journeys come from the user's design feedback, not a separate plan file.

**Status:** Executed RED and GREEN preserved; native design fix verified on simulator.

## User guarantees

- Home renders the original cream canvas and sunshine-yellow action color.
- A person can rehearse before creating an alarm, then cancel consent, recover from
  unavailable AI, self-confirm or end the trial without alarm permission.
- Editor modes and sound choices remain usable in English and Vietnamese.
- The gallery shows real native screens with source-run provenance.

## Executed RED

Test source: `apps/ios/HiMorningUITests/PilotUITests.swift`, commit `fc16b31`.
[Run 38156893186](https://github.com/thanhdanh/HiMorning/actions/runs/38156893186)
built the native app and executed five UI tests. The three earlier journeys passed;
the two new language journeys failed with 12 assertions, zero unexpected failures.

Actual canvas channels included 242 instead of 255/252. The primary action rendered
RGB 255/204/0 instead of the original 245/200/66 (tolerance 3). Both journeys also
failed because rehearsal was unavailable from an empty home. These are executed
visual/interaction failures, not missing SDK or test-compilation failures.

The backend job and ten Swift package tests passed. The editor capture extension
was added after this RED and later passed in the GREEN run. Native UI coverage is not represented
by the separately measured backend and Swift-core percentages.

## SDK integration feedback

The first fix build, [run 38157522962](https://github.com/thanhdanh/HiMorning/actions/runs/38157522962),
failed SwiftUI type checking before UI execution. The trial's `AlarmTime` call
omitted its required weekday set. The follow-up supplies an empty set; it does
not change the domain constructor or bypass validation. This compiler failure
is integration feedback, not an additional behavior RED.

The second build, [run 38157847898](https://github.com/thanhdanh/HiMorning/actions/runs/38157847898),
compiled the app and passed the rendered-color and editor checks. Both rehearsal
journeys failed because the adaptive confirmation dialog omitted its cancel-role
action. Make “Choose another way” an explicit dismissal action so it remains
visible in the popover presentation, then rerun the same journeys.

## Executed GREEN

[Run 38293447198](https://github.com/thanhdanh/HiMorning/actions/runs/38293447198)
at `f648f9151c38abe40190dc69a8d09d601e22ebb6` built the native app and passed
the same five UI tests with zero failures in 122.640 seconds. Both language
journeys passed the rendered color checks, explicit consent exit, actual
unavailable-cloud recovery, self-confirmation and trial exit. Both editor
journeys also selected Balanced/Focused and the sound preview controls.

The run passed 56 Vitest checks including the real Firestore Emulator, 15 portable
Swift journeys and 10 package XCTest cases. Portable core coverage was 84.41%
regions, 98.63% functions and 97.86% lines; LLVM reported no branch counters.
Those percentages do not measure the native views. Native UI line/branch coverage
was not collected, and no whole-app coverage claim is made.

[The gallery](../images/ui/README.md) preserves all 20 named captures from that
GREEN, with source commit, simulator, dates and dimensions. Representative Home,
editor, sound, consent and outcome captures were visually inspected. Copying
verified byte-identical PNGs does not change their pixels.

## Checkpoints and limits

| Checkpoint | Commit |
|---|---|
| Behavior tests before production | `fc16b31` |
| Verified RED evidence | `ed07e01` |
| Native palette/layout and rehearsal | `aa4400b` |
| Required weekday constructor argument | `5a996ce` |
| Visible consent exit; verified GREEN source | `f648f91` |

The four source-check runs were one valid behavior RED, one SDK compile failure,
one dialog-interaction failure and one GREEN. They were push-triggered, without
a duplicate manual dispatch. These intermediate failures are recorded rather
than counted as successful coverage. The final documentation push may produce
an additional check run.

No physical-device alarm/sound/camera, paid inference, model accuracy, large text,
dark mode or VoiceOver validation was performed. Rehearsal uses the actual app
path with a transient sample; it does not create or stop a scheduled OS alarm.
