# AI engineering metrics

Measure the work, keep the limits visible, and connect usage to useful results.
This guide separates development tokens from application inference and software
quality. None of those measures is a substitute for the others.

**Status:** Historical baseline captured at **2026-10-11T10:32:34.654Z**
(17:32 on 11 October 2026 in Vietnam), before the localization change.

## Localization and English documentation update

A separate [usage snapshot](ai-usage-localization.json) preserves later work without
rewriting the original baseline. Cutoff: **2026-10-11T11:23:52.610Z** (UTC).
The manually tagged `localization_english_docs` turn has **7,353,183 input**
(including **7,186,944 cached**), **52,200 output** and
**7,405,383 total tokens**. It includes code, test, documentation and CI
fixes together; it is not an exact split of those activities. The whole conversation
still reconciles with the cumulative token snapshot. USD remains unknown.

## pnpm, Android boundaries and visual documentation

A separate [migration snapshot](ai-usage-pnpm-architecture.json) captures this work
through **2026-10-11T16:28:53.004Z** (UTC). The two manually tagged
`pnpm_android_architecture_visuals` turns include architecture, migration, tests,
CI and documentation together:

| Input | Cached within input | Uncached | Output | Total |
|---:|---:|---:|---:|---:|
| 5,904,238 | 5,756,416 | 147,822 | 42,406 | 5,946,644 |

The conversation total at that cutoff is **44,463,945 tokens** across **314**
responses and reconciles with the cumulative snapshot. This includes later work
in earlier phases; the older baseline files stay frozen. The snapshot ends before
the final screenshot-gallery and PR update, so it is not a final task invoice.
USD and savings remain unmeasured. Reusing dependency resolutions, limiting the
memory query scope and avoiding an Android rewrite are design choices, not a
measured percentage reduction.

## Native design fixes and affordable-AI planning

The [design/follow-up snapshot](ai-usage-native-design.json) ends at
**2026-10-12T18:54:05.831Z** (UTC; 13 October in Vietnam). It preserves the earlier
baselines. These are manual turn categories, each mixing several activities:

| Category | Input | Cached within input | Uncached | Output | Total |
|---|---:|---:|---:|---:|---:|
| Native design and gallery | 6,406,590 | 6,302,848 | 103,742 | 39,161 | 6,445,751 |
| Affordable AI proposal and design follow-up | 3,416,324 | 3,067,520 | 348,804 | 22,245 | 3,438,569 |

The whole conversation reconciles at **58,352,000 tokens across 420 responses**.
Repeated context is included; these are not unique project words. The cutoff
precedes the final screenshot import, documentation commit and PR creation. It is
not a final invoice or an exact split between design, coding, tests and research.
USD remains `null`; neither a smaller model nor cache reuse establishes savings.
The existing collector's eight tests passed for this capture.

## Start with the evidence

| File | What it records |
|---|---|
| [Agent usage](ai-usage-baseline.json) | Real Codex request tokens and reconciliation |
| [Migration usage](ai-usage-pnpm-architecture.json) | Later mixed migration, test and visual-documentation work |
| [Design/follow-up usage](ai-usage-native-design.json) | Later UI fixes and model/challenge planning |
| [Phase map](phase-map.json) | Manual categories for conversation turns |
| [Quality baseline](quality-baseline.json) | Test/coverage results at the recorded commit |
| [CI baseline](ci-baseline.json) | Runs and job times before the documentation push |

These are point-in-time snapshots, not live counters. Raw transcripts, prompts,
images, API keys and personal rollout paths are not committed. The collector reads
one explicitly selected rollout and filters the intended thread. Its local schema
was observed on 11 October 2026; it is not a stable public API.

## Observed token usage

- Input: **25,283,416**, including **23,766,272** cached
  and **1,517,144** uncached input tokens.
- Output: **205,159**, already including **55,721** reasoning tokens.
- Total input + output: **25,488,575** across **178** responses.
- Cached input ratio: **94.00%**.
- Reconciliation: **matched**, with zero delta in every field.
- USD cost: **unknown**, stored as `null`. Codex usage is not an app OpenAI invoice.

Input counts repeated context processing across requests, not unique words in the
project. Cached input is a subset of input; reasoning is a subset of output. Adding
them again would double-count. A cache ratio is not a measured savings percentage.

## By work category

Tokens are measured; category labels are manual. A mixed coding/testing turn cannot
be split exactly after the fact without finer markers. Turns with no usage record
are not filled with invented zeroes; the observed total still matches the snapshot.

| Category | Input | Cached within input | Uncached | Output | Total |
|---|---:|---:|---:|---:|---:|
| Product and UX planning | 861,800 | 766,720 | 95,080 | 7,042 | 868,842 |
| Erly research | 693,121 | 655,744 | 37,377 | 1,838 | 694,959 |
| Architecture and UI mock | 727,018 | 688,512 | 38,506 | 38,616 | 765,634 |
| Movement feedback plan | 3,326,351 | 3,282,176 | 44,175 | 9,807 | 3,336,158 |
| OpenAI architecture | 2,562,602 | 2,232,832 | 329,770 | 19,693 | 2,582,295 |
| Tech stack explanation | 281,577 | 139,776 | 141,801 | 1,207 | 282,784 |
| Repository, GitHub and Firebase setup | 2,772,336 | 2,583,424 | 188,912 | 10,822 | 2,783,158 |
| Implementation/TDD preparation | 1,029,067 | 1,000,192 | 28,875 | 2,120 | 1,031,187 |
| Implementation and testing (mixed) | 11,346,403 | 11,032,320 | 314,083 | 84,250 | 11,430,653 |
| Fixes, metrics and documentation (mixed) | 1,683,141 | 1,384,576 | 298,565 | 29,764 | 1,712,905 |

## By recorded model

| Model | Input | Cached | Output | Total |
|---|---:|---:|---:|---:|
| gpt-6-astra | 8,170,892 | 7,625,984 | 76,996 | 8,247,888 |
| gpt-6.1-sol | 16,666,457 | 15,907,200 | 113,883 | 16,780,340 |
| unknown | 446,067 | 233,088 | 14,280 | 460,347 |

`unknown` means a matching turn context was unavailable for model attribution.
Those tokens stay counted. Recorded labels do not establish intentional or optimal
model routing. Request tokens also cannot be billed separately to each MCP/skill
without additional attribution rules.

## Quality at the historical baseline

| Measure | Observed result | Scope |
|---|---|---|
| Vitest | 50/50 passed: 42 backend + 8 collector | Real Firestore Emulator, mocked OpenAI |
| Backend coverage | 97.54% statements, 95.86% branches, 92.50% functions, 100% lines | Backend TypeScript only |
| Collector coverage | 100% statements/functions/lines, 98.14% branches | Library; CLI wrapper excluded |
| Swift | 13 portable journeys passed; 83.67% regions, 98.55% functions, 97.76% lines | Core only; no branch counters |
| Native | XCTest, simulator SDK build and gentle-default UI passed | Not physical-device alarm/camera validation |
| TDD | 9 mapped cycles before localization | Native integration spike is not counted as local native TDD |
| Production audit | 0 advisories | Full dev audit still had 16 |
| Real paid inference | 0 calls in implementation tests | No accuracy/latency/cost benchmark |

See the [TDD report](../tdd/cost-optimized-pilot.tdd.md) for later localization results.
Do not update historical numbers silently when new tests are added.

CI baseline: **5 runs—1 success, 2 failures, 2 cancelled**. Failures caught native
compile errors. A manual dispatch duplicated a push among the cancelled work; that
is orchestration waste to avoid, not a result to hide. This small sample is not a
long-term productivity score.

[Run 38131960302](https://github.com/thanhdanh/HiMorning/actions/runs/38131960302) at
`39ecc17` took **236s** elapsed. Backend took **56s**, iOS **230s**; jobs overlapped.
Do not add job times and call the result elapsed time. Runner billing and tool/review
waiting time were not measured as model computation or USD.

## Refresh the usage snapshot

Pass the current conversation's exact rollout path. For a new conversation, update
`threadID` and `phaseByTurn` in the phase map first:

```sh
node scripts/collect-ai-usage.mjs --log /absolute/path/to/current-rollout.jsonl > /private/tmp/ai-usage.json
pnpm test tests/engineering-metrics.test.ts
```

Review the sanitized JSON, save it as a dated snapshot and update the reader-facing
table with the same cutoff. Never commit the raw rollout. `sourceSHA256` describes
the bytes read at capture time; appending to the local log changes that hash.

The collector deduplicates response IDs and compares summed request usage with the
last cumulative snapshot. It rejects conflicting duplicates, invalid arithmetic
and malformed complete JSONL lines. An unfinished last line is ignored with a flag.
Missing telemetry/reconciliation stays `null`, not “zero usage”.

The pre-push hook is a quality gate, not a token meter. No agent Stop hook or automatic
snapshot schedule is active. CI runs tests/coverage and keeps logs; it does not read
local chat transcripts. Library tests cover privacy filtering and failure cases.

## What to measure next

| KPI | Definition | Missing evidence |
|---|---|---|
| Usage by phase | Unique request tokens in tagged planning/code/test/review turns | Older turns mix work types |
| First-review acceptance | Tasks meeting all acceptance criteria at first review / total tasks | Independent review ledger |
| Rework | Fix-phase tokens / comparable total tokens | Complete phase labels; testing is not automatically rework |
| CI waste | Duplicate/cancelled runs, job time and runner billing | Actual billing |
| Cost per accepted behavior | Actual agent spend / accepted behaviors | Cost source and acceptance denominator |
| App cost per verified session | Provider cost / verified sessions, with uncertainty rate | Real provider usage, prices and outcomes |
| Exercise quality | False accept/reject, uncertainty, p50/p95 delay by viewing condition | Consented holdout clips and ground truth |
| Memory MCP benefit | Equivalent tasks using graph-first vs source-only retrieval | Controlled comparison at equal quality |

A useful comparison fixes the starting commit, task difficulty, runner, acceptance
criteria and budget. Lower tokens with worse behavior is not a successful optimization.
Prefer accepted behavior and remaining defects over lines of code or tool count.

## Read next

[AI engineering case study](../AI-ENGINEERING.md) · [TDD evidence](../tdd/cost-optimized-pilot.tdd.md)
