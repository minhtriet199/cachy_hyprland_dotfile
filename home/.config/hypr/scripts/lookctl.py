#!/usr/bin/env python3
# Window look (Island Settings → Windows): opacity, backdrop, borders, corners, gaps, blur, shadow, dim, animations.
#   lookctl.py get                 → current values as JSON
#   lookctl.py set key=value ...   → apply live; saved only if Hyprland accepts it
#   lookctl.py apply               → apply the saved values again (Island turning Game mode off)
# Saved twice: ~/.local/state/hypr/look (key=value, for get) and look.lua next to it — the exact Lua that was applied
# live, which config/look.lua loads at startup / reload (so login can never differ from what you saw).
import json, os, re, subprocess, sys

STATE = os.path.expanduser("~/.local/state/hypr/look")
GAMEMODE = "~/.local/state/hypr/gamemode"       # Island Game mode: animations stay off while it exists
DEFAULTS = {
    "active_opacity": "0.95", "inactive_opacity": "0.90", "backdrop": "dark",
    "border_size": "2", "rounding": "10", "gaps_in": "3", "gaps_out": "8",
    "active1": "82dccc", "active2": "007d6f", "inactive": "798bb2", "border_spin": "0",
    "blur": "1", "blur_size": "5", "blur_passes": "4", "shadow": "1", "shadow_range": "4",
    "dim": "0", "dim_strength": "0.2",
    "anim": "1", "anim_speed": "normal", "anim_feel": "springy", "win_style": "slide", "ws_style": "slide",
}
CHECK = {
    "active_opacity": (0.3, 1), "inactive_opacity": (0.3, 1), "dim_strength": (0.05, 0.6),
    "border_size": (0, 8), "rounding": (0, 30), "gaps_in": (0, 30), "gaps_out": (0, 60),
    "blur_size": (1, 20), "blur_passes": (1, 6), "shadow_range": (0, 40),
}
BOOL = {"blur", "shadow", "dim", "anim", "border_spin"}
HEX = {"active1", "active2", "inactive"}
CHOICE = {
    "backdrop": ("dark", "light"),
    "anim_speed": ("slow", "normal", "fast"),
    "anim_feel": ("snappy", "smooth", "bouncy", "springy"),
    "win_style": ("slide", "popin", "gnomed"),
    "ws_style": ("slide", "slidevert", "fade", "slidefade"),
}
TINT = {"dark": (0.5, 0.9), "light": (1.05, 0.8)}           # blur brightness / contrast behind see-through windows
SPEED = {"slow": 1.6, "normal": 1.0, "fast": 0.6}           # × animation time
# four clearly different feels (the Island preview uses the same curves): fast start · slow start and end ·
# overshoot and settle back · wobble
FEEL = {"snappy": 'bezier = "quick"', "smooth": 'bezier = "easeInOutCubic"',
        "bouncy": 'bezier = "islandBounce"', "springy": 'spring = "rubber"'}
WS_FEEL = {"snappy": "quick", "smooth": "easeInOutCubic", "bouncy": "islandBounce", "springy": "islandBounce"}   # workspaces: no spring
WIN_STYLE = {"slide": "slide", "popin": "popin 80%", "gnomed": "gnomed"}
WS_STYLE = {"slide": "slide", "slidevert": "slidevert", "fade": "fade", "slidefade": "slidefade 20%"}


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


def clean(k, val):
    """Valid value for key k, or None."""
    if k in CHECK:
        lo, hi = CHECK[k]
        val = max(lo, min(hi, float(val)))
        return str(round(val, 2)) if "opacity" in k or k == "dim_strength" else str(int(round(val)))
    if k in BOOL:
        return "1" if val in ("1", "true", "on") else "0"
    if k in HEX:
        return val if re.fullmatch(r"[0-9a-fA-F]{6}", val) else None
    return val if val in CHOICE.get(k, ()) else None


def lua(v):
    on = lambda k: v[k] == "1"
    t = TINT[v["backdrop"]]
    sp = SPEED[v["anim_speed"]]
    feel = FEEL[v["anim_feel"]]
    out = [
        'local gm = io.open(os.getenv("HOME") .. "/%s")' % GAMEMODE[2:],
        "if gm then gm:close() end",
        # the curves used below (same as config/animations.lua), so this file works on its own
        'hl.curve("quick", { type = "bezier", points = { {0.15, 0}, {0.1, 1} } })',
        'hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1} } })',
        'hl.curve("islandBounce", { type = "bezier", points = { {0.34, 1.56}, {0.64, 1} } })',
        'hl.curve("rubber", { type = "spring", mass = 1, stiffness = 200, dampening = 15 })',
        'hl.curve("linear", { type = "bezier", points = { {0, 0}, {1, 1} } })',
        "hl.config({ decoration = { active_opacity = %s, inactive_opacity = %s, rounding = %d," % (
            float(v["active_opacity"]), float(v["inactive_opacity"]), int(v["rounding"])),
        "    blur = { enabled = %s, size = %d, passes = %d, brightness = %s, contrast = %s }," % (
            str(on("blur")).lower(), int(v["blur_size"]), int(v["blur_passes"]), t[0], t[1]),
        "    shadow = { enabled = %s, range = %d }," % (str(on("shadow")).lower(), int(v["shadow_range"])),
        "    dim_inactive = %s, dim_strength = %s }," % (str(on("dim")).lower(), float(v["dim_strength"])),
        "  general = { border_size = %d, gaps_in = %d, gaps_out = %d, col = {" % (
            int(v["border_size"]), int(v["gaps_in"]), int(v["gaps_out"])),
        '    active_border = { colors = { "rgba(%sff)", "rgba(%sff)" }, angle = 45 }, inactive_border = "rgba(%sff)" } },' % (
            v["active1"], v["active2"], v["inactive"]),
        "  animations = { enabled = %s and not gm } })" % str(on("anim")).lower(),
        'hl.animation({ leaf = "global", enabled = true, speed = %s, bezier = "quick" })' % round(3 * sp, 2),
        'hl.animation({ leaf = "windows", enabled = true, speed = %s, %s, style = "%s" })' % (round(3 * sp, 2), feel, WIN_STYLE[v["win_style"]]),
        'hl.animation({ leaf = "workspaces", enabled = true, speed = %s, bezier = "%s", style = "%s" })' % (round(5 * sp, 2), WS_FEEL[v["anim_feel"]], WS_STYLE[v["ws_style"]]),
        # spinning border: the two-colour gradient turns slowly around focused windows
        'hl.animation({ leaf = "borderangle", enabled = %s, speed = 60, bezier = "linear"%s })' % (
            str(on("border_spin")).lower(), ', style = "loop"' if on("border_spin") else ""),
    ]
    return "\n".join(out)


def main():
    if len(sys.argv) < 2 or sys.argv[1] == "get":
        print(json.dumps(load()))
        return
    if sys.argv[1] not in ("set", "apply"):
        sys.exit("usage: lookctl.py get | set key=value ... | apply")
    v = load()
    for arg in sys.argv[2:]:
        k, _, val = arg.partition("=")
        if k in DEFAULTS and (val := clean(k, val)) is not None:
            v[k] = val
    # Live first: if Hyprland rejects the Lua, nothing is saved and the next login stays on the old values
    code = lua(v)
    r = subprocess.run(["hyprctl", "eval", code], capture_output=True, text=True)
    if r.returncode:
        subprocess.run(["hyprctl", "eval", lua(load())], stdout=subprocess.DEVNULL)
        subprocess.run(["notify-send", "-a", "Island", "Setting not saved", r.stdout.strip()[:200]])
        sys.exit("%s: Hyprland rejected the change, nothing saved:\n%s" % (os.path.basename(__file__), r.stdout.strip()))
    os.makedirs(os.path.dirname(STATE), exist_ok=True)
    for path, text in ((STATE, "".join(f"{k}={v[k]}\n" for k in DEFAULTS)), (STATE + ".lua", code + "\n")):
        with open(path + ".tmp", "w") as f:
            f.write(text)
        os.replace(path + ".tmp", path)
    print(json.dumps(v))


if __name__ == "__main__":
    main()
