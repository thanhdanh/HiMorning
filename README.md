# HiMorning ☀️

A native iPhone alarm app with a small challenge to help start waking up.

**Status:** iOS 26+ development pilot, English and Vietnamese. Signed development
builds have been installed and exercised on an iPhone; release reliability,
recognition accuracy and production billing are not yet validated. Reviewed against
source revision `6a1e1e7` on 22 October 2026.

## Start here

| Task | Guide |
|---|---|
| Build, test or run on an iPhone | [Running](docs/RUNNING.md) |
| Understand the current system | [Architecture](docs/ARCHITECTURE.md) |
| Understand challenges and camera framing | [Challenges](docs/MODE-CHALLENGES.md) |
| Review the interface and interaction rules | [UI design](docs/UI-DESIGN.md) |
| Check preview/Pro access | [Subscriptions](docs/SUBSCRIPTIONS.md) |
| Check evidence and remaining release work | [Validation](docs/VALIDATION.md) · [Release readiness](docs/RELEASE-READINESS.md) |
| Find other guides and historical decisions | [Documentation index](docs/README.md) |

## Implemented pilot

- Create and edit alarms with a label, sound and optional weekday repeats. New
  alarms start at the current time, with no repeat days selected. A one-time clock
  time that has passed schedules tomorrow.
- Tap an enabled or disabled card to edit it. Swipe left to reveal Delete;
  deletion requires confirmation. Cards distinguish one-time and weekly schedules.
- Choose Gentle, Balanced or Challenging. The Vietnamese labels are Nhẹ nhàng,
  Vừa sức and Năng động. The [catalog](docs/MODE-CHALLENGES.md) lists the available
  activities; Guided Rhythm remains supported for saved legacy alarms.
- Try a challenge without saving an alarm. In the editor, double-tap a challenge
  and confirm the trial; its draft survives the return.
- Camera movements are checked on the iPhone. Live video keeps the person and
  room visible with joint/face guides; it is not saved or uploaded. Read Aloud
  also uses on-device recognition, with an availability fallback.
- Choose system sound or 14 bundled sounds. Preview playback is separate from
  alarm volume; selecting an available sound closes the picker.
- Keep local progress, a 30-day no-card preview and optional monthly/annual Pro.

**System Stop can silence the current AlarmKit ring.** HiMorning cannot remove
that control. Up to 15 pre-scheduled backup rings follow at two-minute intervals,
for 30 minutes. Completing the challenge or using the delayed “I'm awake” cancels
remaining backups. The latter unlocks five minutes after the occurrence and is
recorded separately from challenge completion. Scheduling capacity and delivery
still need the [device checks](docs/RELEASE-READINESS.md).

QR, math challenges, native snooze/countdown and Android are not implemented.
The Workers/Gemini synthetic demo and retained Functions/Modal backend are
[separate development references](docs/README.md#backend-references), not the
normal camera challenge path.

## Quick start

From the repository root, with Node 22 and pnpm 10.34.6:

```sh
corepack enable
pnpm install --frozen-lockfile
pnpm run typecheck
pnpm test
pnpm run build
```

On macOS, with the Apple toolchain and XcodeGen:

```sh
sh scripts/test-swift.sh
swift test --package-path apps/ios/HiMorningCore
xcodegen generate --spec apps/ios/project.yml
open apps/ios/HiMorning.xcodeproj
```

Choose a signing team for a physical iPhone. Firebase configuration is optional
for local alarms and camera challenges. See [Running](docs/RUNNING.md) for native
unit/UI checks, signing and recovery.

## Repository layout

| Path | Responsibility |
|---|---|
| `apps/ios/HiMorning/` | SwiftUI, AlarmKit, camera, speech, sound and StoreKit adapters |
| `apps/ios/HiMorningCore/` | Platform-independent alarm, challenge, content, access and progress rules |
| `apps/ios/Resources/` | EN/VI strings, permissions, bundled content, sounds and app icon |
| `backend/worker/` | Content endpoint and an isolated synthetic Gemini demo |
| `backend/functions/`, `backend/inference/` | Retained Firebase/Modal verification implementation |
| `shared/contracts/`, `shared/content/` | Wire fixtures and curated challenge sources |
| `apps/android/` | Reserved future platform; no Android binary |
| `docs/` | Current guides, validation and clearly marked historical records |

Historical AI-development metrics and TDD checkpoints are preserved in
[the documentation index](docs/README.md#historical-evidence). They are dated
snapshots, not current test totals or product-accuracy claims.
