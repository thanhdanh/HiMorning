# Android implementation

Native Android implementation of the iOS product at `51fba07`.

**Status:** Implemented development build; focused checks and bounded review passed. **Audience:** Android maintainers and reviewers.

## At a glance

Use one Android app module with pure Kotlin domain rules, durable local state,
Android adapters and Compose screens. Keep existing iOS and server behavior intact.
The product baseline includes alarm editing, repeat days, sounds, wake modes,
local challenges, practice, morning history, weekly goals, seven-day journeys,
English/Vietnamese UI, permission recovery and independent stop/snooze controls.

## How it works

Persist alarm intent before scheduling with AlarmManager. A receiver validates the
saved alarm before starting a foreground ringing service. The service owns sound;
Compose owns the active challenge. Completion must come from a correct answer,
recognized speech or measured movement. Practice never updates morning progress.
Stop/recovery must work without camera, network, ads or entitlement checks.

## Key choices

- Kotlin/Compose follows the existing Android extension guide; no iOS rewrite.
- One module and packages keep initial build and ownership simple.
- Local-first state and platform APIs are the runnable baseline. External billing
  and cloud verification need Android-specific production configuration.

## Work board

| Task | Owner | Scope | State | Gate |
|---|---|---|---|---|
| A1 | domain implementer + lead | core models, repository, tests, fixtures | done | 9 domain tests and 3 storage instrumented tests passed |
| A2 | platform implementer + lead | native alarms/recovery, movement/speech adapters | done | 4 platform unit tests, recovery instrumentation and actual emulator alarm passed; hardware remains |
| A3 | lead | Gradle, manifest, Compose UI, integration, docs | done | APK, lint, UI launch and actual emulator alarm flow passed |
| A4 | lead/reviewer | current diff, permissions/races, acceptance evidence | done | revision 6 approved; mode, dismissal, localization and safe-close repairs reviewed |

## Try it

From `apps/android`, with JDK 17 and Android SDK 36:

```sh
./gradlew :app:assembleDebug :app:testDebugUnitTest :app:lintDebug :app:connectedDebugAndroidTest
adb install -r app/build/outputs/apk/debug/app-debug.apk
adb shell am start -n com.himorning.android/.MainActivity
```

Run the connected test task on a dedicated emulator. Test methods use isolated
cache and preference files, but the Android Gradle device runner installs/uninstalls
the target package at teardown and can remove that package's normal app data. Alarm recovery instrumentation
requires exact-alarm access and skips its scheduling test when access is absent.
The validated local emulator was Android 15/API 35, arm64.

## What we checked

Before implementation, reviewed current iOS `Module.swift`, `Pilot.swift`,
`Challenge.swift`, `Morning.swift`, `MorningJourney.swift`, `MorningReflection.swift`
and `WakeEnforcement.swift`. Integrated checks on 27 October 2026 passed:

- Debug APK packaging and Kotlin/Android resource compilation.
- 13 JVM tests passed: 9 domain/fixture/feedback tests, 3 movement-cycle tests and
  1 sound-resource test.
- 4 emulator instrumentation tests: multi-instance storage, corruption preservation,
  interrupted AtomicFile writes and independent recovery sessions/snooze limits.
- Android lint with zero errors. Suggestions about optional KTX/version upgrades
  remain warnings; no broad dependency upgrade was included.
- Cold app launch, native time picker and permission recovery UI on API 35.
- Actual AlarmManager delivery after a UI-created alarm while the app process had
  been killed: the receiver restarted the process and a foreground media-playback
  service appeared. A wrong reading answer did not complete the challenge; a
  correct answer wrote one local-completion entry and one journey day, stopped
  the service and left the one-time alarm disabled.
- Final manual instrumentation rerun passed all four tests with status code 0;
  the existing alarm/history remained intact. This used the installed test APK and
  `am instrument`, avoiding the Gradle runner's uninstall teardown.
- On the final APK, completing a practice reading challenge left the pre-existing
  history and journey records exactly unchanged. Completed real wakes had no
  unresolved recovery records or remaining foreground ringing service.
- Final CRUD smoke created a second alarm, edited its label and deleted it through
  confirmation while preserving the first alarm exactly and keeping its history.
- Vietnamese persisted across process restart. The alarm editor, three mode choices,
  challenge choices, all 15 sound names and the native time-picker controls were
  checked in Vietnamese; weekday labels remained distinct. Switching back to
  English recreated the activity and restored English home/editor text.
- A second real alarm fired with notification permission denied. Reopening its
  pending challenge and pressing Back stopped the foreground ringing service,
  consumed the one-time alarm and recorded dismissal. Deleting only that test
  alarm cleared its reminders while preserving the original alarm and history.
- Bounded independent review approved the final source snapshot after repairs for
  mode-specific challenge choices, one-time dismissal state, activity-owned locale
  resources and safe Back/Close behavior. This supplements
  the lead's alarm/data/permission review; it is not device release certification.

Graph generation was 2026-10-11 with known partial
Swift parsing; current source takes precedence over the stale graph.

## Acceptance and tests

- Validate times/repeat days; compute next occurrence across midnight and DST.
- Persist CRUD without losing unrelated alarms; malformed state surfaces an error.
- Expired access preserves saved settings; the preview begins after the first
  confirmed alarm schedule, not after a permission-denied save.
- Snooze limits and terminal outcome/generation reject late completions.
- Reboot/time change reschedules enabled alarms; disabled/deleted IDs cannot ring.
- Stop always halts sound; permission denial remains recoverable.
- Correct reading/riddle answers pass; wrong answers do not; speech uses token score.
- Movement requires measured cycles and visibility; no tap-based verification.
- Journal deduplicates session IDs; practice adds no score; journeys count one day.
- UI text ships in English and Vietnamese; controls remain accessible to TalkBack.

## Feature parity and configuration

| iOS feature | Android result |
|---|---|
| Create/edit/delete, time/repeat, labels, on/off | Native Compose editor and AlarmManager adapter |
| Three modes, system + 14 sounds | Ported rules, WAV resources and sound previews |
| No challenge and delayed self-confirmation | Distinct self-confirmed outcome; five-minute delay |
| Read and Choose / riddles / explanations | Same reviewed 156-item EN/VI pack; correct answers only |
| Read Aloud / spoken example | On-device SpeechRecognizer, token score and word-level correct/incorrect/pending feedback, TTS and reading fallback |
| Push-ups, wave, neck, jacks, stretch, standing/seated rhythm | CameraX plus on-device ML Kit; debounced measured cycles |
| Practice | Available for all nine challenge activities; excluded from progress |
| Weekly goal/history/month score/seven-morning journey | Local records; one successful local day per journey day |
| 30-day preview and saved configuration after expiry | Ported; effective basic rules preserve saved choices |
| Stop/current sound, backup rings, recovery | Occurrence/session tokens; up to 15 two-minute reminders over 30 minutes |
| Snooze | Android native five-minute snooze with mode budget; iOS currently lacks native snooze |
| English/Vietnamese and accessibility | Resource-localized UI, TalkBack labels, scrollable large-text flows |
| Google Play monthly/annual purchases | Deferred by user: no Play products/configuration; not implemented |
| Firebase/remote AI verification | Deferred by user: Android registration/App Check/server allowlist missing; not implemented |
| Optional remote content refresh | Bundled content works offline; no Android endpoint configured |

The user confirmed that Firebase Android and Play configuration do not exist and
asked to document later setup. To enable these integrations:

1. Register `com.himorning.android` in Firebase with debug/release signing SHA-256;
   add Android configuration through the normal untracked/secret configuration flow.
2. Configure anonymous Auth and Android Play Integrity App Check, then explicitly
   support the registered Android app ID on the verifier. Current Worker
   `workerConfig` requires an `:ios:` Firebase app ID and App Check compares its exact
   `sub`; do not bypass or weaken those checks to accept an Android client.
3. Implement the Android authenticated callable adapter against the shared fixtures,
   including consent/evidence limits and stale-result cancellation tests. No
   cloud-verified result may be shown from local movement alone.
4. Create Play Console monthly/annual products and a Play Billing entitlement path
   with verified purchase state, pending purchases, expiry, restore and grace tests.
   StoreKit product verification cannot be reused as Android purchase evidence.
5. If remote content refresh is desired, configure the reviewed endpoint and add
   versioned/validated cache replacement while keeping the bundled offline pack.

## Limits and next steps

Android currently shows a fitted camera preview, guide text and measured counts;
it does not reproduce the iOS joint/face overlay. The custom Compose design follows the current iOS palette, card hierarchy and
home-to-sheet navigation. Android approximates Apple glass with layered native
surfaces; its native spinner, Nunito headings/system body type and overflow delete menu
remain platform adaptations. The content picker avoids an
immediate repeat during a process; it does not port iOS's persisted 128-prompt and
theme rotation history.

Physical-device alarm delivery, OEM battery behavior, camera calibration and Play
billing require separate evidence. Implementation and build results do not establish
release readiness. A final parity table will distinguish implemented, configured
and externally blocked features.

## Read next

[Android architecture](ANDROID.md) · [Contracts](../shared/contracts/README.md)

## UI parity revision: current iOS design

**Status:** Implemented; focused build, behavior, visual and source review gates
passed. The current iOS UI/UX replaces the initial functional Android shell. Existing alarm
behavior remains the baseline; a bounded per-alarm save compensation repair also
prevents failed saves from changing settings after Cancel.

The first screen must answer: which morning am I preparing, and what is my next
small win? Use the actual iOS source at `51fba07`, not the older documentation
screenshots. The visual identity comes from the sunrise mark, warm yellow alarm
cards, soft purpose card, rounded clock numerals and direct full-width actions.

### Decisions and ownership

- UI1 / design-system-home: theme tokens, custom home/header/alarm/journey/recent-win
  cards and shared vector icon/button styles. Owner: visual implementer.
- UI2 / alarm-composer: near-full-height composer with inline spinner time, hero,
  three mode segments, two-column challenge selection and grouped details; separate
  sound sheet with previews and fixed yellow Save. Owner: composer implementer.
- UI3 / integration: root composition, status/navigation bars, home-to-progress,
  purpose/language/Pro/practice sheets, editor scopes, draft-preserving practice
  and challenge visual integration. Owner: lead.
- UI4 / proof: bounded review and actual Android/iOS screenshot comparison. Lead
  owns fixes; root owns emulator references, builds and screenshots.

Light tokens follow `MorningTheme.swift`: canvas `FFFCF6`, surface `FFFFFF`, soft
`F4F1E9`, ink `29251D`, muted `756F63`, line `E9E5DC`, yellow `F5C842`, alarm card
`F9E07D`, hero `F8D960`, accent `967211`. Dark tokens use canvas `201F1A`, surface
`2C2A24`, soft `353229`, ink `F8F4EA`, muted `C2BBAE`, line `49463D` and yellow
accent. Yellow surfaces retain dark `29251D` text in either theme.

### Observable acceptance

1. Home has the sunrise/name header and progress/Pro/language actions, a soft journey
   card, custom yellow alarm cards, full-width Add alarm/Explore challenges and
   recent wins. The four bottom tabs and floating action button are gone.
2. Alarm cards expose separate schedule/challenge entry points, sound, status,
   practice and on/off. Disabled cards use the soft surface. Delete still confirms.
3. Composer uses the current iOS hierarchy: title/cancel, inline wheel, challenge
   hero, level segments, two-column choices, grouped details and fixed bottom Save.
   Schedule/challenge scopes preserve fields outside their scope. A failed save
   keeps the draft and presents its error; draft practice returns without saving.
4. Repeat labels remain distinct in both languages; all 15 sounds remain selectable
   with available previews and safe release of audio when a sheet closes.
5. Progress, purpose, language, practice and Pro open from the home flow rather than
   acting as tabs. Deferred integrations remain explicit; no fake purchase controls.
6. Current iOS and Android light screenshots show matching hierarchy and palette.
   Also inspect dark mode and large text for clipping, contrast, reachable Save and
   minimum 48 dp interactive targets. Respect system motion settings by avoiding
   required animations; no new animation subsystem.
7. Reuse the 13 unit / 4 instrumented baseline. Recheck actual UI CRUD, scope edits,
   dismissal, practice-without-progress and English/Vietnamese picker behavior.
   Do not rerun physical calibration or claim hardware proof from screenshots.

### Work board

| Task | Owner | State | Gate |
|---|---|---|---|
| UI1 | visual implementer | done | custom home/cards checked against current iOS screenshots |
| UI2 | composer implementer | done | real spinner, grouped details, typed-time save and sound cleanup checked |
| UI3 | lead | done | all routes, scoped edits, persisted purpose and unsaved practice draft checked |
| UI4 | lead + root + reviewer | done | final screenshots, 15 JVM / 5 instrumented tests, lint and revision 5 review passed |


### UI verification and platform adaptations

On 27 October 2026, actual Android 15 emulator screenshots were compared with a
fresh iOS simulator build of `51fba07`. Home, populated alarm cards, the composer,
details, progress, Explore and Vietnamese editor passed the visual check. Dark
mode and 150% font size retained readable controls and a reachable Save action.
The Android spinner honors the device's 12/24-hour preference. Material vector
icons and the bundled Nunito heading face replace SF Symbols and Apple's rounded
typeface; a
custom sunrise mark preserves the brand. Native surfaces approximate translucent
glass. Delete uses an accessible overflow action and confirmation.

The screenshot artifacts are named `android-home-final.png`,
`android-alarms-final.png`, `android-editor-final.png`,
`android-editor-details-final.png`, `android-progress-final.png`,
`android-explore-final.png`, `android-editor-vi-final.png`,
`android-home-dark-final.png`, `android-editor-dark-final.png` and
`android-editor-large-font.png` in the task's `ui-parity` visualization folder.
They are captured app pixels, not design mockups.

Behavior checks preserved the existing alarm, history and journey across the UI
upgrade. Native typed-minute input was saved without pressing Enter. An unsaved
7:15 Balanced / Read and Choose draft retained its label, Monday/Wednesday/Friday
repeat and Sunrise sound through sound preview, completed practice and return.
Practice left the previous history/journey exactly unchanged. Fresh Clear Start
purpose selection hid the introduction, showed the day-zero mission and survived
process restart. English/Vietnamese home actions, scoped editor, distinct weekday
labels and the native time picker were exercised.

The scoped-field and reflection regressions increase the JVM suite from 13 to 15.
Reflection needs three distinct successful local days and a repeated challenge
before showing a preferred-activity pattern, matching iOS's evidence threshold.

### Save-failure recovery exception

Review found that a failed native schedule could leave edited fields persisted
after Cancel. The repair preflights known denied exact-alarm access before writing.
For an unexpected failure after writing, compensation restores only that alarm's
prior settings and attempts to restore its previously confirmed registration. A
new record is removed only after known cancellation. Uncertain registration keeps
the alarm ID with `NEEDS_REVIEW`; it never claims a confirmed schedule. Disabled
alarms stay disabled, and unrelated alarms, history and preferences are preserved.
A repository instrumentation regression covers these distinctions. On the final
APK, denied exact-alarm access followed by edit 7:15 to 7:16, Save error and Cancel
left the stored alarm exactly equal to its baseline. A failed new-alarm save and
Cancel created no ghost record or history. Restoring permission and saving 7:15
confirmed the schedule.

The frozen revision passed debug packaging, all 15 JVM tests, lint with zero
errors and all five manually run instrumentation tests. The fifth test covers
per-alarm save compensation. Focused review revision 5 approved the exact 58-file
source manifest with SHA-256
`a9acbe603d252b4d63536d1deee8fa59a384e6373bd1a73162940ffc1ec60a1c`.
No device/OEM, physical camera or production billing claim follows from these
emulator results.

## Visual softness revision

**Status:** Implemented and verified on the emulator. The revision preserves the
current behavior while reducing the flat, hard-edged feel compared with the
current iOS screens.

The bounded revision adds warm/category radial backdrops, soft surface highlights
and diffuse shadows, rounded heading/clock typography and shared press feedback.
The composer Save action floats above a fading backdrop. Selection, keyboard focus,
error visibility, 48 dp targets and large-text scrolling remain intact. Native
spinners and existing callbacks remain unchanged; no new blur library or feature.
System-disabled animations must suppress press scaling.

| Task | Owner | Scope | State | Gate |
|---|---|---|---|---|
| S1 | visual implementer | shared surfaces/press; home, components and sheets | done | source and same-state visual checks passed |
| S2 | composer implementer | composer and sound presentation | done | focus/semantics preserved; Gentle/learning visual checks passed |
| S3 | lead | typography integration and visual decisions | done | explicit font axes and pre-inflation native wheel face |
| S4 | lead/reviewer + root | review, builds and actual screenshots | done | source review, 15 JVM / 5 instrumented tests, actual visual and behavior gates passed |

Acceptance reuses the 15 JVM / 5 instrumentation baseline. Check populated cards
and Gentle composer in the same state before/after, typed-minute immediate Save,
selection, Cancel, sound cleanup and unsaved practice return. No new tests are
needed for reversible drawing changes; new behavioral logic requires a meaningful
regression. Root owns font evidence/assets, single integrated builds and emulator
captures. Product edits remain in Android UI source only.


Nunito is bundled under the [SIL Open Font License](../apps/android/app/src/main/assets/licenses/nunito_ofl.txt)
from the [official Google Fonts family](https://github.com/google/fonts/tree/main/ofl/nunito).
Its Vietnamese character map was checked against all 104 distinct letters in the
current Vietnamese UI resources. Compose explicitly selects weights 400–700 for
headings, clocks and labels; body text keeps the system face. The native spinner
sets its font before inflation because NumberPicker copies its input face into
the wheel paint during construction.

Shared press feedback scales the whole surface to 96% with a short spring; it
uses the existing control interaction source and suppresses scaling when system
animations are disabled. Mode and challenge selection colors retarget over
170 ms using Compose's system-scaled animations. Static radial gradients replace
expensive backdrop blur. Surface plates composite over the canvas before native
elevation, avoiding translucent shadow artifacts around child render bounds;
low-alpha neutral shadows keep the depth restrained. Native modal sheets own
their position, clipping and elevation; soft decoration stays on child surfaces
so language, purpose and progress content remains visible. The floating Save pill keeps its dark text in dark mode,
button semantics, minimum 64 dp height and fresh native input commit. No alarm,
repository, save-recovery or progress logic changes are part of this revision.


The same-state Gentle composer and populated alarm-card comparison passed after
the plate-compositing correction. Held-touch captures confirmed shrink/fade with
animations enabled and resting bounds/full opacity with
`animator_duration_scale=0`; the setting was restored afterward. The task's
`ui-softness` artifacts include paired `*-before.png` / `*-after.png`,
`android-motion-rest.png`, `android-motion-pressed.png`,
`android-motion-disabled-pressed.png` and an actual interaction recording,
`android-interactions.mp4`.

The final softness source passed debug packaging, all 15 JVM tests, lint with zero
errors and all five manually run instrumentation tests. Focused native input was
saved immediately as minute 16, then restored to 15 with the sample alarm exactly
matching its original state. Dark mode and 150% text retained readable editor
controls and a reachable Save action. Main activity, core, platform and test
sources match the previously validated baseline hashes.


All home modal routes passed on the final APK: language (Vietnamese and back to
English), progress, Pro with deferred-purchase copy, purpose and Explore to
practice and back. Vietnamese weekday labels remained distinct and its native
24-hour picker remained usable. An unsaved 7:15 Riddle draft survived Try practice
and Close; Cancel then left alarms, entries, journey, weekly goal and language
exactly equal to the pre-softness baseline. No ghost alarm or progress update was
created.

Bounded source review revision 2 approved the UI changes. Lead review covers the
subsequent opaque-plate and native-sheet-container corrections; runtime checks
confirmed both fixes. The final 61-file source manifest has SHA-256
`a8bc65a6ce449fe1abe41ca4b68802684b3ec382137ae88ca952a3dc01fda841`.
These are local build/emulator results, not physical-device or frame-rate evidence.

Delivery preparation normalized the Windows wrapper line endings and removed
trailing whitespace from the bundled font license to satisfy the repository
pre-push gate. Executable application code is unchanged from the reviewed source.
