# Run HiMorning

Start with local tests, then use a simulator to review the app. Real alarm, camera
and sound behavior still needs an iPhone; no Firebase configuration is needed to
review or use the local alarm flow.

**Status:** iOS 26+ pilot. Cloud verification is off by default.
The private free staging deployment is enabled and has passed a real synthetic
Gemini request; camera movement verification remains a separate evaluation.

## Prerequisites

| Work | Tools |
|---|---|
| Backend/emulator tests | Node 22, pnpm, Java 21 |
| Portable Swift checks | Apple Command Line Tools |
| Native build/UI | Xcode 26+ and XcodeGen |
| Physical iPhone | iOS 26+, development signing/team |

The working checkout is `~/Projects/HiMorning`. Run commands from its root.

## Free remote demo

Use [Workers + Gemini free setup](FREE-REMOTE-DEMO.md) for the current native
remote test. It sends generated images only, keeps the camera off and needs no
Firebase Functions billing. The paid Qwen backend commands below remain available
for separate evaluation.

## Check the backend

```sh
corepack enable
corepack pnpm@10.34.6 --version
pnpm install --frozen-lockfile
pnpm run typecheck
pnpm run build
pnpm test
pnpm run test:coverage
```

`pnpm test` runs tests without Firestore. Coverage starts the real Firestore Emulator
under the safe `demo-himorning` project, then adds transaction/rules tests. Inference
uses transport mocks. If the emulator cannot find Java, install/select Java 21 and check
`JAVA_HOME`; do not count an environment failure as a behavior-test RED.

Production audit: `pnpm audit --prod`. The historical full development audit had
16 advisories in Firebase tooling dependencies; it was not claimed clean.

## Check Swift and open the app

```sh
sh scripts/test-swift.sh
xcodegen generate --spec apps/ios/project.yml
open apps/ios/HiMorning.xcodeproj
```

The portable harness reports core coverage without requiring local XCTest. Full
Xcode can run `swift test --package-path apps/ios/HiMorningCore` and the native scheme's
UI tests. Hosted CI runs both paths.

Select a simulator to review English/Vietnamese screens. Use the globe menu to
follow the device language or save a choice. On a physical phone, set your team and
enable signing. Simulator runs use local ad-hoc signing so Keychain preview state
can be read and saved. Do not pass `CODE_SIGNING_ALLOWED=NO` when running native
tests; unsigned compile-only builds can still use that override.

Native scope: create and edit alarms, weekday repeats, three modes, on/off/delete, sound
preview, language selection, rehearsal, consented camera, one cloud submission,
self-confirm, stop, a no-card preview and monthly/annual Pro. QR and native
snooze/countdown are planned. See [subscriptions](SUBSCRIPTIONS.md) for current access.

## Local Qwen integration

The user's LM Studio server at `http://localhost:1235/v1` passed synthetic vision
and JSON checks. See the [local server guide](LM-STUDIO.md) for tested request
settings and the remaining adapter/emulator work. The native app uses the
default-off [free remote demo](FREE-REMOTE-DEMO.md). LM Studio remains a local
compatibility reference; the earlier [Modal staging path](REMOTE-PILOT.md) is
retained separately.

## Free remote demo setup

Follow [FREE-REMOTE-DEMO.md](FREE-REMOTE-DEMO.md) for the deployed Worker, Firebase
Spark and Gemini secret setup. Debug builds for `himorning-staging-0109` use the
Firebase debug provider, which needs a separately registered private token per
test device. Release and every other project use App Attest. A registered debug
token allows unverified test devices; the Worker still validates both signed
Auth and App Check JWTs. Apple Personal Team can be used for private device
installation, with seven-day provisioning limits.
The dedicated Simulator's private token is registered and live Auth/App Check
exchange passed. See the linked guide for the explicit deploy override that keeps
AI enabled; a normal default-config deploy switches it off.

## Retained paid Firebase/Modal setup

Do this only when ready for real cloud testing:

1. Register the app bundle ID in your Firebase project and enable anonymous Auth.
2. Configure App Attest and add an untracked `GoogleService-Info.plist` to app resources.
3. Configure backend values using `backend/functions/.env.example`; keep Modal proxy
   credentials in Secret Manager and bind them to submission, status and cancellation.
4. Review quotas, TTL, provider limits and billing before enabling cloud verification.

Release uses App Attest and the server contains no attestation bypass. Missing
Firebase config leaves cloud unavailable while local alarms remain usable.

Enable TTL on `deleteAt` for `verificationSessions`, `attempts` and `quotaBuckets`.
TTL is not enabled by this repo and cleanup is not immediate. No image Storage
bucket is required. This paid path is not deployed and has no billing setup; the
free Worker deployment is documented separately above.

## Rehearse without setting an alarm

From an empty Home, choose **Try a challenge**. The sample uses Balanced mode and
06:30 for display; it does not create or stop an OS alarm. Consent is still required
before cloud/camera work. With no Firebase configuration, the unavailable state
keeps self-confirm and end-trial actions available. See the [screen gallery](UI-DESIGN.md#native-screens).

## Preview the earlier design study

```sh
python3 scripts/preview.py
```

Open http://127.0.0.1:4173/design/. This Vietnamese web simulation has extra planned
screens and sample data; it does not schedule real alarms, open the camera or call
a real model. It is separate from the bilingual native app.

## Before inviting users

Test locked/terminated/restarted states, permission changes, offline stops, sound
routing and camera placement on devices. Benchmark consented movement evidence for
false acceptance/rejection, uncertainty, delay and cost. Neither a green SDK build
nor synthetic-image tests establish exercise accuracy or alarm delivery reliability.

## Read next

[Tech stack](TECH-STACK.md) · [Language guide](LOCALIZATION.md) · [Firebase](FIREBASE.md) ·
[TDD evidence](tdd/cost-optimized-pilot.tdd.md)

## Prepare a Firebase deployment package

```sh
pnpm run prepare:firebase
pnpm --dir .firebase/functions install --prod --frozen-lockfile
```

This builds `backend/functions` and stages a standalone production package in
`.firebase/functions`, including its generated pnpm lockfile. The directory is
ignored and may be rebuilt. It is the configured Firebase source. Preparation
does not deploy anything or create billing.

After separate deployment authorization and project configuration, run the Firebase
CLI from the repo root. Its predeploy hook repeats preparation. Run preparation
first so the configured source exists when the CLI inspects it. Never deploy a
workspace symlink tree without the production stage.

Only `sharp` and `esbuild` dependency builds are allowed in the development
workspace; the production stage allows `sharp`. Other dependency install scripts
stay blocked. The clean install, image processing, emulator and isolated import
checks verify the current dependency set; do not approve every script by default.

[Architecture](ARCHITECTURE.md) · [Android guide](ANDROID.md) · [Contracts](../shared/contracts/README.md)
