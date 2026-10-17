#!/usr/bin/env python3
# Isla → Keyboard page: change one shortcut's keys.
#   setbind.py INDEX "SUPER + SHIFT + W"
# Uses the Keyboard Shortcuts app's own apply(): writes binds.lua, reloads Hyprland,
# rolls back if Hyprland reports a config error, and only then saves keybinds.json.
import importlib.util, os, sys

path = os.path.expanduser("~/.config/hypr/scripts/keybinds.py")
spec = importlib.util.spec_from_file_location("keybinds", path)
kb = importlib.util.module_from_spec(spec)
spec.loader.exec_module(kb)

i, keys = int(sys.argv[1]), sys.argv[2].strip()
binds = kb.load()
if not 0 <= i < len(binds) or not keys:
    print("bad index or keys"); sys.exit(2)
binds[i]["keys"] = keys
err = kb.apply(binds)
print(err or "ok")
sys.exit(1 if err else 0)
