# Run HiMorning

## Backend (no account or API key required for tests)

Use Node 22, npm and Java 21. `npm ci --ignore-scripts`, `npm run typecheck`, `npm run build`, `npm test`, then `npm run test:coverage`. Coverage starts only the local Firestore Emulator with project ID `demo-himorning`; it includes real transaction/rules tests. OpenAI is mocked. `npm run test:emulator` runs only the database integration suite. Local Node 24 also passed; deployed Functions are explicitly Node 22.

The three callable exports are in `functions/src/index.ts`. Production requires Firebase anonymous Auth and App Check on every call. Client UID, quota configuration, verdicts and model names are never accepted from request fields.

Cloud inference is off by default. The adapter explicitly uses `reasoning.effort: none`, low verbosity and 800 maximum output tokens; these are unbenchmarked candidates and may increase uncertain results. Successful provider responses emit only model and numeric token usage via the Firebase logger. Copy `functions/.env.example` to a private environment file only when preparing a real Firebase project. Bind `OPENAI_API_KEY` with Firebase Secret Manager; never put it in iOS or a tracked file. Deploy requires a real project, billing and App Attest registration. No deployment has been performed. Enabling inference is a deployment configuration change, not a remotely instantaneous kill switch; revoke the key or disable the function for an immediate emergency response. Add Firebase/GCP budget alerts before pilot traffic; the call caps do not cap every infrastructure charge.

Configure Firestore TTL for `deleteAt` on collection groups `verificationSessions`, `attempts`, and `quotaBuckets` in the real project. TTL cleanup is asynchronous and is not enabled by this repository. Request expiry is checked synchronously. Each attempt has its own deletion field. No Storage bucket or image/video persistence is provisioned.

## Native iOS 26 pilot

`ios/HiMorningCore` is a portable Swift package. `sh scripts/test-swift.sh` runs 13 domain/integration journeys with LLVM coverage using Command Line Tools, without XCTest. Full Xcode can also run the XCTest package suite.

Install Xcode 26 or later and XcodeGen. Run `xcodegen generate --spec ios/project.yml`, then open `ios/HiMorning.xcodeproj`. Select a simulator for UI review or a real iOS 26+ iPhone for alarm/camera/audio testing. Code signing is disabled in the generated project for CI; set your development team and enable signing for a physical device. The native shell is a pilot integration, not a release-certified alarm app.

The app works with local alarm scheduling and explicit self-confirm/stop without Firebase configuration. For cloud testing, register the bundle ID, enable anonymous Auth, configure App Attest and add an untracked `GoogleService-Info.plist` to the app's resources. Register a debug App Check provider separately for simulators if needed; production source uses App Attest and has no attestation bypass. SDK products are limited to Core, Auth, Functions and App Check. No analytics SDK, account signup, Firestore alarm sync or subscriptions are needed for the pilot.

Native screens: Vietnamese home, local alarm creation with weekday repeat and gentle/balanced/focused presets, on/off and deletion, three sound choices with bounded preview volume, explicit consent, foreground camera with provisional cycles, one bounded cloud submission, self-confirm and stop. A custom AlarmKit action opens the task; the OS Stop remains available. Backgrounding closes the camera and cancels cloud verification; it does not stop the OS alarm or declare success.

Current limits: editing an existing alarm, native snooze/countdown UI, QR enrollment, progress history, expert form coaching and Android are not implemented in this pilot. Preset snooze policy is tested in the core but not connected to native countdowns; that requires a Live Activity extension and device validation. Camera sampling is a prototype, not a proven exercise/safety/liveness detector. A consented movement dataset, accuracy/latency/cost evaluation and real-device alarm checks are required before enabling AI for a user pilot.

## Design prototype

`python3 scripts/preview.py` serves the existing static mock at http://127.0.0.1:4173/design/. It remains a separate simulation and does not invoke the backend or camera.
