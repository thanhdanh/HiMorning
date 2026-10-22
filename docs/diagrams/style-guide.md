# HiMorning diagram style

**Status:** Project-local diagram-design token mapping, approved by the owner on
22 October 2026. Source: `apps/ios/HiMorning/MorningTheme.swift`. This file does not
modify the installed skill or a global profile.

Cream, ink and yellow fills match the app. The app's `#967211` accent is darkened
to `#87630B` for small diagram text/lines (5.37:1 on the cream paper). Brand yellow
is a focal fill with dark ink, never low-contrast yellow text. The semantic link
color reuses the app's green. System sans/mono avoid network font dependencies;
Georgia is an intentional editorial title treatment, not an exact copy of app type.
Only the light HTML variants are produced in this review.

## Tokens

### Semantic roles

Every token is referred to by **semantic role**, not by its hex value. Type references (`type-*.md`) and SKILL.md say `accent`, not `#f7591f`.

| Role | Purpose | Default (light) | Default (dark) |
|---|---|---|---|
| `paper` | Page background, default node fill | `#FFFCF6` | `#201F1A` |
| `paper-2` | Diagram container bg, secondary fill | `#F4F1E9` | `#353229` |
| `ink` | Primary text, primary stroke | `#29251D` | `#F8F4EA` |
| `ink-strong` | High-contrast text on warm accent fills | `#111111` | `#111111` |
| `muted` | Secondary text, default arrow stroke | `#756F63` | `#C2BBAE` |
| `soft` | Sublabels, boundary labels | `#756F63` | `#C2BBAE` |
| `rule` | Hairline borders | `rgba(41,37,29,0.12)` | `rgba(248,244,234,0.12)` |
| `rule-solid` | Stronger borders, baselines | `#E9E5DC` | `#49463D` |
| `accent` | Focal / 1–2 max per diagram | `#87630B` | `#F5C842` |
| `accent-tint` | Fill for accent-bordered boxes | `#F9E07D` | `rgba(245,200,66,0.10)` |
| `link` | HTTP/API calls, external arrows | `#44634A` | `#BDD6BF` |


## Typography

| Role | Family | Size | Weight | Usage |
|---|---|---|---|---|
| `title` | Georgia | 1.75rem | 400 | Page H1 |
| `node-name` | -apple-system, BlinkMacSystemFont, sans-serif | 12px | 600 | Human-readable labels |
| `sublabel` | Menlo, monospace | 9px | 400 | Port, protocol, URL, field type |
| `eyebrow` | Menlo, monospace | 7–8px | 500, tracked 0.18em, uppercase | Type tags, axis labels |
| `arrow-label` | Menlo, monospace | 8px | 400, tracked 0.06em | Arrow annotations |
| `callout` | Georgia italic | 14px | 400 | Editorial asides only |


Font source: `system`

Node-name sizes use the standard `doc-wide` ramp: 12px names, 9px technical
sublabels, 8px tags/arrow labels and 28px editorial titles. Diagrams are static,
self-contained HTML with accessible inline SVG and a local horizontal scroller.
Source revision: `6a1e1e7`. No PNG/SVG export or new current-app screenshot is implied.
