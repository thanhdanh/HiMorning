# Mode challenge collections

Choose a wake mode to see a small set of matching challenges.

**Status:** Implemented on `codex/mode-challenge-collections`; awaiting device calibration. **Audience:** iOS maintainers.

## At a glance

| Mode | Choices | New-alarm default |
| --- | --- | --- |
| Gentle | None, wave hello, neck turns | None |
| Awake | Read aloud, read and choose, riddle | Read and choose |
| Energized | Push-ups, jumping jacks, reach up | 10 push-ups |

## How it works

The editor shows the selected mode's catalog. Changing modes replaces an incompatible
choice. Opening a historical alarm preserves its explicit challenge, including legacy
Guided Rhythm, until the user changes it. Missing historical challenges retain their
original decoding defaults.

Wave hello, neck turns, jumping jacks and reach up use Apple Vision on the phone.
Ordered, stable poses advance a local sequence; unclear visibility resets its unfinished
cycle. Camera frames are neither saved nor uploaded. Local success uses `localCompleted`;
push-ups retain the separate consent-based remote verification path and 10–50 target.

Read and choose offers eight prompts with shuffled answers. Three localized riddles
reuse the same answer mapping. The previous prompt is excluded when another prompt is
chosen within the same challenge view. Read-aloud retries retain the current sentence.

## What we checked

Focused motion self-check and core typecheck pass. Consolidated portable core/integration
checks and localization checks pass. Native build, two prompt-mapping tests, bilingual reading completion, and the
mode catalog UI check pass. The catalog test uses an isolated historical alarm
fixture and verifies legacy preservation before switching modes. Logs are under
`/private/tmp/himorning-mode-*`.

## Limits and next steps

Movement thresholds need physical iPhone calibration for lighting, framing and body
variation. Vision pose checks do not establish exercise technique or liveness. Head turns
use gentle left/right rotations, not full neck circles. Prompt history is scoped to the
active challenge view; it does not guarantee unique content across mornings.
No backend deployment or paid inference is part of this change.
