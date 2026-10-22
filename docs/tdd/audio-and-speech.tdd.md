# Audio and speech integration evidence

> **Dated evidence.** Commands, approvals, test totals and local paths below
> describe the original run. They are not current setup instructions or release
> status. See [current validation](../VALIDATION.md) for newer results and known gaps.

**Status:** Focused core and native unit tests passed. Gate 2 commit approval is
pending. UI runner verification is blocked by an iOS 27 simulator bootstrap
termination, before any UI assertion runs.

## Integrated verification

| Check | Result |
| --- | --- |
| Localization contract | `pnpm exec vitest run tests/localization.test.ts`: 4 passed |
| Core catalog/persistence | `swift test --package-path apps/ios/HiMorningCore`: 20 passed |
| Portable core journeys | `sh scripts/test-swift.sh`: 28 passed; 98.05% lines, 87.28% regions |
| Native sound/speech/TTS/capture tests | Focused `xcodebuild test`: 17 passed |
| Native UI flows | Runner exited with `signal kill` / `signal term` before establishing its test connection, including after simulator reboot |

The native unit run covered all bundled WAV decoding, catalog grouping,
segmented transcript and audio-buffer conversion, startup cancellation, existing
capture stop behavior, and synthesized-example callbacks.

The localization contract now asserts the three permissions the app uses
(camera, AlarmKit, microphone) and the absence of the obsolete
`NSSpeechRecognitionUsageDescription`, matching the SpeechAnalyzer migration.

## Remaining device checks

A physical iPhone still needs to audition the alarm sounds, validate a locked
AlarmKit alarm, grant/deny microphone access, exercise speech asset download and
module fallback, and check interruptions/Bluetooth routing. The iOS 27 simulator
could compile and run unit tests but could not establish a UI-test runner session;
this is recorded as an environment limitation rather than a passing UI result.

No files have been staged or committed.
