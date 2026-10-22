# Free remote AI demo

This reference exercises cloud connectivity with exact generated-color fixtures.
It never accepts arbitrary camera images or records verified movement. The
normal iPhone camera challenge does not use this server.

**Status:** Source retained as a synthetic connectivity reference. The deployment
and live-request observations below are from 15 October 2026 and have not been
reverified by this review; current service availability and account tier are unknown.
**Audience:** Pilot developers.

The product Push-ups flow now uses [on-device camera recognition](PUSH-UP-CAMERA.md).
The server below remains a synthetic connectivity reference, not the camera
challenge or a way to verify real movement.

## At a glance

| Part | Setting |
|---|---|
| Identity | Firebase Spark anonymous Auth and App Check |
| Backend | Cloudflare Workers Free; HTTPS on `workers.dev` |
| Staging origin | `https://himorning-free-staging.andy-local.workers.dev` |
| Session/quota state | One SQLite-backed Durable Object; metadata only, Eastern North America placement hint |
| AI | Gemini API free tier, pinned model `gemini-3.5-flash-lite` |
| Input | Exact generated fixtures from `shared/contracts/v1/free-demo-frames.json` |
| Limits | One attempt/session, 3/user/day, 10 globally/day, 180-second session job deadline |
| Provider call | One request, at most 20 seconds, no retries or paid fallback |
| Outcome | Uncertain/incomplete only; no alarm stop or `ai_verified` entry |

Firestore rules and the earlier paid Functions/Modal service remain in the
repository. This demo stores session/quota metadata in Cloudflare, so it needs no
Firebase admin credential, Secret Manager, Functions deployment or Firestore TTL.
Firebase Spark remains suitable for the existing identity and optional preferences.

## How it works

```text
iPhone -- Firebase ID token + App Check token --> Cloudflare Worker
                                                   |
                                            SQLite Durable Object
                                            claim attempt and quota
                                                   |
                                            Gemini free API
                                            generated images only
```

The Firebase iOS SDK calls the Worker URL using its normal callable envelope. The
Worker verifies both JWT signatures, issuer, audience, expiry and the allowed iOS
app ID. It forwards the authenticated UID through a private Durable Object binding.
The shared verification service keeps ownership, duplicate-request, deadline,
quota and cancellation behavior consistent with the earlier backend. Callable
transport decoding accepts the iOS SDK's signed/unsigned 64-bit integer wrappers
only when they fit JavaScript's safe integer range, then applies the strict domain
schemas. Unknown types, extra wrapper fields and deeply nested input are rejected.

The job is claimed before dispatch. `verifyChallenge` returns pending; background
work uses `waitUntil`, with a provider timeout shorter than its post-response
execution window. The client polls after 2/4/8/10 seconds. A lost acknowledgement,
runtime restart or failed provider request never triggers another inference.
Stop and backgrounding invalidate the local generation and cancel the session.
Aborting the upstream HTTP request cannot guarantee that Google stops accepted
work; a late response still cannot alter a cancelled session.

## Key choices

Gemini unpaid services can use submitted content to improve products and warn
against submitting personal information. The server therefore compares every
image, timestamp and ID with the bundled fixture before calling Gemini. It has no
arbitrary photo endpoint. Even a model hallucinating a completed cycle becomes
unavailable. The native coordinator independently rejects verified outcomes in
demo mode. Consent `2026-10-15-free-demo` names Google/Cloudflare and synthetic input.
See [Gemini terms](https://ai.google.dev/gemini-api/terms#unpaid-services).

SQLite Durable Objects are available on Workers Free. Metadata expires after two
days using a storage alarm; no JPEGs, tokens, provider error bodies or prompts are
logged or stored. Logs contain operation/status, model, elapsed time and bounded
token counts when supplied by the provider. Provider failures expose only bounded
HTTP status, fixed error categories and allowlisted parameter names, never raw
error text. The GPU service under
`backend/inference` is not deployed or invoked by this path.

The initial default placement returned Gemini `LOCATION_UNSUPPORTED`. The staging
object now uses the stable name `free-pilot-enam-v1` with `locationHint: enam`.
Hints apply only when an object is first created and are best effort, not a
country guarantee. The new name started fresh test metadata/quota; the old object
contained only this task's failed synthetic checks and expires through its storage
alarm. Do not rename it again to reset quotas. See
[Cloudflare's placement rules](https://developers.cloudflare.com/durable-objects/reference/data-location/).

## Try it

### 1. Check locally

Use Node 22+, pnpm 10.34.6, Java 21 and Xcode 26+ from the repository root:

```sh
pnpm install --frozen-lockfile
pnpm run check
pnpm run build:worker
pnpm run test:coverage
sh scripts/test-swift.sh
xcodegen generate --spec apps/ios/project.yml
```

Worker tests run real `workerd` with SQLite storage and signed test JWTs. Their
outbound adapter serves fake Google keys and fake Gemini responses; they cannot
contact a real AI provider. `build:worker` is a dry run, not a deployment.

### 2. Set up free accounts

Create a [Cloudflare Free account](https://dash.cloudflare.com/sign-up) and finish
email verification. Sign into [Google AI Studio](https://aistudio.google.com/) with
your Google account, review its terms and create a Gemini API key in a project
shown as **Free tier** with no linked billing account. Do not enable paid billing
for this demo or paste the key into chat, source files or the iOS app.

Log in to Cloudflare from the repository root:

```sh
pnpm --filter @himorning/worker exec wrangler login
pnpm --filter @himorning/worker exec wrangler whoami
```

The account owner completes sign-in, terms and the authorization page directly.
For just this demo, the connected Wrangler session uses `account:read`,
`user:read`, `workers_scripts:write`, `workers_tail:read` and background access.
Wrangler may warn that unrelated default scopes are missing; the staging upload
and Durable Object migration succeeded with these permissions.
Store the key interactively as a Worker secret:

```sh
pnpm --filter @himorning/worker exec wrangler secret put GEMINI_API_KEY
```

The staging secret list now contains `GEMINI_API_KEY` as `secret_text`. Only the
name/type were checked; the key value was not read. The live synthetic test later
confirmed that the deployed secret works with Gemini.

### 3. Prepare Firebase Spark

The staging project is `himorning-staging-0109`. Its iOS app is registered with
bundle ID `com.himorning.HiMorning` and app ID
`1:574230907604:ios:e608269b5dd865fe878941`. Public SDK configuration was downloaded
to the ignored `apps/ios/Resources/GoogleService-Info.plist`.

Anonymous sign-in is enabled; the Auth API readback confirmed this after the
account owner saved it in Firebase Console. Keep the project on Spark.
The Firebase App Check API is enabled. One private token named
`HiMorning Remote Demo Simulator 2026-10-15` was registered with the owner's
approval; a live exchange returned an App Check JWT accepted by the Worker.

The native factory uses Firebase's debug provider only in a **Debug build pointed
at `himorning-staging-0109`**. Release and other project IDs use App Attest. There
is no server bypass: both Firebase Auth and signed App Check JWTs remain required.

For a private Simulator trial, run the Debug app and register its locally
generated token in **Firebase Console -> App Check -> Apps -> Manage debug tokens**.
The SDK prints the token in the local development console; keep it out of chat,
source control and telemetry. A registered debug token allows unverified devices
to access staging. Use a separate token per test device and revoke it when no
longer needed. Never distribute a debug build to users. See
[Firebase's debug-provider instructions](https://firebase.google.com/docs/app-check/ios/debug-provider).

A paid Apple Developer membership is not needed for the Simulator. Apple also
supports installing on a personal iPhone with an Apple Account/Personal Team in
Xcode, with provisioning that expires after seven days. In Xcode, select that team
under Signing & Capabilities and enable device signing (this repository disables
it by default). Use that iPhone's own registered local debug token for the private
staging trial. Check device installation and capabilities before relying on the
alarm. See [Apple's Personal Team limits](https://developer.apple.com/help/account/basics/about-your-developer-account).

For Release, register App Check/App Attest with the actual Apple team and valid
device signing; debug-token tests do not establish genuine device attestation.
Do not deploy Functions for this free demo.

If the public SDK file is missing, download it again:

```sh
pnpm exec firebase apps:sdkconfig ios 1:574230907604:ios:e608269b5dd865fe878941 \
  --project himorning-staging-0109 --out apps/ios/Resources/GoogleService-Info.plist
```

### 4. Deploy the Worker

Review the public project/app IDs in `backend/worker/wrangler.jsonc`. Keep
`AI_VERIFICATION_ENABLED=false` for the first deployment:

```sh
pnpm run deploy:free
```

Copy the HTTPS `workers.dev` origin printed by Wrangler. Confirm `/health` responds
and unauthenticated callable requests fail. After the free-tier/key/auth checks,
enable the synthetic demo explicitly:

```sh
pnpm --filter @himorning/worker exec wrangler deploy --var AI_VERIFICATION_ENABLED:true
```

Source config remains default-off. Running `pnpm run deploy:free` without the
override disables AI again; use it to turn the demo off.
There is no subscription or paid-tier upgrade in the deployment commands.

The staging deployment is live at
[`himorning-free-staging.andy-local.workers.dev/health`](https://himorning-free-staging.andy-local.workers.dev/health).
Health returns `200` with `enabled: true`. All four callable paths reject missing
Auth with `401`. See the verification record for the enabled version and live
synthetic results.

### 5. Connect the native app

Copy `apps/ios/Resources/HiMorningCloud-Info.example.plist` to
`apps/ios/Resources/HiMorningCloud-Info.plist`. Replace `WorkerURL` with that HTTPS
origin. This public deployment file is ignored by Git; it contains no Gemini key.
Generate the project again, then build/install with valid signing:

```sh
xcodegen generate --spec apps/ios/project.yml
```

The local ignored file already contains the staging origin above. A generic
Simulator build with that file succeeded; device signing is still required.

The earlier app demo has been replaced by camera push-ups. Its generated-image
fixtures, server and wire contracts remain available for developer diagnostics.
Do not send camera images to this endpoint: it rejects anything except the exact
fixture and cannot complete a movement challenge. Use [camera setup](PUSH-UP-CAMERA.md)
for the current iPhone flow.

## What we checked

See [free-demo verification evidence](tdd/free-remote-demo.tdd.md). Local checks do
not establish that a fresh account has Gemini quota or that App Attest works on
the user's iPhone. Each additional test device needs its own registered debug
token or production App Attest setup.

## Limits and next steps

Free quotas can change and reject requests; there is no availability guarantee or
Singapore-only placement promise. Remain on the free plans and inspect their live
limits before enabling inference. Real Gemini vision/JSON connectivity passed
with generated images. Real push-up verification needs a separate validated path.

## Read next

[Workers pricing](https://developers.cloudflare.com/workers/platform/pricing/) ·
[Durable Objects pricing](https://developers.cloudflare.com/durable-objects/platform/pricing/) ·
[Gemini pricing](https://ai.google.dev/gemini-api/docs/pricing) ·
[Shared contract](../shared/contracts/README.md) ·
[Earlier paid Qwen backend](REMOTE-PILOT.md)
