# Short challenges worth returning to

Improve the morning content itself: a small, satisfying thought or scene instead of elementary paraphrase or repeated affirmation.

**Status:** Implemented and locally validated, revision 3 (2026-10-23). **Audience:** Product, content and iOS maintainers.

## At a glance

Replace the old mixed-quality pool with 156 original bilingual items: 24 Read & Choose, 18 logic riddles and 36 read-aloud scenes in each language. Six themes make variety visible: work and study, everyday life, people and plans, creative breaks, city and travel, curiosity. All topics remain usable in the free mixed pool. Pro's existing guided routines and reflection remain the ongoing value hypothesis; this change does not introduce a paywall or promise an endless stream of new content.

## How it works

A morning mission offers a short challenge with its theme visible. Correct answers reveal a concise explanation in practice. A real alarm stops through the existing completion path first; Home can show the completed item's takeaway without an additional blocking step. A full pool cycle prevents an item repeating until that kind/language has been exhausted. Selection prefers a different theme when alternatives remain. History survives relaunch, and old history/pack data remains readable.

## Decisions and acceptance criteria

- Replace weak content rather than retain it behind the new items. Read & Choose uses inference from supplied facts; riddles mix ordering, allocation, constraints, patterns, and perspective. Read-aloud contains a coherent miniature scene, not an instruction to be productive.
- Every question has exactly one defensible answer, three plausible distinct choices, and a clue-based explanation. Explanations refer to answer text and facts, never letters, display position or “third option”: choices are shuffled.
- EN and VI express the same puzzle but use natural local wording. No copyrighted quotations, health claims, shame, strenuous activities, or assumptions about a conventional workday. Read-aloud keeps the existing 18–30-token recognition contract.
- Optional theme/explanation fields preserve old payload and initializer compatibility. Generated iOS/worker bundles and JSON schema must agree; bump pack version so existing caches do not shadow the replacement.
- No changes to alarm scheduling, stop/recovery, actual challenge timing, access rules, subscriptions or earned journey progress. Practice still earns no morning. Content practice removes its fake alarm clock and irrelevant self-confirm countdown; actual alarms retain their clock and delayed recovery action. Shorter spacing and a smaller content heading make answers easier to reach. At accessibility text sizes, completed content practice puts optional retry/setup actions inside the scroll area and keeps only the exit fixed, so the explanation has room.
- Root found a real fit issue on the standard simulator viewport: the old large clock and recovery footer pushed answers below the fold. Revision 3 compacts only content layout and uses clue/answer instructions instead of the obsolete closest-meaning wording.

## Team board

| Task | Owner / allowed scope | State | Gate / next action |
|---|---|---|---|
| Read & Choose: 24 EN + 24 VI | pro_value draft / lead revision: two source JSON files only | done | Lead and root reviewed all paired items |
| Logic: 18 EN + 18 VI | content_logic draft / lead replacement: two riddle source JSON files only | done | 18 distinct mechanisms; lead/root semantic review |
| Voice scenes: 36 EN + 36 VI | lead: two read-aloud source files | done | All scenes reviewed; token and theme checks pass |
| Metadata, rotation, visible payoff | lead: core/app/schema/tests | done | Compatibility, standard UI and large text passed |
| Integration and independent review | lead / reviewer | done | Final code approved; both targeted repairs passed |

The initial drafts failed the semantic quality gate: the logic pool repeated allocation grids, and several reading questions had obvious distractors or repeated departure arithmetic. The lead replaced/trimmed those drafts rather than pad the pool to the planned count. Root reviewed all 78 VI items and their 78 EN pairs; corrections include naturally phrased scenes, distinct distractors and unambiguous original-clip selection.

All workers share this checkout, preserve others' changes, do not spawn agents, and have two implementation attempts. Existing accepted journey work remains intact.

## Concrete checks

1. Decode old fixture/history without optional metadata; preserve IDs and recent choices.
2. Pick 36 unique Read & Choose items before repetition, avoid immediate repeat across the boundary, and prefer another theme when available; isolate language and kind.
3. Reject unknown/blank metadata and duplicate choices; preserve shuffled correct answer and associated explanation.
4. Check theme coverage, complete EN/VI pairing, source/license, explanation presence, 18–30-token voice scenes, deterministic generated bundles/schema and version hash.
5. Practice correct/wrong choices: no explanation before success, explanation after success, zero journey credit. Real success keeps immediate stop and Home takeaway; no new stop gate.
6. Build iOS; focused content unit tests and native bilingual reading/logic/voice UI. Root reviews all VI and sampled EN as an end user. This is editorial review, not evidence of paid conversion or retention.

Run `pnpm content:build`, `pnpm exec vitest run tests/challenge-content.test.ts`, focused Swift core/content and app prompt tests, and focused UI tests on the lead test simulator. Keep the preserved root QA simulator untouched. Record exact results and retained examples here when complete.

## What we checked

As of 2026-10-23:

- Focused Swift content tests: 12 passed, including a full 36-item cycle across encode/decode, theme variety, legacy history and invalid metadata.
- JavaScript content/localization: 22 passed. Worker tests: 25 passed. The initial worker invocation lacked its local `jose` dependency; rerunning with the existing workspace dependencies passed. Generated copies, schema, version and hash agree.
- Portable Swift integration runner passed (including existing alarm and journey paths); overall core line coverage was 96.92%. No target coverage percentage was introduced.
- Xcode app unit tests: three prompt mapping tests and one existing requirements test passed. Three standard content UI tests passed, covering EN/VI wrong/correct practice, real-completion return/Home takeaway and VI logic/voice themes.
- The first supplemental batch found an overbroad practice-footer guard and an accessibility-size footer that obscured scrolling. Both were narrowed/repaired; the final two targeted reruns passed: legacy countdown and the long VI question/explanation at accessibility XXXL. Across the final and repair bundles, all four content UI methods and the existing countdown method passed.
- Root manually tried random VI reading and logic in the normal app: wrong choices revealed no explanation, correct choices revealed the right clue, practice preserved its actual 1/7 journey, and the voice scene rendered without starting the microphone. After installing the final signed build and relaunching normally, root confirmed the actual 1/7 journey, both existing alarms and completion markers remained intact. Root also verified all three choices fit on a standard iPhone viewport for the long VI room question after compaction. This is simulator/manual evidence, not physical-alarm or retention evidence.
- Independent reviewer approved final source snapshot `cf5dfb3d15fb31ae13acdd4440e46aac6387018f0ae4192bbccd52ede6815044` (base `33f45d254b445082b31ec66efcf2b989900ba36f`) ; the final UI repair gate then passed. Source snapshot: `/private/tmp/himorning-content-release.diff`.

Retained examples: [content gallery](images/challenge-content/README.md). Logs: `/private/tmp/himorning-content-{core,js,worker,portable}.log`; native result bundles `/private/tmp/himorning-content-{final,repair}.xcresult`. The first bundle honestly retains the two intermediate failures; the repair bundle records their targeted reruns.

## Limits and next steps

A finite curated library makes the next month more varied; it is not a learning course or proof people will subscribe. A real 7–14-morning pilot must test enjoyment, repeat use and willingness to pay. `shared/content/challenges/REVIEW.md` requires project-owner native Vietnamese review before release; implementation and local review do not constitute release. No deployment is authorized.

## Read next

- [First-morning journey plan](FIRST-MORNING-PLAN.md)
- [Erly evidence and limits](ERLY-RESEARCH.md)
- [Source content review](../shared/content/challenges/REVIEW.md)
