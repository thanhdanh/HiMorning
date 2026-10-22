# Alarm cards and challenge consistency

> **Historical document.** This is a superseded proposal or implementation
> checkpoint, not current product behavior or instructions to execute. See the
> [current documentation](../../README.md) and [challenge guide](../../MODE-CHALLENGES.md).
> Original observations, limits and approvals below apply only to their dated scope.

Make daily alarm scanning calm and precise, and show the challenge modes behind
recorded consistency. This extends the approved Home completion change.

**Status:** Implemented; focused behavior checks passed. The full design evidence
gate remains incomplete as detailed below. **Audience:** Product, design and iOS maintainers.

## At a glance

| Contract | Checkable behavior and local reference |
| --- | --- |
| Product surfaces | Native iOS Home and Progress; a repeated morning workflow, not a marketing page |
| Primary jobs | Read the next alarm, adjust it safely, then inspect attendance and challenge mode by day |
| Tone | Quiet, warm and precise; original yellow for enabled alarms, muted off cards and matte Progress surfaces |
| Hierarchy | 12-hour time with a small AM/PM suffix and switch, next date, challenge name and mode, then secondary actions |
| Active delete | Bottom trailing action beside Edit and Try, matching the original card placement requested by the user |
| Off state | Compact muted time/Off row with re-enable and 44pt delete; no hidden scheduling error |
| Completion | Small green check plus text; it remains independent of the next repeating alarm |
| Glass | iOS 26 native glass only for the grouped navigation controls; no glass stacking or glass on every content row |
| History | Store the effective mode and challenge snapshot at completion; editing an alarm cannot rewrite prior days |
| Consistency | Keep the existing completion percentage/weekly goal; show modes separately, without invented weighted difficulty points |
| Partial data | Legacy entries retain outcomes and scores; absent mode/challenge remains unknown |
| Target viewports | 402x874 and 375x812 logical points, portrait; English/Vietnamese; light/dark; accessibility text |

The user's latest feedback restores the original yellow background for enabled
alarms while retaining the refined hierarchy and footer Edit/Try/Delete order.
Foreground and success colors stay dark on yellow in both appearances.
Existing MorningTheme tokens, localization,
MorningJournal, SwiftUI and SF Symbols are the implementation references.

## How it works

Home starts with the actual alarm list. Remove generic motivational filler.
Enabled cards use restrained time typography, a compact next-date line, challenge
name and a small named mode indicator. Destructive actions stay away from the
on/off control. Off cards remain compact. Large text wraps metadata/actions
without clipping the time, switch or delete target.

Progress keeps a seven-day overview with readable mode labels for each day.
Selecting a day reveals its recorded attempts, challenge names, modes and
outcomes. Different modes on one day remain inspectable individually. Mode
counts reflect completed attempts, and unknown legacy mode data is not assigned
to a difficulty. Gentle/Balanced/Focused are saved app modes, not a claimed
standardized measure of effort across different challenge types.

## Content states

| State | Trigger, feedback and safe next action |
| --- | --- |
| Loading | Initial alarm reconciliation or progress/subscription refresh; keep the same structural shell and expose the existing Checking state |
| Empty | No alarms or no records on the selected day; show one concise explanation and Add alarm/return to alarms |
| Error | Alarm scheduling or history persistence failure; retain the specific warning and existing edit/system-settings recovery path |
| Partial | Old history lacks mode/challenge; preserve its date, outcome and score with an explicit unknown detail marker |
| Success | Confirmed completion returns Home with the green marker; the next ring and edit controls remain available |
| Permission | Denied native alarm access retains its existing Settings/retry action; no permission is requested just to view cards or progress |

## Task list

1. Extend existing tests for immutable mode/challenge history, active-card action
   placement and daily progress details before implementation.
2. Add optional backward-compatible journal metadata and preserve the effective
   session snapshot through the existing completion path.
3. Refine Home cards and grouped glass navigation controls; restore the active
   footer and retain compact off cards.
4. Add day inspection and mode context to Progress using existing journal data.
5. Render both target viewports, test applicable states and accessibility,
   inspect captures, review the diff, and run the frontend design evidence checker.

## What we checked

The final background-only revision restores `MorningTheme.hero`, uses fixed dark
foreground/success colors on yellow and leaves behavior unchanged. Checked the
diff and calculated text contrast; no build or test rerun for this small change.
Earlier Home screenshots show the preceding white-card revision.

On 16 October 2026, 62 SwiftPM core tests, the portable suite (98.29% line
coverage), 39 native tests and seven localization/CI checks passed. Focused
completion and footer tests passed after the visual revision. Progress day
selection, scores/empty states and English/Vietnamese accessibility text passed
on the 402x874 simulator. Footer placement and day details also passed at a
measured 375x812 logical viewport. Final source review found no actionable issues.

Rendered review includes both viewports, English/Vietnamese, Home light/dark,
large Progress text, mixed/legacy entries, empty records and history-read failure.
Final fixes expanded glass-button hit regions, increased Off/selected-day text
contrast and removed a duplicate accessible decorative progress indicator.

The broad native accessibility scan still reports one Home OCR warning and two
Progress contrast warnings without identifiable elements. They remain unresolved;
they are not assumed to be false positives. No hit-region, sufficient-label,
clipped-text or trait findings remained in that final scan. The retained automated
test explicitly covers those four categories. Its final test-only simplification
was not rerun, following the user's request to avoid repeated tests for tiny fixes.

The local evidence record and original screenshots are in
`/Users/danhvt0109/.codex/visualizations/2026/10/15/01a14093-74d2-7270-8348-222e75da5718/alarm-progress-design/`.
The frontend evidence checker was run and correctly remains incomplete for
accessibility, transient loading and native permission recovery. No passing
observations were invented for these checks.

## Limits and next steps

No new dependency, difficulty weighting, score migration or invented historical
metadata is needed. Physical-device camera/remote AI, VoiceOver, external keyboard
navigation, Reduced Motion/Transparency, Progress dark appearance and narrow
accessibility-size rendering were not newly exercised. Exploratory Escape did
not dismiss the sheet; the speculative shortcut was removed. Transient loading
and native permission recovery were not newly exercised. Core calendar boundaries
are tested; leaving Home open across midnight remains a manual acceptance check.

The user's request to open a PR supplies Gate 2 authorization. Commit message:
`feat(ios): refine alarm cards and daily challenge progress`.
