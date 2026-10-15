# Sound preview and alert runtime warnings

Use runtime stacks to distinguish app defects from simulator diagnostics, then
verify the affected UI journeys without hiding console output.

**Status:** Fixes implemented; simulator UI journeys passed on 15 October 2026.
**Audience:** iOS developers and reviewers.

## What failed

On 14 October 2026, iOS 27.0 simulator logs contained five audio hang-risk warnings
and two SwiftUI publishing warnings during manual use. Simulator unified logs
included image UUIDs and offsets. Matching the app debug dylib UUID and resolving
the offsets with `atos` identified these app frames:

| Warning | App frame |
|---|---|
| Main-thread audio activation | `AlarmEditor.preview()`, original line 86 |
| Publishing during view updates | `PilotModel.error.setter`, from the Home alert binding at original line 145 |

`LoudnessManager` also reported missing hardware configuration in this simulator.
The `cannot add handler` message has not been attributed to an app frame. Neither
message was suppressed or treated as proof of a failed alarm.

## How the fix works

`SoundPreview` owns one audio player on a serial queue. Creation, playback, stop,
volume and teardown all run off the main thread. Commands retain their queue order,
so a later stop cannot be overtaken by an earlier preview request. This preserves
iOS 26 support without relying on audio activation APIs introduced in iOS 27.

The Home alert binding does nothing when there is no error. When dismissal clears
an error, it schedules the change after the current view update and checks that
the shown message still matches. The explicit confirmation button remains a user
action. No blanket delays were added to other model publications.

## What we checked

All eight UI journeys passed in the preview implementation run, including the
sound-preview journey. It previews both bundled sounds, changes preview volume,
switches to system sound, leaves the editor and opens it again. The initial suite
had language/state isolation failures; DEBUG fixtures now isolate preview state
and initial language, while the explicit language-persistence journey still tests
the real preference across relaunch.

The final UI log `/private/tmp/himorning-preview-final-v2.log` contained no
`AVAudioSession_iOS`, SwiftUI publishing or `LoudnessManager` warning matches.
This is scoped to these simulator journeys, not a claim about every hardware path.
See [preview evidence](no-card-preview.tdd.md) for result bundles and the separately
resolved unsigned Keychain failure in the earlier combined result.

## Limits and next steps

Simulator audio and missing hardware configuration do not establish physical-device
sound quality or AlarmKit reliability. Verify audio routing, interruptions, preview
volume and alarm playback on an iPhone. This change does not alter AlarmKit volume,
subscription checks or camera behavior.

## Read next

- [Alarm editor compiler fix](xcode-27-alarm-editor.tdd.md)
- [Run HiMorning](../RUNNING.md)
- [Release readiness](../RELEASE-READINESS.md)
