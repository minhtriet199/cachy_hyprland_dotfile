#!/usr/bin/env python3
# Isla → Keyboard: add or remove a shortcut, through the Keyboard Shortcuts app's apply()
# (writes binds.lua, reloads Hyprland, rolls back on config errors, then saves keybinds.json).
#   addbind.py add "Name" "command to run" "SUPER + SHIFT + N"
#   addbind.py remove INDEX
import importlib.util, os, sys
spec = importlib.util.spec_from_file_location("keybinds", os.path.expanduser("~/.config/hypr/scripts/keybinds.py"))
kb = importlib.util.module_from_spec(spec); spec.loader.exec_module(kb)
binds = kb.load()
if sys.argv[1] == "add":
    name, cmd, keys = sys.argv[2].strip(), sys.argv[3].strip(), sys.argv[4].strip()
    if not (name and cmd and keys):
        print("name, command and keys are all needed"); sys.exit(2)
    if any(b["keys"] == keys for b in binds):
        print(keys + " is already used"); sys.exit(1)
    binds.append({"keys": keys, "action": "exec", "arg": cmd, "category": "Custom", "desc": name, "locked": False, "repeating": False})
elif sys.argv[1] == "remove":
    i = int(sys.argv[2])
    if not 0 <= i < len(binds):
        print("bad index"); sys.exit(2)
    binds.pop(i)
err = kb.apply(binds)
print(err or "ok"); sys.exit(1 if err else 0)
