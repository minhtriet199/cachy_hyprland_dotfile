#!/usr/bin/env python3
"""Lid closed with another screen ("Screen off" / "Lock"): every laptop workspace that has windows moves to its own
new workspace on the other screen (focus stays where you are), then the laptop screen is switched off as a monitor —
live only through screenctl (never saved, so a reboot always brings it back).
  lid-move.py off LAPTOP OTHER   move + switch off
  lid-move.py on                 every screen back on (screenctl restore)
  lid-move.py fix                lid open but the laptop screen is off (Island restarted / crashed) → on"""
import json, subprocess, sys

SCREENCTL = "/home/gamer/.config/hypr/scripts/screenctl.py"


def hy(*a):
    return json.loads(subprocess.run(["hyprctl", "-j", *a], capture_output=True, text=True).stdout or "[]")


def dispatch(lua):
    subprocess.run(["hyprctl", "dispatch", lua], capture_output=True)


def base(name):          # first workspace id - 1 on that screen (scripts/ws.sh: laptop 11-19, others 1-9)
    return 10 if name.startswith("eDP") else 0


def off(laptop, other):
    wss = hy("workspaces")
    lap_ws = sorted(w["id"] for w in wss if w["monitor"] == laptop and w["windows"] > 0 and w["id"] > 0)
    used = {w["id"] for w in wss}
    b = base(other)
    top = max([u for u in used if b < u <= b + 9] or [b])
    free = list(range(top + 1, b + 10)) + [i for i in range(b + 1, top) if i not in used]   # after your last one, then gaps
    clients = hy("clients")
    for ws in lap_ws:
        if not free:
            break
        target = free.pop(0)
        for c in clients:
            if c["workspace"]["id"] == ws:
                dispatch('hl.dsp.window.move({ workspace = %d, window = "address:%s", follow = false })' % (target, c["address"]))
    subprocess.run(["python3", SCREENCTL, "live"], input=json.dumps({laptop: {"off": 1}}), text=True)
    # the keyboard was on the laptop screen (e.g. a game there): give it to what's showing on the other screen
    if not hy("activewindow").get("address"):
        dispatch('hl.dsp.focus({ monitor = "%s" })' % other)
        win = [c for c in hy("clients") if c["workspace"]["id"] == next((m["activeWorkspace"]["id"] for m in hy("monitors") if m["name"] == other), -1)]
        if win:
            dispatch('hl.dsp.focus({ window = "address:%s" })' % sorted(win, key=lambda c: c["focusHistoryID"])[0]["address"])


def laptop_off():
    on = {m["name"] for m in hy("monitors")}
    every = hy("monitors", "all")
    return [m["name"] for m in every if m["name"].startswith("eDP") and m["name"] not in on]


cmd = sys.argv[1] if len(sys.argv) > 1 else ""
if cmd == "off" and len(sys.argv) == 4:
    off(sys.argv[2], sys.argv[3])
elif cmd == "on":
    subprocess.run(["python3", SCREENCTL, "restore"])
elif cmd == "fix":
    if laptop_off():
        subprocess.run(["python3", SCREENCTL, "restore"])
        print("restored")
else:
    print(__doc__, file=sys.stderr)
    sys.exit(2)
