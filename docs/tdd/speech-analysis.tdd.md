# On-device speech TDD evidence

> **Dated evidence.** Commands, approvals, test totals and local paths below
> describe the original run. They are not current setup instructions or release
> status. See [current validation](../VALIDATION.md) for newer results and known gaps.

Keep segmented speech accurate and cancel microphone startup safely while moving
the read-aloud challenge to Apple's current on-device analyzer.

**Status:** Adapter and focused native tests passed; device validation is pending.
**Audience:** iOS developers and reviewers. Snapshot: October 15, 2026.

## At a glance

| Approved behavior | Test guarantee | Evidence |
| --- | --- | --- |
| Assemble analyzer segments | Partial text replaces the previous partial; final segments accumulate; repeated finals and stale partials cannot duplicate words; empty finals clear volatile text | Four `SpeechAnalysisTests` cases passed |
| Convert microphone buffers | A cached converter handles three consecutive 48 kHz → 16 kHz buffers without replaying input; matching-rate output owns its samples; changed routes fail; empty buffers produce no input | Three `SpeechAnalysisTests` cases passed |
| Cancel preparation | Stop from the initial preparation callback prevents further startup; cancelled startup produces no update | Two `SpeechCaptureCancellationTests` cases passed in the focused native run |

## How it works

`SpeechChallengeCapture` selects a supported English `SpeechTranscriber`, falling
back to `DictationTranscriber`, installs assets, prepares the analyzer, and then
requests microphone permission. The 20-second capture timer starts only after
the audio engine starts. Results use the existing `RecognizedWordMatch` rule.
An individual final segment does not end an attempt.

The main actor serializes startup, updates, and stop. Stop invalidates the capture
immediately, ends the input stream, cancels asset preparation and result tasks,
stops the microphone, and deactivates only the audio session this capture owns.
`stopAndWait()` additionally waits for analyzer cancellation before example
playback. Asynchronous teardown retains only the old analyzer and never modifies a
new capture's state.

## Key choices

The converter is cached for the audio tap and supplies each source buffer once.
Each converted buffer owns its samples, so the analyzer never retains reusable
microphone memory. No audio file, cloud request, legacy speech permission, or
iOS 27-only `AnalyzerInputConverter` is used.

Capture uses `.playAndRecord`, `.measurement`, and
`[.mixWithOthers, .defaultToSpeaker]`. The previous `.record` plus `.duckOthers`
combination is not supported: the installed SDK's `AVAudioSessionTypes.h` limits
ducking to compatible playback categories. Whether AlarmKit delivery and routing
remain satisfactory while recording still requires a ringing iPhone test.

## What we checked

RED: before adding the helpers, the following command failed on missing
`SpeechTranscript` and `SpeechBufferConverter` references in the new test file.
The integration coordinator also observed these intended missing-type failures
in a native `build-for-testing` run.

```sh
xcrun swiftc -module-cache-path /private/tmp/himorning-speech-module-cache -I /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/lib -F /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/Library/Frameworks -typecheck apps/ios/HiMorningTests/SpeechAnalysisTests.swift
```

GREEN: compiled the actual helper source and the same test file into a local
macOS XCTest runner, then ran its `defaultTestSuite`. Result:

```text
Executed 7 tests, with 0 failures (0 unexpected).
```

The actual adapter plus helper source also passed direct SDK 27 typechecking with
`-swift-version 6 -target arm64-apple-ios26.0-simulator`. This used the real
`HiMorningCore` module and a temporary identity `appText` shim, so it verifies API
availability and concurrency typing, not the rest of the app or its localization.
The native cancellation tests also typechecked against that app-source slice.

For the helper runner, instrumentation used `-profile-generate
-profile-coverage-mapping`, then these commands:

```sh
LLVM_PROFILE_FILE=/private/tmp/himorning-speech.profraw /private/tmp/himorning-speech-tests
xcrun llvm-profdata merge -sparse /private/tmp/himorning-speech.profraw -o /private/tmp/himorning-speech.profdata
xcrun llvm-cov report /private/tmp/himorning-speech-tests -instr-profile=/private/tmp/himorning-speech.profdata apps/ios/HiMorning/SpeechTranscript.swift apps/ios/HiMorning/SpeechBufferConverter.swift
```

Measured helper coverage: 43/43 lines (100%), 10/10 functions (100%), and
25/31 regions (80.65%). Transcript regions: 100%; converter regions: 68.42%.
Converter allocation/framework-error paths were not forced. This is helper-only
macOS coverage, not overall feature coverage or proof of iOS speech behavior.

No checkpoint was staged or committed: the approved orchestration plan reserves
all staging/committing for Gate 2 confirmation.

## Limits and next steps

The focused native unit run passed 17 tests, including all seven helper cases,
both cancellation cases, and four `SpokenExampleTests`. The iOS 27 simulator
terminated the UI runner before it established a test connection, so those UI
assertions remain unexecuted; see [audio-and-speech.tdd.md](audio-and-speech.tdd.md).
A real iPhone must verify module and
locale selection, missing-assets/download cancellation, denied microphone
permission, segmented recognition, the Dictation fallback, the capture timeout,
interruptions, speaker/Bluetooth changes, ringing-alarm mixing, and example/capture
handoff. The deterministic tests do not claim to reproduce these framework and
hardware conditions. Total adapter/feature coverage remains unmeasured here.

## Read next

- [Approved audio and speech plan](../archive/design/AUDIO-AND-SPEECH-PLAN.md)
- [SpeechAnalyzer](https://developer.apple.com/documentation/speech/speechanalyzer)
- [SpeechTranscriber](https://developer.apple.com/documentation/speech/speechtranscriber)
- [DictationTranscriber](https://developer.apple.com/documentation/speech/dictationtranscriber)
