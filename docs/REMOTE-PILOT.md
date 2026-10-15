# Test the app against remote AI

The native pilot now uses the [free synthetic demo](FREE-REMOTE-DEMO.md). This
document retains the earlier paid Functions/Modal backend setup; live camera
verification is not enabled by the current native configuration.

Run the native app against Firebase staging and a Qwen GPU service that continues
working when the developer Mac is off. Keep the pilot's total target budget at
$20/month; Kubernetes and a separate observability stack are deferred.

**Status:** Source implemented and locally verified. Firebase project
`himorning-staging-0109` created; Functions and inference are not deployed or GPU-tested.
**Audience:** Developers setting up a small, consented pilot.

## At a glance

| Part | Setting |
|---|---|
| Backend | Firebase Functions v2, anonymous Auth, App Check and Firestore |
| Inference | Modal, one L4, Qwen3.5-9B Q4_K_S plus matching vision projector |
| Placement | `ap-southeast` compute; gateway routes through `ap-south` |
| Idle | No minimum containers, maximum one GPU container, 60-second idle window |
| Limits | One submission/session, 25 JPEGs, 180-second job deadline, 10-minute session |
| Client polling | 2, 4, 8, then 10 seconds; no image resubmission |
| Budget | Modal workspace usage budget and spend limit: $15; Firebase target: $5 |

The existing `demo-himorning` default remains an emulator project. The staging
script requires an explicit real project ID containing `staging` and uses a
separate Firebase deployment config.

## How it works

```text
Native app -> Firebase create/verify/status/cancel -> authenticated Modal gateway
                                                      -> queued Qwen GPU job
```

`verifyChallenge` validates and normalizes JPEGs, claims the one attempt and quota
in Firestore, then dispatches outside the transaction. It returns `pending` once
Modal acknowledges the job. An ambiguous acknowledgement is terminal unavailable:
there is no dispatch retry or paid fallback. Duplicate submissions never dispatch
again. A lost acknowledgement may still leave bounded work running remotely.

`getVerificationResult({sessionID,evidenceID})` checks Auth, App Check and ownership,
then polls the server-only Modal job ID. It validates the raw verdict against the
original ordered frame IDs before recording a final decision. Firestore stores
only IDs, hashes, deadlines, model/policy and results, never JPEGs. Rapid duplicate
status requests are throttled before reaching Modal. Status reads cannot create jobs.

Stop, self-confirm and backgrounding cancel polling and the cloud session. Native
Stop happens before network cleanup. Best-effort Modal cancellation does not undo
the local exit; late results cannot mark it verified. Deadline expiry, malformed
output, missing jobs and exhausted credits remain non-success.

## Key choices

`backend/inference/pins.json` pins the CUDA image digest, Hugging Face revision and
SHA-256 of both GGUF artifacts. Builds verify downloads. These pins came from
upstream metadata on 15 October 2026; they are not proof of GPU compatibility or
exercise accuracy. Changing a pin requires repeating vision/JSON and burst tests.

The GPU uses `llama.cpp` Chat Completions with strict schema output, no thinking,
800 output tokens and no application retries. The model process listens only on
loopback inside its container. Only the authenticated job gateway is public;
Modal proxy credentials are held by Firebase Secret Manager, never the app.

Modal Functions retain encrypted inputs/outputs for up to seven days. Spawned
payloads can be stored in the US even when compute is in Southeast Asia. App
consent names Qwen/Modal and that retention period; it does not claim zero retention
or Singapore-only processing. We do not write images to our own files, logs,
Firestore or Storage. See [retention](https://modal.com/docs/guide/security) and
[data residency](https://modal.com/docs/guide/data-residency).

## Try it

### 1. Verify locally

Use Node 22, pnpm 10.34.6, Java 21, Python 3.11+ and Xcode 26+:

```sh
pnpm install --frozen-lockfile
python3 -m venv backend/inference/.venv
backend/inference/.venv/bin/python -m pip install -r backend/inference/requirements.lock
pnpm run check
pnpm run test:inference
pnpm run test:coverage
sh scripts/test-swift.sh
```

None of these commands needs a real model call. Python tests use synthetic JPEGs.
The Modal definition can be imported without credentials or allocating a GPU.

### 2. Configure accounts and limits before deploying

Create a dedicated Modal Starter workspace. Set its **Workspace usage budget** to
**$15** and **spend limit** to **$15** in Usage & Billing. Do not substitute an
alert or environment budget for the workspace limit. Verify the displayed values
before deployment; the repo cannot configure an unauthenticated account's billing.
Credits, if eligible, are a bonus, not an assumption. See
[Modal budgets](https://modal.com/docs/guide/budgets).

Use a real Firebase staging project (`himorning-staging-0109` exists for this checkout),
link Blaze billing, enable anonymous Auth,
and create Firestore in `asia-southeast1`. Set Google Cloud budget alerts at $2
and $5, scoped to this staging project. Google budget alerts do **not** stop spend.
Functions use zero warm instances and one maximum instance; daily verification
limits default to three/user and ten globally. Inspect billing after the first
session. Build storage, network, secrets and TTL cleanup may cost money even when
normal calls fit free quotas. Stop testing if the total approaches $20.

### 3. Deploy the inference service

Run these commands from the repository root (the directory containing `pnpm-lock.yaml`):

```sh
backend/inference/.venv/bin/python -m modal setup
cd backend/inference
.venv/bin/python -m modal deploy app.py
```

This builds/downloads approximately 6.8 GB of pinned model artifacts on the cloud.
The deployed endpoint is persistent; do not use `modal serve` for this pilot.
No custom domain is required. Copy the gateway HTTPS origin printed by deployment.
Create a Modal proxy token scoped to this app/environment.

### 4. Deploy Firebase staging

From the repository root, log in and select the explicit staging project:

```sh
pnpm exec firebase login
export FIREBASE_STAGING_PROJECT=your-himorning-staging
cp backend/functions/.env.example "backend/functions/.env.$FIREBASE_STAGING_PROJECT"
```

Edit that ignored file: set `AI_BASE_URL` to the gateway HTTPS origin, keep model
`qwen_qwen3.5-9b`, and initially keep `AI_VERIFICATION_ENABLED=false`. Do not put
credentials there. Set the two Secret Manager values interactively:

```sh
pnpm exec firebase functions:secrets:set MODAL_PROXY_KEY --project "$FIREBASE_STAGING_PROJECT"
pnpm exec firebase functions:secrets:set MODAL_PROXY_SECRET --project "$FIREBASE_STAGING_PROJECT"
pnpm run deploy:staging -- --check
pnpm run deploy:staging
```

The staging deployment applies Firestore rules and TTL overrides for sessions,
attempts and quota buckets. TTL deletion is asynchronous and billable. Metadata
is scheduled for deletion after two days; Modal input retention is independent.

Register the actual iOS bundle ID in this staging project, configure App Attest,
and put its untracked `GoogleService-Info.plist` in `apps/ios/Resources`. Build and
install on a physical iPhone with valid signing. The release path has no App Check
bypass. Simulator attestation requires separate development setup.

Before enabling AI, export the proxy credentials and gateway origin in your local
shell (never commit or paste them into chat) and run one paid synthetic smoke:

```sh
backend/inference/.venv/bin/python backend/inference/smoke.py
```

It checks unauthorized access is rejected, triggers one cold-start job and requires
non-person evidence to remain uncertain/incomplete with no cycles. It does not
measure exercise accuracy.

After checking budgets, proxy authentication, consent and deployment settings,
set `AI_VERIFICATION_ENABLED=true` and repeat `pnpm run deploy:staging`.

### 5. Prove the remote path

Turn off the Mac and disable Wi-Fi on the iPhone. Use a consented cloud challenge
through cellular data. Check one cold start, a subsequent warm call and cancellation.
The app must show a waiting state, submit photos once, and return a validated
terminal result within 180 seconds. Synthetic non-movement evidence must not verify.
With a wrong proxy token, unavailable GPU, exhausted quota, or airplane mode, Stop
and self-confirm must still work. Record actual latency and provider/Firebase cost.

For rollback, set `AI_VERIFICATION_ENABLED=false` and redeploy staging. Stop the
Modal app if necessary to terminate leftover work. Preserve existing local history;
new successes use `ai_verified`, and `openai_verified` remains readable.

## What we checked

Local unit/contract tests cover duplicate dispatch, polling without photos, auth,
quota, cancellation races, timeout, invalid output and legacy outcome decoding.
Portable Swift tests exercise the same core test bodies as XCTest. Python tests
check input budgets, ordering, generated verdict schema and bounded output parsing.
See the test commands above and [verification evidence](tdd/remote-pilot.tdd.md).

## Limits and next steps

No budget setting, GPU boot, paid inference or cellular-device test is claimed by
source checks. GPU startup and 25-image latency may exceed the deadline;
measure them before inviting testers. The $5 Firebase allowance is a target, not a
hard cap, and $20 does not buy a GPU that stays loaded all month. Accuracy needs
consented, person-separated movement clips, including partial and occluded cases.

## Read next

[Setup](RUNNING.md) · [Firebase](FIREBASE.md) · [Shared contract](../shared/contracts/README.md) ·
[Modal pricing](https://modal.com/pricing) · [Modal job processing](https://modal.com/docs/guide/job-queue)
