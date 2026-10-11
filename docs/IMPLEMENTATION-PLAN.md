# iOS 26 pilot: implementation and acceptance

Derived from ARCHITECTURE.md, FIREBASE.md, TECH-STACK.md and the user's iOS 26 selection. This run implements the bounded Firebase verification service and the portable Swift domain core, then wires a native pilot shell where the available tools allow validation. Android, subscriptions, remote alarm sync, expert posture coaching and model accuracy certification remain later milestones.

1. As a sleepy user, I can use a gentle alarm and end a challenge without a network dependency or a false AI success.
2. As a user opting into cloud verification, I submit a short ordered image sequence once; unclear/model failure leads to a clear fallback, never a guessed completion.
3. As a developer paying for inference, I have strict frame/byte/output caps, zero automatic provider retries, atomic user/global daily reservations, idempotency and a default-off switch.
4. As a user stopping a challenge, I cannot receive a late completion; cancellation and expiry win.
5. As a user, only I can access my preferences; clients cannot write authoritative verdicts or quotas, and no camera bytes are persisted.
6. As a user choosing a mode, preset snoozes and provisional counts are predictable; camera interruption resets an unfinished rep, and local counts never imply OpenAI verification.

Tests precede production implementation. Vitest unit tests cover evidence, policy, provider contracts and service races; Firestore Emulator tests cover real transactions and rules; Swift XCTest covers domain behavior. Real camera, AlarmKit lifecycle, sound volume and end-to-end iOS tests require Xcode and a device. Real model evaluation requires a separate consented dataset and budget.

Pilot defaults (configuration limits, not accuracy claims): 1–5 reps, five ordered frames per observed cycle, at most 25 JPEG frames, 512px long edge, 50KB/frame and 1.25MB total, at most one paid attempt/session, 3 calls/user/UTC day, 100 global/UTC day, 800 output tokens, 15s provider timeout, 25s non-reclaimable attempt lease. A crashed/ambiguous attempt is never retried automatically. These caps must be tuned with measured accuracy/latency before release.
