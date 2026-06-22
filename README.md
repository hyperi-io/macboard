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
| **System terminals (Terminal.app, Ghostty, iTerm2, …)** | Exempted from the translation, so **`Ctrl+C` = interrupt (SIGINT)** like on Linux. `Ctrl+Shift+C/V` = copy/paste; `Ctrl+←/→` and `Home`/`End` word/line motion come from the shell bindings ([`shell/macboard.zsh`](shell/macboard.zsh)). |
| **Command keys** | Unchanged and additive: `Cmd+C` still copies, so copy works from *both* the Globe/Control key and Command. |
| **Top function row** | Real **F1–F12** by default (on both keyboards). The rare Mac system ops move to a **Right-Option layer**. |
| **Right-Option + F1…F12** | Brightness ↓↑, Mission Control, Spotlight, keyboard backlight ↓↑, ⏮ ⏯ ⏭, mute, volume ↓↑. |
| **PrintScreen** | Opens the macOS screenshot toolbar (`Cmd+Shift+5`). |
| **Windows Delete key** | Forward-deletes in text (native); in **Finder**, `Delete` = move to Trash, `Shift+Delete` = delete immediately. On the built-in keyboard, `Right-Option+Backspace` = forward delete. |
| **Windows nav keys** | `Home`/`End`, `Ctrl+←/→` (word jump), `Ctrl+Backspace/Delete` (word delete), `Alt+F4` (quit), etc. — from windows-mode. |
| **VS Code / Cursor** | Editor gets Windows-style **Ctrl shortcuts via `keybindings.json`** (additive; Cmd still works; your bindings win). The **Claude Code panel** additionally gets `Ctrl+C/X/Z/A` (copy/cut/undo/select-all) and `Home`/`End` at the Karabiner level, because its webview input can't be reached by `keybindings.json`. The **integrated terminal** is best-effort (selection-aware `Ctrl+C` copy, else SIGINT). |
| **Alt+Tab** | Per-**window** switching via the [AltTab](https://alt-tab-macos.netlify.app/) app (installed by the installer). When AltTab is installed and running, `Alt+Tab` (`Option+Tab`) is left **raw** for it; otherwise the config falls back to `Option+Tab → Cmd+Tab` (the macOS per-app switcher). |
| **Remote desktop (Thincast, Citrix, MS RDP)** | Exempt from the matrix — keys pass through **raw** so the remote Linux/Windows session handles them natively. `Globe→Control` still applies, so Globe stays your Ctrl *into* the session. |

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
1. Ensures Karabiner-Elements, `jsonnet`, and **AltTab** are installed (via Homebrew), and
   launches AltTab so it can claim `Alt+Tab`.
2. Renders `jsonnet/macboard.jsonnet` → `json/macboard.json` and lints it. **If AltTab is
   installed and running**, `Alt+Tab` (`Option+Tab`) is left raw so AltTab's per-window
   switcher gets it; otherwise the `Option+Tab → Cmd+Tab` (macOS app-switcher) fallback is
   compiled in (`--tla-code has_alttab=…`).
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
8. Adds `source …/shell/macboard.zsh` to your **`~/.zshrc`** so terminal word/line motion
   (`Ctrl+←/→`, `Home`/`End`) loads in every new shell. Skipped if already present.

It's **idempotent**: every step changes only what's actually out of date, and a file is
backed up only when it's modified — so repeat runs are no-ops, not a pile of backups.

Grant Karabiner **Input Monitoring** / **Accessibility** permission if prompted.

> ⚠️ **Log out and back in (or restart) after installing.** macOS only applies the
> F-key (`fnState`) and the Spaces-shortcut changes at login — until you do, the top row
> and `Ctrl+←/→` won't behave yet.

The installer adds the shell-bindings `source` line to your `~/.zshrc` automatically (step 8
above). To wire it up by hand — or in a different shell rc — add:

```sh
source /path/to/macboard/shell/macboard.zsh
```

## Uninstall

```bash
./uninstall.sh
```

Restores the most recent pre-install backup, reverts the F-key (`fnState`) and
**"Move left/right a space"** settings, and removes the `source …/macboard.zsh` line from
your `~/.zshrc`. (Karabiner-Elements and AltTab themselves are left installed.)

## Customize

Rules live in [`jsonnet/macboard.jsonnet`](jsonnet/macboard.jsonnet) (our amendments —
media layer, PrintScreen, Finder delete, the AltTab fallback) layered on the vendored
[`jsonnet/windows_shortcuts.jsonnet`](jsonnet/windows_shortcuts.jsonnet) (the matrix). It
takes one top-level arg, `has_alttab` (default `false`), which the installer sets from
AltTab detection. Edit, then re-run `./install.sh`.

## Caveats

- It's **SIGINT** (interrupt), which is the correct Linux `Ctrl+C` behavior — not
  literally SIGTERM.
- The full matrix overrides some macOS Control defaults in GUI apps (e.g. `Ctrl+A` =
  Select All instead of start-of-line). Mission Control (`Ctrl+↑`), `Ctrl+click`, and
  lock (`Ctrl+Cmd+Q`) still work.
- macboard **disables the macOS "Move left/right a space" shortcut** so `Ctrl+←/→` is
  free for word-jump (you lose Ctrl+arrow Space-switching — use a swipe / Mission Control,
  or remap it). **Requires a logout/restart** to take effect.
- **Terminal** word/line motion (`Ctrl+←/→`, `Ctrl+Backspace/Delete`, `Home`/`End`) comes
  from the shell bindings in [`shell/macboard.zsh`](shell/macboard.zsh), which the installer
  sources from `~/.zshrc`. New shells pick it up automatically; `source ~/.zshrc` in any
  already-open ones.
- **VS Code / Cursor need a restart** after install: macboard sets
  `keyboard.dispatch: keyCode` so the editor honors the Globe→Control remap (without it,
  *none* of the editor Ctrl bindings fire), and that setting only applies on restart.
- **AltTab grabs `Option+Tab` globally**, so inside a remote-desktop client (Thincast/RDP)
  it fires the *Mac's* window switcher rather than sending `Alt+Tab` to the remote. Add the
  client under AltTab → **Exceptions** if you want `Alt+Tab` to reach the session.
- On the **built-in keyboard** the `fn`/Globe layer is gone (it's now Control), so the keys
  it used to produce are unavailable: `fn+Delete` forward-delete → use `Right-Option+Backspace`;
  and there are no `Home`/`End`/`PgUp`/`PgDn` keys → use `Cmd+←/→` for line start/end and the
  trackpad to scroll. (On an external PC keyboard those keys exist and work.)

## License

[MIT](LICENSE) © Hyperi. The vendored files under `jsonnet/` (from
[rux616/karabiner-windows-mode](https://github.com/rux616/karabiner-windows-mode)) are
public-domain (Unlicense) and retain that dedication.

## Credits

- [rux616/karabiner-windows-mode](https://github.com/rux616/karabiner-windows-mode) — the core ruleset (Unlicense).
- [Karabiner-Elements](https://github.com/pqrs-org/Karabiner-Elements) by pqrs.org.
