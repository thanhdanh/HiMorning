# Firebase backend

Firebase handles identity, metadata and the small amount of server work needed for
AI checking. It does not keep time for the alarm; the phone's OS does that.

**Status:** Functions, rules and emulator tests are implemented. No real Firebase
project, billing account, database or function deployment has been created.

## Responsibilities

| Service | Current job |
|---|---|
| Anonymous Auth | Give cloud requests a UID without a sign-up flow |
| App Check | Require attestation in addition to user identity |
| Callable Functions v2 | Check ownership, validate evidence, reserve quota and call OpenAI |
| Firestore | Store sessions, attempts and quota metadata |
| Secret Manager | Bind the OpenAI key only to the verification function |
| Emulator Suite | Test transactions and rules without production deployment |

Auth and attestation do not prove that a person exercised. Local alarms and explicit
stops remain usable when cloud sign-in fails. No Storage bucket, analytics SDK,
remote alarm sync or subscription service is provisioned for this pilot.

## Data and authority

```text
users/{uid}                                  allowed preference document
verificationSessions/{sessionID}             owner, nonce, target, expiry, state
verificationSessions/{sessionID}/attempts/{evidenceID}
                                              hash, lease, decision, model/policy version
quotaBuckets/{bucketID}                       server-owned counters
```

Client rules allow only an owner's preference document with exactly `locale`,
`theme` and `guidance`. Locale is `en` or `vi`. Every other client path is denied.
The current native app stores its language locally; it does not sync preferences.

Functions use the Admin SDK, so they enforce ownership and inputs themselves.
Clients cannot set a verified outcome or change quotas. Images, labels and raw
request bodies are not stored in these documents.

## One verification, step by step

1. Create a deterministic session ID from UID and request ID. Matching creates
   reuse the session; a changed request under the same ID is rejected.
2. Check auth, App Check, owner, nonce, consent and expiry. Decode JPEG evidence and
   validate byte/dimension/frame/order limits.
3. Atomically claim an attempt and reserve the user's and global daily quota.
4. Call OpenAI **outside** the transaction callback. Firestore may run that callback
   again; paid work inside it could duplicate spending.
5. Finalize only the current, active lease. Cancellation and expiry win even over
   cached results or a response that arrives later.

One attempt is allowed per session. A running replay returns pending, a finished
matching replay returns its decision, and changed payloads are rejected. A stale
lease becomes uncertain and is never reclaimed automatically. This avoids blind
retries, but it is not a promise of exactly-once provider billing after a crash.

Repeated consent reuses the current client session. Repeated cancellation performs
no second Firestore write. Both cost edges have regression tests.

## Operating limits

| Setting | Current default |
|---|---|
| Region | `asia-southeast1` |
| Runtime | Node 22, 256MiB, concurrency 8 |
| Instances | Minimum 0, maximum 2 |
| Timeouts | Create/cancel 10s; verify 30s; provider 15s |
| Session / lease | 120s / 25s |
| AI quota | 3 per user/day UTC, 100 globally/day UTC |
| Create quota | 20 per user/day UTC, 1,000 globally/day UTC |
| Cloud AI | Disabled unless configured |

These are pilot limits, not a latency or monthly-cost forecast. A region near users
does not determine OpenAI's processing location. Measure cold starts and delay
before paying for warm instances.

Each metadata document has a `deleteAt` field two days ahead. Enable TTL separately
for sessions, attempts and quota buckets in a real project. Cleanup is asynchronous;
request expiry is checked synchronously. Parent deletion does not replace retention
for attempt documents.

## Run it locally

See [setup](RUNNING.md) for prerequisites and environment variables:

```sh
corepack enable
pnpm install --frozen-lockfile
pnpm run test:coverage
```

This uses `demo-himorning` and the Firestore Emulator. The suite checks real
transactions, concurrent claims, global quotas and deny-by-default rules. OpenAI
is mocked; no paid inference is needed.

## Before deployment

Review project configuration, access permissions, secret binding, TTL, provider
limits and billing. Deployment needs a real project and a supported billing plan;
none is enabled by this repo. Keep cloud off until consented evaluation meets agreed
accuracy, latency and cost gates. A cloud kill switch must leave local alarms usable.

Account linking, anonymous-account cleanup, deletion workflows and sync conflict
rules remain future work. Adding sync must never make FCM or a cloud job the alarm
clock, or change an active challenge midway.

## Deployment packaging

`pnpm run prepare:firebase` builds the backend and uses pnpm deploy to produce
`.firebase/functions`. This isolated source has a production package and generated
lockfile; it does not depend on workspace symlinks outside the upload. See
[setup](RUNNING.md) for the preparation and validation commands. No cloud deployment
has been performed.

## Read next

[Tech stack](TECH-STACK.md) · [Architecture](ARCHITECTURE.md) · [Evidence](tdd/cost-optimized-pilot.tdd.md)

Platform references: [callable functions](https://firebase.google.com/docs/functions/callable),
[anonymous Auth](https://firebase.google.com/docs/auth/ios/anonymous-auth),
[App Check](https://firebase.google.com/docs/app-check/cloud-functions),
[transactions](https://firebase.google.com/docs/firestore/manage-data/transactions),
[TTL](https://firebase.google.com/docs/firestore/ttl),
[secret parameters](https://firebase.google.com/docs/functions/config-env).
