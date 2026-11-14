# Tech stack

Keep the local iPhone runtime separate from backend experiments and the native
Android app.

**Status:** Source inventory reviewed on 22 October 2026. **Audience:** Developers.

## At a glance

| Part | Current implementation |
|---|---|
| Native UI | SwiftUI, iOS 26+; native glass controls and adaptive EN/VI copy |
| Alarms | AlarmKit and App Intents; atomic saved alarms and persisted backup-ring IDs |
| Local recognition | AVFoundation + Vision for movement; Apple on-device speech APIs for Read Aloud |
| Domain and persistence | Swift package; atomic JSON for alarms/history/content cache, Keychain preview dates |
| Purchases | StoreKit 2, monthly/annual products and local StoreKit test configuration |
| Optional content service | TypeScript Worker serving versioned JSON with ETag caching |
| Synthetic cloud demo | Workers, SQLite Durable Object, Firebase Auth/App Check and Gemini; generated fixtures only |
| Retained paid verifier | Node 22 Functions v2, Firestore, Python Qwen/llama.cpp service on Modal |
| Tests | Vitest, Firestore Emulator, SwiftPM/XCTest, portable Swift, native XCUITest and Python unittest |
| Tooling | pnpm 10.34.6, XcodeGen, pinned dependency/artifact files |
| Android | Kotlin 2.3.21, Compose, AlarmManager, CameraX/ML Kit, on-device speech and atomic JSON; [evidence](ANDROID-IMPLEMENTATION.md) |

## How it works

The normal alarm and challenge flow uses the iPhone's scheduler, camera and
recognition APIs. No remote verdict is needed for local completion. The Worker
can refresh content; failure leaves bundled/cached content available.

The separate synthetic demo validates connectivity with exact generated images.
The retained Functions/Modal verifier has its own consent, quota, bounded evidence
and cancellation policy. [Shared contracts](../shared/contracts/README.md) own
its numeric limits. Neither backend is evidence of exercise accuracy.

## Source and checks

Use [`project.yml`](../apps/ios/project.yml), [`package.json`](../package.json),
the [workflow](../.github/workflows/ci.yml), and
[`pins.json`](../backend/inference/pins.json) for actual dependencies/configuration.
[Running](RUNNING.md) owns runnable setup commands; [Validation](VALIDATION.md)
owns dated results and limitations. No library upgrade is proposed by this audit.

## Read next

[Architecture](ARCHITECTURE.md) · [Android boundaries](ANDROID.md) ·
[Backend references](README.md#backend-references)
