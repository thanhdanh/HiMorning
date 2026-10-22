# Remote AI pilot verification

> **Dated evidence.** Commands, approvals, test totals and local paths below
> describe the original run. They are not current setup instructions or release
> status. See [current validation](../VALIDATION.md) for newer results and known gaps.

Record what the asynchronous Firebase/Modal implementation has actually passed,
separately from deployment, GPU compatibility and physical-device acceptance.

**Status:** Local checks passed on 15 October 2026. Firebase staging project created;
inference and Functions are not deployed. **Audience:** Pilot maintainers.

## At a glance

| Lane | Executed check | Result |
|---|---|---|
| Backend and contracts | `pnpm run typecheck`, build and contract generation | Passed |
| Firestore integration | `pnpm run test:coverage` with `demo-himorning` emulator | Passed; 62 tests |
| Python transport/protocol | `pnpm run test:inference` | Passed; 8 tests, no GPU |
| Native domain | `sh scripts/test-swift.sh` | Passed; 98.46% line coverage |
| Native integration | Generic iOS Simulator `xcodebuild`, signing disabled | Build succeeded |
| Staging guard | `pnpm run deploy:staging -- --check` with temporary non-secret config | Passed; nothing deployed |
| Cloud project | Firebase create and project-list readback | `himorning-staging-0109`, ACTIVE |
| Real inference and cellular iPhone | Not executed | Pending budgets, billing and deployment |

## How it works

Backend tests exercise a single dispatch across duplicate uploads and pending
acknowledgements, quota reservation, owner/App Check enforcement, result caching,
provider errors, kill switch, timeout and cancellation before/after dispatch.
Final decisions still validate the original ordered frame IDs. Persistence checks
reject storing JPEG payloads or data URLs in Firestore metadata.

Swift tests exercise the 2/4/8/10-second polling schedule, stopping during a sleep,
the 180-second deadline and legacy `openai_verified` decoding. New results use
`ai_verified`. Python tests use synthetic JPEGs and fake Modal handles; they check
bounded input, strict JSON requests, non-success for malformed completions and job
start/status/cancel routes without allocating a GPU.

## Key choices

The local machine used Node 24.21.0, pnpm 10.34.6, Python 3.12.14 and the iOS 27
Simulator SDK. Deployment/CI target Node 22 and Python 3.11. Local success does not
claim an executed CI run on those target versions.

The final emulator coverage snapshot reports 100% lines, 97.29% statements,
93.97% branches and 93.65% functions for its configured scope. Portable native
coverage is for domain code, not camera, AlarmKit or Firebase SDK adapters.

## Try it

Use the prerequisites and commands in [REMOTE-PILOT.md](../REMOTE-PILOT.md).
The staging check validates the target and non-secret configuration; it neither
links billing nor verifies an endpoint. The remote smoke script makes one paid
synthetic call and must wait until account limits are configured.

## What we checked

An earlier final-check attempt failed two localization tests while new iOS copy
was being added. Another portable compilation detected a file modified during
the build. After those edits settled, the backend suite, portable Swift suite
and full simulator build were rerun successfully. No iOS changes were reverted.

Local logs for this session are in `/private/tmp/himorning-remote-backend.log`,
`/private/tmp/himorning-remote-swift.log` and
`/private/tmp/himorning-remote-xcode.log`; these temporary files are not durable
release artifacts. Generated schemas and sanitized fixtures live in the repository.

## Limits and next steps

Firebase and Modal CLI logins were verified. A billing readback on 15 October 2026
returned `billingEnabled=false` for `himorning-staging-0109` and no available Cloud
Billing accounts. Modal's billing page still showed its $1 Starter usage limit and
requested a payment method. Payment setup pages were opened for the account owner;
no payment was submitted. Blaze, project budget alerts and the $15 Modal workspace
usage/spend limits remain pending. No model image build, GPU cold start, real vision verdict,
automatic scale-down, App Attest on a physical device or Mac-off/4G test is claimed.
Model and runtime metadata pins do not establish GPU compatibility or movement
accuracy. Firebase's $5 allowance is a monitoring target, not a hard payment cap.

## Read next

[Remote setup and acceptance](../REMOTE-PILOT.md) ·
[Shared wire contract](../../shared/contracts/README.md) ·
[Firebase](../FIREBASE.md)
