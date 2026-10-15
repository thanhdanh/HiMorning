# Challenge completion feedback

Record completion feedback and challenge guidance, including manual-confirmation
timing and Read Aloud status.

**Status:** Implemented; simulator regressions passed on 15 October 2026.
**Audience:** iOS maintainers and reviewers.

## At a glance

Every successful challenge shows a localized celebration, a brief fireworks
animation and a fixed Back to home button. Reading keeps its word feedback and
score below the celebration. Reduce Motion uses a static success badge.

Manual confirmation stays visible but disabled for two minutes after opening a
challenge, with a countdown inside the button. Start controls have a brief icon
cue. Read Aloud draws from 24 English sentences and clearly marks active listening
and correctly recognized words.

## How it works

`ChallengeView` routes successful movement verification and local challenge
completion through one completion function. It uses the coordinator's final
outcome, pauses capture and example playback, and records the result once.
Completion appears only after the existing coordinator operation succeeds,
including native alarm stopping outside practice. A stopped challenge and a
self-confirmed wake-up retain their own messages.

The view scrolls to the result and keeps the exit outside the scrollable content.
`ChallengeCelebrationView` animates decorative sparks once and has no audio or
permission requirements. The parent requests the success haptic once.
Instructions appear before challenge content; a spinner and
status message explain camera startup, verification and finishing.

The confirmation deadline belongs to the challenge view and survives redraws and
background/resume. Both the button and its handler enforce the deadline. The Stop
action stays available throughout; successful challenge completion can finish
immediately. DEBUG countdown fixtures can start ready or five seconds from the end
for unrelated journeys and deadline-transition tests.

Reading chooses a random prompt once when the session starts. The target stays
fixed while recording and retrying. Sentences span 19–24 words, yielding 72–87
seconds with the existing length-based limit. English learning targets remain in
English in both locales. A pulsing microphone appears only while the audio engine
is running, and disappears during finalization, interruption and completion.
Correct words use saturated adaptive green and bold text.

## Key choices

- Native SwiftUI effects reuse the app colors without another dependency.
- Reduce Motion removes moving sparks. The accessible text and static badge
  remain; decorative shapes do not intercept input or enter the accessibility tree.
- The same success presentation is used for practice and alarms. Practice still
  does not stop or reschedule native alarms.
- The DEBUG presentation fixture requires `--ui-testing`, practice and
  `--ui-complete-challenge`. It simulates a successful result without camera,
  microphone, network or native alarm operations. It checks presentation only.

## What we checked

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
