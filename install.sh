#!/usr/bin/env bash
#
# macboard installer — make a Mac keyboard behave like a Windows/Linux keyboard.
# Idempotent: safe to re-run. Backs up your live Karabiner config before changing it.
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

# 2. Render jsonnet -> json and lint it.
say "Rendering config…"
mkdir -p "${REPO_DIR}/json"
jsonnet "${REPO_DIR}/jsonnet/macboard.jsonnet" > "${RENDERED}"

if command -v karabiner_cli >/dev/null 2>&1; then
  say "Linting with karabiner_cli…"
  karabiner_cli --lint-complex-modifications "${RENDERED}"
else
  warn "karabiner_cli not found; skipping lint."
fi

# 3. Back up the live config.
if [ ! -f "${KARABINER_JSON}" ]; then
  echo "No ${KARABINER_JSON} found — launch Karabiner-Elements once, then re-run." >&2
  exit 1
fi
BACKUP="${KARABINER_JSON}.macboard-backup-$(date +%Y%m%d-%H%M%S)"
cp "${KARABINER_JSON}" "${BACKUP}"
say "Backed up live config -> ${BACKUP}"

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

cat <<EOF

$(say "macboard installed.")
  • Globe (bottom-left) is now Control; Ctrl+C/V/X/Z/S/… work Windows-style.
  • Terminals & IDEs keep raw Control (Ctrl+C = interrupt).
  • Top row = F1–F12;  Right-Option + F1…F12 = brightness / Mission Control / volume / media.
  • PrintScreen = Cmd+Shift+5;  Finder Delete = move to Trash.
  • Ctrl+←/→ freed from Spaces-switching → word-jump in terminals (via your shell bindings).

  Backup: ${BACKUP}
  Revert: ./uninstall.sh

  >> LOG OUT AND BACK IN (or restart) to finish <<
     macOS only applies the F-key (fnState) and the Spaces-shortcut changes at login.

  • If Karabiner asks for Input Monitoring / Accessibility permission, grant it.
  • Terminal word-jump needs your shell to bind Ctrl+arrow sequences — see shell/macboard.zsh.
EOF
