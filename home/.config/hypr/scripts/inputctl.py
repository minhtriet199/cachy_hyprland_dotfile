#!/usr/bin/env python3
# Mouse, touchpad, keyboard layout, cursor and text size (Island Settings → Mouse & touchpad / Time & language).
#   inputctl.py get                 → current values as JSON
#   inputctl.py set key=value ...   → save to ~/.local/state/hypr/input and apply live
# config/input_island.lua reads the same file at startup / reload.
import json, os, re, subprocess, sys

STATE = os.path.expanduser("~/.local/state/hypr/input")
DEFAULTS = {
    "kb_layout": "us", "kb_options": "",
    "sensitivity": "0", "accel": "flat",
    "natural_scroll": "0", "tap_to_click": "1", "dwt": "1", "tp_scroll": "1",
    "cursor_size": "24", "text_scale": "1",
}
NUM = {"sensitivity": (-1, 1), "tp_scroll": (0.2, 3), "cursor_size": (16, 64), "text_scale": (0.8, 1.6)}
BOOL = ("natural_scroll", "tap_to_click", "dwt")
CURSOR_THEME = os.environ.get("XCURSOR_THEME") or "Bibata-Modern-Ice"


def load():
    v = dict(DEFAULTS)
    try:
        for line in open(STATE):
            k, _, val = line.rstrip("\n").partition("=")
            if k in v:
                v[k] = val
    except FileNotFoundError:
        pass
    return v


def lua(v):
    b = lambda k: "true" if v[k] == "1" else "false"
    s = lambda x: '"' + x.replace("\\", "").replace('"', "") + '"'
    return ("hl.config({ input = { kb_layout = %s, kb_options = %s, sensitivity = %s, accel_profile = %s, "
            "touchpad = { natural_scroll = %s, tap_to_click = %s, disable_while_typing = %s, scroll_factor = %s } } })") % (
        s(v["kb_layout"]), s(v["kb_options"]), float(v["sensitivity"]), s(v["accel"]),
        b("natural_scroll"), b("tap_to_click"), b("dwt"), float(v["tp_scroll"]))


def main():
    if len(sys.argv) < 2 or sys.argv[1] == "get":
        print(json.dumps(load()))
        return
    if sys.argv[1] != "set":
        sys.exit("usage: inputctl.py get | set key=value ...")
    v, old = load(), load()
    for arg in sys.argv[2:]:
        k, _, val = arg.partition("=")
        if k not in DEFAULTS:
            continue
        if k in NUM:
            lo, hi = NUM[k]
            val = max(lo, min(hi, float(val)))
            val = str(int(round(val))) if k == "cursor_size" else str(round(val, 2))
        elif k in BOOL:
            val = "1" if val in ("1", "true", "on") else "0"
        elif k == "accel":
            val = "adaptive" if val == "adaptive" else "flat"
        elif k == "kb_layout":
            if not re.fullmatch(r"[a-z]{2,3}(\([a-z0-9_-]+\))?(,[a-z]{2,3}(\([a-z0-9_-]+\))?)*", val):
                continue
        elif k == "kb_options":
            if not re.fullmatch(r"[a-z0-9_:,]*", val):
                continue
        v[k] = val
    # Live first: if Hyprland rejects the Lua, nothing is saved and the next login stays on the old values
    r = subprocess.run(["hyprctl", "eval", lua(v)], capture_output=True, text=True)
    if r.returncode:
        subprocess.run(["hyprctl", "eval", lua(load())], stdout=subprocess.DEVNULL)
        subprocess.run(["notify-send", "-a", "Island", "Setting not saved", r.stdout.strip()[:200]])
        sys.exit("%s: Hyprland rejected the change, nothing saved:\n%s" % (os.path.basename(__file__), r.stdout.strip()))
    os.makedirs(os.path.dirname(STATE), exist_ok=True)
    with open(STATE + ".tmp", "w") as f:
        f.writelines(f"{k}={v[k]}\n" for k in DEFAULTS)
    os.replace(STATE + ".tmp", STATE)
    if v["cursor_size"] != old["cursor_size"]:
        subprocess.run(["hyprctl", "setcursor", CURSOR_THEME, v["cursor_size"]], stdout=subprocess.DEVNULL)
        subprocess.run(["gsettings", "set", "org.gnome.desktop.interface", "cursor-size", v["cursor_size"]])
    if v["text_scale"] != old["text_scale"]:
        subprocess.run(["gsettings", "set", "org.gnome.desktop.interface", "text-scaling-factor", v["text_scale"]])
    print(json.dumps(v))


if __name__ == "__main__":
    main()
