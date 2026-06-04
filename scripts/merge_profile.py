#!/usr/bin/env python3
"""Merge the macboard ruleset into the active Karabiner-Elements profile.

Usage:
    merge_profile.py <karabiner.json> <macboard.json>

What it does to the *selected* profile (the one Karabiner is currently using):
  1. Ensures the `fn -> left_control` simple modification exists (Globe = Control).
     Simple modifications run BEFORE complex modifications, so this is what lets
     Globe+C chain into the Ctrl->Cmd matrix.
  2. Replaces the profile's complex_modifications.rules with macboard's rules.
     (The user explicitly asked to "back up and replace" their existing setup; the
     installer takes a timestamped backup before this runs.)

It writes atomically (temp file + os.replace) and never touches other profiles.
"""
import json
import os
import sys


FN_TO_LCTRL = {"from": {"key_code": "fn"}, "to": [{"key_code": "left_control"}]}


def is_fn_mapping(mod):
    return isinstance(mod, dict) and mod.get("from", {}).get("key_code") == "fn"


def main():
    if len(sys.argv) != 3:
        sys.exit("usage: merge_profile.py <karabiner.json> <macboard.json>")
    karabiner_path, macboard_path = sys.argv[1], sys.argv[2]

    with open(karabiner_path) as f:
        config = json.load(f)
    with open(macboard_path) as f:
        macboard = json.load(f)

    profiles = config.get("profiles", [])
    if not profiles:
        sys.exit("error: no profiles found in karabiner.json")

    selected = next((p for p in profiles if p.get("selected")), profiles[0])

    # 1. Globe = Control (simple modification), preserving any unrelated entries.
    simple = [m for m in selected.get("simple_modifications", []) if not is_fn_mapping(m)]
    simple.insert(0, FN_TO_LCTRL)
    selected["simple_modifications"] = simple

    # 2. Replace complex_modifications.rules, keeping any existing parameters block.
    cm = selected.setdefault("complex_modifications", {})
    cm.setdefault("parameters", {})
    rules = macboard.get("rules", [])
    cm["rules"] = rules

    tmp = karabiner_path + ".macboard-tmp"
    with open(tmp, "w") as f:
        json.dump(config, f, indent=4, ensure_ascii=False)
        f.write("\n")
    os.replace(tmp, karabiner_path)

    print(f"  profile        : {selected.get('name', '(unnamed)')}")
    print(f"  simple mods    : fn -> left_control ensured ({len(simple)} total)")
    print(f"  complex rules  : replaced with {len(rules)} macboard rules")


if __name__ == "__main__":
    main()
