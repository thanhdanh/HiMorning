# Free remote demo verification

> **Dated evidence.** Commands, approvals, test totals and local paths below
> describe the original run. They are not current setup instructions or release
> status. See [current validation](../VALIDATION.md) for newer results and known gaps.

Record the checks completed for the Cloudflare Workers/Gemini demo separately
from account setup, live deployment and physical-device acceptance.

**Status:** Local checks and live synthetic Gemini requests passed on 15 October
2026, including the native Simulator/Firebase SDK flow. Physical iPhone acceptance
is pending. **Audience:** Pilot maintainers.

## Verification

| Lane | Executed check | Result |
|---|---|---|
| TypeScript | `pnpm run typecheck` | Passed for Functions, contracts and Worker |
| Backend, contracts and persistence | `pnpm run test:coverage` with the `demo-himorning` Firestore emulator | 83 tests passed in 12 files on the PR checkout; includes three CI-selection tests already on main |
| Worker runtime | Included SQLite/workerd integration with signed test JWTs and fake outbound Google services | Passed; no external AI calls |
| Worker bundle | Checked deployment upload | 847.04 KiB, gzip 138.11 KiB; startup 24 ms |
| Native domain | `sh scripts/test-swift.sh` | Passed; 98.54% line coverage in the configured domain scope |
| Swift package | SwiftPM XCTest | 47 tests passed, including three remote-demo tests |
| Native integration | Generic iOS Simulator build, signing disabled | Build succeeded for arm64/x86_64 |
| Retained GPU service | `pnpm run test:inference` | Eight Python tests passed with fake handles; no GPU |
| Retained Functions package | `pnpm run prepare:firebase` and import of its generated entry point | Passed; all four callable exports available |
| Dependencies and formatting | `pnpm audit --prod --json`, `git diff --check` | Passed |
| Staging deployment | Wrangler deploy with `--var AI_VERIFICATION_ENABLED:true` after typecheck and 18 Worker tests | AI enabled; source config remains default-off |
| Live HTTPS and auth boundary | GET health and POST all four callables without tokens | Health `200`, `enabled: true`; four `401 UNAUTHENTICATED` responses |
| Connected native configuration | Ignored WorkerURL plist, XcodeGen regeneration and generic Simulator build | Build succeeded; public configs remain ignored |
| Worker secret | `wrangler secret list` | `GEMINI_API_KEY` exists as `secret_text`; value not read |
| Anonymous Auth | Auth config readback after the owner saved it | Enabled; no billing change |
| Debug attestation gate | Native `AttestationTests` on a separate iOS 26.2 Simulator | Two tests passed in Debug and two in Release; other projects and Release use App Attest |
| Live identity/attestation | Anonymous sign-in and private registered debug-token exchange | Real Firebase ID/App Check JWTs accepted by Worker; no server bypass |
| Live five-image smoke | Create, submit, duplicate, poll and cancel using generated fixtures | Passed in 9.54 s, `uncertain`, zero verified reps; one inference, Gemini HTTP 200 in 2.819 s |
| Native SDK/Simulator | Push-ups -> Test remote AI -> disclosure -> result | Passed with 15 generated frames for the default target of 3; Gemini HTTP 200 in 6.582 s; camera stayed off |
| Native end-practice | End practice after the live result | UI showed practice ended; server cancellation returned HTTP 200 |
| PR integration | Isolated branch from `main`, preserving merged iOS and CI changes | Typecheck, Functions build, Worker dry run, schema drift check, portable Swift, eight Python tests and a fresh generic Simulator build passed; no private config/token files staged |
| Physical iPhone | Not executed | Device signing and a separate private debug token still required |

## Behaviors exercised

Worker tests validate native callable integer wrappers, signed Firebase Auth and
App Check tokens, rejection of
tampered or mismatched claims, exact generated-image matching, bounded request
and provider bodies, strict verdict JSON, quotas, duplicates, deadlines and
cancellation. The runtime test executes the actual Worker and SQLite-backed
Durable Object with controlled outbound responses. Gemini redirects are handled
manually and rejected rather than followed with the API-key header.

Shared service tests preserve one attempt and dispatch across retries, ownership
checks, pending acknowledgements, cached decisions and cancellation races.
Generated images cannot produce a verified movement: the provider adapter rejects
complete cycles, and native tests independently reject a malicious success in
demo mode. Swift fixtures also check the shared consent/wire shapes, trusted
Worker URL restrictions and generated-frame ordering and bounds.

Coverage for the configured TypeScript scope was 97.98% statements, 93.99%
branches, 95.87% functions and 100% lines. The Worker entry point executes in the
separate workerd process and is not included in Vitest's instrumented source
percentage. Portable Swift coverage does not cover camera hardware, AlarmKit,
Firebase SDK token delivery or UI automation.

## Environment and evidence

The local environment used Node 24.21.0, pnpm 10.34.6, Python 3.12.14 and Xcode
with the iOS 27 Simulator SDK. CI/deployment targets Node 22 and the retained
Modal image targets Python 3.11; these results do not claim a CI run on those
versions.

Temporary session logs are `/private/tmp/himorning-free-backend.log`,
`/private/tmp/himorning-free-runtime.log`, `/private/tmp/himorning-free-swift.log`,
`/private/tmp/himorning-free-spm.log`, `/private/tmp/himorning-free-xcode.log`,
`/private/tmp/himorning-free-package.log` and
`/private/tmp/himorning-free-audit.json`. They are local diagnostic evidence,
not durable release artifacts. The tests and sanitized shared fixtures are in
the repository.

The Spark project `himorning-staging-0109` has registered iOS app
`1:574230907604:ios:e608269b5dd865fe878941`, bundle ID
`com.himorning.HiMorning`. Its public SDK configuration is in the ignored
`apps/ios/Resources/GoogleService-Info.plist`. The initial Auth configuration
readback returned `404 CONFIGURATION_NOT_FOUND`. Firebase Authentication was
then initialized through the Console on Spark. The owner saved Anonymous sign-in,
and a later readback returned `anonymousEnabled: true`. The owner has no Apple
Developer membership. The
native factory now limits the debug provider to Debug builds for this exact
staging project; Release and other projects retain App Attest. After explicit
owner approval, one token named `HiMorning Remote Demo Simulator 2026-10-15` was
registered for the dedicated Simulator. Its value stays private. The Worker still
verifies signed Auth and App Check JWTs.

The first debug-token exchange failed with `SERVICE_DISABLED`. Enabling only
`firebaseappcheck.googleapis.com` completed successfully; its readback was ENABLED
and subsequent real exchanges passed. No billing upgrade was performed.

The Release XCTest run needed `ENABLE_TESTABILITY=YES` for the test command's
`@testable` imports, and the dedicated Simulator needed an explicit boot before
`test-without-building` completed. No shipping Release settings were changed.
Logs are `/private/tmp/himorning-debug-attestation-v2.log` and
`/private/tmp/himorning-release-attestation-v3.log`; local development logs can
contain SDK debug credentials and must not be published unredacted.

## Pending acceptance and limits

The account owner completed Cloudflare/Google account setup and authorized the
Wrangler device login. The CLI readback confirmed account
`27ecba812f47cf67168ce4152a9ebcf5` with only user/account read, Workers script write,
Workers tail read and background scopes. The enabled staging version is
`9b64eb9d-ef7e-4b7a-852d-7dc89dfd9f4f`, at
`https://himorning-free-staging.andy-local.workers.dev`. Startup time reported by
Wrangler was 24 ms; that is not an end-to-end latency measurement.

Reading account subscriptions returned `403` with these limited OAuth scopes;
no billing permission was added. The paid-plan state was not independently
confirmed through this API. No subscription was created or upgraded.

The Worker secret list confirmed `GEMINI_API_KEY` as `secret_text` after owner
entry. Its value was not inspected; two successful Gemini requests established
that the deployed secret works. Absence of linked billing was not independently
confirmed through an account API. No billing upgrade, payment, GPU allocation or
secret value inspection was performed. The connected Simulator build log is
`/private/tmp/himorning-free-connected-xcode.log`.

Default Durable Object placement produced four known terminal HTTP 400 failures;
safe diagnostics identified `LOCATION_UNSUPPORTED`. The new stable object
`free-pilot-enam-v1` requests Eastern North America placement, and Gemini vision
and structured JSON then passed. This created fresh synthetic test metadata and
quota; old test records expire after two days. A first check during deployment
propagation returned session-not-found before any inference; the following smoke
completed and closed its session. Jobs are never automatically resubmitted.

The first native request exposed Firebase's Int64 transport wrapping: creation
returned 400 before inference. The API now decodes bounded Int64/UInt64 wrappers
before domain validation, with a regression test in the real workerd/SQLite flow.
The same installed Debug app then showed
`The remote AI replied. Demo complete; no movement was verified.` Live metrics
showed exactly one inference for this native attempt. Local evidence is
`/private/tmp/himorning-remote-demo-success.png`; backend smoke output is
`/private/tmp/himorning-staging-live-result-v5.log`. Raw tail logs can include
request headers and must remain private; only fixed, safe metrics were inspected.

Follow [FREE-REMOTE-DEMO.md](../FREE-REMOTE-DEMO.md) for private iPhone setup.
App Attest on a physical iPhone, cellular/Mac-off operation, background cancellation
during a live inference, real movement accuracy and sustained free quota still
need acceptance. Free-tier limits can change or reject calls. Generated color
fixtures establish no movement accuracy and must never be treated as a push-up
evaluation.
