# Alarm choices and celebration refinement

Make sound and challenge choices immediately accessible, reliably save the chosen
sound, and make successful challenges feel more energetic.

**Status:** Gate 1 approved; implementation and focused verification complete; awaiting pre-commit review. **Audience:** iOS and
verification maintainers.

## At a glance

| Surface | Approved behavior |
| --- | --- |
| Editor | Two collapsible choice boxes with always-visible headers; shared time, repeat and Save draft |
| Sound | Selection survives switching sections and reopening after Save; failures retain the draft and existing alarm |
| Modes | Gentle / Awake / Energized; Vietnamese Nhẹ nhàng / Tỉnh táo / Bứt phá; stored identifiers unchanged |
| Push-ups | New defaults/floors 5/10, decrease/increase within mode floor and 50; changing modes cannot lower an already-higher target |
| Legacy data | Existing explicit targets and historical attempts remain readable without rewriting |
| Celebration | Strong initial burst with drag, gravity and varied flutter; native Canvas, no new dependency; Reduce Motion supported |
| Real completion | Return Home automatically and celebrate there once; practice retains retry |

## Task list

1. Extend focused existing tests, reproduce the native sound-save failure and fix
   the demonstrated cause while preserving rollback.
2. Reuse existing editor content inside collapsible sections and preserve one draft.
3. Update targets, bounded capture, contracts and inference validators together;
   preserve strict generated-demo isolation and prior client targets.
4. Refine confetti motion and bilingual labels, inspect the rendered editor and
   animation, review code/security, then present the diff before committing.

## Key choices

Fifty cycles require at most 250 frames and 12.5 MB decoded JPEG data. Keep the
per-frame size/dimension checks,300-second evidence horizon, authorization,
consent, session lifetime and cancellation boundaries. Transport is bounded at 18 MiB.
Inference uses at most 25 images per call, aggregates only validated batches,
and retains the shared 180-second verification deadline. No remote deployment or
paid inference is part of local implementation verification.

The user's canvas-confetti reference, especially its Realistic Look example,
informs mixed launch velocities, drag and flutter rather than a uniform cone:
https://www.kirilv.com/canvas-confetti/

## What we checked

- Reproduced AlarmKit same-ID reschedule failure on iPhone 15 Pro; cancel/replace
  with restoration passes the same physical sound-edit regression.
- Editor sound choice/save/reopen and access-expiry recovery pass in EN/VI.
- Updated UI regression passes both +/- controls, floors 5/10, mode preservation
  and maximum 50; native editor layout no longer lets hidden rows hit Save.
- Focused core capture, upload, legacy decoding, demo isolation and access checks
  pass; consolidated portable core/integration harness passes (98.34% lines).
- Backend: 64 focused TypeScript tests, one real worker runtime target-50 test,
  eight Python protocol tests and TypeScript checks pass. Surplus-frame review fix also passes 20 evidence
  and 14 service checks; extra evidence is rejected before inference dispatch.
- Native confetti recording inspected; real completion and practice/retry checks
  pass. Bilingual localization checks pass; independent source review performed.

Logs and result bundles are under `/private/tmp/himorning-*` and
`/private/tmp/pushup50-*`. Visual evidence lives in the task's `editor-polish`
artifact directory.

## Limits and next steps

The sound-save regression passed on the physical phone. The restoration path
preserves the previous full alarm configuration if replacement scheduling fails.
Live GPU latency and 50-repetition exercise pacing remain separate physical
acceptance checks; ten inference calls may hit the shared deadline and safely
return unavailable. No backend deployment or paid GPU run was performed.
Existing free entitlement cap remains 5; Pro/active preview supports 50.
