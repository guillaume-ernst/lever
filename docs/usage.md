# Usage

Operate Lever after install and pairing: menu bar interactions, common sit/stand workflows, the full `deskctl` CLI surface, and the JSON output and exit codes you need for scripting.

## Basic use

Lever has two front ends. They share the same paired desk and the same configuration file, so you can mix them freely.

**Menu bar app — one item, two gestures**

After launching `Lever.app`, the menu bar shows a single item: the current desk height as a bare number (e.g. `114.4` — the unit is your configured one).

- **Left-click — preset menu.** A dropdown listing the four hardware presets (numbered 1–4) followed by your named software presets; pick one to move there. An empty slot shows `+ Add` and saves the current height when selected. `Add Preset…` captures the current height as a new software preset, and the menu ends with `Settings…`, which opens the popover.
- **Right-click — control popover.** The full instrument: live height, manual up/down controls, the 2×2 preset grid, and the settings gear.
- **Fault state.** On a desk fault the item gains an orange warning triangle; hover it for the cause.
- Hiding the readout ("Show height in menu bar" off in Settings) falls back to a plain desk icon; both gestures keep working.

**CLI — `deskctl`**

The CLI talks to the running menu bar app over a Unix socket, so the app must be running for desk commands to work. The simplest sanity-check after pairing:

```bash
deskctl status
```

A successful run prints the connection state, the desk name, the current height, the four preset slots, and any software presets (`*` marks the active one):

```
Lever Daemon
  Connection: connected
  Desk:       LINAK-DPG1C-1A2B
  Height:     72.4 cm
  Presets:    1=63.0cm  2=78.5cm*  3=110.0cm  4=120.0cm
  Software:   Focus=63.0cm*  Call=110.0cm
```

If `deskctl` reports `Daemon: not running`, launch the app first.

## Common workflows

The patterns below cover what most users want Lever for. Each one shows both the GUI path and the CLI path.

**Set up a sit/stand routine**

The point of presets is one-click switching between sitting and standing height. Once paired:

1. Move the desk to your preferred sitting height (manual up/down in the popover, or `deskctl up --manual` then `deskctl stop`).
2. Save it to preset 1 — open the popover **Settings**, find preset 1, and tap **Save current height**. From the CLI: `deskctl preset 1 --save`.
3. Repeat at your standing height and save to preset 2.
4. Switch between the two from the left-click preset menu, the popover preset grid, or:

   ```bash
   deskctl preset 1   # sit
   deskctl preset 2   # stand
   ```

**Label your presets**

Labels appear in `deskctl status` and (when supported by the UI) in the menu — useful when you can't remember which slot is which.

```bash
deskctl config label 1 Sitting
deskctl config label 2 Standing
deskctl config label 3 --clear   # remove a label
deskctl config label 2           # show current label without changing it
```

**Software presets — beyond the four hardware slots**

The hardware only stores four positions. Software presets live in the app's config: unlimited count, real names instead of slot numbers, and the same movement loop when invoked.

- **From the menu bar:** `Add Preset…` at the bottom of the left-click menu captures the current height under a generated name (`Preset 5`, `Preset 6`, …).
- **From Settings:** the *Presets* section lists each software preset with an inline name field, its stored height, a "set to current height" action, reorder arrows, and delete.
- **From the CLI:**

```bash
deskctl preset add Focus        # capture current height as "Focus"
deskctl preset Focus            # move to it (names are case-insensitive)
deskctl preset Focus --save     # re-point "Focus" at the current height
deskctl preset rename Focus Sit # rename it
deskctl preset remove Sit       # delete it
```

Name matching is case-insensitive; `deskctl preset standing desk` works for a preset named `Standing Desk` even without quotes. If a name also matches a UUID `id` it resolves by id first — pick another name if you hit a collision (unlikely).

A note on scope: `--save` on a hardware index writes into the desk's flash (the DPG1C's own memory); `--save` on a software name only updates the app's config. Same flag, different backing store.

**Manual movement when no preset fits**

The popover has hold-to-move up/down buttons. Releasing the button stops the desk. If you have `auto_run_up` / `auto_run_down` set to `auto` (see [Configuration](configuration.md)), the buttons toggle continuous movement instead of requiring a hold.

The CLI mirrors both modes:

```bash
deskctl up --manual    # nudges up; stops when the desk's safety timeout expires
deskctl up --auto      # starts continuous up movement
deskctl stop           # stops any movement immediately
deskctl down --auto    # same in the other direction
```

`--auto` and `--manual` are mutually exclusive; passing neither uses the configured default for that direction.

**Script height changes**

Pipe `--json` output into your tooling. For example, a shell snippet that toggles between presets 1 and 2 based on the current active slot:

```bash
active=$(deskctl status --json | jq '.active_preset')
if [ "$active" = "1" ]; then
    deskctl preset 2
else
    deskctl preset 1
fi
```

Use this as the body of a cron job, a hotkey via macOS Shortcuts/Raycast, or a Home Assistant automation.

## deskctl CLI reference

All commands are subcommands of `deskctl`. Every command except `config show`, `config reset`, `config label`, and `service install` requires the menu bar app to be running (it owns the BLE connection; the CLI is an IPC client).

| Command | Description | Flags |
|---|---|---|
| `deskctl status` | Connection state, paired desk name, current height, presets. | `--json` |
| `deskctl height` | Just the current height (no surrounding fields). | `--json` |
| `deskctl up` | Move the desk up. | `--auto`, `--manual` (mutually exclusive) |
| `deskctl down` | Move the desk down. | `--auto`, `--manual` (mutually exclusive) |
| `deskctl stop` | Stop any active movement immediately. | — |
| `deskctl preset <1-4>` | Move to the hardware preset in that slot. | `--save` (overwrite the slot with the current height) |
| `deskctl preset <name>` | Move to a software preset by name (case-insensitive). | `--save` (re-point the preset at the current height) |
| `deskctl preset add <name>` | Create a software preset at the current height. | — |
| `deskctl preset remove <name>` | Delete a software preset. | aliases: `rm`, `delete` |
| `deskctl preset rename <name> <new>` | Rename a software preset. | — |
| `deskctl config show` | Print the full config JSON. | — |
| `deskctl config reset` | Wipe config back to defaults (clears pairing). Prompts unless forced. | `--force` |
| `deskctl config label <1-4> [text]` | Show, set, or clear a preset label. | `--clear` |
| `deskctl service status` | Check whether the daemon (the menu bar app) is reachable. | — |
| `deskctl service stop` | Send SIGTERM to the running daemon. | — |
| `deskctl service install` | Print instructions for enabling Start-at-Login. | — |

A few details that are not obvious from `--help`:

- **Preset indices are validated** — `deskctl preset 5` returns a `ValidationError`. Anything that is not a number or an action keyword is treated as a software preset name; unknown names come back as `software preset not found` (exit code 1). The same goes for labels.
- **Names resolve case-insensitively** — `deskctl preset focus` and `deskctl preset Focus` hit the same preset. `add`, `remove`, `rm`, `delete`, and `rename` are reserved words; avoid naming a preset exactly `add` (you can still reach it — and remove it — through Settings in the app).
- **`config show` reads the config file directly**, so it works even if the daemon is stopped. Same for `config reset` and `config label`.
- **`config reset` clears pairing too** — the next app launch goes back to first-run scanning. Use `--force` only in scripts where you're certain.
- **`service install`** does not register anything itself; it just prints the steps for the Settings panel.
- **Version** — `deskctl --version` prints `1.0.0` (defined in `DeskctlCommand.swift`).

## Output formats and exit codes

**Plain text (default).** Status, height, and preset commands print human-readable lines. Error messages are also plain text and go to **stderr**, never stdout — so piping stdout into another program stays clean.

**`--json` (where available).** `deskctl status` and `deskctl height` accept `--json`. Field names are snake_case. The schema is **additive**: fields get added as the app grows (`needs_reference` and `fault_code` both arrived after the first release), so parse by key and ignore what you do not recognise rather than assuming a fixed set.

`deskctl status --json` shape:

```json
{
  "connected": true,
  "desk_name": "DESK 0726",
  "height_mm": 1097,
  "height_display": "109.7 cm",
  "unit": "cm",
  "presets": [
    {"index": 1, "height_mm": 709},
    {"index": 2, "height_mm": 1097, "label": "Standing"},
    {"index": 3, "height_mm": 1146},
    {"index": 4}
  ],
  "active_preset": 2,
  "software_presets": [
    {"id": "F5A0…", "name": "Focus", "height_mm": 630},
    {"id": "8B21…", "name": "Call", "height_mm": 1100}
  ],
  "active_software_preset": "F5A0…",
  "needs_reference": false
}
```

Two things to know before you parse it:

- **Optional fields are omitted, not null.** An unset preset is `{"index": 4}` — no `height_mm`, no `label`. Same for `fault_code` below. Use `jq`'s `//` default or check for presence; do not expect `null`.
- **`height_display` includes the unit** (`"109.7 cm"`, `"43.2 in"`). Use `height_mm` for arithmetic — it is always millimetres regardless of the `unit` setting, and already includes `desk_offset_mm`.

**Fault fields.** Two fields report whether the desk is asking to be re-referenced:

| Field | Type | Always present | Meaning |
|---|---|---|---|
| `needs_reference` | bool | yes | A move stalled or the desk reported a fault. The app has disconnected so you can operate the control box. |
| `fault_code` | int | **no** — only when the desk pushed one | Raw code behind `needs_reference`, e.g. `30` (`0x1e`) for **E16**, `23` (`0x17`) for **E26**. |

When `needs_reference` is `true`, the desk needs a manual re-reference on the control box — see [Troubleshooting](troubleshooting.md). A script that drives the desk unattended should check it before issuing a move, since movement commands will not take effect until the desk is re-referenced:

```bash
if [ "$(deskctl status --json | jq '.needs_reference')" = "true" ]; then
  echo "Desk needs a manual reset — code: $(deskctl status --json | jq '.fault_code // "none reported"')" >&2
  exit 1
fi
```

`deskctl height --json` shape:

```json
{"height_mm": 724, "height_display": "72.4", "unit": "cm"}
```

Errors in `--json` mode print a single JSON object: `{"error": <code>, "message": "<text>"}`. The code matches the process exit code.

**Exit codes.** Scripts can branch on these:

| Code | Name | Cause |
|---|---|---|
| `0` | `success` | Command completed. |
| `1` | `general` | Connection failed, invalid response, or any uncategorised failure. |
| `2` | `daemonNotRunning` | The menu bar app is not running. Start `Lever.app` and retry. |
| `3` | `notConnected` | The daemon is up but the desk is not currently paired/connected (e.g. desk powered off). |
| `5` | `timeout` | The desk did not respond within the timeout. Often resolved by trying again. |

A robust polling script:

```bash
if ! deskctl status >/dev/null 2>&1; then
    case $? in
        2) echo "Start Lever.app first."; exit 1 ;;
        3) echo "Desk disconnected — power on and re-pair."; exit 1 ;;
        5) echo "Desk timed out; retrying."; exec "$0" ;;
        *) echo "Unknown failure."; exit 1 ;;
    esac
fi
```
