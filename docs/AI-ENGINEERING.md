# Building HiMorning with AI

HiMorning is a practical case study in using an AI agent to build, test and explain
a mobile product. The useful evidence is the chain from a user need to a decision,
a test and a reviewable change—not the number of tools used.

**Status:** Pilot source and [PR #1](https://github.com/thanhdanh/HiMorning/pull/1).
No production deployment, paid inference benchmark or release certification.

## The problem and the human decisions

The goal was a morning alarm for people with different habits: some want structure,
others need a gentle start. The developer set the product direction: simple choices,
yellow sunshine branding, Vietnamese users, OpenAI/Firebase, an iOS 26+ pilot, then
English and Vietnamese support with English code and docs.

The agent researched, proposed architecture, built the mockup, wrote tests and code,
read failures and prepared documentation. Do not describe agent-written work as
hand-written, or claim every line received human review unless that review happened.

## From idea to evidence

| Stage | How AI helped | Reviewable artifact |
|---|---|---|
| Plan | Turn a broad idea into user choices, constraints and milestones | [Plan](IMPLEMENTATION-PLAN.md), [feedback proposal](POSE-FEEDBACK-PLAN.md) |
| Design | Explore a calm yellow UI and simple morning flow | [UI guide](UI-DESIGN.md), `design/` study |
| Architecture | Separate local alarms from optional cloud checking | [Architecture](ARCHITECTURE.md), [backend](FIREBASE.md) |
| Code | Implement behavior around failing contracts and preserved checkpoints | [TDD evidence](tdd/cost-optimized-pilot.tdd.md), Git history |
| Test | Run unit, emulator, Swift, native build and UI checks | [Setup](RUNNING.md), GitHub Actions |
| Measure | Extract actual token records, reconcile totals and label limits | [Metrics](metrics/README.md), tested collector library |
| Refine | Add language resources and rewrite reader-facing guides | [Language guide](LOCALIZATION.md), [doc template](DOC-TEMPLATE.md) |

## Monthly Pro: use the platform before adding services

The owner set a $2–3 monthly budget; the pilot targets US $2.99. AI-assisted work
used failing Swift history journeys and a missing-StoreKit-adapter Xcode RED, then
implemented verified local access with Apple's native subscription view. Paid
cloud AI and rewarded referrals remain separate work. The [monthly Pro evidence](tdd/monthly-pro.tdd.md)
records checkpoints, coverage and validation gaps without inventing token savings.

## A concrete example: cost bugs that tests caught

Accepting camera consent twice created two cloud sessions. A runtime test reproduced
the extra session; the fix reuses the current unexpired one. Repeating cancellation
also performed an extra Firestore write. Its RED showed `expected 5 to be 4` writes;
the fix returns the same outcome without writing again.

These small cases connect product behavior with operating cost. They are stronger
interview evidence than saying “the app is cost optimized” without a reproducer.
The [checkpoint index](tdd/cost-optimized-pilot.tdd.md) shows both failures and fixes.

Native UI tests also caught a packaging bug: language files existed and resource
checks passed, but XcodeGen had omitted them from the app bundle. The English
journey passed through fallback text; Vietnamese and saved-choice journeys failed.
The fix includes the resource folder in the target sources; all three UI journeys
then passed in [CI](https://github.com/thanhdanh/HiMorning/actions/runs/38135338781).
This shows why catalog checks and native runtime checks answer different questions.

## A second example: a move that clients can check

The pnpm migration moved Apple code into `apps/ios` and Firebase code into
`backend/functions`. A JSON Schema and synthetic fixtures in `shared/contracts/v1`
keep the wire format visible to future Android clients without pretending Swift
and Kotlin share a runtime. TypeScript checks the exported schema against the live
validators; the Swift harness decodes and encodes the same fixtures.

The missing contract module and missing Swift fixture each produced an executed
RED, followed by the same checks passing. A clean pnpm install and an isolated
Firebase production install tested packaging separately. The first staging attempt
failed because legacy deploy mode did not produce a lockfile; the current mode
fixed it. Android remains a guide and reserved folder, not a working app.

CI also captures named screenshots from the English and Vietnamese UI tests. The
[gallery](UI-DESIGN.md#native-screens) links the actual simulator images and their
source run. Architecture SVGs were authored as diagrams and visually inspected;
they are not screenshots of an implemented Android app.

## Design feedback exposed a gap in the checks

The first native UI used gray system surfaces and default yellow, while the
approved web study used cream `#FFFCF6` and yellow `#F5C842`. Its four screenshots
only showed two screens in two languages. Resource parity and interaction tests
had not checked the rendered visual direction.

Following user feedback, the agent reviewed the original screens with Chrome
DevTools and applied ECC `frontend-design-direction`. Two native UI tests then
reproduced the color mismatch by sampling screenshot pixels; they also found no
rehearsal entry before creating an alarm. The [design evidence](tdd/native-design-parity.tdd.md)
keeps the actual RED run separate from compilation or packaging feedback.

A shared native theme, compact editor choices and a dedicated sound screen bring
the existing flow back to that reference. The expanded gallery contains 20 actual
captures across 10 states and two languages, including consent, unavailable AI,
self-confirmation and trial exit. It does not present a generated camera image or
an unmeasured AI verdict as real verification. This is a concrete example of adding
a visual acceptance check after text-only tests missed a product requirement.

## Revisit the model choice with evidence

The user later requested a cheaper open model and more challenge choices. The
[updated proposal](AI-AND-CHALLENGES-PLAN.md) keeps Firebase policy and the existing
verifier port and evaluates the user-selected bartowski Qwen3.5-9B GGUF with its
matching vision projector on an exact host/runtime. Local tasks remain separate
from the cloud provider. Official Jev documentation rules out a direct image
replacement for TypeSafe's text-only model. The proposal also identifies provider-specific
consent and historical outcomes that a replacement must migrate together.

This is architecture and evaluation work, not an implemented Qwen service. GPU
cost, cold loading, morning concurrency, false decisions and uncertainty need
measurement. No local model was installed and no production image was sent in
this review. Avoid describing “open weights” as measured savings.

The later [product brief](PRODUCT-BRIEF.md) applies ECC `product-lens` to compare
primary competitor listings, separate facts from hypotheses and prioritize two
small experiments. Math/QR variety already exists in the market, so the proposed
value is a brief, enjoyable and useful morning activity. The architecture separates
vision, speech and temporal scoring instead of assuming one model can verify them
all. The brief defines usability, repeat-use and reliability measures; its priority
scores are judgment, not user research or proof of superiority. This is an example
of deciding what to test before asking an agent to write more code.

## Tools, skills and plugins

An **MCP** exposes tools to the agent. A **skill** guides a workflow. A **plugin**
packages capabilities; installation alone is not evidence that they were used.

| Used capability | Role in this work | Boundary |
|---|---|---|
| `codebase-memory` skill + MCP | Inspect index, architecture and path coverage; refresh stale data | Graph results need freshness checks and source fallback |
| ECC 2.2.3 planning/ADR/frontend skills | Guide planning, architecture and the design study; skill paths appear in the trace | No subagents or parallel agent team were used |
| ECC `tdd-workflow` | Require a valid RED, GREEN, checkpoints, coverage and evidence | Initial native adapters were an integration spike, not complete local native TDD |
| ECC `product-lens` | Frame product hypotheses, rank small experiments and define outcomes | No hands-on competitor test or user research; scores are provisional judgment |
| `openai-docs` | Consult official API material at the point of implementation | Documentation does not measure model accuracy |
| ECC `cost-tracking` | Review cost-log availability and cumulative-snapshot pitfalls | Its Claude cost log was absent; Codex token records are the actual source here |
| Codex app tools | Open artifacts and attach the PR to the conversation | Git/`gh` operations remain CLI work, not automatically MCP calls |
| Computer use/CUA and Chrome DevTools MCP | Review the earlier prototype and render architecture SVGs | Not proof of native camera or alarm behavior |
| pnpm (current), npm (earlier), Swift, Firebase CLI and Actions | Execute checks and preserve build feedback | SDK mocks and emulators are not production results |

The JSON-oriented `i18n-sync` skill was reviewed for the language change. Native
`.strings` extraction is outside its scope, so the implementation uses Apple's
localization format and project tests instead of claiming that workflow was applied.

## Memory that can be checked

The initial index at `2026-10-11T05:21:54Z` had 162 nodes/359 edges. After native and
backend files were added, path coverage reported `not_tracked` even though the issue
status said `no_recorded_issue`. The agent read source and refreshed the index in
`fast` mode, without adding semantic embeddings.

The `2026-10-11T10:26:33Z` snapshot had 632 nodes/1,920 edges. Relevant backend/camera/
core paths matched metadata. `ChallengeView.swift:66` had a partial parse, so the
source around it was read directly. Some docs/scripts/tests were excluded by the
fast index. Those counts describe that snapshot, not the final repo or token savings.

After localization, the `2026-10-11T11:19:16Z` fast index had 889 nodes and
2,267 edges. The new language helper and policy paths matched metadata; the partial
challenge-view parse and fast-mode exclusions still required source fallback.

After the folder migration, the old index still named `ios/` paths. A requested
`fast` refresh at `2026-10-11T16:28:17Z` reported 1,036 nodes and 2,478 edges.
Coverage checks for six relocated contract/client/UI paths matched metadata; the
challenge view still had a partial parse at line 66, so lines 45–85 were read
from source. These are retrieval diagnostics, not measured token savings.

Use this sequence: inspect readiness → query a small scope → check path coverage →
read gaps → refresh if needed. A clean signal is not proof of completeness, and an
empty result is not proof that code does not exist. This is codebase memory, not
personal memory about users.

## Techniques worth explaining in an interview

1. **Bounded hybrid inference.** Local pose/capture gives quick feedback, but cannot
   declare AI success. OpenAI receives ordered evidence; server policy checks it.
   Image/output budgets, one attempt, quotas and default-off cloud limit spending.
   Accuracy and actual dollar savings remain unmeasured.
2. **Transactions around paid work.** Reserve an attempt atomically, call the model
   outside the transaction, then finalize the current lease. This protects against
   callback retries and concurrent workers without promising exactly-once billing.
3. **Lifecycle and late results.** Client generations and server cancellation/expiry
   stop old results from changing the outcome. Offline scheduling/stop is separate
   from sign-in, camera and cloud success.
4. **Evidence before claims.** Keep runtime/compile REDs and GREEN commits. Missing
   Java or XCTest is infrastructure failure, not a behavior RED. Keep SDK build
   feedback separate and report coverage by scope.
5. **Focused context.** Use graph queries, targeted source reads and official docs;
   batch independent reads. Handoffs preserve current work. These practices still
   need a controlled comparison before claiming a savings percentage.
6. **Measured usage.** Filter one conversation, deduplicate response IDs, sum each
   request's usage and compare with the last cumulative snapshot. Cached input is
   part of input; reasoning is part of output. Neither is added twice.

## Hooks and quality gates

The project-local [.githooks/pre-push](../.githooks/pre-push) runs whitespace checks,
TypeScript and non-emulator tests. It was enabled locally with:

```sh
git config --local core.hooksPath .githooks
```

It actually ran on pushes. A fresh clone needs to enable it separately. It does
not call OpenAI or export transcripts. Emulator/native checks run in CI. No global
or agent Stop hook was installed; the ECC Claude cost hook is not a Codex meter.
Remove the local hook with `git config --local --unset core.hooksPath` if needed.

## Measure useful outcomes

Separate agent usage, software quality and app inference. See the [baseline](metrics/README.md)
for exact counts and missing data. No per-MCP/skill token billing is available;
request usage includes context and tool results, so allocating it to individual
tools would require additional instrumentation and clear attribution rules.

A future comparison should use equivalent tasks, the same starting commit, runner,
acceptance criteria and budget. Measure uncached input, output, elapsed time,
first-review acceptance and remaining defects. Cost per accepted behavior needs an
actual cost source and an acceptance ledger. More code or more tool calls is not
success by itself.

Split future planning/coding/testing/review turns and label them in the phase map.
Historical mixed turns stay combined. Observed model labels do not prove an optimal
routing strategy. A high cache ratio is not the same as dollars or minutes saved.

## A short interview story

> I built HiMorning with an AI agent, while setting the product goals and pilot
> scope myself. I used tests and preserved RED/GREEN commits to check cloud cost
> controls, cancellation and local alarm state. I also built a tested token collector
> that reconciles real usage records, then documented both the results and gaps.
> The pilot has native build/UI checks; physical-device reliability and exercise
> accuracy still need separate evaluation.

A useful demo is one RED commit, its GREEN fix, the test result, a CI run and the
token ledger. Explain what you verified and what the agent did. Be ready to describe
one failure and the tradeoff behind its fix.
