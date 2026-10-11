# Language and copy

HiMorning supports English and Vietnamese in the native app. The copy should feel
clear and kind when someone has just woken up.

**Status:** Both catalogs and the saved language picker are implemented. Native
build and all three language UI journeys passed in [CI](https://github.com/thanhdanh/HiMorning/actions/runs/38135338781).
See [TDD evidence](tdd/cost-optimized-pilot.tdd.md) for scope and earlier failures.

## Choosing a language

Open the globe menu on the home screen. Choose **Use device language**, **English**
or **Vietnamese**. The choice is saved locally as `appLanguage`.

Device mode uses the first supported language in the device's preference list.
Vietnamese regions such as `vi-VN` resolve to `vi`; English regions resolve to `en`.
If neither language is available, the app uses English. Changing language does
not change alarm times, weekdays, modes or challenge targets.

## Where copy lives

| File | Purpose |
|---|---|
| `ios/Resources/en.lproj/Localizable.strings` | English source copy and keys |
| `ios/Resources/vi.lproj/Localizable.strings` | Matching Vietnamese translations |
| `ios/Resources/*/InfoPlist.strings` | Camera and alarm permission explanations |
| `ios/HiMorning/Localization.swift` | Foundation bundle lookup and count formatting |
| `ios/HiMorningCore/.../Language.swift` | Supported-language choice and fallback |

SwiftUI uses the selected locale for date/time controls. App messages and newly
scheduled AlarmKit labels use the same saved language. Existing OS alarm labels
keep the language used when scheduled; changing the picker does not reschedule
alarms. Permission dialogs and system intent metadata follow iOS language settings,
which an in-app preference does not change. Check permission copy on device.

The older web design study in `design/` is a Vietnamese concept, separate from the
native app. Its labels and simulated features are not evidence of native behavior.

## Write like a helpful person

Use short sentences, familiar verbs and one next step. Explain what happened
without blaming the user. Keep Stop easy to find. Avoid pressure, jokes about being
lazy, and claims that AI knows whether someone is truly awake.

| Purpose | English | Vietnamese |
|---|---|---|
| Self-confirm | I'm awake | Tôi đã thức dậy |
| Stop | Stop alarm | Dừng báo thức |
| Camera framing | The view is unclear. Try moving your phone. | Chưa nhìn rõ. Bạn có thể đổi góc máy. |
| Gentle mode | Wake up at your own pace | Thức dậy theo nhịp của bạn |

English is the language for code, comments, commits and developer docs. Vietnamese
belongs in translation resources and clearly marked UI/test examples. Keep product
terms consistent: **alarm**, **challenge**, **Gentle**, **Balanced**, **Focused**.

## Add or change a string

1. Read the screen and action where the string appears.
2. Add the English key/value and a natural Vietnamese translation.
3. Keep format placeholders unchanged. `Try %lld push-ups` needs `%lld` in both
   languages; the value comes from the selected target.
4. Use `appText("English source copy")` in app code. Do not translate saved IDs or
   user-created content.
5. Keep `Resources` in the app target's `sources` in `ios/project.yml`. XcodeGen
   uses that list for localization and sound resources too.
6. Run the checks, then review both languages in the simulator.

```sh
npm test -- tests/localization.test.ts
sh scripts/test-swift.sh
```

Tests check key parity, nonempty text, format placeholders, native message coverage,
permission resources and language fallback. XCUITest covers both editor languages
and a choice that survives relaunch. Structural checks do not prove translation
quality, layout fit or correct delivery of an OS alarm.

## Read next

[UI guide](UI-DESIGN.md) · [Writing template](DOC-TEMPLATE.md) · [TDD evidence](tdd/cost-optimized-pilot.tdd.md)

Native format references: [Apple strings files](https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPInternational/MaintaingYourOwnStringsFiles/MaintaingYourOwnStringsFiles.html),
[language resources](https://developer.apple.com/documentation/xcode/adding-support-for-languages-and-regions),
[XcodeGen project options](https://github.com/yonaskolb/XcodeGen/blob/master/Docs/ProjectSpec.md).
