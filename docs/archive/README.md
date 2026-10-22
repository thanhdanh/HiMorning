# Historical plans and references

These files preserve earlier reasoning and implementation checkpoints. They are
not an active backlog, current setup instructions or new approval requirements.
Use the [current documentation index](../README.md), [roadmap](../IMPLEMENTATION-PLAN.md)
and [validation](../VALIDATION.md) first.

## Superseded design work

| Record | Current guide |
|---|---|
| [Home completion](design/ALARM-HOME-STATES-PLAN.md), [cards/progress](design/ALARM-PROGRESS-DESIGN.md), [editor/sound](design/EDITOR-SOUND-CHALLENGE-PLAN.md), [device fixes](design/IOS-DEVICE-FIXES-PLAN.md) | [UI design](../UI-DESIGN.md), [Running](../RUNNING.md) |
| [Audio/speech plan](design/AUDIO-AND-SPEECH-PLAN.md) | [Challenges](../MODE-CHALLENGES.md), [resources](../../apps/ios/Resources/README.md) |
| [AI/challenge proposal](design/AI-AND-CHALLENGES-PLAN.md), [LM Studio smoke reference](design/LM-STUDIO.md) | [Architecture](../ARCHITECTURE.md), [backend references](../README.md#backend-references) |
| [Movement feedback proposal](design/POSE-FEEDBACK-PLAN.md) | [Challenges](../MODE-CHALLENGES.md); technique coaching remains future work |
| [Business proposal](design/BUSINESS-MODEL.md) | [Subscriptions](../SUBSCRIPTIONS.md), [product hypotheses](../PRODUCT-BRIEF.md) |

The old architecture/verification SVGs in `images/` describe an earlier cloud
path. They are retained only for provenance and must not be used as the current
system overview.

## October 17 plans and specifications

| Topic | Original plan | Original design | Current status |
|---|---|---|---|
| Alarm recovery | [Plan](2026-10-17/plans/2026-10-17-alarm-enforcement.md) | [Design](2026-10-17/specs/2026-10-17-alarm-enforcement-design.md) | Backup rings and delayed self-confirmation implemented; OS Stop remains outside app control |
| Content packs | [Plan](2026-10-17/plans/2026-10-17-challenge-content.md) | [Design](2026-10-17/specs/2026-10-17-challenge-content-design.md) | Bundling, refresh and history implemented; Vietnamese review remains open |
| Camera challenges | [Plan](2026-10-17/plans/2026-10-17-vision-challenges.md) | [Design](2026-10-17/specs/2026-10-17-vision-challenges-design.md) | Counters/guides implemented and revised; thresholds still need real-person calibration |

Unchecked boxes, obsolete class names, suggested ARKit alternatives and worker
instructions from those plans are not a current source inventory. Consult the
owning guide before reusing a command or assumption.
