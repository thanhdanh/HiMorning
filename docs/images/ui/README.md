# Native screen captures

These images let reviewers see the current pilot in English and Vietnamese.

**Status:** Actual, unedited XCUITest screenshots. **Audience:** Product and code
reviewers. The editor images show the top of a scrollable form; remaining weekdays
and sound controls are below the viewport.

## Capture details

| Field | Source |
|---|---|
| CI | [Run 38155392322](https://github.com/thanhdanh/HiMorning/actions/runs/38155392322), both jobs passed |
| Source commit | `72e1bb9b7b1396c75bee8bfe6e7276952003e05d` |
| Capture date | 11 October 2026, 16:28–16:29 UTC |
| Simulator | iPhone 17 Pro, iOS 26.4; Xcode 26.6 |
| Artifact | `ios-ui-evidence`, exported from `/tmp/himorning-ui.xcresult` |
| Image size | 1206 × 2622 PNG, copied without resizing or retouching |

## What each image shows

| Image / attachment name | UI test |
|---|---|
| [home-en](home-en.png), [alarm-editor-en](alarm-editor-en.png) | `testEnglishGentleDefaultAndCancelWithoutPermissions` |
| [home-vi](home-vi.png), [alarm-editor-vi](alarm-editor-vi.png) | `testVietnameseGentleDefaultAndCancelWithoutPermissions` |

The attachment names map to exported filenames through the artifact's
`manifest.json`. Both journeys open the editor, check the Gentle copy and cancel.
A third test checks that the chosen language survives relaunch. The four committed
images remain available after the temporary CI artifact expires.

## Reproduce

Run the native scheme's tests using the [setup guide](../../RUNNING.md). CI uses:

```sh
xcodebuild -project apps/ios/HiMorning.xcodeproj -scheme HiMorning \
  -destination 'platform=iOS Simulator,id=YOUR_SIMULATOR_ID' \
  CODE_SIGNING_ALLOWED=NO -resultBundlePath /tmp/himorning-ui.xcresult test
xcrun xcresulttool export attachments --path /tmp/himorning-ui.xcresult \
  --output-path /tmp/himorning-ui-attachments
```

Use a fresh result-bundle path for each run. Status-bar times can differ. No
camera, alarm permission or cloud inference is involved in these captures.

## Limits and next steps

These images do not validate physical-device alarm delivery, camera accuracy,
sound, VoiceOver, large text or dark mode. They show the native pilot, not every
screen in the earlier web concept or a planned Android app.

[UI guide](../../UI-DESIGN.md) · [Architecture](../../ARCHITECTURE.md)
