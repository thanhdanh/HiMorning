# Curated challenge examples

Retained simulator screenshots from the focused content UI tests on 2026-10-23. IDs select real bundled content deterministically; alarm/journey state in these test images is synthetic. They demonstrate content, layout and answer feedback, not overnight reliability or retention.

| Experience | Evidence |
|---|---|
| Short reading inference, EN / VI | [English](content-reading-en.png), [Vietnamese](content-reading-vi.png) |
| Correct-answer payoff, EN / VI | [English](content-explanation-en.png), [Vietnamese](content-explanation-vi.png) |
| Exactly-one-true logic and explanation | [Question](content-logic-vi.png), [Explanation](content-logic-explanation-vi.png) |
| A tiny voice scene, without starting the microphone | [Vietnamese scene](content-voice-vi.png) |
| Real-completion code path returns Home before displaying a takeaway | [Synthetic completion](content-real-completion-takeaway.png) |

Accessibility-size scrolling passed after moving optional completion actions into the scroll content: [long question](content-reading-vi-accessibility.png), [explanation](content-explanation-vi-accessibility.png). The final two targeted checks (large text and the existing countdown) passed. The root agent separately tried random reading/logic practice and viewed a voice scene in the normal app while preserving its actual 1/7 journey data. That manual observation is distinct from these fixtures.

See [the plan](../../CHALLENGE-CONTENT-PLAN.md) and [source review rubric](../../../shared/content/challenges/REVIEW.md).
