# Shared mobile contracts

One wire contract lets iOS and a future Android client use the same callable
payloads through Workers or Firebase. These files are language-neutral data.

**Status:** v1 exported from the backend's Zod schemas; TypeScript and portable
Swift consume the same fixtures. Android consumption remains planned.

## Files

| File | Purpose |
|---|---|
| `v1/verification.schema.json` | JSON Schema definitions for request/response shapes, including async result lookup |
| `v1/wire-fixtures.json` | Synthetic, valid callable payloads for client/server tests |
| `v1/free-demo-wire.json` / `v1/free-demo-frames.json` | Demo consent payloads and exact generated images shared with Swift and Workers |
| `v1/wake-modes.json` | Gentle, Balanced and Focused rep/snooze presets |

The five fixture JPEGs are generated flat colors. They contain no people and do
not demonstrate exercise accuracy. The verified result is a test fixture, not a
real provider response.

## Callable mapping

| Firebase callable | Request definition | Response definition |
|---|---|---|
| `createVerificationSession` | `CreateRequest` | `CreateResponse` |
| `verifyChallenge` | `SubmitRequest` | `Decision` |
| `getVerificationResult` | `ResultRequest` | `Decision` |
| `cancelVerificationSession` | `CancelRequest` | `CancelResponse` |

The Firebase SDK handles transport wrapping, Auth and App Check, including when
calling a configured Worker URL. Workers verifies the JWTs and returns the same
callable envelope. Schemas describe the data payload. `expiresAt` is Unix time in
milliseconds. `timestampMs` is relative to a capture sequence. Base64 contains raw
JPEG bytes without a data-URL prefix. Request IDs are UUIDs; session IDs are hashes.
Workers decodes Firebase's `Int64Value`/`UInt64Value` transport wrappers before
validating these logical shapes; values outside JavaScript's safe integer range
and malformed wrappers are rejected. The workerd test covers native-wrapped
targets and frame timestamps, as well as ordinary JSON clients.

Requests reject extra fields. Clients should allow additive response fields while
checking recognized status values before applying success. Unknown values must
never become verified. Write `ai_verified` for new AI successes; preserve historical `openai_verified`, `self_confirmed` and `dismissed`
as separate local outcomes; only the server can report `verified`.

## Change the contract

Edit `backend/functions/src/contracts.ts`, then run:

```sh
pnpm run contracts:generate
pnpm test tests/contracts.test.ts
sh scripts/test-swift.sh
```

Commit the exported schema with its source. CI regenerates it and fails on drift.
Update fixtures and both native/server tests when payloads change. Keep breaking
changes in a new version directory and plan a callable migration; a folder name
alone does not version a deployed API. Do not expose provider prompts or verdict
schemas as the mobile contract.

[Architecture](../../docs/ARCHITECTURE.md) · [Android guide](../../docs/ANDROID.md)

Consent version is `2026-10-15`. Pending verification is polled without resending
photos: 2, 4, 8, then 10-second intervals, for at most 180 seconds. Provider job IDs
and credentials are never part of the public contract. See [remote pilot](../../docs/REMOTE-PILOT.md).

The free path requires consent `2026-10-15-free-demo`; the retained paid path
rejects it. Workers rejects any image outside the generated fixture. Demo results
never become `ai_verified`, even if a provider returns a hallucinated success.
See [free remote demo](../../docs/FREE-REMOTE-DEMO.md).
