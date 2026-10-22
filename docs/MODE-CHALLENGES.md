# Challenges and camera framing

A challenge is saved separately from its difficulty level. Check movement on the
phone and show a clear next step when the camera cannot see the required joints.

**Status:** Implemented iOS pilot, reviewed against `6a1e1e7` on 22 October 2026.
Recognition thresholds are still being calibrated with physical use.
**Audience:** iOS maintainers, designers and pilot testers.

## At a glance

| Display level (EN / VI) | Editor catalog | Default when changing to the level |
|---|---|---|
| Gentle / Nhẹ nhàng | No challenge, Wave hello, Neck turns | No challenge |
| Balanced / Vừa sức | Read Aloud, Read & Choose, Riddle | Read & Choose |
| Challenging / Năng động | Push-ups, Jumping jacks, Reach up | 10 push-ups |

Persisted IDs remain `gentle`, `balanced` and `focused`; localized labels are not
storage migrations. New alarms default to Gentle and no challenge. Incompatible
choices change with the selected level. Explicit legacy selections, including
standing/seated Guided Rhythm, remain editable until a new choice is made.
[Access rules](SUBSCRIPTIONS.md) can cap a saved push-up target without rewriting it.

## Movement rules

| Challenge | Camera needs | What counts |
|---|---|---|
| Wave hello | A visible hand/palm | Horizontal side-to-side swings, not simply lifting the hand; 3 repetitions |
| Neck turns | Face and usable yaw | Turn to each side and return toward the middle; either side can come first; 3 repetitions |
| Reach up | Both shoulders and elbows; wrists/head/hips/legs are not required | Both upper arms raised near shoulder height counts immediately after a short stable observation; 3 repetitions |
| Jumping jacks | Shoulders, wrists and ankles | Closed → open → closed, with arms and legs in the matching poses; 10 repetitions |
| Push-ups | A side view of the whole body, including the visible shoulder/elbow/wrist and body alignment | A complete controlled down-and-up movement; exact saved target, up to 50 |
| Guided Rhythm (legacy) | Seated: upper body and wrists; standing: body/knee geometry | Ordered down/up/down or stand/bend/stand sequence; 3 cycles |

Reach up counts on the raised pose, even if the camera starts with arms already
raised. Holding them up counts only once; lowering both arms rearms the next
count. Tracking loss, transitions and interrupted timestamps do not rearm held
arms. Current tuning accepts a 120 ms raised observation, moderately confident
joints and near-edge framing. Both shoulders/elbows must still be detected inside
the image; missing joints are not invented. The geometry uses the shoulder axis
and pixel aspect ratio rather than fixed image-height thresholds.

The live preview retains the person and room. Arm/body lines connect observed
joints; the optional curved face centerline helps visualize head turns but does
not change yaw counting. Stale or missing landmarks disappear. Permission denial,
backgrounding or interruption stops capture. These heuristics do not establish
exercise technique, identity, liveness or wakefulness.

## Trying a challenge and hearing guidance

In the editor, a single tap selects. Double-tap and confirm to start a trial with
the current draft target/variant. Returning preserves unsaved values. Trials do
not create alarms, stop an existing alarm or add progress records.

Voice coaching starts with one short cue. A changing hint must stay stable for
two seconds, and spoken hints are at least 15 seconds apart; progress suppresses
hints for ten seconds. Repetitions tick, while only occasional five-count
milestones are spoken. Hints do not interrupt speech or build a speech queue.
Installed voice quality varies by phone. Completion copy is time-neutral.

## Reading and content

Read & Choose and Riddle use local answer mapping; Read Aloud compares recognized
words with the displayed sentence at the existing 80% passing threshold. It does
not grade accent or pronunciation. Unsupported on-device speech during a real
wake falls back to a reading question rather than a network recognizer.

Content sources live under [`shared/content/challenges`](../shared/content/challenges/).
`pnpm run content:build` validates and generates both app and Worker packs.
The app uses bundled/cached content offline and optionally refreshes from
`/content/v1/challenge-content.json` at most once per 24 hours outside a challenge.
It remembers the last 20 prompt IDs per content kind/language and resets an
exhausted pool without immediately repeating the previous prompt when possible.
Read-aloud retries retain the sentence. Vietnamese items still need the
[owner's native-speaker review](../shared/content/challenges/REVIEW.md).

## What we checked

[`MotionCounterTests`](../apps/ios/HiMorningCore/Tests/HiMorningCoreTests/MotionCounterTests.swift)
cover frame loss, partial movement, close framing, camera tilt, one-arm/small lifts,
raised-pose counting and duplicate prevention. Native tests cover projection,
observed arm/face lines and capture cancellation. See [Validation](VALIDATION.md)
for dated results; synthetic joints do not measure a person's recognition rate.

## Read next

[Push-ups](PUSH-UP-CAMERA.md) · [UI rules](UI-DESIGN.md) ·
[Alarm recovery](ARCHITECTURE.md#follow-one-alarm) · [Release checks](RELEASE-READINESS.md)
