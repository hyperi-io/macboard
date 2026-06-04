# macboard

> **macboard is a muscle-memory tool, first and foremost.**

It makes a **Mac keyboard behave like a Windows/Linux (QWERTY) keyboard** so the keymap
your hands have already burned in over years keeps working on macOS. This isn't about a
"better" layout — it's about **zero relearning**. The reflexes you use on Linux and Windows
should fire correctly on the Mac too, so you never have to retrain your fingers (or fight
them) just because you switched machines. Everything below exists to protect that muscle
memory; every other feature is in service of it.

## Who this is for

Developers and infra people who **routinely swap between macOS, Linux, and Windows** and are sick of the
mental context-shift *every single time* — the one forced purely by the junk difference in
modifier conventions. Windows and Linux put **Ctrl** in the bottom-left corner and use it
for copy / paste / save / select-all / interrupt; macOS uses **Command** for all of those
and parks Control somewhere your fingers never expect. So every keyboard switch costs you a
tax: "wait, is this the Mac one?" macboard deletes that tax. The Mac's bottom-left (world) key
becomes your Ctrl and the Windows-style shortcuts just work, so you stop thinking about the
keyboard and get back to work.

**Especially when docked.** The scenario: a MacBook on a docking station driving
an external monitor with a full-size **Windows/PC keyboard** plugged in. That external
keyboard sends a *real* Ctrl — which macOS normally ignores for copy/paste — so macboard's
`Ctrl→Cmd` translation is exactly what makes `Ctrl+C` actually copy on it. The rules apply
to **both** the external PC keyboard and the MacBook's built-in keyboard identically, and
they follow you across undock / redock and hot-plugging. Swap your hands between the two
keyboards mid-task and nothing changes under your fingers.

Built on [Karabiner-Elements](https://karabiner-elements.pqrs.org/) and a fork of
[rux616/karabiner-windows-mode](https://github.com/rux616/karabiner-windows-mode).
Apple Silicon MacBook (tested on an M-series Air), recent macOS. **macOS only.**

## What it does

| Area | Behavior |
|------|----------|
| **Globe key (bottom-left)** | Acts as **Control**. One-way `fn → left_control` simple modification — your real Control key is untouched, you just gain a Control in the Windows position. |
| **Ctrl shortcuts** | `Ctrl+C/V/X/Z/A/S/F/W/T/N/…` are translated to their `Cmd` equivalents (copy/paste/cut/undo/select-all/save/find/close/new-tab/new) — Windows-style — **everywhere except terminals and IDEs**. |
| **Terminals (Terminal.app, Ghostty, iTerm2, …)** | Exempted from the translation, so **`Ctrl+C` = interrupt (SIGINT)** like on Linux. `Ctrl+Shift+C/V` = copy/paste in terminals. |
| **Command keys** | Unchanged and additive: `Cmd+C` still copies, so copy works from *both* the Globe/Control key and Command. |
| **Top function row** | Real **F1–F12** by default (on both keyboards). The rare Mac system ops move to a **Right-Option layer**. |
| **Right-Option + F1…F12** | Brightness ↓↑, Mission Control, Spotlight, keyboard backlight ↓↑, ⏮ ⏯ ⏭, mute, volume ↓↑. |
| **PrintScreen** | Opens the macOS screenshot toolbar (`Cmd+Shift+5`). |
| **Windows Delete key** | Forward-deletes in text (native); in **Finder**, `Delete` = move to Trash, `Shift+Delete` = delete immediately. On the built-in keyboard, `Right-Option+Backspace` = forward delete. |
| **Windows nav keys** | `Home`/`End`, `Ctrl+←/→` (word jump), `Ctrl+Backspace/Delete` (word delete), `Alt+F4` (quit), etc. — from windows-mode. |
| **VS Code / Cursor** | IDEs are exempt from the OS matrix, so Windows-style **Ctrl shortcuts are added to your editor's `keybindings.json`** instead — additive (Cmd still works, your own bindings win, the integrated terminal stays raw). |

### Why a "matrix" and not just a key swap?

On Linux the *same* Ctrl key means "copy" to apps and "interrupt" to the terminal.
On macOS that split lives across **two** keys — GUI copy is `Cmd+C`, terminal interrupt
is `Ctrl+C`. To put both back on one corner key, the software has to translate
`Ctrl→Cmd` **only in GUI apps** and leave terminals raw. That conditional translation
is the rule "matrix." A plain key swap can't be context-aware, and your external PC
keyboard (which sends a real Ctrl) needs the translation to copy at all — so the matrix
is unavoidable, not incidental.

## Install

```bash
./install.sh           # merge macboard into your existing profile
./install.sh --clean    # wipe existing keymap config, install macboard-only
```

The installer is idempotent and:
1. Ensures Karabiner-Elements + `jsonnet` are installed (via Homebrew).
2. Renders `jsonnet/macboard.jsonnet` → `json/macboard.json` and lints it.
3. **Backs up** `~/.config/karabiner/karabiner.json` (timestamped).
4. Applies the `fn→left_control` simple-mod and the full ruleset. By default it
   **merges** into your active profile; `--clean` instead replaces your whole config
   with a single pristine macboard profile (other profiles / per-device settings dropped;
   Karabiner re-detects devices automatically).
5. Sets the top row to standard F1–F12 (`fnState`).
6. Disables the macOS **"Move left/right a space"** shortcut so `Ctrl+←/→` reaches the
   terminal (word-jump) instead of switching Spaces.
7. Adds Windows-style **Ctrl keybindings to VS Code / Cursor** (`keybindings.json`) —
   additive: your Cmd shortcuts and your own bindings are kept, the integrated terminal
   stays raw. Skipped if neither is installed.

It's **idempotent**: every step changes only what's actually out of date, and a file is
backed up only when it's modified — so repeat runs are no-ops, not a pile of backups.

Grant Karabiner **Input Monitoring** / **Accessibility** permission if prompted.

> ⚠️ **Log out and back in (or restart) after installing.** macOS only applies the
> F-key (`fnState`) and the Spaces-shortcut changes at login — until you do, the top row
> and `Ctrl+←/→` won't behave yet.

For terminal word-jump, source the shell bindings from your `~/.zshrc`:

```sh
source /path/to/macboard/shell/macboard.zsh
```

## Uninstall

```bash
./uninstall.sh
```

Restores the most recent pre-install backup and reverts the F-key setting.
(Karabiner-Elements itself is left installed.)

## Customize

Rules live in [`jsonnet/macboard.jsonnet`](jsonnet/macboard.jsonnet) (our amendments —
media layer, PrintScreen, Finder delete) layered on the vendored
[`jsonnet/windows_shortcuts.jsonnet`](jsonnet/windows_shortcuts.jsonnet) (the matrix).
Edit, then re-run `./install.sh`.

## Caveats

- It's **SIGINT** (interrupt), which is the correct Linux `Ctrl+C` behavior — not
  literally SIGTERM.
- The full matrix overrides some macOS Control defaults in GUI apps (e.g. `Ctrl+A` =
  Select All instead of start-of-line). Mission Control (`Ctrl+↑`), `Ctrl+click`, and
  lock (`Ctrl+Cmd+Q`) still work.
- macboard **disables the macOS "Move left/right a space" shortcut** so `Ctrl+←/→` is
  free for word-jump (you lose Ctrl+arrow Space-switching — use a swipe / Mission Control,
  or remap it). **Requires a logout/restart** to take effect.
- **Terminal** word-jump (`Ctrl+←/→`, `Ctrl+Backspace/Delete`) relies on your shell
  binding the Ctrl+arrow escape sequences — source [`shell/macboard.zsh`](shell/macboard.zsh).
- The built-in keyboard loses `fn+Delete` forward-delete (the fn layer is now Control);
  use `Right-Option+Backspace`, or the dedicated Delete key on an external keyboard.

## License

[MIT](LICENSE) © Hyperi. The vendored files under `jsonnet/` (from
[rux616/karabiner-windows-mode](https://github.com/rux616/karabiner-windows-mode)) are
public-domain (Unlicense) and retain that dedication.

## Credits

- [rux616/karabiner-windows-mode](https://github.com/rux616/karabiner-windows-mode) — the core ruleset (Unlicense).
- [Karabiner-Elements](https://github.com/pqrs-org/Karabiner-Elements) by pqrs.org.
