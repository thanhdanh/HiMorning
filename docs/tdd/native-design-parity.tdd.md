# Native design parity evidence

Restore the original warm visual direction and show the supported morning flow.
Journeys come from the user's design feedback, not a separate plan file.

**Status:** RED verified; implementation in progress.

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
was added after this RED and has not yet run. Native UI coverage is not represented
by the separately measured backend and Swift-core percentages.

## SDK integration feedback

The first fix build, [run 38157522962](https://github.com/thanhdanh/HiMorning/actions/runs/38157522962),
failed SwiftUI type checking before UI execution. The trial's `AlarmTime` call
omitted its required weekday set. The follow-up supplies an empty set; it does
not change the domain constructor or bypass validation. This compiler failure
is integration feedback, not an additional behavior RED.
