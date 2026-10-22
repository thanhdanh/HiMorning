# Erly public product research

This evidence summary explains the competitor lessons used for HiMorning's first-morning improvements.

**Status:** Public-surface REA capture completed on 23 October 2026; Android native investigation unresolved. **Audience:** Product and iOS contributors.

## At a glance

Actual REA observed the official [Erly website](https://erly.co/) in a temporary headless Chrome instance, capturing the rendered DOM, accessibility tree and a 390 × 844 screenshot. It did not inspect an APK or exercise Android alarms, onboarding, camera recognition or purchases.

| Evidence | Scope and result |
| --- | --- |
| `ev_d39e61da91fb6dd25ed9ec57c96ce2a8431715444782a4320d6799b81301b61c` | Successful REA website scenario capture; owned browser cleaned up |
| `ev_08cbb728ada0133e616eb1534729250d07511e4bc0014c1cba9e53a12ff0c563` | Official website artifact inventory; JavaScript semantic parsing failed from heap exhaustion |
| `ev_03347f292921163bcf3f19ea6bee75d4736b8a98b1162ea17a0072cf2bf9ddd3` | Bounded static retry also exhausted memory; zero JavaScript files parsed |

Complete local output is retained in the task workspace at `research/erly-2026-10-23/REPORT.md` and its adjacent `evidence/` directory, outside this Git worktree. No application-code claims are based on the failed static passes.

## How it works

The website frames a familiar problem, then demonstrates alarm setup, a mission and getting up. Examples, phone mockups, progress and streak messaging make the promised result concrete before installation. These are observed marketing surfaces, not independently verified mobile capabilities. The site's user and rating totals have no clearly established measurement scope.

The [Google Play listing](https://play.google.com/store/apps/details?id=com.erly.myapp&hl=en) advertises mission-based alarms, daily accountability, streak/history and a goal lock four hours before wake time. The observed listing showed 4.6 stars, 50K+ downloads and a September 2026 update. Visible reliability complaints are individual anecdotes, not measured failure rates. Its subscription text references iTunes, so current Android price, trial terms and free limits cannot be established from it.

## Key choices

The likely attraction mechanism is an understandable daily outcome, demonstrated quickly and reinforced by visible accumulation. This is a product inference, not conversion or retention data. HiMorning should connect its existing challenges into a purpose-based routine: choose a reason, anticipate the next mission, complete a small morning action, see earned progress and continue toward a nearby milestone. Safe practice and truthful counts support that experience.

The paid-value hypothesis is ongoing guidance, relevant variety and useful reflection as a routine develops. A seven-morning journey is a HiMorning proposal, not an observed Erly feature. The additional [official App Store page](https://apps.apple.com/us/app/erly-wake-up-early/id6751428380) contains anecdotal examples of both paying for a useful daily outcome and resisting payment before experiencing value; it does not establish their frequency, age distribution or current trial policy. The fuller product interpretation is retained in `research/erly-2026-10-23/PRODUCT-LOOP.md` outside this worktree.

Preserve offline local completion, recovery choices and optional billing. A four-hour edit lock, guaranteed wake-up promise, fake social proof, or unverified subscription price is not justified by this research.

## What we checked

REA 6.7.0 was run through its existing public launcher. No MCP configuration, Java/JADX engine or unrelated toolchain was installed. Public website runtime capture succeeded; static parsing failed under both attempted memory budgets. A native Android package was not available through an official acquired artifact or installed instance.

A bounded follow-up found an APKPure listing for the exact package `com.erly.myapp`. Its direct XAPK request returned HTTP 403 and a “Just a moment...” HTML page; no package was acquired and no access challenge was bypassed. The host has no usable Java runtime, JADX, ADB or configured JADX MCP JAR. Third-party version and signature metadata therefore remain unverified. Exact response metadata and tool diagnostics are retained beside the full report in `evidence/android-follow-up.json`.

## Limits and next steps

Native Android implementation, actual first-run flow, paywall timing, billing entitlements, offline recovery and overnight reliability remain unknown. A separate native pass needs an authorized official APK or installed Android instance. Interviews and repeated real morning trials are needed to establish willingness to pay and retention.

## Read next

- [Direct HiMorning experience](FIRST-MORNING-REVIEW.md)
- [Erly official website](https://erly.co/)
- [Erly Android listing](https://play.google.com/store/apps/details?id=com.erly.myapp&hl=en)
