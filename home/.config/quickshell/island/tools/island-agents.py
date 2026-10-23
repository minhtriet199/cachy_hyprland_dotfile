#!/usr/bin/env python3
# Both Island helpers in one Python process (saves ~25 MB): the keyring prompter (keyring-prompter.py)
# and the Bluetooth pairing agent (bt-agent.py). Each message to Island gets "ch": "key" | "bt";
# Island's answers come back as "key <answer>" / "bt <answer>" (the rest is each helper's own protocol).
# If one helper can't start, the other still runs.
import importlib.util, json, os, sys
from gi.repository import GLib

here = os.path.dirname(os.path.abspath(__file__))
helpers = {}


def load(ch, filename):
    spec = importlib.util.spec_from_file_location(filename.replace("-", "_")[:-3], os.path.join(here, filename))
    mod = importlib.util.module_from_spec(spec)
    try:
        spec.loader.exec_module(mod)
        mod.emit = lambda d, ch=ch: print(json.dumps(dict(d, ch=ch)), flush=True)
        mod.start()
        helpers[ch] = mod
    except Exception as e:
        print(f"island-agents: {filename} not started: {e}", file=sys.stderr, flush=True)


def answer(src, cond):
    line = sys.stdin.readline()
    if not line:
        loop.quit()
        return False
    ch, _, rest = line.partition(" ")
    if ch in helpers:
        helpers[ch].handle(rest)
    return True


load("key", "keyring-prompter.py")
load("bt", "bt-agent.py")
if not helpers:
    sys.exit(1)
GLib.io_add_watch(sys.stdin, GLib.IO_IN | GLib.IO_HUP, answer)
loop = GLib.MainLoop()
loop.run()
