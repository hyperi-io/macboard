#!/usr/bin/env python3
"""Add Windows/Linux-style Ctrl keybindings to VS Code / Cursor (and forks).

ADDITIVE and NON-DESTRUCTIVE:
  - VS Code's default Cmd shortcuts are built-in and are NOT touched, so Cmd+C etc.
    keep working everywhere.
  - We only append `ctrl+...` entries to the USER keybindings.json (backed up first).
  - Idempotent: on re-run we drop only our own (key, command) entries, then re-add.
  - We never override a key you've already bound yourself — if you have a binding for
    a key macboard wants, yours is kept and macboard's is skipped.
  - Every Ctrl binding is scoped with `!terminalFocus`, so VS Code's integrated
    terminal stays raw (Ctrl+C = SIGINT, Ctrl+A/E/W = readline). Cmd shortcuts still
    work in the terminal.
  - Also sets `keyboard.dispatch: keyCode` in settings.json — REQUIRED for the editor to
    honor the Globe->Control remap (without it none of these Ctrl bindings fire). Only
    added if you haven't set it yourself; takes effect on the next VS Code restart.

Targets every installed app among: VS Code, VS Code Insiders, Cursor, VSCodium.
"""
import datetime
import json
import os
import re
import shutil
import sys

NT = "!terminalFocus"  # keep the integrated terminal raw


def b(key, command, when=None):
    e = {"key": key, "command": command}
    if when:
        e["when"] = when
    return e


# Editor / input context that still excludes the integrated terminal.
TXT = f"textInputFocus && {NT}"
EDIT = f"textInputFocus && !editorReadonly && {NT}"
ED = f"editorTextFocus && {NT}"
EDW = f"editorTextFocus && !editorReadonly && {NT}"

BINDINGS = [
    # --- clipboard & selection (editor/inputs only; terminal stays raw) ---
    b("ctrl+c", "editor.action.clipboardCopyAction", TXT),
    b("ctrl+x", "editor.action.clipboardCutAction", EDIT),
    b("ctrl+v", "editor.action.clipboardPasteAction", EDIT),
    b("ctrl+a", "editor.action.selectAll", ED),
    # --- undo / redo ---
    b("ctrl+z", "undo", EDIT),
    b("ctrl+shift+z", "redo", EDIT),
    b("ctrl+y", "redo", EDIT),
    # --- find / replace ---
    b("ctrl+f", "actions.find", NT),
    b("ctrl+h", "editor.action.startFindReplaceAction", NT),
    b("ctrl+shift+f", "workbench.action.findInFiles", NT),
    b("ctrl+shift+h", "workbench.action.replaceInFiles", NT),
    # --- editing ---
    b("ctrl+/", "editor.action.commentLine", EDW),
    b("ctrl+d", "editor.action.addSelectionToNextFindMatch", f"editorFocus && {NT}"),
    b("ctrl+shift+l", "editor.action.selectHighlights", f"editorFocus && {NT}"),
    b("ctrl+shift+k", "editor.action.deleteLines", EDW),
    b("ctrl+enter", "editor.action.insertLineAfter", EDW),
    b("ctrl+]", "editor.action.indentLines", EDW),
    b("ctrl+[", "editor.action.outdentLines", EDW),
    # --- files ---
    b("ctrl+s", "workbench.action.files.save", NT),
    b("ctrl+shift+s", "workbench.action.files.saveAs", NT),
    b("ctrl+k s", "workbench.action.files.saveAll", NT),
    b("ctrl+n", "workbench.action.files.newUntitledFile", NT),
    b("ctrl+o", "workbench.action.files.openFileFolder", NT),
    b("ctrl+w", "workbench.action.closeActiveEditor", NT),
    b("ctrl+shift+t", "workbench.action.reopenClosedEditor", NT),
    b("ctrl+k ctrl+w", "workbench.action.closeAllEditors", NT),
    # --- editor / view management ---
    b("ctrl+\\", "workbench.action.splitEditor", NT),
    b("ctrl+b", "workbench.action.toggleSidebarVisibility", NT),
    b("ctrl+j", "workbench.action.togglePanel", NT),
    b("ctrl+,", "workbench.action.openSettings", NT),
    # --- navigation & palettes ---
    b("ctrl+p", "workbench.action.quickOpen", NT),
    b("ctrl+shift+p", "workbench.action.showCommands", NT),
    b("ctrl+shift+e", "workbench.view.explorer", NT),
    b("ctrl+shift+g", "workbench.view.scm", NT),
    b("ctrl+shift+d", "workbench.view.debug", NT),
    b("ctrl+shift+x", "workbench.view.extensions", NT),
    b("ctrl+shift+m", "workbench.actions.view.problems", NT),
    b("ctrl+shift+o", "workbench.action.gotoSymbol", f"editorFocus && {NT}"),
    b("ctrl+t", "workbench.action.showAllSymbols", NT),
    # --- markdown preview (your original request) ---
    b("ctrl+shift+v", "markdown.showPreview", f"editorLangId == markdown && {NT}"),
    b("ctrl+k v", "markdown.showPreviewToSide", f"editorLangId == markdown && {NT}"),
]

APP_DIRS = {
    "VS Code": "Code",
    "VS Code Insiders": "Code - Insiders",
    "Cursor": "Cursor",
    "VSCodium": "VSCodium",
}


def strip_jsonc(text):
    """Remove // and /* */ comments and trailing commas, respecting strings."""
    out, i, n, in_str = [], 0, len(text), False
    while i < n:
        c = text[i]
        if in_str:
            out.append(c)
            if c == "\\" and i + 1 < n:
                out.append(text[i + 1]); i += 2; continue
            if c == '"':
                in_str = False
            i += 1; continue
        if c == '"':
            in_str = True; out.append(c); i += 1; continue
        if c == "/" and i + 1 < n and text[i + 1] == "/":
            while i < n and text[i] != "\n":
                i += 1
            continue
        if c == "/" and i + 1 < n and text[i + 1] == "*":
            i += 2
            while i + 1 < n and not (text[i] == "*" and text[i + 1] == "/"):
                i += 1
            i += 2; continue
        out.append(c); i += 1
    return re.sub(r",(\s*[}\]])", r"\1", "".join(out))


def apply_to(name, support_dir):
    kb = os.path.join(support_dir, "User", "keybindings.json")
    existing = []
    file_exists = os.path.exists(kb)
    if file_exists:
        raw = open(kb, encoding="utf-8").read()
        try:
            existing = json.loads(strip_jsonc(raw) or "[]")
            if not isinstance(existing, list):
                raise ValueError("keybindings.json is not a JSON array")
        except Exception as e:
            print(f"  {name}: SKIP — could not parse keybindings.json ({e})")
            return

    ours = {(e["key"], e["command"]) for e in BINDINGS}
    kept = [e for e in existing if (e.get("key"), e.get("command")) not in ours]
    # Respect the user's own bindings: never override a key they already bound.
    user_keys = {e.get("key") for e in kept}
    to_add = [e for e in BINDINGS if e["key"] not in user_keys]
    skipped = sorted({e["key"] for e in BINDINGS if e["key"] in user_keys})
    merged = kept + to_add

    if file_exists and merged == existing:
        print(f"  {name}: no change — already current")
        return

    if file_exists:
        ts = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
        shutil.copy2(kb, f"{kb}.macboard-backup-{ts}")

    os.makedirs(os.path.dirname(kb), exist_ok=True)
    with open(kb, "w", encoding="utf-8") as f:
        json.dump(merged, f, indent=4, ensure_ascii=False)
        f.write("\n")
    print(f"  {name}: +{len(to_add)} Ctrl bindings ({len(merged)} total) -> {kb}")
    if skipped:
        print(f"           kept your existing bindings for: {', '.join(skipped)}")


def ensure_dispatch(name, support_dir):
    """Set keyboard.dispatch=keyCode so the editor honors the Globe->Control remap.

    Without this, VS Code / Electron ignores the remapped Control modifier and none of
    the Ctrl bindings above fire. Comment-preserving: only inserts if the key is absent.
    """
    settings = os.path.join(support_dir, "User", "settings.json")
    raw = open(settings, encoding="utf-8").read() if os.path.exists(settings) else ""
    if "keyboard.dispatch" in raw:
        return  # already configured — respect the user's choice
    if os.path.exists(settings):
        ts = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
        shutil.copy2(settings, f"{settings}.macboard-backup-{ts}")
    if raw.strip() in ("", "{}"):
        new = '{\n    "keyboard.dispatch": "keyCode"\n}\n'
    else:
        i = raw.find("{")
        if i == -1:
            return  # not a JSON object we understand — leave it alone
        new = raw[:i + 1] + '\n    "keyboard.dispatch": "keyCode",' + raw[i + 1:]
    os.makedirs(os.path.dirname(settings), exist_ok=True)
    with open(settings, "w", encoding="utf-8") as f:
        f.write(new)
    print(f"  {name}: set keyboard.dispatch=keyCode (restart {name} to apply)")


def main():
    base = os.path.expanduser("~/Library/Application Support")
    found = False
    for name, d in APP_DIRS.items():
        support = os.path.join(base, d)
        if os.path.isdir(support):
            found = True
            apply_to(name, support)
            ensure_dispatch(name, support)
    if not found:
        print("  (no VS Code / Cursor install found — skipping)")


if __name__ == "__main__":
    main()
