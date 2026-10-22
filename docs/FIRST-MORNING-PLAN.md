# A morning worth coming back for

Give a new user a purposeful first success, then a different small mission to return to over seven successful mornings.

**Status:** Implemented and locally validated on 23 October 2026, product revision 2. **Audience:** Product and iOS contributors.

## At a glance

The user's priority is an interesting, useful habit and a reason to keep paying after novelty wears off. Payment plumbing is outside this revision. The isolated branch is `codex/first-morning-value`, based on main `33f45d2`. [Consumer review](FIRST-MORNING-REVIEW.md) and [Erly research](ERLY-RESEARCH.md) supply hypotheses, not measured willingness to pay.

| Task | Owner | Scope | State | Gate / next action |
| --- | --- | --- | --- | --- |
| Purposeful seven-morning domain | Implementer `pro_value` | New MorningJourney domain/store and their tests only | Done | Persistent domain and store tests passed; long-gap and duplicate-day cases covered |
| Mission, anticipation and rewards | Lead | Home, new journey views, alarm editor draft preset, localization, focused UI tests | Done | Bilingual goal → mission → practice → alarm draft → real completion → next mission passed |
| Ongoing value and review | Lead + reviewer | Thirty-day reflection, free/Pro explanation, exact final diff | Done | Energetic path and measured-pattern reflection demonstrated; final exact code reviewed |

## How it works

Choose a purpose: get a clear start for work/study, wake up with gentle seated-compatible movement, or find confidence reading aloud in the current app language. A seven-morning starter path rotates existing reading, riddle and gentle movement challenges. The card explains today's purpose, gives one-tap practice and opens an alarm draft with that mission. Existing schedules only change after the user saves the editor. Planner choices include only enabled, confirmed upcoming alarms; elapsed one-time alarms, disabled alarms and alarms needing review are excluded. When none qualify, planning opens a new full-schedule draft. Suggestions never claim an automatic daily change to the saved alarm.

Only a successfully recorded real challenge earns a morning. Practice, dismissal and self-confirmation never advance the path. Multiple alarms on one local day earn one step. There is no consecutive-day requirement or penalty: a missed morning shows a welcoming return and keeps the next unfinished step. Purpose changes preserve earned progress. Completion dates live in a separate small local record so a long break cannot erase milestones when the journal prunes older entries.

After each win, show the earned step and a concrete teaser for tomorrow. At three mornings, recognize having returned three times; at seven, show the completed path and offer an explicit next seven-morning round. Another round can be prepared that evening; the finished round and its last completion date remain saved, so another success cannot earn a second step on the same local day. The following morning can count normally.

## Key choices

`task_id=first-morning-value`, `plan_id=first-morning-value`, `revision=2`, `assigned_by=lead`, parent `/root`. Implementer owns only four new domain/store/test files and has two implementation attempts. Lead owns integration, views, copy, acceptance and final review. Work stays in the isolated worktree and preserves others' edits.

Free keeps all three starter purposes, seven-morning progress, milestones, recovery, practice and basic alarms. The existing 30-day no-card preview exposes the deeper value before anyone decides to pay. Pro adds an explicitly selected energetic workout sequence with gradual movement variety and the existing full challenge access, plus useful thirty-day reflection about which challenges users actually finish. Free users keep their earned journey; expiry never deletes it or locks recovery. An expired energetic path uses gentle missions and keeps progress.

Reflection names a repeated challenge only after at least three completed days and at least two days with that challenge. Otherwise it honestly says a pattern has not emerged. It describes completion choices, not sleep quality or causation.

The paid hypothesis is renewed intentional variety and learning what works for oneself over time, not charging for an earned badge. This revision demonstrates one deeper workout path and real recent-pattern reflection using shipped mechanics. Long-term retention and willingness to pay still require repeated mornings with consenting users.

Do not promise English learning in a Vietnamese flow: reading missions use the current app language. Do not copy Erly's punitive goal lock, invent AI coaching, add backend services or change alarm data schemas. The deferred commerce implementation is preserved in the task workspace at `research/himorning-first-morning-deferred/commerce.patch`, outside this worktree; original billing code is restored.

## What we check

- Domain: seven distinct local-day completions; same-day duplicates, practice and non-completion outcomes rejected; long break/relaunch retains progress; pre-enrollment/future entries rejected; purpose changes retain earned steps; explicit restart cannot double count the finishing day.
- Persistence: corrupt data is not overwritten; failed writes keep the previous state and report an honest warning.
- Missions: gentle path always seated-compatible; energetic movement is explicitly chosen with full access; expired access falls back gently without modifying stored intent or earned progress.
- UI EN/VI: choose purpose, see a concrete mission and tomorrow teaser, practice without advancement, open a preset alarm draft, cancel without changing a saved schedule, see real completion earn one step, milestones and return-after-gap messaging, reflection based on actual completions.
- Checks: focused Swift core/store tests; localization contract; simulator build and the UI paths affected by the product changes. No more StoreKit engineering tests for this revision.

## Validation result

The final iOS code snapshot is based on `33f45d2`, SHA-256 `21127d2aec5dee695956a027a38f8819561654cf1d493d5686e58375601c2425` for the tracked and new iOS diff. The reviewer approved this exact snapshot; lead integration review also covered persistence, alarm-draft preservation and paid-value truthfulness.

- 201 core tests passed, including journey dates, long gaps, safe mission rotations, same-evening round preparation, no duplicate-day credit and reflection evidence thresholds.
- Five JourneyStore tests passed for relaunch, corruption, failed writes, access choice and round persistence.
- All eight focused journey UI cases passed across `/private/tmp/himorning-journey-final-ui.xcresult` and `/private/tmp/himorning-journey-supplemental.xcresult`: EN/VI practice without advancement, existing-schedule draft preservation, actual completion and tomorrow preparation, safe planner filtering, milestones and repeat rounds, gentle large-text UI, energetic routine/reflection, and optional deeper-value explanation.
- The affected existing unsaved-draft rehearsal UI case also passed. No full native UI-suite result is claimed.
- Six localization contract cases passed. The portable core/integration runner passed. The final simulator app/test bundles compiled through the focused `xcodebuild test` runs; `git diff --check` passed.
- Manual native simulator use separately confirmed purpose selection, practice staying at zero, a matching scheduled alarm challenge advancing zero to one, and next-morning anticipation. See [the experience review](FIRST-MORNING-REVIEW.md).

One initial UI check encountered duplicate accessibility alert nodes; using the first matching confirmation element corrected the selector. Product review caught and fixed microphone-requiring missions in Clear Start and planning against an elapsed alarm. No unresolved blocking finding remains. [Retained product screenshots](images/first-morning/README.md) show the tested states and identify synthetic fixtures.

Original `Subscriptions.swift`, `SubscriptionTests.swift` and `project.yml` match the main baseline. ProView only explains the shipped deeper value and wraps its headline; no payment API, entitlement rule, product identifier or price was changed. Earlier commerce work is deferred outside this worktree.

## Limits and next steps

The knowledge graph is stale and has coverage gaps; current source reads are the structural evidence. Physical overnight reliability and genuine week-long behavior remain unverified. Erly Android internals are unknown; public REA evidence supports product hypotheses only. No deployment, real purchase or merge is included.

## Read next

- [Erly evidence](ERLY-RESEARCH.md)
- [Consumer experience](FIRST-MORNING-REVIEW.md)
