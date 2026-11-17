# Product

<!-- impeccable:product-schema 1 -->

## Platform

macos

macOS 14+ native application (SwiftUI + AppKit, Apple HIG). Outside the
web/ios/android/adaptive taxonomy — record kept truthful rather than forced
into the closest enum value.

## Users

- **Primary:** the owner — a developer with a LINAK DPG1C standing desk
  (IKEA IDÅSEN) who wants to move it, watch its height, and trigger presets
  from the menu bar, global hotkeys, and shell scripts — without paying for
  features the hardware already supports.
- **Secondary:** other LINAK DPG1C/IDÅSEN owners. Personal-first, public
  welcome — the repo is documented well enough for strangers to build and
  use, but nobody is committed to supporting them.

## Product Purpose

Lever is a free, local-only macOS controller for LINAK DPG1C standing desks:
a menu bar app plus the `deskctl` CLI. It exists because the commercial
alternative (Desk Remote Control) puts a paywall on functionality the desk
already implements — Lever makes all of it free, and goes further than the
hardware's own limits (software preset layer beyond the 4 DPG slots,
automation, reminders, Siri Shortcuts, widget).

Success means: the desk moves reliably when told to, live height is
trustworthy, presets and automations just work, and nothing ever leaves the
machine.

## Positioning

The free, open-source macOS desk controller that is not capped by the desk's
four hardware presets — and where every GUI action is also a scriptable
command. A neighboring paid app cannot truthfully copy "all features free,
local-only, unlimited presets" without abandoning its business model.

## Operating Context

- Menu bar app expected to run all day during work hours; two status-item
  zones (desk icon popover + height/preset quick menu).
- The desk holds **one BLE connection at a time** — while Lever is connected,
  the desk is unreachable from an iPhone, Home Assistant, etc.
- Workflows: sit/stand switching during the day, preset recall by hotkey
  (Ctrl+Opt+1-4) or `deskctl`, occasional manual nudge, fault recovery
  (E16/E26/Initialise → stand-down, manual re-reference on the control box).
- Config and pairing persist in `~/Library/Application Support/LinakControl/`;
  logs in `~/Library/Logs/LinakControl/` (1 MB rotation).

## Capabilities and Constraints

- BLE protocol for LINAK DPG1C (4 services; heights in 0.1 mm units; USER_ID
  session activation required before DPG queries).
- Live height display, manual/auto/hold movement, 4 hardware presets,
  stand-down on desk faults, auto-reconnect with backoff + wake detection,
  start-at-login via SMAppService, global hotkeys (hardcoded for now).
- `deskctl` exposes the same surface over a Unix socket — status, height,
  move, preset, config, service — with `--json` output and documented exit
  codes.
- Built with Swift 6 (strict concurrency), SPM + XcodeGen; 479 tests.
- Constraints: macOS 14+, Bluetooth + Accessibility permissions required,
  no network/cloud by design, source distribution today.
- **Undecided (confirmed direction, not designed):** software preset layer
  beyond the 4 hardware slots; Siri Shortcuts; widget; configurable hotkeys;
  correct auto-parsed desk base offset (GET_DESK_OFFSET misreads 1413 mm —
  possibly 0x81).
- **Distribution:** source-only today; signed/notarized releases are
  intended someday, timing undecided.

## Brand Commitments

- Name: **Lever** (chosen 2026-11-16) — the lever that lifts, and French
  *se lever*, to stand up.
- UI and docs in English.
- Independent continuation of `MMoMM-org/linak-control`; MIT license
  preserves Marcus Breiden's original copyright. Provenance is stated, not
  hidden.

## Evidence on Hand

- Real screenshots in `docs/screenshots/` (menubar, popover, preset menu,
  settings ×2) — captured from the running app.
- A physically paired desk ("Desk 8965") used for manual verification.
- User-facing docs in `docs/` (installation, usage, configuration,
  troubleshooting); deep protocol knowledge in `docs/ai/memory/domain.md`.
- No website, logo, or marketing assets exist yet — none should be
  fabricated.

## Product Principles

1. **Free means all of it** — no feature ever gets gated; that is the
   project's reason to exist.
2. **Local only** — BLE and a Unix socket; privacy and offline function are
   architectural, not policy.
3. **Never surprise the hardware** — a physical actuator that moves on its
   own is a bug of the worst kind; stand-down and determinism come before
   features.
4. **GUI/CLI parity** — if it can be clicked, it can be scripted.
5. **The desk's own truth wins** — displayed heights, presets, and state
   always reflect what the hardware reports, never what the app wishes.
