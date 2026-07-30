#!/usr/bin/env python3
"""Report Shottr's capture hotkeys as Karabiner output specs.

macboard sends every screenshot request to Shottr when Shottr is installed, and to the
native macOS screenshot keys when it is not. The hotkeys are not hardcoded: Shottr stores
its shortcuts in its own preferences, so we read them and emit whatever is actually bound.

Prints a JSON object on stdout (consumed by install.sh, passed to jsonnet as the
`shottr_capture` top-level arg)::

    {"area": {"key_code": "2", "modifiers": ["shift", "command"], "label": "Cmd+Shift+2"},
     "fullscreen": {"key_code": "1", "modifiers": ["shift", "command"], "label": "Cmd+Shift+1"},
     "summary": "area Cmd+Shift+2, full screen Cmd+Shift+1"}

`fullscreen` is null when that shortcut cannot be decoded, which leaves Cmd+Shift+3
native. Exits 1 (with a reason on stderr) when Shottr is not installed or its area
hotkey cannot be decoded, which is the installer's signal to keep the macOS defaults.

Options:
    --launch    start Shottr in the background if it is installed but not running,
                so the keys work immediately after install (a hotkey only fires
                while its owner is running).
"""

from __future__ import annotations

import json
import plistlib
import subprocess
import sys
from pathlib import Path

BUNDLE_ID = "cc.ffitch.shottr"
# Shottr's own default bindings, used when a preference is absent.
DEFAULT_SHORTCUTS = {
    "area": {"carbonModifiers": 768, "carbonKeyCode": 19},        # Cmd+Shift+2
    "fullscreen": {"carbonModifiers": 768, "carbonKeyCode": 18},   # Cmd+Shift+1
}

# Carbon modifier masks (Inside Macintosh: Events), as stored by the KeyboardShortcuts
# library Shottr uses. alphaLock (1024) is deliberately ignored.
CARBON_MODIFIERS = [
    (0x1000, "control", "Ctrl"),
    (0x0800, "option", "Opt"),
    (0x0200, "shift", "Shift"),
    (0x0100, "command", "Cmd"),
]

# Virtual key codes (kVK_*) -> Karabiner key_code names.
KEY_CODES = {
    0: "a", 1: "s", 2: "d", 3: "f", 4: "h", 5: "g", 6: "z", 7: "x", 8: "c", 9: "v",
    11: "b", 12: "q", 13: "w", 14: "e", 15: "r", 16: "y", 17: "t",
    18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5",
    24: "equal_sign", 25: "9", 26: "7", 27: "hyphen", 28: "8", 29: "0",
    30: "close_bracket", 31: "o", 32: "u", 33: "open_bracket", 34: "i", 35: "p",
    36: "return_or_enter", 37: "l", 38: "j", 39: "quote", 40: "k", 41: "semicolon",
    42: "backslash", 43: "comma", 44: "slash", 45: "n", 46: "m", 47: "period",
    48: "tab", 49: "spacebar", 50: "grave_accent_and_tilde", 51: "delete_or_backspace",
    53: "escape",
    65: "keypad_period", 67: "keypad_asterisk", 69: "keypad_plus", 71: "keypad_num_lock",
    75: "keypad_slash", 76: "keypad_enter", 78: "keypad_hyphen", 81: "keypad_equal_sign",
    82: "keypad_0", 83: "keypad_1", 84: "keypad_2", 85: "keypad_3", 86: "keypad_4",
    87: "keypad_5", 88: "keypad_6", 89: "keypad_7", 91: "keypad_8", 92: "keypad_9",
    96: "f5", 97: "f6", 98: "f7", 99: "f3", 100: "f8", 101: "f9", 103: "f11",
    105: "f13", 107: "f14", 109: "f10", 111: "f12", 113: "f15",
    114: "insert", 115: "home", 116: "page_up", 117: "delete_forward", 118: "f4",
    119: "end", 120: "f2", 121: "page_down", 122: "f1",
    123: "left_arrow", 124: "right_arrow", 125: "down_arrow", 126: "up_arrow",
}


def app_path() -> Path | None:
    """Locate Shottr.app, falling back to Spotlight for non-standard install dirs."""
    for candidate in (Path("/Applications/Shottr.app"), Path.home() / "Applications/Shottr.app"):
        if candidate.is_dir():
            return candidate
    found = subprocess.run(
        ["mdfind", f"kMDItemCFBundleIdentifier == {BUNDLE_ID}"],
        capture_output=True, check=False, text=True, encoding="utf-8", errors="replace",
    ).stdout.split("\n")
    for line in found:
        if line.strip().endswith(".app") and Path(line.strip()).is_dir():
            return Path(line.strip())
    return None


def is_running() -> bool:
    return subprocess.run(
        ["pgrep", "-x", "Shottr"], capture_output=True, check=False,
    ).returncode == 0


def launch() -> None:
    """Start Shottr in the background (menu-bar app; no window is brought forward)."""
    subprocess.run(["open", "-ga", "Shottr"], capture_output=True, check=False)


def shortcuts() -> dict:
    """Read Shottr's configured capture shortcuts, falling back to its defaults."""
    exported = subprocess.run(
        ["defaults", "export", BUNDLE_ID, "-"], capture_output=True, check=False,
    ).stdout
    prefs = plistlib.loads(exported) if exported.strip() else {}
    found = {}
    for name, default in DEFAULT_SHORTCUTS.items():
        raw = prefs.get(f"KeyboardShortcuts_{name}")
        try:
            found[name] = json.loads(raw) if raw else default
        except (TypeError, ValueError):
            found[name] = default
    return found


def to_karabiner(shortcut: dict) -> dict:
    """Turn a Carbon {carbonModifiers, carbonKeyCode} pair into a Karabiner output."""
    key_code = KEY_CODES.get(shortcut.get("carbonKeyCode"))
    if key_code is None:
        raise ValueError(f"unmapped key code {shortcut.get('carbonKeyCode')!r}")
    mask = int(shortcut.get("carbonModifiers", 0))
    modifiers = [name for bit, name, _ in CARBON_MODIFIERS if mask & bit]
    if not modifiers:
        raise ValueError("shortcut has no modifiers; refusing to bind a screenshot key to it")
    # Label order follows how macboard's docs write combos (Cmd first), not the
    # menu-bar glyph order.
    pretty = [short for short in ("Cmd", "Ctrl", "Opt", "Shift")
              if any(mask & bit and s == short for bit, _, s in CARBON_MODIFIERS)]
    key_label = key_code.upper() if len(key_code) == 1 else key_code
    return {
        "key_code": key_code,
        "modifiers": modifiers,
        "label": "+".join(pretty + [key_label]),
    }


def main() -> int:
    if app_path() is None:
        print("Shottr is not installed", file=sys.stderr)
        return 1
    if "--launch" in sys.argv and not is_running():
        launch()
    found = shortcuts()
    try:
        area = to_karabiner(found["area"])
    except ValueError as exc:
        print(f"Cannot use Shottr's area-capture hotkey: {exc}", file=sys.stderr)
        return 1
    # An undecodable full-screen hotkey is not fatal: Cmd+Shift+3 stays native.
    try:
        fullscreen = to_karabiner(found["fullscreen"])
    except ValueError as exc:
        print(f"Leaving Cmd+Shift+3 native: {exc}", file=sys.stderr)
        fullscreen = None
    summary = "area " + area["label"]
    if fullscreen is not None:
        summary += ", full screen " + fullscreen["label"]
    print(json.dumps({"area": area, "fullscreen": fullscreen, "summary": summary}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
