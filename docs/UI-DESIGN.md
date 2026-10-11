# UI and experience

HiMorning should be easy to understand before bed and easy to use half-awake. The
sunny yellow theme suggests a fresh start; the interaction leaves room for different
habits, energy levels and living situations.

**Status:** Native pilot screens exist in English and Vietnamese. The earlier
Vietnamese web concept includes planned screens and simulated behavior.

## Native screens

These are unedited screenshots attached by XCUITest, showing the same home and
new-alarm journeys in both languages. Gentle is selected by default. The language
menu changes app copy; it does not change the phone's language settings.

| Screen | English | Vietnamese |
|---|---|---|
| Home | <img src="images/ui/home-en.png" width="260" alt="Native home in English"> | <img src="images/ui/home-vi.png" width="260" alt="Native home in Vietnamese"> |
| New alarm | <img src="images/ui/alarm-editor-en.png" width="260" alt="Native alarm editor in English"> | <img src="images/ui/alarm-editor-vi.png" width="260" alt="Native alarm editor in Vietnamese"> |

Open an image for full resolution. [Capture details](images/ui/README.md) record
the CI run, source commit and simulator. These four images do not cover the camera,
permission prompts, large text, dark mode or physical-device behavior.

## Design at a glance

- One clear next action on each screen, with a visible way to stop.
- Gentle defaults; stronger modes are a choice, not a personality label.
- Short, calm copy in both languages. See the [language guide](LOCALIZATION.md).
- Dark text on yellow buttons, clear focus and large touch areas.
- No ads, paywall or forced exercise in the morning stop path.

## Different mornings, one simple app

Leave room for work or school days, weekends, shift schedules and shared rooms.
Do not assume everyone has space, privacy or the ability to exercise in the morning.
A regular alarm must stay useful. Keep weekday choices editable, sound preview easy
to reach, and challenge consent separate from setting a time. Review the wording
with Vietnamese and English speakers rather than treating a literal translation as
proof of cultural fit.

## Look and feel

| Token | Light | Dark |
|---|---|---|
| Canvas | `#FFFCF6` | `#201F1A` |
| Surface | `#FFFFFF` | `#2C2A24` |
| Primary | `#F5C842` | `#F5C842` |
| Text on primary | `#29251D` | `#29251D` |
| Text | `#29251D` | `#F8F4EA` |
| Muted text | `#756F63` | `#C2BBAE` |
| Border | `#E9E5DC` | `#49463D` |
| Success text | `#44634A` | `#BDD6BF` |

These are design tokens, not a claim that every native surface already matches
the web study. The current SwiftUI pilot uses system surfaces with yellow accents.
Use system fonts, support larger text, aim for 44pt touch targets and avoid small
white text on yellow. Sun artwork is original to the concept.

## Follow the main flow

| Screen | What the person needs | Current native scope |
|---|---|---|
| Home | See alarms and add one | Add, on/off, delete, try a challenge, language menu |
| New alarm | Set time without a long setup | Time, weekdays, mode and sound; Gentle default |
| Sound | Hear a sound before choosing it | System sound + two chime sketches; preview volume |
| Challenge | Understand consent and progress | Explicit consent, camera, provisional count, checking state |
| Finish | Know what happened | AI checked, self-confirmed or stopped; clear return action |
| History | See progress without shame | Planned; web study has sample data only |

The web study also includes QR and snooze simulations, an editor and weekly progress.
They must not be presented as native features. Review controls outside the phone
simulate events; they do not access a real camera or cloud model.

## Modes and choices

Gentle requires no exercise. Balanced suggests three push-ups, Focused five. The
current native pilot does not offer target editing or QR. Modes never change the
sound by themselves. A new choice should explain what changes before saving it.

The tested core has snooze budgets of two, one and zero five-minute periods.
Native snooze/countdown still needs implementation and device testing. Do not show
a working-looking snooze control until it actually schedules the intended behavior.

## Camera and feedback

Ask for camera/cloud consent only when a person chooses the challenge. Show one
short cue at a time. Poor visibility means insufficient evidence, not a wrong pose.
Local counts remain provisional until the backend checks the evidence.

Keep self-confirm and Stop available during capture, checking and errors. Do not
punish an unclear rep by adding more reps or extending the alarm. Deeper form advice
is optional future work with separate validation; see the [feedback plan](POSE-FEEDBACK-PLAN.md).

## Sound should be a choice

The design study explores six sound sketches in soft, bright and clear families.
The native pilot currently ships two original five-second chimes and system sound.
Only one preview plays at a time. Leaving the editor stops it.

Preview volume is not alarm volume. Before release, compare tone, loudness, peaks,
looping, device speakers, headphones and the effect on people sharing a room.
Volume ramps and ducking remain device/API questions, not promised controls.

## Review both languages

Check English and Vietnamese at small phone widths, large Dynamic Type and with
VoiceOver. Look for clipped buttons, unclear weekdays, focus problems and long
consent text. Use labels and symbols together; color alone should not carry meaning.
Respect reduced motion. Prefer explicit outcomes over streaks that erase progress.

The tests cover both editor languages and language persistence. Device and native
speaker review are still needed for sound, wording and layout.

## Read next

[Language guide](LOCALIZATION.md) · [Architecture](ARCHITECTURE.md) · [Setup](RUNNING.md)

Research references: [Erly App Store](https://apps.apple.com/us/app/erly-wake-up-early/id6751428380),
[Erly Google Play](https://play.google.com/store/apps/details?id=com.erly.myapp&hl=en),
[Apple accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility).
