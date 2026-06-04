#!/usr/bin/env python3
"""Apply the macboard ruleset to Karabiner-Elements.

Usage:
    merge_profile.py [--clean] <karabiner.json> <macboard.json>

Default (merge) mode — touches only the *selected* profile:
  1. Ensures the `fn -> left_control` simple modification exists (Globe = Control).
     Simple modifications run BEFORE complex modifications, so this is what lets
     Globe+C chain into the Ctrl->Cmd matrix.
  2. Replaces the profile's complex_modifications.rules with macboard's rules.
  Other profiles, device settings, and global prefs are left untouched.

--clean mode — wipes existing keymap config:
  Rebuilds a single pristine "Default" profile containing ONLY macboard
  (fn->left_control + the rules), drops all other profiles and per-device
  settings. Karabiner re-detects devices automatically. Top-level `global`
  app prefs (menu-bar etc.) are preserved.

Either way it writes atomically (temp file + os.replace). The installer takes a
timestamped backup before this runs.
"""
import json
import os
import sys


FN_TO_LCTRL = {"from": {"key_code": "fn"}, "to": [{"key_code": "left_control"}]}

DEFAULT_CM_PARAMS = {
    "basic.simultaneous_threshold_milliseconds": 50,
    "basic.to_delayed_action_delay_milliseconds": 500,
    "basic.to_if_alone_timeout_milliseconds": 1000,
    "basic.to_if_held_down_threshold_milliseconds": 500,
}


def is_fn_mapping(mod):
    return isinstance(mod, dict) and mod.get("from", {}).get("key_code") == "fn"


def main():
    argv = sys.argv[1:]
    clean = "--clean" in argv
    positional = [a for a in argv if a != "--clean"]
    if len(positional) != 2:
        sys.exit("usage: merge_profile.py [--clean] <karabiner.json> <macboard.json>")
    karabiner_path, macboard_path = positional

    with open(karabiner_path) as f:
        config = json.load(f)
    with open(macboard_path) as f:
        macboard = json.load(f)

    profiles = config.get("profiles", [])
    if not profiles:
        sys.exit("error: no profiles found in karabiner.json")

    selected = next((p for p in profiles if p.get("selected")), profiles[0])
    rules = macboard.get("rules", [])

    if clean:
        # Rebuild a pristine macboard-only profile; discard everything else.
        clean_profile = {
            "name": selected.get("name", "Default"),
            "selected": True,
            "parameters": {"delay_milliseconds_before_open_device": 1000},
            "simple_modifications": [FN_TO_LCTRL],
            "fn_function_keys": [],
            "complex_modifications": {"parameters": DEFAULT_CM_PARAMS, "rules": rules},
            "virtual_hid_keyboard": selected.get(
                "virtual_hid_keyboard", {"keyboard_type_v2": "ansi"}
            ),
            "devices": [],
        }
        config["profiles"] = [clean_profile]
        summary = (
            f"  mode           : CLEAN (existing keymap config removed)\n"
            f"  profile        : {clean_profile['name']} (only profile now)\n"
            f"  simple mods    : fn -> left_control\n"
            f"  complex rules  : {len(rules)} macboard rules"
        )
    else:
        # Merge into the selected profile, preserving everything else.
        simple = [m for m in selected.get("simple_modifications", []) if not is_fn_mapping(m)]
        simple.insert(0, FN_TO_LCTRL)
        selected["simple_modifications"] = simple

        cm = selected.setdefault("complex_modifications", {})
        cm.setdefault("parameters", {})
        cm["rules"] = rules
        summary = (
            f"  mode           : MERGE\n"
            f"  profile        : {selected.get('name', '(unnamed)')}\n"
            f"  simple mods    : fn -> left_control ensured ({len(simple)} total)\n"
            f"  complex rules  : replaced with {len(rules)} macboard rules"
        )

    tmp = karabiner_path + ".macboard-tmp"
    with open(tmp, "w") as f:
        json.dump(config, f, indent=4, ensure_ascii=False)
        f.write("\n")
    os.replace(tmp, karabiner_path)
    print(summary)


if __name__ == "__main__":
    main()
