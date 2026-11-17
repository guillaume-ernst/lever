---
name: Lever
description: Free macOS menu-bar controller for LINAK standing desks — a built-in instrument, not a branded product surface.
colors:
  system-accent: "#007AFF"
  fault-orange: "#FF9500"
  success-green: "#28CD41"
  destructive-red: "#FF3B30"
  text-secondary: "#6E6E73"
  surface-control: "#FFFFFF"
  warning-tint: "#FF95001F"
  active-tint: "#007AFF26"
typography:
  display:
    fontFamily: "-apple-system, SF Pro Rounded, sans-serif"
    fontSize: "36px"
    fontWeight: 700
    letterSpacing: "0em"
  headline:
    fontFamily: "-apple-system, SF Pro, sans-serif"
    fontSize: "13px"
    fontWeight: 600
  title:
    fontFamily: "-apple-system, SF Pro, sans-serif"
    fontSize: "22px"
    fontWeight: 600
  body:
    fontFamily: "-apple-system, SF Pro, sans-serif"
    fontSize: "13px"
    fontWeight: 400
  label:
    fontFamily: "-apple-system, SF Pro, sans-serif"
    fontSize: "10px"
    fontWeight: 400
rounded:
  xs: "1px"
  md: "8px"
spacing:
  xs: "4px"
  sm: "8px"
  md: "12px"
  lg: "16px"
components:
  preset-cell:
    backgroundColor: "{colors.surface-control}"
    textColor: "{colors.system-accent}"
    rounded: "{rounded.md}"
    padding: "8px"
  preset-cell-active:
    backgroundColor: "{colors.active-tint}"
    textColor: "{colors.system-accent}"
    rounded: "{rounded.md}"
    padding: "8px"
  warning-banner:
    backgroundColor: "{colors.warning-tint}"
    textColor: "{colors.text-secondary}"
    rounded: "{rounded.md}"
    padding: "8px"
  button-bordered:
    backgroundColor: "{colors.surface-control}"
    textColor: "{colors.system-accent}"
    rounded: "{rounded.md}"
    padding: "4px 12px"
---

# Design System: Lever

## Overview

**Creative North Star: "The Built-in Instrument"**

Lever's interface is honest machinery. It looks and behaves like something
macOS shipped, because everything about it is borrowed from the platform:
system accent, system materials, system text styles, SF Symbols, standard
controls. There is no brand color, no custom typeface, no decorative chrome.
The ambition is not to be noticed — it is to be *trusted on sight*, the way
a physical instrument panel earns trust by reporting exactly what the
machine is doing and nothing more.

That restraint is a product decision, not an absence of design. The desk is
a piece of hardware that physically moves; the interface is its readout and
its controls. Every pixel exists to answer "what is the desk doing right
now" or to move it. Color appears when the machine has something to say
(a fault, an active preset, a confirmation) — which is why a quiet gray
interface can shout effectively when it needs to.

**Key Characteristics:**
- Pure system accent — inherits the user's macOS theme, zero brand color
- Semantic color only: accent = active/actionable, orange = fault, green =
  confirmed, red = destructive
- One expressive type moment: the 36 pt rounded weight readout
- 8 pt rounded rectangles as the sole geometry beyond system chrome
- Content surface is flat; depth lives in the system popover material

## Colors

The palette is entirely semantic and dynamic — every swatch below resolves
through `Color`/`NSColor` to follow the user's light/dark mode and accent
setting. Hex values are the light-mode canonical appearance; never hardcode
them in new work — reach for the semantic token instead.

### Primary
- **System Accent** (#007AFF light / #0A84FF dark): `Color.accentColor`.
  Interactive elements only — active preset ring and tint, segmented
  control selection, primary buttons, links (Back, Disconnect), first-run
  progress bars, the preset-slot number.

### Secondary
- **Fault Orange** (#FF9500): `.orange` / `.systemOrange`. Reserved for
  desk fault states — the stand-down banner, the menu-bar warning triangle
  (rendered self-colored, non-template, so it reads orange even on tinted
  menu bars).

### Tertiary
- **Success Green** (#28CD41): `.green`. Confirmation checkmarks
  (e.g. "paired" status in Settings). Rare by design.
- **Destructive Red** (#FF3B30): `.red`. Destructive confirmation buttons
  (forget desk / reset). Used once.

### Neutral
- **Secondary Text** (#6E6E73): `.secondary` label color. Captions, unit
  hints ("(hold)"), explanatory copy, inactive icons, dimmed states.
- **Control Surface** (#FFFFFF light): `NSColor.controlBackgroundColor`.
  Inactive preset cells — the platform's standard control gray, not a
  custom tint.
- **Warning Tint** (orange @ 12%): translucent fault banner background.
- **Active Tint** (accent @ 15%): translucent active-preset cell fill.

**The Semantic-Only Rule.** If a color does not come from a semantic system
token (accent, orange, green, red, secondary, controlBackground), it does
not belong in this interface. Brand color is a deliberate absence.

## Typography

**Display / Body / Label:** SF Pro (system) throughout — no custom fonts.
The one deviation is the height readout, which uses the `.rounded` design.

**Character:** standard macOS text hierarchy; captions do the explaining,
numbers do the impressing.

### Hierarchy
- **Display** (700, 36 pt, SF Pro Rounded): the live height ("70.9 cm") —
  the single largest element in the app, and the only use of the rounded
  design.
- **Title** (600, 22 pt `.title2`): first-run screen headings ("Pair your
  desk").
- **Headline** (600, 13 pt `.headline`): section titles, preset slot
  numbers, popover headers.
- **Body** (400, 13 pt `.body`): settings labels, values, menu content.
- **Label** (400, 10 pt `.caption` / `.caption2`): "(hold)" hints, helper
  lines, status strings ("DESK 0726").

**The Rounded Readout Rule.** `.rounded` is reserved for the live height
number — one expressive moment that makes the instrument feel machined.
Everything else uses default SF Pro.

## Layout

Everything lives in a **280 pt-wide vertical stack** — popover, settings,
and first-run share the same column width. No grids, no breakpoints: the
app has one window size, and it is small.

- The popover reads top-down as an instrument: desk name (caption) →
  height readout (36 pt) → movement controls → preset grid → footer.
- Presets lay out in a **2×2 cell grid**, max-width cells, 8 pt padding.
- Settings is a scrolled column of labeled rows with plain-text section
  headers (secondary, subheadline semibold).
- The menu bar holds two status items: the desk icon (opens popover) and
  a text zone showing `preset + height` — e.g. `1  70.9 cm`.
- Disconnected cells dim to 40 % opacity rather than hiding — the layout
  never jumps.

## Elevation & Depth

Flat by constitution. All depth belongs to the platform: the popover's
translucent system material, the menu's shadow, the standard bordered
button relief. Content surfaces cast no shadows of their own.

**The Flat-By-Default Rule.** No element inside the popover draws a
custom shadow. State changes are expressed by tint, border, and opacity —
never by lift.

## Shapes

One radius, everywhere content needs a container: **gently rounded
rectangles (8 pt)** — preset cells, the warning banner. First-run progress
indicators are **1 pt bars** (near-square). Everything else is system
chrome with system corners.

**The One-Radius Rule.** If a new container is needed, it takes 8 pt.
If the system provides a shape (buttons, segmented control, popover), the
system's shape wins unmodified.

## Components

### Preset cell (signature)
Rounded rectangle (8 pt) holding slot number (headline, accent), height
(caption, secondary). Inactive: control-gray fill. Active: accent fill at
15 % + accent stroke (2 pt). Dimmed to 40 % when the desk is unreachable.
A preset in motion **pulses** — opacity oscillating on a 0.6 s
ease-in-out loop — the interface's only recurring animation.

**Empty slot ("+ Add"):** an unconfigured slot is an invitation, not a dead
cell — the number stays (dimmed to 65 %, one shade above the 40 %
disconnected dim) and the height caption becomes "+ Add" in accent.
Double-tapping saves the current height into the slot; the Zone-2 menu
item mirrors it ("4  + Add"). Empty is a state, never a void.

### Movement buttons
Standard `.bordered` buttons, minimum width 64 pt, SF Symbol chevrons
(▲/▼) with a "(hold)" caption beneath. Primary action (Connect/Retry)
escalates to `.borderedProminent`. Plain-style text buttons (accent) for
secondary actions (Back, Disconnect, gear → Settings).

### Warning banner
Orange tint (12 %) rounded rectangle (8 pt), leading
`exclamationmark.triangle.fill` in fault orange, secondary-color message.
Appears inside the popover at the top on stand-down; its menu-bar twin is
the self-colored orange warning triangle replacing the desk icon.

### Menu bar zones
- **Zone 1 — icon:** `table.furniture` template symbol; 70 % alpha when
  disconnected; replaced by the non-template orange warning triangle on
  fault.
- **Zone 2 — readout:** plain status text, `preset  height` when a preset
  is active, or `Connecting…` / `Scanning…` / `Not Connected`.

### Segmented controls & inputs
System `Picker` segmented style for unit/movement-mode choices; standard
text fields with `.bordered` Apply buttons. Row labels in secondary text.

## Do's and Don'ts

### Do:
- **Do** use `Color.accentColor` for anything interactive — it is the only
  accent this app will ever have.
- **Do** express state through tint (15 % accent fill), border (2 pt accent
  ring), and opacity (40 % dim) — the established state vocabulary.
- **Do** keep the 280 pt column; new surfaces fit inside it.
- **Do** use `.secondary` for every hint, caption, and explanation.
- **Do** let system controls keep their shape, material, and behavior.

### Don't:
- **Don't** introduce a brand color, custom font, gradient, or custom
  shadow — the absence of all four is the identity.
- **Don't** use `.rounded` type anywhere except the height readout.
- **Don't** use orange, green, or red decoratively — each already means
  fault, confirmed, and destructive.
- **Don't** add container radii other than 8 pt (or 1 pt for bars).
- **Don't** hide or jump the layout on disconnect — dim to 40 % instead.
