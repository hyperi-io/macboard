#!/usr/bin/env bash
#
# macboard uninstaller -- restore the Karabiner config from before macboard and revert the
# macOS settings and ~/.zshrc line the installer changed.
#
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KARABINER_DIR="${HOME}/.config/karabiner"
KARABINER_JSON="${KARABINER_DIR}/karabiner.json"

say() { printf '\033[1;34m==>\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$1"; }

# A re-install backs up a config that already holds macboard, so restore the newest
# backup WITHOUT macboard rules. Names end in a YYYYmmdd-HHMMSS stamp, so glob order is
# oldest first.
restore_backup=""
for backup in "${KARABINER_JSON}".macboard-backup-*; do
  [ -f "${backup}" ] || continue
  grep -qF '[macboard]' "${backup}" || restore_backup="${backup}"
done

if [ -n "${restore_backup}" ]; then
  # Safety copy of the current (macboard) state before we overwrite it.
  cp "${KARABINER_JSON}" "${KARABINER_JSON}.macboard-preuninstall-$(date +%Y%m%d-%H%M%S)"
  cp "${restore_backup}" "${KARABINER_JSON}"
  say "Restored ${restore_backup} -> ${KARABINER_JSON}"
else
  warn "No pre-macboard Karabiner backup in ${KARABINER_DIR}; Karabiner config left as is."
fi

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

# Remove the ~/.zshrc source line (current or legacy) and ~/.config/macboard/macboard.zsh.
python3 "${REPO_DIR}/scripts/zshrc.py" uninstall

say "Done. Karabiner-Elements auto-reloads its config."
echo "  (Log out / restart to fully restore the F-key and Spaces shortcuts.)"
echo "  (Karabiner-Elements itself was left installed; remove with: brew uninstall --cask karabiner-elements)"
