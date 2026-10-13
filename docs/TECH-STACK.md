# Tech stack

HiMorning uses native iOS code for alarms and camera access, Firebase for a small
backend, and OpenAI to check consented movement evidence. Each part has a clear job.

**Status:** Pilot source and contract tests are implemented. No cloud deployment
or exercise-accuracy benchmark has been run. A separate [local Qwen check](LM-STUDIO.md)
confirms synthetic image/JSON compatibility; the app adapter remains unchanged.

The proposed next direction evaluates the user-selected bartowski Qwen3.5-9B GGUF
with its vision projector through LM Studio headless. Short rhythm and English
activities use their own local timing/content checks; optional speech needs a
separate recognition engine. The [architecture proposal](AI-AND-CHALLENGES-PLAN.md)
and [product brief](PRODUCT-BRIEF.md) separate these plans from the OpenAI
implementation described below.

## Stack at a glance

| Part | Choice | Why it is here |
|---|---|---|
| Native UI | SwiftUI, iOS 26+ | Direct access to platform behavior and accessible controls |
| Alarm scheduling | AlarmKit + App Intents | Let the OS keep the schedule and provide user controls |
| Local state | Swift domain + atomic JSON journal | Save intent before scheduling and recover after interruption |
| Camera | AVFoundation + Vision + Core Image | Foreground capture, provisional pose checks and bounded JPEGs |
| Languages | Foundation `.strings` resources, English + Vietnamese | Native UI and permission copy, with a saved in-app choice |
| Cloud identity | Firebase anonymous Auth + App Check | Identify cloud callers and enforce attestation |
| Database | Cloud Firestore | Server-owned sessions, attempts and quotas |
| Compute | Callable Functions v2, TypeScript, Node 22 | Validate evidence and keep the API key on the server |
| AI | OpenAI Responses + structured output | Assess ordered image evidence; the backend checks the result |
| Validation | Zod + sharp | Check schemas, decode images and strip metadata |
| Tests | Vitest, Firestore Emulator, Swift harness/XCTest, XCUITest | Test rules, races, domain behavior and native UI |
| Build | pnpm workspace and lockfile, XcodeGen, GitHub Actions | Repeatable dependencies, project generation and CI |

Pinned package versions are recorded in the manifests and lockfile. Firebase iOS
is pinned to 13.0.1 in `apps/ios/project.yml`. No analytics SDK, subscriptions or alarm
sync are required for the current pilot.

## What OpenAI receives

The app does not stream continuous video to the model. It selects a short ordered
sequence of JPEGs covering top, descent, bottom, ascent and return for each cycle.
Frame IDs and relative timestamps describe the order. They do not prove movement
by themselves.

| Limit | Pilot value |
|---|---|
| Requested reps | 1–5 |
| Evidence | 5 phases per provisional cycle, at most 25 frames |
| Image size | 512px long edge, 50KB per JPEG, 1.25MB total |
| Session life | 120 seconds |
| Paid attempts | 1 per session; no automatic provider retry |
| Daily AI quota | 3 per user, 100 globally, using UTC days |
| Provider timeout / lease | 15 seconds / 25 seconds; no lease reclaim |
| Model output | At most 800 tokens, reasoning `none`, verbosity `low` |
| Default cloud state | Off |

The configured candidate is `gpt-5.6-terra`. It has not been chosen through a real
accuracy/cost comparison, and no measured success rate is claimed.

The OpenAI adapter uses `responses.parse`, a strict Zod output schema, low-detail
images and `store: false`. Refusal, incomplete output or invalid evidence cannot
become `verified`. Only reviewed cue codes are accepted; free-text coaching is
not displayed. See [OpenAI image inputs](https://developers.openai.com/api/docs/guides/images-vision)
and [structured output](https://developers.openai.com/api/docs/guides/structured-outputs).

## Callable contract

These functions exist in source; they are not deployed URLs:

```text
createVerificationSession({ requestID, challenge: "pushup", target, consentVersion })
  -> { sessionID, nonce, expiresAt, limits }

verifyChallenge({ sessionID, nonce, evidenceID, consentVersion, frames })
  -> { status, reasonCode, decisionID, verifiedRepCount?, cue? }

cancelVerificationSession({ sessionID })
  -> { status: "cancelled" }
```

Possible verification statuses include `verified`, `incomplete`, `uncertain`,
`unavailable`, `pending`, `cancelled` and `expired`. Ownership, nonce, expiry and
current session state are checked on the server. An identical replay returns a
cached/pending result; changed content under the same evidence ID is rejected.

## When something goes wrong

| Situation | User-facing behavior |
|---|---|
| Camera cannot see enough | A short framing cue; no guessed rep |
| Evidence is ready | Show a checking state and keep Stop available |
| AI confirms valid evidence | Record `openai_verified` |
| Network/model/evidence is unclear | Offer self-confirm or stop; do not loop forever |
| User confirms being awake | Record `self_confirmed` |
| User stops or leaves | Cancel/invalidate cloud work and ignore late success |

The pilot is not an identity, liveness, anti-replay or exercise-safety system.
Native sound behavior still needs device tests.

## Data and cost

Images are handled in memory, not saved to a default bucket or database. OpenAI's
retention rules still apply; `store: false` does not mean zero retention. Review
[data controls](https://developers.openai.com/api/docs/guides/your-data) before launch.

The backend emits numeric `verification_token_usage` events. No real paid call has
been made in these tests. Cost per verified session needs measured provider usage,
current pricing, outcomes and Firebase costs. The [agent token ledger](metrics/README.md)
is a separate measure of development work, not an app API bill.

## Read next

[Setup](RUNNING.md) · [Backend policy](FIREBASE.md) · [Architecture](ARCHITECTURE.md) ·
[Implementation plan](IMPLEMENTATION-PLAN.md)
