# Run HiMorning

Start with local tests, then use a simulator to review the app. Real alarm, camera
and sound behavior still needs an iPhone; no Firebase configuration is needed to
review or use the local alarm flow.

**Status:** iOS 26+ pilot. Cloud verification is off by default.

## Prerequisites

| Work | Tools |
|---|---|
| Backend/emulator tests | Node 22, npm, Java 21 |
| Portable Swift checks | Apple Command Line Tools |
| Native build/UI | Xcode 26+ and XcodeGen |
| Physical iPhone | iOS 26+, development signing/team |

The working checkout is `~/Projects/HiMorning`. Run commands from its root.

## Check the backend

```sh
npm ci --ignore-scripts
npm run typecheck
npm run build
npm test
npm run test:coverage
```

`npm test` runs tests without Firestore. Coverage starts the real Firestore Emulator
under the safe `demo-himorning` project, then adds transaction/rules tests. OpenAI
uses SDK mocks. If the emulator cannot find Java, install/select Java 21 and check
`JAVA_HOME`; do not count an environment failure as a behavior-test RED.

Production audit: `npm audit --omit=dev`. The historical full development audit had
16 advisories in Firebase tooling dependencies; it was not claimed clean.

## Check Swift and open the app

```sh
sh scripts/test-swift.sh
xcodegen generate --spec ios/project.yml
open ios/HiMorning.xcodeproj
```

The portable harness reports core coverage without requiring local XCTest. Full
Xcode can run `swift test --package-path ios/HiMorningCore` and the native scheme's
UI tests. Hosted CI runs both paths.

Select a simulator to review English/Vietnamese screens. Use the globe menu to
follow the device language or save a choice. On a physical phone, set your team and
enable signing; generated projects disable signing for CI.

Native scope: create alarms, weekday repeats, three modes, on/off/delete, sound
preview, language selection, rehearsal, consented camera, one cloud submission,
self-confirm and stop. Editing, QR, native snooze/countdown and history are planned.

## Optional Firebase setup

Do this only when ready for real cloud testing:

1. Register the app bundle ID in your Firebase project and enable anonymous Auth.
2. Configure App Attest and add an untracked `GoogleService-Info.plist` to app resources.
3. Configure backend values using `functions/.env.example`; keep OpenAI credentials
   in Secret Manager and bind them only to verification.
4. Review quotas, TTL, provider limits and billing before enabling cloud verification.

A simulator may need a separately registered App Check debug provider. Production
source uses App Attest and contains no attestation bypass. Missing Firebase config
leaves cloud unavailable while local alarms remain usable.

Enable TTL on `deleteAt` for `verificationSessions`, `attempts` and `quotaBuckets`.
TTL is not enabled by this repo and cleanup is not immediate. No image Storage
bucket is required. Deployment and billing have not been performed in this work.

## Preview the earlier design study

```sh
python3 scripts/preview.py
```

Open http://127.0.0.1:4173/design/. This Vietnamese web simulation has extra planned
screens and sample data; it does not schedule real alarms, open the camera or call
OpenAI. It is separate from the bilingual native app.

## Before inviting users

Test locked/terminated/restarted states, permission changes, offline stops, sound
routing and camera placement on devices. Benchmark consented movement evidence for
false acceptance/rejection, uncertainty, delay and cost. Neither a green SDK build
nor synthetic-image tests establish exercise accuracy or alarm delivery reliability.

## Read next

[Tech stack](TECH-STACK.md) · [Language guide](LOCALIZATION.md) · [Firebase](FIREBASE.md) ·
[TDD evidence](tdd/cost-optimized-pilot.tdd.md)
