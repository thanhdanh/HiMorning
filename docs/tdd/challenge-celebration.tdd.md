# Challenge completion feedback

> **Dated evidence.** Commands, approvals, test totals and local paths below
> describe the original run. They are not current setup instructions or release
> status. See [current validation](../VALIDATION.md) for newer results and known gaps.

Record completion feedback and challenge guidance, including manual-confirmation
timing and Read Aloud status.

**Status:** Implemented; retry validation updated on 16 October 2026.
**Audience:** iOS maintainers and reviewers.

## At a glance

Every successful challenge shows a localized celebration, three seconds of
full-screen confetti, and fixed Try again and Back to home buttons. Reading keeps
its word feedback and score below the celebration. Reduce Motion uses a static
success badge.

Manual confirmation stays visible but disabled for two minutes after opening a
challenge, with a countdown inside the button. Start controls have a brief icon
cue. Read Aloud draws from 24 English sentences and clearly marks active listening
and correctly recognized words.

## How it works

`ChallengeView` routes successful movement verification and local challenge
completion through one completion function. It uses the coordinator's final
outcome, pauses capture and example playback, and records the result once.
Completion appears only after the existing coordinator operation succeeds,
including native alarm stopping outside practice. A stopped alarm and a
self-confirmed wake-up retain their own messages.

The view scrolls to the result and keeps both actions outside the scrollable
content. `ChallengeConfetti` renders decorative particles over the root view,
outside the scroll content, without intercepting taps. Its timeline stops after
three seconds. The parent requests the success haptic once per passed attempt.
Instructions appear before challenge content; a spinner and
status message explain camera startup, verification and finishing.

Try again creates a fresh coordinator in practice mode, preserving the effective
challenge, reading prompt and confirmation deadline. It clears the previous
transcript, score, counters and completion state and invalidates old capture
callbacks. Retrying never changes the shared practice setting, stops the original
alarm again, or adds or replaces journal entries. Starting movement or speech
remains an explicit action; movement verification still requires consent.
Practice and retry sessions have a direct Back to home exit. Dismissal stops
capture and example playback, invalidates pending updates and suspends remote
verification through the existing disappearance cleanup. There is no End practice
button or intermediate practice-ended screen. Only an active real alarm offers
Stop alarm; stopped alarms and self-confirmed attempts retain their result screen.
Completion stays presented until the user chooses an action; Home routing must
not dismiss it from `complete`, which would hide both confetti and Try again.

The confirmation deadline belongs to the challenge view and survives redraws and
background/resume. Both the button and its handler enforce the deadline. Real
alarms keep Stop available; practice keeps its Home exit available. Successful challenge completion can finish
immediately. DEBUG countdown fixtures can start ready or five seconds from the end
for unrelated journeys and deadline-transition tests.

Reading chooses a random prompt once when the session starts. The target stays
fixed while recording and retrying. Sentences span 19–24 words, yielding 72–87
seconds with the existing length-based limit. English learning targets remain in
English in both locales. A pulsing microphone appears only while the audio engine
is running, and disappears during finalization, interruption and completion.
Correct words use saturated adaptive green and bold text.

## Key choices

- Native SwiftUI Canvas and TimelineView reuse app colors without another dependency.
- Reduce Motion removes moving sparks. The accessible text and static badge
  remain; decorative shapes do not intercept input or enter the accessibility tree.
- The same success presentation is used for practice and alarms. Practice still
  does not stop or reschedule native alarms.
- The DEBUG presentation fixture requires `--ui-testing`, practice and
  `--ui-complete-challenge`. It simulates a successful result without camera,
  microphone, network or native alarm operations. It checks presentation only.

## What we checked

Retry validation on 16 October 2026:

- RED: the new Read Aloud retry UI regression ran against the previous app and
  failed because `retryChallenge` was absent. The completion fixture also replaced
  the supplied 80% transcript with a perfect transcript; it now preserves supplied
  speech feedback.
- All 66 SwiftPM core tests passed. The new integration test verifies one native
  stop for the original completion and no new journal entries after repeated
  successful or stopped practice attempts.
- The portable runner passed with 98.28% core line coverage. Both core runners
  include the new coordinator/journal regression.
- All ten localization and CI-selection tests passed. Push CI includes the new
  Read Aloud retry regression and the existing bilingual reading completion test,
  which now completes two further real local attempts.
- A delegated code and security review found no actionable issues in the retry
  lifecycle, consent flow, localization or animation lifecycle.

All seven focused celebration UI tests passed on the isolated iOS 26.2 simulator,
covering repeated local completions in both languages, an 80% Read Aloud retry,
movement controls, large text, countdowns, stopped outcomes and self-confirmation.
Frame inspection of the Simulator recording confirmed the visible full-screen
burst, falling particles and disappearance after three seconds. The result
actions stayed usable. Reduce Motion was checked in source; its system setting
was not toggled in this run.
Logs and result bundles use `/private/tmp/himorning-retry-{red,green}`; portable
coverage is in `/private/tmp/himorning-retry-portable.log`. These temporary files
are session evidence, not durable release artifacts.

Commands executed from the checkout:

```sh
pnpm exec vitest run tests/ios-ci.test.ts tests/localization.test.ts
sh scripts/test-swift.sh
env CLANG_MODULE_CACHE_PATH=/private/tmp/himorning-retry-clang-cache SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/himorning-retry-swift-cache swift test --disable-sandbox --package-path apps/ios/HiMorningCore --scratch-path /private/tmp/himorning-retry-core --cache-path /private/tmp/himorning-retry-spm-cache --config-path /private/tmp/himorning-retry-spm-config --security-path /private/tmp/himorning-retry-spm-security
```

Full Xcode invocations, including the selected tests and isolated simulator ID,
are recorded at the start of the RED and GREEN logs. The combined Xcode run
passed all 41 native tests, seven celebration UI tests and three existing reading
feedback/control UI tests. The final existing bilingual practice test's runner
was killed during app launch (`Test crashed with signal kill`), before its
assertions. Its isolated rerun passed without code changes (one test, zero
failures) and is recorded in
`/private/tmp/himorning-retry-pilot-green.log` and the matching `.xcresult` bundle.

Direct practice-exit follow-up on 16 October 2026:

- Removed End practice and its intermediate result screen; practice exits now
  return Home directly using the existing resource cleanup. Real alarms retain Stop.
- The updated retry-exit test failed against the old button, before the change.
  The updated app then built, and all ten localization/CI checks passed.
- Updated affected UI tests and strengthened the awake-confirmation assertion to
  wait for its actual result, because Home is now available before completion.
- The broader UI rerun was intentionally stopped at the user's request to limit
  repeated local testing for small fixes. Its partial results are not a full-suite
  PASS. Evidence: `/private/tmp/himorning-practice-exit-{red,green,copy}.log`.
- Review found no production or cleanup issues. No additional core or hardware
  tests were run for this small refinement.

Earlier completion-feedback validation on 15 October 2026:

- RED: the real Read & Choose practice regression failed against the old UI
  because the celebration copy and identifiable exit were absent.
- The app compiles; 54 SwiftPM core tests, the portable core runner, 39 native
  tests and seven localization/CI tests passed. Portable core line coverage is
  98.57%, excluding native adapters and UI.
- All 13 focused Read Aloud tests passed for the expanded pool, including unique
  prompt IDs/text, useful sentence lengths, scoring and length-based deadlines.
- A delegated review found no actionable P1/P2 issues in completion handling,
  localization, accessibility or fixture isolation.
- All ten selected UI tests passed without skips on the isolated iPhone 17 Pro /
  iOS 26.2 Simulator: the five new celebration/countdown/listening tests, the
  enabled-alarm edit regression, three reading-control/feedback regressions and
  existing bilingual offline reading practice.
- The correct-word palette has calculated contrast ratios of 6.44:1 on the light
  canvas and 10.71:1 on the dark canvas. This is a palette calculation, not a
  display measurement.
- The final app rebuild and all 39 native tests passed after the finishing-state
  and disabled-control motion cleanup.
- Manual Vietnamese practice completed a real Read & Choose answer, displayed
  the sparks and success message, and returned home using the single fixed exit.
  Reduce Motion produced a static badge with the same usable exit, then was
  restored. The real expanded Read Aloud prompt, new instructions, microphone
  start label and two-minute countdown were inspected without audio access.
  A separate display fixture confirmed the listening icon and saturated green
  matched words; ending practice cleared the listening indicator.

The bilingual real-completion and confirmation-countdown regressions are included
in push CI. Other UI tests
cover large-text success for all remaining challenge kinds using the presentation
fixture, plus real stopped and self-confirmed outcomes. Existing reading feedback
and enabled-alarm editing regressions are run alongside these checks.

Session evidence: `/private/tmp/himorning-celebration-red.log`,
`/private/tmp/himorning-challenge-ux-green.log` and matching `.xcresult` bundles;
`/private/tmp/himorning-reading-pool-{red,green}.log` records the content regression.
The first shared-simulator run was interrupted because another task replaced the
installed app. Acceptance uses the isolated HiMorning Celebration QA 20261015
simulator (`21ABB2DA-E26D-4BDE-B159-C27887F98680`). These temporary files are not
durable release artifacts.

## Limits and next steps

Presentation fixtures do not verify physical movement, speech recognition or
remote AI decisions. Physical iPhone acceptance, including haptic strength and
animation feel, remains pending. The earlier alarm-edit fix is retained in this
checkout and has its own evidence report.

## Read next

[UI regressions](../../apps/ios/HiMorningUITests/ChallengeCelebrationUITests.swift) ·
[Alarm editing fix](alarm-challenge-edit.tdd.md)
