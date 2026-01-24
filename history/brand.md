# CONVERSATION CAPTURE APP

## Brand Guidelines

# Vapor

_Ethereal Memory Preservation_

---

## Brand Philosophy

Conversations are like breath—ephemeral unless captured. The Vapor brand treats speech as something delicate and transient being solidified into memory. The aesthetic communicates that the app is barely there, a whisper-quiet presence that preserves without intruding.

**Core Brand Values:**

- **Gentleness** — Never demands attention
- **Transience** — Acknowledges the fleeting nature of speech
- **Preservation** — Solidifies the ephemeral
- **Minimal presence** — The app succeeds when you forget it's there

---

## Color System

The Vapor palette moves from pure white through soft blue-grays to pale lavender. Colors should feel like morning mist or breath on cold glass.

### Primary Palette

| Swatch                                                   | Name     | Hex       |
| -------------------------------------------------------- | -------- | --------- |
| ![#FFFFFF](https://via.placeholder.com/20/FFFFFF/FFFFFF) | Cloud    | `#FFFFFF` |
| ![#F7FAFC](https://via.placeholder.com/20/F7FAFC/F7FAFC) | Mist     | `#F7FAFC` |
| ![#EDF2F7](https://via.placeholder.com/20/EDF2F7/EDF2F7) | Haze     | `#EDF2F7` |
| ![#E2E8F0](https://via.placeholder.com/20/E2E8F0/E2E8F0) | Fog      | `#E2E8F0` |
| ![#CBD5E0](https://via.placeholder.com/20/CBD5E0/CBD5E0) | Overcast | `#CBD5E0` |

### Accent Colors

| Swatch                                                   | Name          | Hex       |
| -------------------------------------------------------- | ------------- | --------- |
| ![#A0C4E8](https://via.placeholder.com/20/A0C4E8/A0C4E8) | Sky           | `#A0C4E8` |
| ![#B8C4D8](https://via.placeholder.com/20/B8C4D8/B8C4D8) | Dusk          | `#B8C4D8` |
| ![#C9B8D8](https://via.placeholder.com/20/C9B8D8/C9B8D8) | Lavender      | `#C9B8D8` |
| ![#4A90A4](https://via.placeholder.com/20/4A90A4/4A90A4) | Deep (Active) | `#4A90A4` |

### Semantic Colors

| Swatch                                                   | Name         | Hex       |
| -------------------------------------------------------- | ------------ | --------- |
| ![#E88B8B](https://via.placeholder.com/20/E88B8B/E88B8B) | Recording    | `#E88B8B` |
| ![#90C4A8](https://via.placeholder.com/20/90C4A8/90C4A8) | Success      | `#90C4A8` |
| ![#2D3748](https://via.placeholder.com/20/2D3748/2D3748) | Text Primary | `#2D3748` |

### Color Usage Guidelines

- **Background:** Always Cloud (`#FFFFFF`) or Mist (`#F7FAFC`)
- **Cards/Surfaces:** Haze (`#EDF2F7`) with 0-2pt blur shadow
- **Recording indicator:** Recording Red at 60% opacity, pulsing
- **Interactive elements:** Deep accent, never fully saturated
- **Speaker colors:** Subtle variations of Sky, Dusk, Lavender (never bold)

---

## Typography

Typography should feel weightless. Use thin and light weights exclusively. The type should feel like it could drift away.

### Type Scale

| Element   | Font           | Weight           | Size | Tracking |
| --------- | -------------- | ---------------- | ---- | -------- |
| Display   | SF Pro Display | Ultralight (100) | 34pt | -0.02em  |
| Title     | SF Pro Display | Thin (200)       | 28pt | -0.01em  |
| Headline  | SF Pro Text    | Light (300)      | 20pt | 0        |
| Body      | SF Pro Text    | Light (300)      | 16pt | 0        |
| Caption   | SF Pro Text    | Light (300)      | 13pt | +0.01em  |
| Timestamp | SF Mono        | Light (300)      | 11pt | +0.02em  |

### Typography Rules

- Never use bold weights — maximum is Regular (400) for critical UI labels only
- Line height: 1.6 for body text, 1.3 for headlines
- Text color: `#2D3748` (never pure black)
- Secondary text: `#718096` (60% visible weight)
- Fallback stack: `Inter Light, -apple-system, sans-serif`

---

## Spacing System

Generous whitespace is essential to the Vapor aesthetic. The UI should breathe. Use the 8pt grid with a preference for larger increments.

### Base Units

| Token       | Value | Usage                      |
| ----------- | ----- | -------------------------- |
| `space-xs`  | 4pt   | Icon-to-label gap          |
| `space-sm`  | 8pt   | Inline element spacing     |
| `space-md`  | 16pt  | Component internal padding |
| `space-lg`  | 24pt  | Between related elements   |
| `space-xl`  | 40pt  | Section separation         |
| `space-2xl` | 64pt  | Major section breaks       |

### Corner Radius

- Small elements (buttons, chips): **8pt**
- Cards and containers: **16pt**
- Modal sheets: **24pt** (top corners only)
- Circular elements (recording button): **Full radius**

---

## Motion Design

Motion in Vapor should feel like condensation forming or mist clearing. Nothing snaps; everything drifts.

### Timing Curves

| Curve Name      | CSS Value                          | Usage               |
| --------------- | ---------------------------------- | ------------------- |
| `vapor-appear`  | `cubic-bezier(0.16, 1, 0.3, 1)`    | Elements fading in  |
| `vapor-exit`    | `cubic-bezier(0.7, 0, 0.84, 0)`    | Elements fading out |
| `vapor-drift`   | `cubic-bezier(0.25, 0.1, 0.25, 1)` | Positional movement |
| `vapor-breathe` | `cubic-bezier(0.45, 0, 0.55, 1)`   | Scale pulsing       |

### Animation Durations

- Micro-interactions (button feedback): **150ms**
- Element appear/disappear: **300ms**
- Page transitions: **400ms**
- Blur focus transitions: **500ms**
- Breathing loop (recording indicator): **2000ms** per cycle

### Key Animation Patterns

**Appear Animation (New Elements)**

```
Start: opacity 0, scale 0.98, blur 4px
End: opacity 1, scale 1, blur 0px
Duration: 300ms
Curve: vapor-appear
```

**Speaker Bubble Breathing**

```
While active: scale oscillates 0.98 ↔ 1.02
Duration: 2000ms per cycle
Curve: vapor-breathe (ease-in-out-sine)
```

**Transcript Text Reveal**

```
Words fade in with gaussian blur clearing
Stagger: 20ms per word
Duration per word: 200ms
Curve: vapor-appear
```

---

## Icon Style

- Stroke weight: **1pt** (thinner than SF Symbols default)
- Corner radius on strokes: **1pt** minimum
- Icon size: **24×24pt** canvas, **20×20pt** optical
- Color: Single color, no fills (outline only)
- Style: Minimalist, geometric, inspired by Feather Icons

---

## Sound Design

Sounds should be almost subliminal — present but not demanding attention.

| Event            | Sound                                        | Duration | Level |
| ---------------- | -------------------------------------------- | -------- | ----- |
| Recording start  | Soft rising tone (C5 → E5), sine wave        | 200ms    | -18dB |
| Recording stop   | Gentle falling tone (E5 → C5), triangle wave | 300ms    | -20dB |
| Segment complete | Soft chime, single note (G5)                 | 150ms    | -22dB |
| Error            | Low soft pulse (C4) × 2                      | 100ms    | -16dB |

**Haptics:** No haptic feedback except for recording start/stop (soft tap)

---

## Component Specifications

### Recording Button

- **Size:** 72pt diameter
- **Idle:** Cloud (`#FFFFFF`) fill, 1pt Fog (`#E2E8F0`) border
- **Recording:** Recording Red (`#E88B8B`) at 60% opacity, breathing animation
- **Icon:** Microphone (1pt stroke), transitions to square-rounded when recording
- **Shadow:** `0 4pt 16pt rgba(0,0,0,0.06)`

### Session Card

- **Background:** Haze (`#EDF2F7`)
- **Corner radius:** 16pt
- **Padding:** 16pt all sides
- **Shadow:** `0 2pt 8pt rgba(0,0,0,0.04)`
- **Hover/Focus:** Shadow increases to `0 4pt 16pt rgba(0,0,0,0.08)`

### Speaker Bubble (Live Transcript)

- **Shape:** Rounded rectangle, 12pt radius
- **Speaker 1:** Sky (`#A0C4E8`) at 30% opacity
- **Speaker 2:** Lavender (`#C9B8D8`) at 30% opacity
- **Additional speakers:** Cycle through Dusk variations
- **Active state:** Subtle breathing animation (scale 0.98-1.02)

---

## Do's and Don'ts

| ✓ DO                                  | ✗ DON'T                               |
| ------------------------------------- | ------------------------------------- |
| Use generous whitespace               | Crowd the interface with elements     |
| Keep colors muted and desaturated     | Use bright, saturated accent colors   |
| Use thin typography weights           | Use bold or black weights anywhere    |
| Animate with blur and fade            | Use bouncy or snappy animations       |
| Let the UI breathe and pulse subtly   | Create static, rigid interfaces       |
| Use subtle, almost inaudible sounds   | Add notification-style sounds         |
| Make recording state gentle but clear | Use alarming red recording indicators |
