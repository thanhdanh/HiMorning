# Alarm catalog TDD evidence

> **Dated evidence.** Commands, approvals, test totals and local paths below
> describe the original run. They are not current setup instructions or release
> status. See [current validation](../VALIDATION.md) for newer results and known gaps.

Give the alarm picker fifteen stable choices with individual offline previews.

**Status:** Core verification passed; native integration and device checks are
reported by the parent implementation run. **Audience:** iOS reviewers.

## Source and journeys

The approved [audio and speech plan](../archive/design/AUDIO-AND-SPEECH-PLAN.md) supplies the scope.
A person selects and saves any catalog sound, can preview another row without
changing that selection, and retains existing saved system/sunrise/softChime IDs.
Another selection, leaving the picker, or inactive/background state stops previews.

## RED and GREEN evidence

Tests were added before catalog or picker implementation. Initial sandbox-only
runs could not write the compiler's module cache; these environment errors are
not counted as RED. The same tests then ran with the approved compiler access.

| Guarantee | Test target | RED | GREEN |
| --- | --- | --- | --- |
| Catalog has fifteen unique stable IDs, including legacy values | `AlarmSoundTests.testCatalogKeepsLegacyIDsAndAddsTwelveDistinctChoices` and portable sound journey | SwiftPM executed the test: count 3 versus 15, with all twelve additions absent | All expected IDs pass |
| Every catalog sound survives file persistence and Codable decoding | `AlarmSoundTests.testEverySoundPersistsAndRestoresWithoutChangingTheSelection` and portable sound journey | Existing three choices already passed; catalog RED limits this to legacy IDs | All fifteen selections pass |
| Every custom choice has a nonempty WAV named by its raw value | `AlarmSoundTests.testEveryCustomCatalogChoiceHasANonemptyWAVResource` and portable sound journey | Custom count 2 versus 14 | Fourteen resources pass RIFF/WAVE checks |
| All custom resources decode from the same main bundle used by scheduling | `AlarmSoundResourceTests` | Added before assets | Native run is reported separately; not claimed here |
| Groups include every catalog choice once | `AlarmSoundResourceTests.testSoundGroupsContainEveryChoiceExactlyOnce` | Catalog RED above | Native run is reported separately |

Commands run from the repository root:

```sh
swift test --package-path apps/ios/HiMorningCore --filter AlarmSoundTests
sh scripts/test-swift.sh
swift test --package-path apps/ios/HiMorningCore
```

The filtered RED run compiled and executed three tests with fifteen intended
failures (two catalog-count failures, twelve missing IDs, one custom-resource
count failure). The portable RED executable failed with
`Precondition failed: Expected 3 == 15`, exit 133. No production source was edited
until the portable runtime RED had been observed.

After implementation the full SwiftPM run passed twenty XCTest tests, including
the three new catalog tests, with zero failures. The portable runner reported
`PASS: 28 portable Swift domain and integration journeys`. Its measured coverage
was 98.05% lines / 87.28% regions overall, and 99.16% lines / 82.58% regions in
`Pilot.swift`. This is core coverage, not native UI or audio-device coverage.

## Asset checks

The twelve conversion outputs were decoded by a temporary development-only
SoundFile/libsndfile tool. Assertions verified finite samples, 44.1 kHz mono,
7–9 second duration, conservative peak no greater than 0.501, and zero endpoints.
`afinfo apps/ios/Resources/pizzicatoDawn.wav` independently confirmed 44.1 kHz
mono 16-bit PCM and 7.659206 seconds. The twelve WAV files total 8,438,266 bytes.
The official source archive hash, original filenames, author, license, and exact
arrangement changes are recorded in [Resources/README](../../apps/ios/Resources/README.md).

## Scope and remaining checks

The existing serial-queue preview helper is reused. Caller cleanup was extended
to scene changes, while per-row preview actions keep selection unchanged. Native
unit integration passed on October 15: `AlarmSoundResourceTests` decoded all
fourteen custom WAVs and verified the groups; the focused native run passed
17 tests total. The focused UI runner was terminated by the iOS 27 simulator
before it established a test connection, so its UI/lifecycle assertions did not
run; see [audio-and-speech.tdd.md](audio-and-speech.tdd.md).

No subjective audition, phone-speaker comfort, locked-screen AlarmKit playback,
looping, route-change, or interruption result is claimed. Those need an iPhone.
No runtime dependency, shared wire contract, scheduler mapping, or migration was
added. Existing dirty editor/app/preview work was retained.

No files were staged or committed: the orchestration skill's Gate 2 requires
human confirmation and overrides TDD checkpoint suggestions.
