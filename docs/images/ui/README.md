# Historical native screen captures

These images preserve the earlier pilot's screens in English and Vietnamese.
They do not show the current card/editor, challenge catalog, local camera flow
or subscription state. Use the [current UI guide](../../UI-DESIGN.md) for behavior.

**Status:** Historical set of 20 actual, unedited XCUITest screenshots: 10 screens/states in two
languages. **Audience:** Product and code reviewers. These are simulator captures,
not generated mockups or a claim of 20 distinct product screens.

## Capture details

| Field | Source |
|---|---|
| CI | [Run 38293447198](https://github.com/thanhdanh/HiMorning/actions/runs/38293447198), both jobs passed |
| Source commit | `f648f9151c38abe40190dc69a8d09d601e22ebb6` |
| Capture date | 12 October 2026, 18:52:46–18:54:18 UTC; 13 October in Vietnam |
| Simulator | iPhone 17 Pro, iOS 26.4.1; Xcode 26.6 |
| Artifact | `ios-ui-evidence`, exported from `/tmp/himorning-ui.xcresult` |
| Image size | 1206 × 2622 PNG; copied byte-for-byte without resizing or retouching |

The artifact's `manifest.json` connects attachment names, exported filenames and
test identifiers. All 20 expected names were present, were not marked as failure
attachments, and matched the committed PNG bytes. The files remain in Git after
the temporary CI artifact expires. Earlier four-image evidence remains available
at [commit 9aa77d7](https://github.com/thanhdanh/HiMorning/tree/9aa77d7/docs/images/ui).

## What each image shows

| State | English | Vietnamese |
|---|---|---|
| Empty home | [home-en](home-en.png) | [home-vi](home-vi.png) |
| New alarm, Gentle | [alarm-editor-en](alarm-editor-en.png) | [alarm-editor-vi](alarm-editor-vi.png) |
| Balanced mode | [balanced-en](balanced-en.png) | [balanced-vi](balanced-vi.png) |
| Focused mode | [focused-en](focused-en.png) | [focused-vi](focused-vi.png) |
| Sound choices and preview volume | [sounds-en](sounds-en.png) | [sounds-vi](sounds-vi.png) |
| Rehearsal ready | [challenge-ready-en](challenge-ready-en.png) | [challenge-ready-vi](challenge-ready-vi.png) |
| Camera/cloud consent | [consent-en](consent-en.png) | [consent-vi](consent-vi.png) |
| AI unavailable | [ai-unavailable-en](ai-unavailable-en.png) | [ai-unavailable-vi](ai-unavailable-vi.png) |
| Self-confirmed | [self-confirmed-en](self-confirmed-en.png) | [self-confirmed-vi](self-confirmed-vi.png) |
| Trial ended | [stopped-en](stopped-en.png) | [stopped-vi](stopped-vi.png) |

The first five states come from `testEnglishGentleDefaultAndCancelWithoutPermissions`
and `testVietnameseGentleDefaultAndCancelWithoutPermissions`. The remaining states
come from `testEnglishBrandAndRehearsalRecovery` and
`testVietnameseBrandAndRehearsalRecovery`. A fifth test checks saved language after
relaunch. All five passed with zero failures.

Rehearsal uses a transient Balanced sample at 06:30, without scheduling an alarm.
The unavailable state comes from the real unconfigured cloud path, not a fake AI
answer. Self-confirmation and ending the trial are explicit local outcomes. The
consent screen names the adapter used at that old revision. It is not the
current product consent or evidence of today's cloud configuration.

## Reproduce or collect new evidence

Reproducing these exact images requires their recorded source revision and toolchain.
Do not run the current suite and describe its output as this historical gallery.
For new captures, follow [Running](../../RUNNING.md), keep simulator signing for
Keychain tests, use a fresh result-bundle path and export attachments with
`xcrun xcresulttool export attachments`. Record revision, device/runtime and test
selector alongside each new image. A screenshot does not prove sound playback,
real movement detection or alarm delivery.

## Limits and next steps

These images do not validate physical-device alarm delivery, camera accuracy,
sound, VoiceOver, large text or dark mode. They show the native pilot, not every
screen in the earlier web concept or a planned Android app.

[UI guide](../../UI-DESIGN.md) · [Architecture](../../ARCHITECTURE.md) ·
[Executed design RED/GREEN](../../tdd/native-design-parity.tdd.md)
