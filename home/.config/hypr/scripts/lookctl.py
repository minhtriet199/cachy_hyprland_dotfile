#!/usr/bin/env python3
# Window look (Isla Settings → Windows): opacity, backdrop tint, borders, corner radius, gaps.
#   lookctl.py get                 → current values as JSON
#   lookctl.py set key=value ...   → save to ~/.local/state/hypr/look and apply live
# config/look.lua reads the same file at startup / reload.
import json, os, re, subprocess, sys

STATE = os.path.expanduser("~/.local/state/hypr/look")
DEFAULTS = {
    "active_opacity": "0.95", "inactive_opacity": "0.90",
    "border_size": "2", "rounding": "10", "gaps_in": "3", "gaps_out": "8",
    "active1": "82dccc", "active2": "007d6f", "inactive": "798bb2",
    "backdrop": "dark",
}
# what shows through see-through windows: dark = dimmed blur (light text stays readable), light = frosted
BACKDROP = {"dark": (0.5, 0.9), "light": (1.05, 0.8)}   # blur brightness, contrast
CHECK = {
    "active_opacity": (0.3, 1), "inactive_opacity": (0.3, 1),
    "border_size": (0, 8), "rounding": (0, 30), "gaps_in": (0, 30), "gaps_out": (0, 60),
}


def load():
    v = dict(DEFAULTS)
    try:
        for line in open(STATE):
            k, _, val = line.strip().partition("=")
            if k in v and val:
                v[k] = val
    except FileNotFoundError:
        pass
    return v


def lua(v):
    bb, bc = BACKDROP.get(v["backdrop"], BACKDROP["dark"])
    return ("hl.config({ decoration = { active_opacity = %s, inactive_opacity = %s, rounding = %d, "
            "blur = { brightness = %s, contrast = %s } }, "
            "general = { border_size = %d, gaps_in = %d, gaps_out = %d, col = { "
            "active_border = { colors = { \"rgba(%sff)\", \"rgba(%sff)\" }, angle = 45 }, "
            "inactive_border = \"rgba(%sff)\" } } })") % (
        float(v["active_opacity"]), float(v["inactive_opacity"]), int(float(v["rounding"])), bb, bc,
        int(float(v["border_size"])), int(float(v["gaps_in"])), int(float(v["gaps_out"])),
        v["active1"], v["active2"], v["inactive"])


def main():
    if len(sys.argv) < 2 or sys.argv[1] == "get":
        print(json.dumps(load()))
        return
    if sys.argv[1] != "set":
        sys.exit("usage: lookctl.py get | set key=value ...")
    v = load()
    for arg in sys.argv[2:]:
        k, _, val = arg.partition("=")
        if k not in DEFAULTS:
            continue
        if k in CHECK:
            lo, hi = CHECK[k]
            val = max(lo, min(hi, float(val)))
            val = str(round(val, 2)) if "opacity" in k else str(int(round(val)))
        elif k == "backdrop":
            if val not in BACKDROP:
                continue
        elif not re.fullmatch(r"[0-9a-fA-F]{6}", val):
            continue
        v[k] = val
    os.makedirs(os.path.dirname(STATE), exist_ok=True)
    with open(STATE + ".tmp", "w") as f:
        f.writelines(f"{k}={v[k]}\n" for k in DEFAULTS)
    os.replace(STATE + ".tmp", STATE)
    subprocess.run(["hyprctl", "eval", lua(v)], stdout=subprocess.DEVNULL)
    print(json.dumps(v))


if __name__ == "__main__":
    main()
