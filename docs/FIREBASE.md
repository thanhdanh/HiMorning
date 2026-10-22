# Firebase verification backend

The separate [synthetic remote demo](FREE-REMOTE-DEMO.md) uses Firebase for Auth
and App Check and Cloudflare for metadata/inference dispatch. The Functions and
Firestore flow below is the retained paid-backend reference, not the native default.

Firebase protects the boundary between the native app and paid inference. The GPU
model runs on Modal; Firebase owns identity, sessions, evidence policy and quota.

**Status:** Retained async backend source and local tests. It is not the normal
camera path; live deployment and provider policies were not rechecked in this
review. **Audience:** Backend and native developers.

## At a glance

| Component | Responsibility |
|---|---|
| Anonymous Auth | A server-known UID for cloud verification |
| App Check | Attestation on every callable, including result lookup and cancellation |
| Functions v2 | Validate evidence, reserve quota, dispatch/read/cancel Modal work |
| Firestore | Owned sessions, one attempt, quota buckets and final results |
| Emulator | Real transaction/rules tests using `demo-himorning`, without paid inference |

## How it works

The create callable snapshots target, consent and policy for ten minutes. Submit
checks owner/nonce/consent and bounded JPEGs, force-decodes them and strips EXIF/GPS.
It reserves one attempt and UTC daily quotas in a transaction. Modal dispatch is
outside that transaction because Firestore may replay transaction callbacks.

The attempt stores only normalized frame IDs, sufficiency, hashes, model/policy,
a 180-second deadline and a private provider job ID. An accepted job returns
`pending`. An uncertain dispatch acknowledgement is not retried. An identical
submission returns its current/cached result; different data under an existing
ID is rejected. A second evidence ID cannot claim another attempt for that session.

`getVerificationResult` checks owner and App Check on each call, fetches an existing
job without photos, and applies the same ordered, non-overlapping five-phase-cycle
policy. Model confidence or valid JSON alone never verifies a challenge. Refused,
truncated, malformed, expired or missing results remain non-success.

Cancel marks the session first, then best-effort cancels the remote job. A verdict
arriving after cancellation, deadline or expiry cannot overwrite the terminal state.
The iOS native stop and backup-ring cancel happen before cloud cleanup and work offline. The system Stop still exists, but backup rings follow it.

## Key choices

All callables run in `asia-southeast1`, with zero minimum and one maximum instance.
Create has a ten-second timeout; submit/status/cancel have thirty seconds. Provider
dispatch uses a twenty-second HTTP timeout; status/cancellation use eight seconds.
All provider calls reject redirects and do not retry. Status
requests are throttled before reaching Modal. The default AI cap is three attempts
per user/day and ten globally/day, in UTC.

The cloud kill switch defaults off. Modal credentials are needed only for actual
inference operations and remain in Secret Manager. No image Storage bucket is
required. Firestore client rules deny all access to sessions, attempts and quotas;
clients cannot write their own verified result.

Firestore TTL is configured for `deleteAt` on sessions, attempts and quota buckets
in the staging index file. Metadata is scheduled for deletion after two days;
TTL is asynchronous and has separate billing. Modal Functions may retain image
inputs and outputs for up to seven days under its own policy. Consent version
`2026-10-15` discloses Qwen/Modal. New local history writes `ai_verified`, with
historical `openai_verified` decoding retained.

## Try it

```sh
pnpm install --frozen-lockfile
pnpm run typecheck
pnpm run build
pnpm run test:coverage
```

Java 21 must be on PATH for the emulator. Cloud deployment needs a separate real
staging project, Blaze billing, proxy secrets and confirmed budgets. Follow
[remote staging](REMOTE-PILOT.md); the safe emulator default is never changed.

`pnpm run prepare:firebase` copies the production package into ignored
`.firebase/functions` with its own generated pnpm lockfile. For staging it also
copies the ignored, non-secret `.env.<project>` file selected explicitly through
`FIREBASE_STAGING_PROJECT`. Use `pnpm run deploy:staging -- --check` to validate the
target/config without deployment, then `pnpm run deploy:staging` for the actual deploy.

## What we checked

Tests cover callable identity/attestation, strict contracts, normalization, shared
quota races, one-job dispatch, acknowledgement failure, polling, cancellation and
late results. Firestore Emulator checks rules and real concurrent transactions.
No live accuracy, latency or Firebase bill is implied by those tests.

## Limits and next steps

Firebase has free quotas, but deploying Functions needs Blaze billing. Build
storage, network, secrets and TTL can incur charges independently. The $5 allowance
is a monitoring target, not a hard cap. Run the cellular-device smoke checks and
inspect the first invoice before inviting more users.

## Read next

[Remote pilot](REMOTE-PILOT.md) · [Shared contracts](../shared/contracts/README.md) ·
[Functions](https://firebase.google.com/docs/functions/callable) ·
[TTL](https://firebase.google.com/docs/firestore/ttl)
