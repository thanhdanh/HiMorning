# A morning people want to start

Give HiMorning a reason to be chosen beyond price or the number of alarm missions.
The proposed promise is a short, enjoyable start with one small useful activity.

**Status:** Product hypotheses from 13 October 2026; not user-validated. See the
[current feature list](../README.md#implemented-pilot) for implemented prototypes;
the richer beat and combined speaking/meaning activities below remain proposals.
**Audience:** Product, design and engineering. **Decision:** Evaluate bounded
prototypes; no-go for a claim that HiMorning is better than Erly until tested.

## At a glance

| Question | Working answer |
|---|---|
| Who is it for? | People who want help starting their morning, with different levels of structure, space and privacy |
| Pain | Repeatedly dismissing an alarm, then feeling frustrated by either drifting back to bed or an unpleasant task |
| Job to do | Help me begin something small that feels worth getting up for |
| Why explore this now? | The native pilot provides a starting flow; the user has selected a vision model to evaluate and requested more enjoyable challenges |
| Ideal experience | The alarm works, the task is familiar and brief, feedback feels fair, and I leave my phone with a small win |
| Smallest experiment | Read & Choose, a short rhythm sequence and an existing local exit; QR is a separate practical fallback |
| Anti-goal | An exercise enforcer, pronunciation examiner, addictive game feed or complicated morning dashboard |
| Main outcome | People keep using it because mornings feel easier and more pleasant, with fewer unwanted returns to bed |

The last outcome is a hypothesis. Finishing a task does not prove wakefulness,
learning, exercise safety or a health benefit. Keep ordinary alarms and voluntary
self-confirmation useful for people who do not want a challenge.

## What the comparison actually shows

Erly already offers movement missions and accountability through goals and streaks.
Its public pages emphasize firm commitment; this is a strength for users who want
that structure. Math also appears in its public Android reviews. These observations
come from the [App Store listing](https://apps.apple.com/us/app/erly-wake-up-early/id6751428380)
and [Google Play listing](https://play.google.com/store/apps/details?id=com.erly.myapp&hl=en),
reviewed on 13 October 2026, not a hands-on comparison.

Variety alone is weak differentiation: Alarmy's official guide describes brain,
movement and location missions, including custom typing, memory, QR and an AI item
hunt. It also describes a wake-up recheck and an emergency path for location tasks.
[Alarmy mission guide](https://alar.my/en/blog/how-to-choose-alarmy-mission)

Do not claim that competitors lack dance, language activities, recovery or quiet
options based only on these listings. Their full current experience has not been
reproduced. HiMorning's opportunity is a coherent experience whose usefulness,
enjoyment and reliability can be measured, not a claim to have invented missions.

## Two activities worth testing

### Catch the beat / Bắt nhịp

Follow the sun through three or four simple upper-body moves for about 20–30 seconds.
For example: lift hands, reach left, reach right, then repeat the sequence. Offer a
seated version and a visual/haptic option without added music. The alarm's own
sound behavior still needs separate device validation.

A short original or licensed beat gives the task character. Preview the exact task
before saving an alarm. Keep the same expected effort in the morning; freshness
can come from optional variations, not surprise difficulty.

Completion should recognize participation in the intended sequence with a generous,
calibrated timing window. It should not require polished dancing or judge body
shape, flexibility or exercise technique. Poor visibility should suggest adjusting
the phone or choosing another task, without adding moves as a penalty.

**Technical approach:** Use local pose observations and timestamps against a known
sequence. Test seated/standing motion, camera framing, occlusion and interruptions
with real people. Qwen may be evaluated for a coarse image-sequence check, but it
is not the default beat judge. Sparse images cannot establish precise rhythm.
The current five-phase push-up policy cannot be reused unchanged for dance.

**What to learn:** Is this enjoyable after the first few mornings, and is camera
placement less trouble than the activity is worth? Test this before building a
library of choreography or social sharing.

### One English thought / Một câu tiếng Anh

Read one short, practical sentence, then answer one simple meaning question.
Use curated, reviewed content at a chosen level and topic. English learning is
optional and independent of whether the app's menus are in English or Vietnamese.

Example content, not shipped UI copy:

> “I’ll leave a little earlier today.”
>
> Choose its meaning: “Hôm nay tôi sẽ đi sớm hơn một chút.”

Start with **Read & Choose**: it works without a microphone, a server or speaking
near someone sleeping. Ask for understanding rather than a long typed answer.
Repeat useful material over days without promising a learning gain before testing.

Add **Speak & Choose** only after validating demand: say the sentence, then answer
its meaning. Speech recognition can check intended words; it should not reject a
Vietnamese accent or pretend a transcript is a pronunciation assessment. Offer a
quiet alternative and clear recovery if speech is unclear.

**Technical approach:** Local content and answer rules first. Optional speech uses
a separate platform speech engine, not the Qwen vision path. Only offer an offline
voice promise where the device/locale actually supports on-device recognition;
otherwise keep Read & Choose available. Microphone/speech permissions, recognition
availability, alarm-audio interference and interruption behavior need native tests.
Apple distinguishes [on-device support](https://developer.apple.com/documentation/speech/sfspeechrecognizer/supportsondevicerecognition)
from [requesting on-device recognition](https://developer.apple.com/documentation/speech/sfspeechrecognitionrequest/requiresondevicerecognition).
Do not silently switch to a network recognizer.

**What to learn:** Do people want this during their actual mornings? Measure repeated
use and usefulness separately from answer completion. Keep live generated lessons
and detailed pronunciation coaching outside this experiment.

## Make the whole morning better

These are proposed advantages to validate, not exclusive features or proven wins.

| Advantage to earn | Concrete behavior | Evidence needed |
|---|---|---|
| A small useful win | A brief rhythm activity or one useful English thought, then leave the phone | Repeated voluntary choice and usefulness ratings after novelty fades |
| Fit different living situations | Quiet task, seated motion, camera-free choice and editable weekday schedules | Try shared rooms, small spaces, different abilities and shift schedules without assuming every Vietnamese user has the same needs |
| Fair feedback | Clear progress, one helpful cue, another way to finish; optional form advice after completion | Unnecessary rejection, recovery time and frustration reports |
| Trust on a difficult morning | Local alarm and exit; no login or server round trip required to stop | Physical-device tests for offline use, interruption, permissions, time zones and sound |
| Calm sensory design | Existing cream/yellow theme, warm sun, reviewed short cues, deliberate sounds | Native speaker tests, shared-room feedback, large text, VoiceOver and reduced motion |
| Control and privacy | Preview before enabling; no automatic bedroom recordings or public uploads; explicit processor disclosure | Verify data handling and consent, not just reassuring copy |
| Progress without shame | Optional weekly wins and gentle return after a missed day | Whether it helps people return; no unmeasured streak-pressure claim |

Personalization starts with explicit choices, not AI profiling. Let users choose
activity, effort and sound before bed. Keep the choice editable; do not silently
raise effort, move the alarm time or infer a medical or emotional condition.

A possible future sharing loop is an optional illustrated morning card after
completion. Raw camera/audio sharing and public leaderboards are outside the MVP.
Content quality and returning users can become an advantage over time; a model
name or a longer mission list is easy for another app to copy.

## One simple journey

1. **Before bed:** Set time and sound; choose one activity and try it. Show only its
   relevant goal. Keep Gentle/Balanced/Focused as effort suggestions, not identities.
2. **When the alarm rings:** Show the chosen familiar task and clear progress. Keep
   another way to finish and Stop visible. Do not open a catalog or add new setup.
3. **If checking fails:** Explain the uncertainty briefly and offer a local choice.
   Do not add questions, moves or retries as punishment.
4. **After finishing:** Show a small win and let the person leave. An optional single
   “Feeling more awake?” response must not block completion or be treated as proof.

Use short, natural English and Vietnamese copy. Preserve the original sunshine
palette; adding playful content does not require a new visual identity. The current
[native gallery](UI-DESIGN.md#native-screens) does not show these planned activities.

## What to prototype first

The following scores are product judgment, not measured demand. Impact and
confidence use 1–5; effort uses 1–5, where 5 is largest. Score = impact × confidence /
effort. Reliability is a release gate and is not traded against feature scores.

| Candidate | Impact | Confidence | Effort | Score | Decision |
|---|---:|---:|---:|---:|---|
| Read & Choose | 4 | 3 | 2 | 6.0 | First differentiation experiment; no speech dependency |
| Local QR | 3 | 4 | 2 | 6.0 | Practical fallback in a separate small change, not the product headline |
| Guided rhythm | 5 | 2 | 3 | 3.3 | Second experiment; test framing and repeat appeal early |
| Speak & Choose | 4 | 2 | 4 | 2.0 | Add after demand, permission and recognition checks |
| Free-form dance judging | 4 | 1 | 5 | 0.8 | Defer; unclear success rules and harder validation |

Retain the existing push-up choice for people who want it. Short math and memory
can be useful alternatives later, but neither needs to become another launch
project. Do not build all candidates at once.

## How to know whether it is better

Start with a consented exploratory pilot of roughly 12–20 people across relevant
living situations and preferences. Use their normal wake schedules. Where feasible,
vary the order of the current push-up flow, Read & Choose and rhythm across repeated
mornings. Track actual exposures and task switching; report small counts and
novelty effects. This is usability learning, not a statistically conclusive trial.

| Question | Measure |
|---|---|
| Does the foundation work? | Alarm/recovery outcomes in a documented device matrix, including offline and interrupted cases; investigate every missed alarm |
| Is the task brief and fair? | Start-to-finish p50/p95, incomplete attempts, unnecessary rejection on reviewed complete attempts, overrides and exits |
| Is it pleasant and useful? | Optional usefulness/enjoyment feedback after several uses, reasons for switching, noise and camera-framing complaints |
| Does the person stay up? | Optional return-to-bed self-report within a defined follow-up window; no claim of passive sleep detection |
| Do people return? | D7/D28 app-use retention and repeat challenge use, with cohort dates, eligible users, opt-in coverage and denominators |
| Does English add value? | Repeated choice and an optional later comprehension check, separate from speech-transcript success |

Define a retained user before the pilot: for example, a person who starts a morning
flow and completes a task or self-confirms on day 7/28 after their first eligible
morning. Use only cohorts with that full follow-up window, report eligible counts
and disclose missing/opted-out telemetry. Count exits and switches separately;
auto-enabled alarms and simple app opens are not completed morning journeys.

Record task/version, result, timing and chosen effort only where consent permits.
Keep raw images/audio and recognized speech out of product telemetry by default.
Agree target completion, false-block and return rates before collecting the pilot;
do not tune success criteria after seeing results. Stop expansion while reliability
or repeated unfair blocking remains unresolved. Few minutes spent in the app is
not a failure: helping the person leave the phone is part of the product.

A head-to-head claim needs a separate, disclosed comparison on matched devices,
settings and schedules, with participant consent. Do not infer Erly's failure rate
from selected store reviews or present a HiMorning-only pilot as that comparison.

## What we checked and what comes next

Reviewed the primary competitor listings, official Alarmy guide, selected Qwen
model and platform speech limits. Checked current camera, push-up counter and
backend verifier boundaries with codebase-memory coverage and source reads.
No competitor app was exercised and no user research, dance scoring, speech test
or Qwen inference was run for this brief.

Next, use the existing task rehearsals and interview people about repeated use. In
parallel with product validation, smoke-test the exact downloaded Qwen 9B build
with its vision projector on the intended host. Keep model evaluation separate
from whether users value a challenge. Expand the selected activities only after
that evidence, preserving EN/VI copy, saved-alarm migration and behavior tests.

## Read next

[AI and challenge architecture](AI-AND-CHALLENGES-PLAN.md) ·
[Implementation plan](IMPLEMENTATION-PLAN.md) · [UI and sound](UI-DESIGN.md) ·
[Optional form feedback](POSE-FEEDBACK-PLAN.md) · [Engineering evidence](AI-ENGINEERING.md)
