#!/usr/bin/env bash
#
# macboard uninstaller — restore the most recent pre-install Karabiner backup.
#
set -euo pipefail

KARABINER_DIR="${HOME}/.config/karabiner"
KARABINER_JSON="${KARABINER_DIR}/karabiner.json"

say() { printf '\033[1;34m==>\033[0m %s\n' "$1"; }

# Find the most recent macboard backup.
latest_backup="$(ls -1t "${KARABINER_JSON}".macboard-backup-* 2>/dev/null | head -n1 || true)"

if [ -z "${latest_backup}" ]; then
  echo "No macboard backup found in ${KARABINER_DIR}; nothing to restore." >&2
  exit 1
fi

# Safety copy of the current (macboard) state before we overwrite it.
cp "${KARABINER_JSON}" "${KARABINER_JSON}.macboard-preuninstall-$(date +%Y%m%d-%H%M%S)"

cp "${latest_backup}" "${KARABINER_JSON}"
say "Restored ${latest_backup} -> ${KARABINER_JSON}"

say "Reverting top row to media keys (fnState)…"
defaults write -g com.apple.keyboard.fnState -bool false

say "Restoring Ctrl+←/→ Spaces switching…"
python3 - <<'PY'
import subprocess, plistlib
dom = "com.apple.symbolichotkeys"
out = subprocess.run(["defaults", "export", dom, "-"], capture_output=True).stdout
data = plistlib.loads(out) if out.strip() else {}
sk = data.setdefault("AppleSymbolicHotKeys", {})
for k in ("79", "80", "81", "82"):  # Move left/right a space
    entry = sk.get(k) if isinstance(sk.get(k), dict) else {}
    entry["enabled"] = True
    sk[k] = entry
subprocess.run(["defaults", "import", dom, "-"], input=plistlib.dumps(data))
PY
/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u 2>/dev/null || true

say "Done. Karabiner-Elements will auto-reload the restored config."
echo "  (Log out / restart to fully restore the F-key and Spaces shortcuts.)"
echo "  (Karabiner-Elements itself was left installed; remove with: brew uninstall --cask karabiner-elements)"
