# UI and interaction rules

Keep time and challenge primary, with a warm yellow identity and familiar iPhone
alarm interactions. Secondary settings should be easy to reach without competing
for attention.

**Status:** Current native behavior reviewed against `6a1e1e7` on 22 October 2026.
**Audience:** Design, product and iOS contributors.

## Home cards

- Time anchors the left side; challenge and level sit on the right. Enabled cards
  retain the HiMorning yellow background. Subtle concentric corner light indicates
  level; color is reinforced by a text label. No-challenge cards stay simpler.
- Show recurrence with a repeat symbol and a readable single weekday such as
  “Every Wednesday” / “Thứ 4 hằng tuần”. Multiple days stay compact. One-time
  alarms use a calendar/clock symbol and Today/Tomorrow/Once wording.
- Tap anywhere on a yellow or disabled gray card to edit. Keep the toggle and
  trial action distinct. Swipe left for Delete and confirm it; there is no Edit
  button or three-dot delete menu.
- Disabled cards remain compact and muted. Large text may rearrange/wrap content;
  time, state and controls must remain readable and reachable.

## Alarm editor

The time picker begins at now. No weekday is preselected: the default is a
one-time alarm, today when still possible or tomorrow if the clock time has
passed. Seven compact weekday circles share one row. Repeat, sound and the
optional user label sit below the primary time/challenge choices.

Use Gentle / Balanced / Challenging, translated as Nhẹ nhàng / Vừa sức /
Năng động. These are display labels; persisted `focused` remains unchanged.
The [catalog guide](MODE-CHALLENGES.md) owns compatible choices and targets.

Challenge tiles keep their colored static SF Symbols in the editor. A single
tap selects; double-tapping prompts before practice. The accessible trial action
is retained. Do not add back a separate large “Try this challenge” button.
Save awaits scheduling; failure keeps the draft and offers the existing recovery.

## Sound selection

The catalog is system sound plus 14 bundled choices. Previewing is separate from
selecting and leaves the picker open. Selecting an available row, including the
already-selected sound, updates the draft and closes the picker; it does not
save the alarm. Locked choices open Pro. Only one preview plays, and leaving or
backgrounding stops it. Preview volume is not AlarmKit volume.

## Challenge presentation

Animated movement illustrations guide framing on cards and the challenge screen;
editor tiles retain static colored icons. Illustrations use balanced body
proportions and a restrained circular camera boundary.

The active camera shows real video, including the person and room, with observed
arm/body lines and a curved face guide for neck turns. It does not cut out the
person or replace them with a silhouette. Show unclear framing as insufficient
visibility, not a failed exercise. Keep spoken cues short and infrequent; see
[coaching behavior](MODE-CHALLENGES.md#trying-a-challenge-and-hearing-guidance).

A real completion returns Home and celebrates once. Practice keeps its retry/
return behavior. Completion copy must fit any time of day; do not add a morning
wish. “I'm awake” appears after its five-minute delay. System Stop can silence a
ring even before then; the [backup plan](ARCHITECTURE.md#follow-one-alarm) remains.

## Brand tokens

[`MorningTheme.swift`](../apps/ios/HiMorning/MorningTheme.swift) owns app colors.

| Token | Light | Dark |
|---|---|---|
| Canvas | `#FFFCF6` | `#201F1A` |
| Surface | `#FFFFFF` | `#2C2A24` |
| Primary action | `#F5C842` | `#F5C842` |
| Alarm card | `#F9E07D` | `#F9E07D` |
| Text on yellow | `#29251D` | `#29251D` |
| Main text | `#29251D` | `#F8F4EA` |
| Muted text | `#756F63` | `#C2BBAE` |
| Border | `#E9E5DC` | `#49463D` |

Use platform fonts, native time wheels and confirmation dialogs. Apply glass to
controls deliberately; respect Reduce Motion and Reduce Transparency. Review
both languages, narrow widths, Dynamic Type and VoiceOver. Automated color and
layout checks do not constitute a complete accessibility audit.

## Native screens

The [committed screenshot gallery](images/ui/README.md) is a dated record of an
older UI and cloud flow. It is retained for provenance, not as a current visual
specification. The [web study](../design/index.html) is also a simulation. Use the
current app and the interaction rules above when implementing changes.

## What we checked

Current behavior is covered by the editor/card/trial/sound UI tests and native
camera/voice tests. [Validation](VALIDATION.md) separates dated observations from
remaining device and accessibility work. Do not copy an old screenshot's labels,
buttons, default time or cloud consent back into the current app.

## Read next

[Localization](LOCALIZATION.md) · [Challenges](MODE-CHALLENGES.md) ·
[Resources](../apps/ios/Resources/README.md) · [Release readiness](RELEASE-READINESS.md)
