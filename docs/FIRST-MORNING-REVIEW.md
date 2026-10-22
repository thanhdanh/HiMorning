# First morning experience and subscription review

This review links a simulated new user's experience to a bounded set of product improvements.

**Status:** Baseline and implemented purpose-based journey observed on 23 October 2026; local validation complete. **Audience:** Product and iOS contributors.

## At a glance

The baseline is main commit `33f45d2`. A fresh iPhone 17 Pro simulator (iOS 26.2, ID `8C73D549-DD7D-47DA-8808-8F3FF07FE047`) ran a newly built app with no UI fixtures. This is an agent's novice-role evaluation, not an interview, willingness-to-pay study, overnight trial, or physical-device validation.

| Journey | Direct observation | Implication |
| --- | --- | --- |
| First launch | Warm cream/yellow UI; empty card says “No alarms yet”; Add alarm and Explore challenges are visible | The purpose and first useful outcome need a short explanation |
| Explore challenges | A menu exposes ten choices, including No challenge | A novice must choose before knowing what a challenge feels like |
| Read & Choose | A short English sentence, three choices, immediate correct-answer feedback, cheerful completion and confetti | This is a low-friction way to demonstrate value without camera or sign-in |
| After practice | Home returns to its initial empty state; Progress says “Complete your first challenge to see your rating” | Practice correctly does not count as a morning, but the distinction and next step are unclear |
| Progress | Empty monthly score, seven empty days, zero mode counts, goal controls lower on the screen | New users encounter empty analysis before useful guidance |
| Pro | Benefit headline truncates beside the sun; purchase region loads and then says “Subscription Unavailable” in this storefront | The screen needs resilient layout and helpful unavailable/retry handling; production billing is unproven |
| First alarm | Chose Balanced / Read & Choose, saved 02:14, allowed AlarmKit; returned to a visible enabled alarm card | Saving and no-card preview activation worked in Simulator |
| Alarm action and completion | At 02:14 the native alarm banner appeared; its configured sun action opened the matching 02:14 Read & Choose; the correct answer stopped the banner and returned Home with “Completed today” | Simulator alarm delivery/action/completion were directly exercised; physical-device and lock-screen coverage remain open |
| Actual progress | Progress then showed 100 points, 1 of 1 challenges completed, today's Balanced / Read & Choose record and weekly goal 1 / 3 | An actual alarm challenge counted once; the earlier practice did not add a record |
| Elapsed one-time alarm | Footer briefly changed to “Next: Sat, Oct 24” after firing; after completion it showed “Check system alarms” beside “Completed today” | Readiness language for completed one-time alarms needs a separate bounded review; this does not establish a scheduler failure |

## How it works

The novice-role question was: “Can I understand why this is useful, try it safely, and see why I would keep using it?” A reading challenge produced a quick success. Creating an alarm needed no account. The no-card 30-day preview was explained and began after a successful alarm save.

At baseline, the purchase proposition listed history, a custom weekly goal, extra challenges and sounds. As a simulated ordinary young user, I would keep trying the app but would not pay yet: I need trust in actual morning delivery and a visible habit benefit over several days. This is a product judgement, not measured consumer demand. No subscription was purchased and no market price was validated.

Potential reasons to subscribe, as hypotheses for later interviews:

- A varied seven-day morning routine matched to available time and preferred challenge types, so the app stays useful beyond its novelty.
- A useful account of actual completed mornings and how the routine changes over time, with clear definitions rather than an unexplained score.
- Optional customization and fresh content after the user has experienced several successful real mornings. Basic alarm delivery and recovery should remain dependable at every access level.

These ideas are product hypotheses. One simulated persona cannot establish demand or a price. Repeated use, interviews after actual mornings and a concrete paid offer are needed to test willingness to pay.

At baseline, content quality was a material risk: some reading questions were elementary, such as choosing to open a window on a sunny day. The subsequent [content revision](CHALLENGE-CONTENT-PLAN.md) replaces that pool with 156 original bilingual items, visible themes, clue-based explanations and full-cycle rotation. These changes address the editorial gap; they do not establish long-term enjoyment or willingness to pay.

## Key choices

The main product gap is continuity: a new user can enjoy a challenge but still has to invent their own reason to return. Build a purpose-based journey across seven successful mornings, with a varied suggested mission, a small milestone and a preview of the next mission. Keep missed days recoverable and rehearsal out of earned progress. Preserve the optional subscription, no-card preview, alarm recovery and local privacy model.

The recurring-value hypothesis is curated routines and useful reflection. A first journey makes that benefit tangible; a fresh journey and a deeper optional path can give users a reason to continue. A plan picker, successful purchase or technical entitlement test cannot establish willingness to pay.

The [Erly investigation](ERLY-RESEARCH.md) used actual REA capture of the official website. It shows an outcome-led promise, a short alarm/mission/awake demonstration, varied mission examples and streak/history positioning. Google Play describes a four-hour goal lock. These are public-surface observations and marketing declarations; no Android APK was decompiled, Android native runtime was not exercised, and current Android pricing was not verified. Do not copy punitive locking or guarantee wake-up.

## What we checked

- Main was fetched before creating branch `codex/first-morning-value`; existing checkout changes were left intact.
- A fresh Debug Simulator build succeeded before baseline observation.
- Native Device Hub accessibility and screenshots were used to navigate first launch, practice completion, Progress, Pro and first alarm save.
- The 02:14 system alarm banner, configured action, matching challenge, dismissal and resulting journal entry were also exercised directly in Simulator. One rehearsal followed by one actual completion yielded one recorded completion.
- Codebase-memory listed the main project, searched relevant view symbols and checked path coverage. Its generation was stale (`2026-10-11T16:28:17Z`); several views were untracked and ChallengeView had a parse gap. Indexing the new worktree failed because daemon coordination could not be verified. Current source reads supplied the fallback evidence.

### Updated app: direct observations

The first-use groundwork was installed over the baseline without deleting its data. The existing alarm and one real completion survived. Home displayed one completed challenge day out of seven in both English and Vietnamese. This establishes data preservation for that groundwork; the new journey requires its own validation.

A temporary empty-home debug fixture then exercised the new Vietnamese journey without altering the saved journal: the purpose and three steps were visible, one tap opened a Vietnamese reading challenge, the correct answer displayed the practice explanation, and “Set your first alarm” opened the new-alarm editor. Practice did not request camera, microphone or alarm permission. The existing Gentle/no-challenge new-alarm default was preserved.

The initial manual pass caught a parent accessibility identifier overriding the recent-win child identifiers. The lead removed that parent identifier and included the fix in subsequent UI verification.

### Purpose-based journey observations

The product revision was installed over the same saved data. Its Vietnamese
purpose picker offered clear-start, gentle movement, reading aloud, and an
explicit energetic Pro path included in the no-card preview. Choosing clear-start
showed Read & Choose for the current step and a Riddle teaser for the next step.
The initial journey correctly began at zero rather than crediting an unrelated
completion recorded before enrollment.

Completing a Vietnamese practice question kept the journey at 0/7. Choosing an
existing alarm from the mission planner opened a challenge-only draft; cancelling
left the original schedule intact. Choosing New alarm opened a draft with the
suggested Read & Choose already selected at Balanced level. This connects trying
the mission to preparing the actual morning action.

A new alarm created through that planner rang at 02:46. Its configured action
opened the matching Vietnamese Read & Choose. The correct answer stopped the
alarm and returned Home, where the path advanced from 0/7 to 1/7, one marker
filled, a specific success message appeared, and the next Riddle was revealed
with a Prepare tomorrow action. This directly exercised the proposed
action/reward/anticipation loop once. Two real completions existed on that local
date, but only the one after journey enrollment counted toward the new path.

The manual review also found that the planner offered an elapsed one-time alarm,
which could make tomorrow's preparation misleading. The lead restricted planner
choices to enabled, confirmed, upcoming alarms and kept the new-alarm route for
other cases. This is a product-flow correction; it does not certify native alarm
delivery.

Installing the final build preserved the same non-fixture 1/7 progress and both
completion records. Prepare tomorrow opened a full new-alarm draft with Riddle
selected and a tomorrow occurrence, rather than offering either elapsed alarm.
Cancelling preserved the existing alarms. The reflection displayed one completed
day out of thirty and asked for three completed mornings before describing a
repeated challenge; it did not invent an insight from this one-day sample.

## Limits and next steps

The [implementation plan](FIRST-MORNING-PLAN.md#validation-result) records passing focused core, persistence, bilingual journey UI and localization checks, plus the exact reviewed code snapshot. Verify alarm delivery and actions on a physical device before making reliability claims. Interview several consenting users after 7–14 actual mornings to test whether the variety, preparation and reflection feel useful enough to keep. Payment mechanics cannot answer that product question.

## Read next

- [Erly official website](https://erly.co/)
- [Erly Google Play listing](https://play.google.com/store/apps/details?id=com.erly.myapp&hl=en)
- [Subscription setup](SUBSCRIPTIONS.md)
- [Earlier business model](archive/design/BUSINESS-MODEL.md)
