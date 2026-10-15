# Alarm sounds and on-device speech

Give people more pleasant alarm sounds and a spoken example for the English
read-aloud challenge. Move speech recognition to Apple's current on-device APIs
while preserving the existing word-match completion rule.

**Status:** Implemented and verified in focused core/native tests. See the
[current feature list](../README.md#implemented-pilot). **Audience:** iOS implementation and review. Research
snapshot: October 15, 2026.

## At a glance

| Area | Planned behavior | Important limit |
| --- | --- | --- |
| Alarm catalog | 15 choices: system default, the existing two sounds, and 12 curated additions | New sounds must pass audition and license checks before inclusion |
| Sound picker | Localized names, useful groups, and individual previews using the existing player | System default keeps its current no-preview behavior |
| Recognition | `SpeechAnalyzer` with `SpeechTranscriber`, or `DictationTranscriber` on compatible older hardware | Check `en-US`, hardware, and downloaded assets at runtime |
| Spoken example | An explicit Listen button using `AVSpeechSynthesizer` and an `en-US` voice | Playback and microphone capture must exclude each other |

No additional package dependency is planned. Keep the iOS 26 deployment target.
UI text ships in English and Vietnamese; the English challenge sentence and its
speech locale stay English in either UI language.

## How it works

A person opens the existing alarm sound picker, selects a sound, and can preview
each bundled choice at the existing preview level. A new preview stops
the previous one. Leaving the picker or backgrounding the app stops playback.
Saving persists the stable sound ID, which the native scheduler resolves to the
bundled `rawValue + ".wav"` name. The system option continues using the system
default. Preview volume does not promise control over the operating system's
locked-screen alarm volume; keep the existing slider explicitly preview-only.

In the read-aloud challenge, Listen speaks the displayed English sentence. Starting
Listen stops and invalidates recognition first. Enable recording only after the
example finishes or its cancellation callback completes; the person then starts
recording explicitly. Never start the microphone automatically after an example.
Stop, leaving the challenge, backgrounding, timeouts, and late callbacks must not
leave audio running or complete a cancelled attempt. The app must not pass a
challenge from its own example playback.
Opening the challenge through `OpenMorningIntent` must not stop the scheduled
alarm. Preserve the existing coordinator's `finish` ownership and accessible
Stop/self-confirm actions while changing audio sessions.

Before capture, check the supported recognition module and `en-US` locale, then
the required speech assets. Show preparation, permission, or unavailable states
with a usable recovery path instead of silently waiting. Asset installation can
need a network connection; recognized audio remains on the device. Keep the
existing Stop/self-confirm recovery available when recognition cannot start.

Recognition still feeds the existing `SpeechUpdate` path and requires a
`RecognizedWordMatch` score of at least 0.8. `AVSpeechSynthesizer` provides the example; it
does not analyze speech. Pronunciation, accent, and fluency scoring are outside
this change.

## Key choices

### Sound source and bundling

Use [Kenney Music Jingles](https://kenney.nl/assets/music-jingles) as the first
source: its pack has 85 files under CC0. The
[creator's pack description](https://opengameart.org/content/85-short-music-jingles)
identifies 17 motifs in five instrument variants.
Choose 12 distinct motifs, not multiple instruments playing the same tune. Kenney's
[support page](https://kenney.nl/support) confirms commercial use and that
attribution is not required. Curate 12 additions only after listening for a calm
start, audible detail on a phone speaker, and a clean ending or loop boundary.
Choose names and groups from the actual selected assets, rather than promising
categories the pack does not support.

Keep the existing PCM WAV convention. Convert the source OGG files with the
platform's `afconvert`; its local format listing includes Ogg/Vorbis, though actual
selected-file conversion still needs validation. Prefer short excerpts around
8–12 seconds as an editorial and bundle-size choice, not an asserted AlarmKit
limit. Record the
pack URL, original filename, CC0/license evidence, and any conversion or trimming
in the resource README; retain the supplied license. The 15 choices require 14
WAV files because system default has no app-owned file. Twelve eight-second,
44.1 kHz mono 16-bit additions would occupy approximately 8.5 MB before packaging;
measure the actual bundle growth.

[Kenney Interface Sounds](https://kenney.nl/assets/interface-sounds) also has a
CC0 pack, but its UI cues are a secondary source rather than the main alarm
catalog. [Freesound](https://freesound.org/help/faq/#licenses-0) has mixed licenses;
use it only for individually verified CC0 files if Kenney lacks a suitable cue.
Exclude Mixkit from the repository's bundled assets: its
[sound-effects license](https://mixkit.co/license/modal/sfxFree/) allows commercial
end products but restricts source-file redistribution. Do not add a runtime asset
store, download API, file import, or audio-processing package.

Apple's [`AlertSound.named(_:)`](https://developer.apple.com/documentation/activitykit/alertconfiguration/alertsound/named(_:))
supports files in the main bundle or `Library/Sounds`; keep the current main-bundle
route and explicit extension. No authoritative AlarmKit-specific codec, duration,
or volume guarantee was established in this research. Do not apply the local
notification 30-second rule to AlarmKit as though it were verified. Confirm actual
delivery on a locked iPhone.

### One speech pipeline

Use [`SpeechAnalyzer`](https://developer.apple.com/documentation/speech/speechanalyzer)
with [`SpeechTranscriber`](https://developer.apple.com/documentation/speech/speechtranscriber)
as the primary module. Where its hardware support is unavailable, select
[`DictationTranscriber`](https://developer.apple.com/documentation/speech/dictationtranscriber)
within the same analyzer pipeline after checking locale support. Dictation uses
the legacy on-device models and does not offer network-only languages.

Use [`AssetInventory`](https://developer.apple.com/documentation/speech/assetinventory)
for readiness and installation before opening the microphone or starting the
existing 20-second capture timeout. Allow progress and cancellation while assets
are being prepared. Convert microphone audio with `AVAudioConverter` to the
analyzer's `bestAvailableAudioFormat`; do not use the iOS 27-only
`AnalyzerInputConverter`. The iOS 26 presets are `.progressiveTranscription` and
`.progressiveShortDictation` for the respective modules.

Analyzer results are segmented. Append each final segment once and clear its
volatile text; partial results replace the volatile segment. Score the assembled
transcript using the existing 80% rule. A final segment alone does not mean the
whole attempt has ended. Preserve the cancellation guard, audio-session cleanup,
and unavailable-state recovery. Normal cancellation uses
`await analyzer.cancelAndFinishNow()`; an intentional final flush must end the
input stream first. Do not persist audio or add locale-reservation machinery for
this single-locale flow.

The new analyzer path needs microphone permission, not the old
`SFSpeechRecognizer` authorization flow, per
[Apple's permission rules](https://developer.apple.com/documentation/speech/asking-permission-to-use-speech-recognition).
Remove that legacy engine and its speech
permission strings/config only after a global reference check confirms nothing
still uses them. Keep microphone purpose text and its English/Vietnamese
localizations accurate. No cloud transcription or new backend contract is planned.

Use [`AVSpeechSynthesizer`](https://developer.apple.com/documentation/avfaudio/avspeechsynthesizer)
for the explicit example action. Never auto-speak an answer into an active capture
session. Make playback/capture exclusion part of the tested capture lifecycle,
including asynchronous stop and stale recognition results. Use the real
`didFinish`/`didCancel` callbacks to release the example state; evaluate
[`usesApplicationAudioSession = false`](https://developer.apple.com/documentation/avfaudio/avspeechsynthesizer/usesapplicationaudiosession)
for synthesis so it does not take ownership of the capture session. If an English
voice is unavailable, explain that the example cannot play and keep the reading
and recovery actions usable.

### Scope and compatibility

| Existing area | Work it must receive |
| --- | --- |
| `HiMorningCore/.../Pilot.swift` | Add sound choices without changing `system`, `sunrise`, or `softChime` raw values or saved-alarm decoding |
| `HiMorningApp.swift` and EN/VI localization resources | Sound names/groups, Listen/state labels, and accurate permission text |
| `AlarmEditor.swift`, `SoundPreview.swift` | Catalog presentation, per-choice previews, and preview lifecycle |
| `NativeAlarmScheduler.swift` and bundled resources | Ensure every custom ID resolves to its actual WAV in the app bundle |
| `SpeechChallengeCapture.swift`, `ChallengeView.swift` | Analyzer readiness/capture, Dictation fallback, example playback, and existing completion/recovery path |
| `project.yml`, InfoPlist localizations | Bundle resources and framework/permission configuration as needed; keep iOS 26 |
| Both core runners, capture tests, UI tests | Persistence/catalog, resource validity, speech/audio lifecycle, and bilingual UI coverage |

Preserve unrelated work already present in the editor, app, preview helper, and UI
tests. No data deletion, saved-alarm migration, server change, or new shared
contract is expected. Existing callers and legacy sound selections must continue
to work.

## Task list

Each implementation slice starts with new failing tests for its behavior, then the
smallest change that passes them. Phase 3 scaffold is unnecessary.

1. **Catalog through real alarm scheduling.** Audition and license-check 12
   additions; add stable IDs, localized names/grouping, resources, and provenance.
   Test legacy saved values and the full catalog in both core runners. Test custom
   filename/bundle mapping and decode every bundled WAV in the app/resource checks.
2. **Sound selection through preview cleanup.** Extend the existing picker/player
   for the catalog. Test selection persistence, preview switching, stop on
   navigation and scene-background transitions, and accessible English/Vietnamese
   labels. Retain the system default's lack of preview controls.
3. **Microphone through on-device recognition.** Implement module/locale/asset
   readiness, SpeechTranscriber and DictationTranscriber selection, and compatible
   audio conversion. Feed the current transcript/matching path. Test denied
   permission, missing assets, unavailable modules, multi-segment assembly,
   replacing partials, cancellation during installation/capture, timeout, and late
   callbacks; keep recovery usable.
4. **Listen through safe capture handoff.** Add the explicit synthesized example
   and localized accessible state. Test Listen→record, record→Listen, Stop,
   navigation/background, and stale callbacks so app playback cannot earn a pass.
5. **Verify and review the whole flow.** Run the commands below and native tests,
   inspect relevant coverage, and resolve review findings. Include a security
   review because this changes microphone/user-audio handling. Validate custom
   sounds and speech on real hardware before calling the feature complete.

**Gate 1:** approve this task list before implementation. **Gate 2:** after tests
and review, present the diff summary and proposed conventional commit messages;
do not stage or commit until confirmation.

## Try it

After implementation, run from the repository root with the pinned development
tooling and Xcode available:

```sh
sh scripts/test-swift.sh
swift test --package-path apps/ios/HiMorningCore
xcodegen generate --spec apps/ios/project.yml
xcodebuild -project apps/ios/HiMorning.xcodeproj -scheme HiMorning -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /private/tmp/himorning-audio-derived CODE_SIGNING_ALLOWED=NO build
```

For native unit/UI tests, discover an installed simulator with `xcrun simctl list
devices available`, then use its ID and a result bundle with the existing Xcode
test setup. Do not hardcode a simulator UUID. Inspect native coverage with
`xcrun xccov`; target at least 80% of new testable behavior where measurable, and
report actual coverage separately from manual device evidence. Existing core
coverage or mocked framework results do not prove the new Apple adapters work.

## What we checked

Planning compared the current sound enum/persistence, picker/player, AlarmKit
mapping, speech capture/matching, localization/config, and test surfaces with the
primary sources linked above. Xcode 27 is available locally; compatibility must
still be checked against the iOS 26 deployment target. The existing CI uses iOS
26.2 for its StoreKit test setup.

Implementation evidence is in [alarm-sounds.tdd.md](tdd/alarm-sounds.tdd.md),
[speech-analysis.tdd.md](tdd/speech-analysis.tdd.md), and
[audio-and-speech.tdd.md](tdd/audio-and-speech.tdd.md). No physical iPhone
audition, locked-device AlarmKit delivery, or live microphone/asset-download run
has been completed. Backend tests remain unnecessary because this change has no
server or shared-contract impact.

## Limits and next steps

The next step is Gate 1 approval, followed by asset audition and the ordered
implementation slices. A real iPhone check must cover locked-screen/background
AlarmKit delivery for every new sound, first-use asset installation, an offline
attempt after installation, the applicable Dictation fallback, and Listen/capture
handoff. Also open a challenge while an alarm is actually ringing: microphone/TTS
session changes must not prematurely finish or stop it. Include interruptions and
speaker/Bluetooth route changes. Simulator success cannot
settle wake-up loudness, speaker quality, AlarmKit mixing/ducking,
hardware-dependent speech support, or interruption behavior.

## Read next

- [Apple: Bring advanced speech-to-text to your app](https://developer.apple.com/videos/play/wwdc2025/277/)
- [Apple: Wake up to the AlarmKit API](https://developer.apple.com/videos/play/wwdc2025/230/)
- [Repository documentation template](DOC-TEMPLATE.md)
