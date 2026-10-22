# Documentation

Use the current guides for behavior and setup. Historical plans explain earlier
decisions and test checkpoints; they do not override current source.

**Status:** Repository documentation reviewed against `6a1e1e7` on 22 October 2026.
**Audience:** Contributors, product reviewers and pilot maintainers.

## Current guides

| Topic | Source of truth |
|---|---|
| Project overview and implemented features | [Repository README](../README.md) |
| Build, test and physical-device installation | [Running](RUNNING.md) |
| Runtime boundaries and alarm recovery | [Architecture](ARCHITECTURE.md), with [system](diagrams/current-architecture.html) and [wake lifecycle](diagrams/wake-recovery.html) diagrams |
| Challenge catalogs, framing and counting | [Challenges](MODE-CHALLENGES.md) · [Push-ups](PUSH-UP-CAMERA.md) |
| Interaction and brand rules | [UI design](UI-DESIGN.md) · [Localization](LOCALIZATION.md) |
| Access, preview and StoreKit setup | [Subscriptions](SUBSCRIPTIONS.md) |
| What has passed, failed or remains untested | [Validation](VALIDATION.md) · [Release readiness](RELEASE-READINESS.md) |
| Roadmap and product hypotheses | [Implementation plan](IMPLEMENTATION-PLAN.md) · [Product brief](PRODUCT-BRIEF.md) |
| CI operation | [Self-hosted CI](SELF-HOSTED-CI.md) |
| Stack and platform boundaries | [Tech stack](TECH-STACK.md) · [Android](ANDROID.md) |
| Wire contracts and content sources | [Contracts](../shared/contracts/README.md) · [Content review](../shared/content/challenges/REVIEW.md) |
| Bundled sound/icon provenance | [Resource guide](../apps/ios/Resources/README.md) |

## Backend references

Local wake challenges need neither server credentials nor AI inference. The
optional Worker also serves a public content pack; this does not upload camera data.

- [Free remote demo](FREE-REMOTE-DEMO.md): exact generated-image fixtures only;
  cannot verify a person's movement. Deployment observations are dated snapshots.
- [Firebase backend](FIREBASE.md) and [remote pilot](REMOTE-PILOT.md): retained
  paid Functions/Modal implementation, separate from the current app camera path.
- [Shared contracts](../shared/contracts/README.md): current source limits and
  payloads for those backend paths.

## Historical evidence

- [Archived plans and proposals](archive/README.md): superseded UI plans,
  October 17 implementation plans/specifications and earlier model/business work.
- [TDD records](tdd/README.md): dated RED/GREEN and integration records.
- [AI engineering case study](AI-ENGINEERING.md) and [usage metrics](metrics/README.md):
  historical development evidence, with original cutoffs preserved.
- [Old native screenshots](images/ui/README.md): historical UI, not the current
  alarm editor or cloud configuration.

## Maintaining these docs

Update the guide that owns a behavior instead of adding another competing plan.
Use [the document template](DOC-TEMPLATE.md) for new technical guides. Link source
files and reproducible checks; date environment/deployment observations. Do not
turn a passing synthetic test into a claim of real movement accuracy, reliable
alarm delivery or production billing. Keep internal enum IDs distinct from their
localized display labels. Keep credentials and machine-specific rollout paths out
of current guides.
