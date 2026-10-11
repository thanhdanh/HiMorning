# Shared mobile contracts

One wire contract lets iOS and a future Android client use the same Firebase
service. These files are language-neutral data, not a shared JavaScript runtime.

**Status:** v1 exported from the backend's Zod schemas; TypeScript and portable
Swift consume the same fixtures. Android consumption remains planned.

## Files

| File | Purpose |
|---|---|
| `v1/verification.schema.json` | JSON Schema definitions for six request/response shapes |
| `v1/wire-fixtures.json` | Synthetic, valid callable payloads for client/server tests |
| `v1/wake-modes.json` | Gentle, Balanced and Focused rep/snooze presets |

The five fixture JPEGs are generated flat colors. They contain no people and do
not demonstrate exercise accuracy. The verified result is a test fixture, not a
real provider response.

## Callable mapping

| Firebase callable | Request definition | Response definition |
|---|---|---|
| `createVerificationSession` | `CreateRequest` | `CreateResponse` |
| `verifyChallenge` | `SubmitRequest` | `Decision` |
| `cancelVerificationSession` | `CancelRequest` | `CancelResponse` |

The Firebase SDK handles transport wrapping, Auth and App Check. Schemas describe
the callable's data payload, not a new REST endpoint. `expiresAt` is Unix time in
milliseconds. `timestampMs` is relative to a capture sequence. Base64 contains raw
JPEG bytes without a data-URL prefix. Request IDs are UUIDs; session IDs are hashes.

Requests reject extra fields. Clients should allow additive response fields while
checking recognized status values before applying success. Unknown values must
never become verified. Preserve `self_confirmed`, `openai_verified` and `dismissed`
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
