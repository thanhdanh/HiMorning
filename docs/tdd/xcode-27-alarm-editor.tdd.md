# Alarm editor build fix on Xcode 27

Record the reported compiler failure and the smallest change that restores the
simulator build. This is build and UI evidence, not device alarm validation.

**Status:** Simulator build and both targeted UI tests pass.
**Audience:** iOS developers and reviewers.

## How it works

`AlarmEditor` still owns the selected wake mode. Its `ForEach` now calls the
private `modeButton` helper, giving Swift a separate expression to type-check.
The button action, label, colors, spacing and accessibility modifiers are unchanged.
No new dependency or behavior was added.

## What we checked

On 14 October 2026, with Xcode 27.0 (27A266a), the unchanged source failed at
`AlarmEditor.swift:43` with:

> the compiler is unable to type-check this expression in reasonable time

The generic iOS Simulator Debug build failed for arm64 and x86_64. After extracting
the mode button, the same command completed with `BUILD SUCCEEDED`:

```sh
xcodebuild -project apps/ios/HiMorning.xcodeproj -scheme HiMorning \
  -configuration Debug -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' build
```

The existing English and Vietnamese alarm editor UI tests passed on an iPhone
18 Pro simulator with iOS 27.0: **2 tests, 0 failures**, `TEST SUCCEEDED`.
They cover opening the editor, changing modes, selecting a sound and cancelling
without requesting alarm access.

```sh
xcodebuild -project apps/ios/HiMorning.xcodeproj -scheme HiMorning \
  -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
  -parallel-testing-enabled NO \
  -only-testing:HiMorningUITests/PilotUITests/testEnglishGentleDefaultAndCancelWithoutPermissions \
  -only-testing:HiMorningUITests/PilotUITests/testVietnameseGentleDefaultAndCancelWithoutPermissions \
  CODE_SIGNING_ALLOWED=NO test
```

Local diagnostic files are `/private/tmp/himorning-build-debug.log` (RED),
`/private/tmp/himorning-build-fixed.log` (GREEN),
`/private/tmp/himorning-editor-tests.log` and
`/private/tmp/himorning-editor-xcode27.xcresult`. Temporary files are not committed
and may be removed by the operating system.

## Limits and next steps

The build emits linker warnings about an ambiguous target atom; those warnings
were not investigated by this compiler fix. Physical-device signing, alarm
reliability, TestFlight distribution and the full test suite were not checked.

## Read next

- [Run HiMorning](../RUNNING.md)
- [Existing UI tests](../../apps/ios/HiMorningUITests/PilotUITests.swift)
- [Release readiness](../RELEASE-READINESS.md)
