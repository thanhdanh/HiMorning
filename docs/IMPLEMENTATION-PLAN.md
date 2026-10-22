# Implementation status and next work

Use this roadmap for remaining work. Current behavior belongs in the owning
guide; earlier task-by-task plans belong in the archive.

**Status:** iOS development pilot at `6a1e1e7`, reviewed 22 October 2026.
**Audience:** Product and engineering contributors.

## At a glance

| Workstream | Implemented | Remaining |
|---|---|---|
| Alarm experience | Create/edit/labels, one-time defaults, weekday repeats, swipe-confirm delete, backup rings | Physical delivery/recovery/capacity matrix; native snooze remains unimplemented |
| Challenges | Mode catalogs, local movement, reading/riddles, speech and draft trials | Recognition calibration with real people; content review; accessibility |
| Feedback and design | Yellow cards, clear repeat labels, observed body/face guides, calmer coaching | Broader device/VoiceOver review and repeated-use feedback |
| Content | Bundled EN/VI packs, validation, recent history and optional Worker refresh | Native-speaker review and deployed refresh acceptance |
| Progress/access | Local snapshots, preview and monthly/annual StoreKit source | Known expiry-test investigation and sandbox/TestFlight lifecycle |
| Optional backend | Synthetic demo and retained paid-verifier implementation | Separate current deployment/runtime/accuracy/cost evaluation if pursued |
| Android | Reserved folder and shared contract plan | Native implementation and platform-specific validation |

## Next priorities

1. Investigate the [known subscription failure](VALIDATION.md#known-failure).
2. Record the [device acceptance matrix](RELEASE-READINESS.md), concentrating on
   system dismissal/re-ringing, close-camera Reach up and interrupted speech.
3. Validate EN/VI content, accessibility and repeated morning use before adding
   new challenge types. [Product hypotheses](PRODUCT-BRIEF.md) remain hypotheses.
4. Prepare a release archive and sandbox/TestFlight billing, privacy and support
   evidence. Keep local alarms independent of optional AI/backend work.

QR, math, native snooze, detailed technique coaching, sync and Android remain
future choices, not currently advertised features. Do not treat old unchecked
plan boxes as proof that implemented features are missing.

## What we checked

[Validation](VALIDATION.md) owns dated results. [The archive](archive/README.md)
preserves earlier proposals and implementation checkpoints; those are not active
instructions or automatic approval gates for new work.

## Read next

[Architecture](ARCHITECTURE.md) · [Running](RUNNING.md) · [Release readiness](RELEASE-READINESS.md)
