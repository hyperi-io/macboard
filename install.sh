#!/usr/bin/env bash
#
# macboard installer — make a Mac keyboard behave like a Windows/Linux keyboard.
# Idempotent: safe to re-run — each step changes only what's needed, and a file is backed
# up only when it's actually modified (no pile-up of backups on repeat runs).
#
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KARABINER_DIR="${HOME}/.config/karabiner"
KARABINER_JSON="${KARABINER_DIR}/karabiner.json"
RENDERED="${REPO_DIR}/json/macboard.json"

# --clean wipes your existing Karabiner keymap config and installs macboard-only.
CLEAN_FLAG=""
for arg in "$@"; do
  [ "$arg" = "--clean" ] && CLEAN_FLAG="--clean"
done

say() { printf '\033[1;34m==>\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$1"; }

# 1. Dependencies (Homebrew assumed present on macOS dev machines).
if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew is required: https://brew.sh" >&2; exit 1
fi

say "Checking Karabiner-Elements…"
if ! brew list --cask karabiner-elements >/dev/null 2>&1 && [ ! -d "/Applications/Karabiner-Elements.app" ]; then
  say "Installing Karabiner-Elements…"
  brew install --cask karabiner-elements
fi

say "Checking jsonnet…"
command -v jsonnet >/dev/null 2>&1 || { say "Installing jsonnet…"; brew install jsonnet; }

# AltTab gives Windows-style per-window Alt+Tab switching. The cask auto-updates
# itself, so installing it once here is all the maintenance it needs.
say "Checking AltTab…"
if ! brew list --cask alt-tab >/dev/null 2>&1 && [ ! -d "/Applications/AltTab.app" ]; then
  say "Installing AltTab…"
  brew install --cask alt-tab
fi
# Launch AltTab in the background so it is running and claims Option+Tab; idempotent
# (no-op if already running). Brief poll so the render step below detects it.
if [ -d "/Applications/AltTab.app" ]; then
  open -ga AltTab 2>/dev/null || true
  for _ in 1 2 3 4 5 6; do pgrep -x AltTab >/dev/null 2>&1 && break; sleep 0.5; done
fi

# 2. Render jsonnet -> json and lint it. If AltTab is installed AND running, leave Alt+Tab
#    (Option+Tab) RAW so AltTab's per-window switcher handles it (has_alttab=true). Otherwise
#    keep windows-mode's Option+Tab -> Cmd+Tab remap (the macOS per-app switcher default).
HAS_ALTTAB=false
pgrep -x AltTab >/dev/null 2>&1 && HAS_ALTTAB=true
say "Rendering config (AltTab active: ${HAS_ALTTAB})…"
mkdir -p "${REPO_DIR}/json"
jsonnet --tla-code "has_alttab=${HAS_ALTTAB}" "${REPO_DIR}/jsonnet/macboard.jsonnet" > "${RENDERED}"

if command -v karabiner_cli >/dev/null 2>&1; then
  say "Linting with karabiner_cli…"
  karabiner_cli --lint-complex-modifications "${RENDERED}"
else
  warn "karabiner_cli not found; skipping lint."
fi

# 3. Ensure the live config exists. merge_profile.py backs it up (timestamped) ONLY when
#    it actually changes something, so re-running with nothing to do writes nothing.
if [ ! -f "${KARABINER_JSON}" ]; then
  echo "No ${KARABINER_JSON} found — launch Karabiner-Elements once, then re-run." >&2
  exit 1
fi

# 4. Apply macboard (Globe=Control simple-mod + full ruleset).
if [ -n "${CLEAN_FLAG}" ]; then
  say "Clean install: replacing your existing Karabiner config with macboard-only…"
else
  say "Merging macboard into your active profile…"
fi
python3 "${REPO_DIR}/scripts/merge_profile.py" ${CLEAN_FLAG} "${KARABINER_JSON}" "${RENDERED}"

# 5. Make the top row real F1-F12 (Globe is now Control, so the fn layer is gone;
#    the rare Mac media ops live on Right-Option+F-key).
say "Setting top row to standard F1–F12 (fnState)…"
defaults write -g com.apple.keyboard.fnState -bool true

# 6. Free Ctrl+←/→ from the macOS "Move left/right a space" shortcuts so those
#    keystrokes reach the focused app/terminal (word-jump via your shell bindings)
#    instead of switching Spaces. System-wide — not terminal-specific.
#    NOTE: macOS only re-reads these shortcuts at login, so this needs a logout/restart.
say "Freeing Ctrl+←/→ from Spaces switching (applies after logout/restart)…"
python3 - <<'PY'
import subprocess, plistlib
dom = "com.apple.symbolichotkeys"
out = subprocess.run(["defaults", "export", dom, "-"], capture_output=True).stdout
data = plistlib.loads(out) if out.strip() else {}
sk = data.setdefault("AppleSymbolicHotKeys", {})
for k in ("79", "80", "81", "82"):  # Move left/right a space
    entry = sk.get(k) if isinstance(sk.get(k), dict) else {}
    entry["enabled"] = False
    sk[k] = entry
subprocess.run(["defaults", "import", dom, "-"], input=plistlib.dumps(data))
PY
/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u 2>/dev/null || true

# 7. Add Windows/Linux-style Ctrl keybindings to VS Code / Cursor (additive; your Cmd
#    shortcuts and any bindings you set yourself are preserved; the integrated terminal
#    stays raw). No-op if neither editor is installed.
say "Adding Ctrl keybindings to VS Code / Cursor (if installed)…"
python3 "${REPO_DIR}/scripts/vscode_keybindings.py" || true

# 8. Source the shell word/line-motion bindings from ~/.zshrc so they load in every new
#    shell (terminal Ctrl+arrow word-jump and Home/End). Idempotent: skipped if already
#    sourced; ~/.zshrc is backed up (timestamped) only when this actually appends.
say "Ensuring ~/.zshrc sources macboard.zsh…"
ZSHRC="${HOME}/.zshrc"
if [ -f "${ZSHRC}" ] && grep -qF "shell/macboard.zsh" "${ZSHRC}"; then
  say "~/.zshrc already sources macboard.zsh; leaving as is."
else
  [ -f "${ZSHRC}" ] && cp "${ZSHRC}" "${ZSHRC}.macboard-backup-$(date +%Y%m%d-%H%M%S)"
  {
    printf '\n# macboard: PC-style word/line navigation at the zsh prompt\n'
    printf 'source "%s/shell/macboard.zsh"\n' "${REPO_DIR}"
  } >> "${ZSHRC}"
  say "Added source line to ~/.zshrc (open a new terminal to apply)."
fi

cat <<EOF

$(say "macboard installed.")
  • Globe (bottom-left) is now Control; Ctrl+C/V/X/Z/S/… work Windows-style.
  • System terminals stay raw Control (Ctrl+C = interrupt; copy/paste = Ctrl+Shift+C/V).
  • VS Code + Claude Code panel: Ctrl+C/V/X/Z/A and word/line motion work Windows-style.
  • Top row = F1–F12;  Right-Option + F1…F12 = brightness / Mission Control / volume / media.
  • PrintScreen = Cmd+Shift+5;  Finder Delete = move to Trash.
  • AltTab installed — Windows-style per-window switching on Alt+Tab (built-in keyboard:
    Cmd+Tab too). Grant it Accessibility + Screen Recording permission on first launch.
  • Ctrl+←/→ freed from Spaces-switching → word-jump in terminals (via your shell bindings).
  • VS Code / Cursor: Windows-style Ctrl shortcuts added — RESTART the editor to apply
    (macboard also sets keyboard.dispatch=keyCode so it honors Globe→Control).

  Backups are timestamped in ~/.config/karabiner/ (written only when something changed).
  Revert: ./uninstall.sh

  >> LOG OUT AND BACK IN (or restart) to finish <<
     macOS only applies the F-key (fnState) and the Spaces-shortcut changes at login.

  • If Karabiner asks for Input Monitoring / Accessibility permission, grant it.
  • Shell word/line motion auto-loads via ~/.zshrc (open a new terminal); see shell/macboard.zsh.
EOF
