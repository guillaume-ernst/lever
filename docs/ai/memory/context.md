# Context -- lever
<!-- Current sprint focus, active work, known blockers. Updated: 2026-11-16 -->

## Current State

Independent continuation of `MMoMM-org/linak-control`, detached from the fork
network and rebranded to **Lever** (`guillaume-ernst/lever`). Product/bundle is
Lever (`Lever.app`, `Lever.xcodeproj`, scheme `LeverApp`,
`com.guillaumeernst.Lever`); internals kept the LinakControl names
(`LinakControlKit`, `deskctl`, `~/Library/Application Support/LinakControl`).
Swift 6 language mode, 479 tests green.

Design context captured via Impeccable: `PRODUCT.md` (product truth) and
`DESIGN.md` + `.impeccable/design.json` ("The Built-in Instrument" — pure
semantic macOS, no brand colors). Critique of the UI scored 35/40; the
top findings were fixed (Lever strings in first-run/About, destructive-action
confirmations, scan fallback + connect cancel, empty preset slots now show
"+ Add" and save the current height on double-click).

## Known Issues

- Desk offset auto-parse from GET_DESK_OFFSET response gives wrong value
  (1413mm). User sets offset manually for now.
- The correct base offset may be derivable from the USER_ID response
  (rhyst/linak-controller uses CMD 0x81 for base_height).

## Next Steps

- Investigate correct base offset auto-parse — check if GET_BASE_OFFSET (0x81)
  gives the right one (currently set manually by user).

## Feature Backlog

- Configurable hotkeys (currently hardcoded Ctrl+Opt+1-4/Up/Down in
  HotkeyManager.swift).
- Editable preset labels in Settings GUI (deskctl `config label` supports
  names; the UI shows only "1:", "2:"). Bridge toward software presets.
- Software presets beyond the 4 hardware slots (PRODUCT.md north star).
