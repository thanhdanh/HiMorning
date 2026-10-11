# Pilot implementation plan

Build a small alarm app that is easy to leave running, easy to stop and honest about
what AI can check. The first release target is iOS 26+, as chosen for the pilot.

**Status:** Backend and native foundation implemented; release validation remains.

## Milestones

| Milestone | Acceptance | Status |
|---|---|---|
| Local alarm foundation | Journal before scheduling; confirmed only after OS result; recover after interruption | Implemented and core-tested; device tests remain |
| Bounded cloud checking | Owned sessions, consent, quota, one attempt, ordered evidence and conservative verdict | Implemented; model accuracy unmeasured |
| Clear recovery | Local stop works without network; cancel/expiry reject late success | Implemented and tested at contract/core level |
| Two languages | English/Vietnamese copy, device fallback, saved picker and translated permissions | Implemented; hosted UI checks tracked in PR |
| Developer evidence | TDD checkpoints, CI, token ledger and case study | Baselines recorded; no invented USD or savings claim |
| Release evaluation | Real-device matrix and consented model benchmark | Pending |

## User journeys to protect

1. A sleepy person can choose Gentle and finish without cloud or false AI success.
2. An opting-in person sends one bounded sequence; uncertainty offers a clear exit.
3. Stopping a challenge prevents a later result from changing it to success.
4. Clients cannot write authoritative verdicts, quotas or other users' preferences.
5. Interrupted camera movement does not create a rep from partial evidence.
6. Changing language affects copy, not the alarm time, mode or target.

Write the relevant tests before production code, validate a real RED, keep its
checkpoint, then implement and rerun the same target for GREEN. Record SDK/build
failures separately from behavior-test REDs.

## Pilot budgets

1–5 reps; five phases per cycle; 25 JPEGs maximum; 512px long edge; 50KB/frame;
1.25MB total; one paid attempt/session; 3 calls/user/day UTC and 100 globally;
800 output tokens; 15s provider timeout; 25s non-reclaimable lease. These need
accuracy/latency evaluation, not blind reduction for a lower token count.

## Next decisions

Validate the native alarm/camera/sound flow first. Then evaluate OpenAI on consented,
person-separated fixtures. QR, editing, native snooze, weekly history, deeper form
advice, Android, sync and subscriptions are separate future milestones.

## Read next

[Setup](RUNNING.md) · [Architecture](ARCHITECTURE.md) · [TDD evidence](tdd/cost-optimized-pilot.tdd.md)
