# Tech stack

HiMorning uses native iOS code for local alarms and a Workers/Gemini free demo
with Firebase Spark identity. The earlier Functions/Modal backend remains separate.

**Status:** Source and local tests implemented. Remote staging, pinned GPU runtime
compatibility and real exercise accuracy still require validation. **Audience:** Developers.

## At a glance

| Part | Choice |
|---|---|
| Native UI / alarms | SwiftUI, AlarmKit, App Intents, iOS 26+ |
| Local state | Swift domain and atomic JSON journal |
| Capture | AVFoundation, Vision, Core Image; bounded foreground JPEGs |
| Languages | Native English/Vietnamese strings and permission resources |
| Cloud identity | Firebase anonymous Auth and App Check |
| Current backend / AI | TypeScript Workers Free, SQLite Durable Object, Gemini free API; generated fixtures only |
| Retained paid backend / AI | Node 22 Functions v2, Firestore, Qwen3.5-9B on Modal L4 |
| Validation | Zod/sharp in Firebase; bounded Python/Pillow gateway checks |
| Tests | Vitest, Firestore Emulator, Swift portable/XCTest, native XCUITest, Python unittest |
| Build | pnpm 10.34.6, XcodeGen, pinned Python requirements and GPU artifact hashes |

## How it works

The current native demo sends generated fixtures through a Worker URL using the
Firebase callable client SDK. Workers verifies Auth/App Check, stores metadata in
SQLite and calls Gemini once. No camera evidence or verified outcome is accepted.
See the [free-demo guide](FREE-REMOTE-DEMO.md). The remaining sections describe the
separate paid path and its evaluation boundaries.

The app submits evidence once. Firebase reserves quota and dispatches a queued
GPU job; the app receives `pending` and polls the result without uploading again.
Firebase remains the authority on observed cycles. Local alarm delivery, backup rings,
"I'm awake", reading, rhythm and speech do not depend on inference.

## Key choices

| Limit | Pilot value |
|---|---|
| Requested reps | 1–5 |
| Evidence | Five phases per cycle, at most 25 ordered JPEGs |
| Image size | 512px long edge, 50KB each, 1.25MB total |
| Session / job | 10 minutes / 180 seconds |
| Attempts | One per session; no application dispatch retry or paid fallback |
| Daily AI quota | Three per user, ten globally, UTC days; configurable bounds |
| Model output | 800 tokens, strict JSON schema, thinking disabled |
| Cloud default | Off; zero warm containers/Functions instances |

New history uses `ai_verified`; legacy `openai_verified` still decodes. Modal
Functions can retain inputs/outputs for up to seven days. No images go into our
Firestore, Storage or application logs. Runtime/model/projector pins are recorded
in `backend/inference/pins.json`, pending a real GPU compatibility smoke check.

## Try it

Use the [remote pilot guide](REMOTE-PILOT.md) for Python setup, budgets, secrets,
explicit staging deployment, device configuration and rollback.

## What we checked

Local tests cover auth, contracts, ordered evidence, async races, quota, duplicate
suppression, cancellation, bounded polling and historical outcome decoding. These
checks do not establish movement accuracy or cloud availability.

## Limits and next steps

The $20 monthly target requires scale-to-zero GPU operation. Modal has a workspace
spend limit; Google budget alerts do not impose a hard Firebase spend cap. Measure
startup, 5/15/25-frame latency and actual invoices before expanding the pilot.

## Read next

[Remote pilot](REMOTE-PILOT.md) · [Firebase](FIREBASE.md) · [Architecture](ARCHITECTURE.md)
