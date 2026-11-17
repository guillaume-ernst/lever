# Context -- lever
<!-- Current sprint focus, active work, known blockers. Updated: 2026-11-16 -->

## Current State

Independent continuation of `MMoMM-org/linak-control`, detached from the fork
network and rebranded to **Lever** (`guillaume-ernst/lever`). Product/bundle is
Lever (`Lever.app`, `Lever.xcodeproj`, scheme `LeverApp`,
`com.guillaumeernst.Lever`); internals kept the LinakControl names
(`LinakControlKit`, `deskctl`, `~/Library/Application Support/LinakControl`).
Swift 6 language mode, 504 tests green. UI is localized: `fr.lproj`/
`Localizable.strings` + `InfoPlist.strings` in `LinakControl/Sources/App/
Resources` (keys = English literals; SPM target excludes `Resources/` —
app-bundle concern only). deskctl output stays English for scripts.

Design context captured via Impeccable: `PRODUCT.md` (product truth) and
`DESIGN.md` + `.impeccable/design.json` ("The Built-in Instrument" — pure
semantic macOS, no brand colors). Critique of the UI scored 38/40 after
fixes (Lever strings, destructive-action confirmations, scan fallback +
connect cancel, empty preset slots show "+ Add" and save on double-click).

The menu bar is now a **single status item**: the bare height number.
Left-click opens the native preset menu (4 hardware slots, then software
presets, `Add Preset…`, `Settings…`); right-click opens the popover.

**Software presets shipped** (the PRODUCT.md north star): `SoftwarePreset
{id, name, heightMM}` in `AppConfig.softwarePresets` (tolerant decode,
`[]` default); manager CRUD + `goToSoftwarePreset` reusing
`runPresetLoop`'s arbitrary-target loop; UUID-keyed `activeSoftwarePresetID`/
`targetSoftwarePresetID` alongside Int hardware state; management in
Settings (rename, repoint-to-current, delete, reorder arrows); full
IPC/`deskctl` parity (`preset <name>`, `add`/`remove`/`rename`, `--save`
repoints). Software presets also render in the popover under the grid;
names are unique case-insensitively (`DeskError.softwarePresetNameTaken`,
`DeskError` now has `errorDescription`); inline rename commits on focus
loss; generated names fill gaps via `uniquePresetName` (nonisolated).

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
  HotkeyManager.swift) — extend to software presets.
- Editable hardware preset labels in Settings GUI (deskctl `config label`
  supports names; software presets have full name editing already).
- Siri Shortcuts / Intents, widget (longer-term PRODUCT.md items).
