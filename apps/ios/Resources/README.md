# Alarm sounds

Bundle fifteen offline choices for the alarm picker: system default, two original
HiMorning sounds, and twelve arrangements from Kenney Music Jingles.

**Status:** Implemented; device audition and locked-screen delivery need checking.
**Audience:** iOS developers and release reviewers.

## Original sounds

`sunrise.wav` and `softChime.wav` are original synthesized, five-second mono PCM chime sketches created for HiMorning. No third-party recording or voice is included. Gentle attack, decay and conservative digital peaks are intentional; these are pilot assets, not validated release sounds. Test perceptual loudness, OS looping, device volume, sleep comfort and accessibility on real hardware. Preview volume is separate from the system alarm volume.

## Kenney provenance and license

- Author: Kenney Vleugels (Kenney.nl).
- Pack: [Music Jingles](https://kenney.nl/assets/music-jingles), 85 assets, version 1.0.
- Creator description: [85 short music jingles](https://opengameart.org/content/85-short-music-jingles).
- Download: [official archive](https://kenney.nl/media/pages/assets/music-jingles/f37e530b9e-1677590399/kenney_music-jingles.zip), retrieved October 15, 2026.
- Archive SHA-256: `b729ba57959bd58793d2c5cafa348aaf2655d354f3da35ec4729e03ec77197b8`.
- License: [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/), allowing personal and commercial use. Attribution is not mandatory. The supplied license text is retained in `Kenney-Music-Jingles-License.txt` with whitespace normalized.

Only the twelve selected motifs are bundled. Motif numbers 00–11 are distinct;
the catalog does not pad its count with alternate instruments for one motif.
All source paths below are relative to the archive's `Audio/` directory.

| Bundled WAV / stable ID | Original filename | Repetitions | Duration |
| --- | --- | ---: | ---: |
| `pizzicatoDawn` | `Pizzicato jingles/jingles_PIZZI00.ogg` | 7 | 7.659 s |
| `pizzicatoSteps` | `Pizzicato jingles/jingles_PIZZI01.ogg` | 5 | 8.012 s |
| `pizzicatoRise` | `Pizzicato jingles/jingles_PIZZI02.ogg` | 5 | 7.779 s |
| `pizzicatoBloom` | `Pizzicato jingles/jingles_PIZZI03.ogg` | 5 | 8.734 s |
| `steelShimmer` | `Steel jingles/jingles_STEEL04.ogg` | 5 | 7.544 s |
| `steelBreeze` | `Steel jingles/jingles_STEEL05.ogg` | 5 | 7.724 s |
| `steelMorning` | `Steel jingles/jingles_STEEL06.ogg` | 4 | 7.901 s |
| `steelSparkle` | `Steel jingles/jingles_STEEL07.ogg` | 4 | 8.619 s |
| `saxHello` | `Sax jingles/jingles_SAX08.ogg` | 8 | 7.925 s |
| `saxStroll` | `Sax jingles/jingles_SAX09.ogg` | 8 | 7.783 s |
| `saxGlow` | `Sax jingles/jingles_SAX10.ogg` | 6 | 7.435 s |
| `saxDaybreak` | `Sax jingles/jingles_SAX11.ogg` | 7 | 8.550 s |

## Conversion and playback

The Ogg/Vorbis originals were decoded with temporary development tooling
(`soundfile` 0.14.0/libsndfile and the bundled NumPy). Neither is an app dependency.
Although `afconvert -hf` lists Ogg/Vorbis locally, actual input conversion failed
with `Couldn't open input file ('dta?')`; no successful `afconvert` decode is claimed.

Each arrangement averages the stereo channels into mono at the original 44,100 Hz,
adds a 15 ms linear fade-in and 40 ms fade-out to each motif, scales its absolute
peak to 0.5 (approximately −6 dBFS), and repeats the full motif plus 600 ms silence
the number of times above. The repetition count is `round(8 / (motifSeconds + 0.6))`.
Each result is a 16-bit little-endian PCM WAV with a clean zero-valued beginning
and a silent ending. No voice, trimming of the source motif, or synthetic notes
were added. The twelve new WAVs total 8,438,266 bytes (about 8.05 MiB).

The native scheduler resolves every custom sound as `rawValue + ".wav"` in the
main app bundle. The system choice has no app-owned file. The preview uses the
existing player and volume control; it stops on another selection, navigation,
or inactive/background state. Previewing a row does not change the saved choice.

## What we checked

The conversion self-check decoded every output and checked finite samples, mono,
44.1 kHz, 7–9 second duration, peak no greater than 0.501, and zero endpoints.
The core runners cover catalog IDs, persistence, and WAV headers; native resource
tests decode every custom WAV from the application bundle.

## Limits and next steps

No subjective audition, phone-speaker quality, locked-screen looping, perceptual
loudness, Bluetooth route, or AlarmKit delivery result is claimed by signal checks.
Audition these on an iPhone before release; the titles are catalog names, not
measured acoustic or wake-up guarantees. See the [implementation plan](../../../docs/AUDIO-AND-SPEECH-PLAN.md).
