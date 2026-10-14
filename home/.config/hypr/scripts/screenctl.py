#!/usr/bin/env python3
# Screen Settings backend: brightness, HDR, resolution, refresh rate and scale for every screen.
# Screens are keyed by their EDID description, so a different monitor on the same port gets its
# own settings. HDR support and peak nits are read from each screen's EDID.
# State: ~/.local/state/hypr/screens, one line per screen, read by config/monitors.lua:
#   <description>\tmode=2560x1440@120 pos=0x0 scale=1 hdr=1 nits=250 ddc=56 out=HDMI-A-1 bus=5
#   External, HDR on : brightness = sdr_max_luminance (nits), applied via hyprctl reload
#   External, HDR off: brightness = monitor backlight over DDC/CI
#   Laptop (eDP)     : brightness = backlight via brightnessctl
# CLI (OUT = output name like HDMI-A-1):
#   screenctl.py list                      JSON of all screens + state + capabilities
#   screenctl.py set OUT PCT               brightness 0-100
#   screenctl.py hdr OUT on|off|toggle
#   screenctl.py mode OUT WxH@HZ SCALE     resolution / refresh / scale, re-lays out screens left to right
#   screenctl.py up|down|toggle [OUT]      for keybinds (default: focused external screen), notifies
import glob, json, os, re, subprocess, sys

STATE = os.path.expanduser("~/.local/state/hypr/screens")
NITS_MIN, NITS_DEFAULT_MAX, NITS_STEP, DDC_STEP = 80, 300, 25, 10


def run(*cmd):
    return subprocess.run(cmd, capture_output=True, text=True).stdout


# ---------- state ----------

def parse_val(v):
    try:
        return int(v)
    except ValueError:
        return v


def load():
    st = {}
    if os.path.exists(STATE):
        legacy = {}
        for line in open(STATE):
            line = line.rstrip("\n")
            if "\t" in line:
                key, rest = line.split("\t", 1)
            elif line.strip():  # old format keyed by output name: "HDMI-A-1 hdr=1 ..."
                key, rest = line.split(" ", 1)
                legacy[key] = rest
                continue
            else:
                continue
            st[key] = {k: parse_val(v) for k, v in (p.split("=", 1) for p in rest.split())}
        if legacy:
            for m in monitors():
                if m["name"] in legacy:
                    st[m["description"]] = {k: parse_val(v) for k, v in
                                            (p.split("=", 1) for p in legacy[m["name"]].split())}
                    st[m["description"]]["out"] = m["name"]
    return st


def save(st):
    os.makedirs(os.path.dirname(STATE), exist_ok=True)
    with open(STATE, "w") as f:
        for key, d in sorted(st.items()):
            f.write(key + "\t" + " ".join(f"{k}={v}" for k, v in d.items()) + "\n")


def entry(st, m):
    d = st.setdefault(m["description"], {})
    d.setdefault("hdr", 0); d.setdefault("nits", 200); d.setdefault("ddc", 50)
    if d.get("out") != m["name"]:  # moved to another port: DDC bus must be re-detected
        d.pop("bus", None)
        d["out"] = m["name"]
    return d


# ---------- monitors / EDID ----------

def monitors():
    return json.loads(run("hyprctl", "monitors", "-j") or "[]")


def monitors_all():
    # includes disabled outputs, so a screen turned off ("Only screen X") is still listed
    return json.loads(run("hyprctl", "monitors", "all", "-j") or "[]")


def find(out):
    return next((m for m in monitors() if m["name"] == out), None)


def is_internal(out):
    return out.startswith("eDP")


def edid_hdr(out):
    """(supports HDR10, peak nits or None) from the CTA-861 HDR static metadata block."""
    for path in glob.glob(f"/sys/class/drm/card*-{out}/edid"):
        try:
            e = open(path, "rb").read()
        except OSError:
            continue
        for blk in range(1, len(e) // 128):
            b = e[blk * 128:(blk + 1) * 128]
            if b[0] != 0x02:  # CTA extension
                continue
            i, end = 4, b[2]
            while i < end:
                tag, ln = b[i] >> 5, b[i] & 31
                if tag == 7 and ln >= 3 and b[i + 1] == 6:  # extended tag 6: HDR static metadata
                    pq = bool(b[i + 2] & 0b100)  # SMPTE ST2084
                    nits = round(50 * 2 ** (b[i + 4] / 32)) if ln >= 4 and b[i + 4] else None
                    return pq, nits
                i += ln + 1
    return False, None


def edid_native(out):
    """Native resolution from the EDID's first detailed timing (the preferred mode)."""
    for path in glob.glob(f"/sys/class/drm/card*-{out}/edid"):
        try:
            b = open(path, "rb").read()[54:72]
        except OSError:
            continue
        if len(b) == 18 and (b[0] or b[1]):
            return [b[2] + ((b[4] & 0xF0) << 4), b[5] + ((b[7] & 0xF0) << 4)]
    return None


def detect_buses(st):
    # DRM connector (card1-HDMI-A-1) -> i2c bus, for every display ddcutil can talk to
    mons = {m["name"]: m for m in monitors()}
    block = {}
    for line in run("ddcutil", "detect", "--brief").splitlines() + [""]:
        if m := re.search(r"/dev/i2c-(\d+)", line):
            block["bus"] = int(m.group(1))
        elif m := re.search(r"DRM connector:\s+card\d+-(\S+)", line):
            block["out"] = m.group(1)
        elif not line.strip():
            out = block.get("out")
            if "bus" in block and out in mons and not is_internal(out):
                entry(st, mons[out])["bus"] = block["bus"]
            block = {}


def bus(st, m):
    d = entry(st, m)
    if "bus" not in d:
        detect_buses(st)
    return d.get("bus")


def ddc_get(st, m):
    b = bus(st, m)
    if b is None:
        return None
    f = run("ddcutil", "--bus", str(b), "--terse", "getvcp", "10").split()
    if len(f) >= 5 and f[3].isdigit():
        return round(int(f[3]) * 100 / max(int(f[4]), 1))
    return None


def backlight_get():
    f = run("brightnessctl", "-m", "-c", "backlight").strip().split(",")
    return int(f[3].rstrip("%")) if len(f) >= 4 else 100


def nits_max(m):
    return edid_hdr(m["name"])[1] or NITS_DEFAULT_MAX


def nits_to_pct(nits, top):
    return max(0, min(100, round((nits - NITS_MIN) * 100 / max(top - NITS_MIN, 1))))


def pct_to_nits(pct, top):
    return NITS_MIN + pct * (top - NITS_MIN) // 100


def modes(m):
    """[{w, h, rates:[hz,...]}] largest first, rates highest first."""
    res = {}
    for s in m.get("availableModes", []):
        if mt := re.match(r"(\d+)x(\d+)@([\d.]+)Hz", s):
            w, h, hz = int(mt.group(1)), int(mt.group(2)), round(float(mt.group(3)), 2)
            res.setdefault((w, h), set()).add(hz)
    return [{"w": w, "h": h, "rates": sorted(r, reverse=True)}
            for (w, h), r in sorted(res.items(), key=lambda kv: kv[0][0] * kv[0][1], reverse=True)]


def reload():
    run("hyprctl", "reload")


# ---------- SAFE live apply (hyprctl eval; nothing saved to disk) ----------
# Rotation / mirror / disable are applied LIVE only and are NEVER written to the state file,
# so a crash can't persist a bad config and a reboot always returns to the known-good layout.

def _lua_str(v):
    return '"' + str(v).replace("\\", "\\\\").replace('"', '\\"') + '"'


def mon_lua(out, d, st_entry):
    """Build an hl.monitor({...}) call for one output. d: mode,pos,scale,transform,mirror,off."""
    if d.get("off"):
        return 'hl.monitor({output=%s, disabled=true})' % _lua_str(out)
    parts = ['output=%s' % _lua_str(out),
             'mode=%s' % _lua_str(d.get("mode") or "preferred"),
             'position=%s' % _lua_str(d.get("pos") or "auto"),
             'scale=%s' % (d.get("scale") or "1")]
    t = int(d.get("transform") or 0)
    if t:
        parts.append('transform=%d' % (t % 4))
    if d.get("mirror"):
        parts.append('mirror=%s' % _lua_str(d["mirror"]))
    # keep HDR if this screen has it on (so rotating/arranging doesn't drop HDR)
    if st_entry and st_entry.get("hdr") == 1:
        parts += ['bitdepth=10', 'cm="hdr"', 'sdr_max_luminance=%d' % int(st_entry.get("nits") or 200)]
    return 'hl.monitor({%s})' % ', '.join(parts)


def apply_live(st, desired):
    """desired: {output: {mode,pos,scale,transform,mirror,off}} -> apply each via hyprctl eval."""
    by_desc = {m["description"]: entry(st, m) for m in monitors_all()}
    out_to_desc = {m["name"]: m["description"] for m in monitors_all()}
    for out, d in desired.items():
        se = by_desc.get(out_to_desc.get(out, ""), {})
        run("hyprctl", "eval", mon_lua(out, d, se))


def restore_live(st):
    """Revert live to the saved-good base: every screen on, no mirror, no rotation."""
    desired = {}
    for m in monitors_all():
        e = entry(st, m)
        desired[m["name"]] = {"mode": e.get("mode"), "pos": e.get("pos"),
                              "scale": e.get("scale"), "transform": 0, "mirror": "", "off": 0}
    apply_live(st, desired)


# ---------- actions ----------

def info(st, m):
    out = m["name"]
    internal = is_internal(out)
    hdr_ok, peak = edid_hdr(out)
    d = entry(st, m)
    top = peak or NITS_DEFAULT_MAX
    if internal:
        pct, ddc_ok = backlight_get(), True
    elif d["hdr"]:
        pct, ddc_ok = nits_to_pct(d["nits"], top), True
    else:
        live = ddc_get(st, m)
        if live is not None:
            d["ddc"] = live
        pct, ddc_ok = d["ddc"], d.get("bus") is not None
    return {"output": out, "key": m["description"], "name": f'{m["make"]} {m["model"]}'.strip(),
            "model": "Laptop screen" if internal else (m["model"] or out), "internal": internal,
            "x": m["x"], "y": m["y"], "width": m["width"], "height": m["height"],
            "refresh": round(m["refreshRate"], 2), "scale": m["scale"], "transform": m["transform"],
            "modes": modes(m), "native": edid_native(out), "hdr_supported": hdr_ok, "nits_max": top, "hdr": bool(d["hdr"]),
            "nits": d["nits"], "pct": pct, "ddc": ddc_ok, "focused": m["focused"],
            "mirror": "" if m.get("mirrorOf", "none") in ("none", "", None) else m["mirrorOf"],
            "off": bool(m.get("disabled"))}


def set_pct(st, m, pct):
    pct = max(0, min(100, int(pct)))
    if is_internal(m["name"]):
        run("brightnessctl", "-q", "-c", "backlight", "set", f"{max(pct, 1)}%")  # never fully black
        return pct
    d = entry(st, m)
    if d["hdr"]:
        d["nits"] = pct_to_nits(pct, nits_max(m))
        save(st); reload()
    else:
        b = bus(st, m)
        if b is not None:
            run("ddcutil", "--bus", str(b), "--noverify", "setvcp", "10", str(pct))
        d["ddc"] = pct
        save(st)
    return pct


def set_hdr(st, m, mode):
    d = entry(st, m)
    if not edid_hdr(m["name"])[0]:
        d["hdr"] = 0
    else:
        d["hdr"] = (1 - d["hdr"]) if mode == "toggle" else int(mode == "on")
    save(st); reload()
    return d["hdr"]


def fmt_hz(hz):
    hz = float(hz)
    return str(int(hz)) if hz == int(hz) else f"{hz:.2f}"


def set_mode(st, m, mode, scale):
    d = entry(st, m)
    w, h, hz = re.match(r"(\d+)x(\d+)@([\d.]+)", mode).groups()
    d["mode"] = f"{w}x{h}@{fmt_hz(hz)}"
    d["scale"] = f"{float(scale):g}"
    # lay screens out left to right in their current order, using the new size for this one
    x = 0
    for mon in sorted(monitors(), key=lambda mo: mo["x"]):
        e = entry(st, mon)
        if mon["name"] == m["name"]:
            lw, lh, sc = int(w), int(h), float(scale)
        else:
            lw, lh, sc = mon["width"], mon["height"], mon["scale"]
            e.setdefault("mode", f'{lw}x{lh}@{fmt_hz(round(mon["refreshRate"], 2))}')
            e.setdefault("scale", f"{sc:g}")
        if mon["transform"] % 2:  # rotated 90/270
            lw, lh = lh, lw
        e["pos"] = f"{x}x0"
        x += round(lw / sc)
    save(st); reload()


def notify(value, title, body):
    run("notify-send", "-a", "Monitor", "-h", "string:x-canonical-private-synchronous:screenctl",
        "-h", f"int:value:{value}", title, body)


def target(args):
    mons = monitors()
    if args:
        return next((m for m in mons if m["name"] == args[0]), None)
    ext = [m for m in mons if not is_internal(m["name"])]
    return next((m for m in ext if m["focused"]), ext[0] if ext else None)


def main(argv):
    st = load()
    cmd, args = (argv[0] if argv else ""), argv[1:]
    if cmd == "list":
        mons = sorted(monitors_all(), key=lambda m: (is_internal(m["name"]), m["x"], m["y"]))
        print(json.dumps([info(st, m) for m in mons]))
        save(st)
    elif cmd in ("set", "hdr", "mode") and len(args) >= 2:
        m = find(args[0])
        if not m:
            sys.exit(f"no screen {args[0]}")
        if cmd == "set":
            set_pct(st, m, args[1])
        elif cmd == "hdr":
            set_hdr(st, m, args[1])
        else:
            set_mode(st, m, args[1], args[2] if len(args) > 2 else m["scale"])
    elif cmd in ("up", "down", "toggle"):
        m = target(args)
        if not m:
            notify(0, "Screen Settings", "No external screen"); return
        label = m["model"] or m["name"]
        if cmd == "toggle":
            if not edid_hdr(m["name"])[0]:
                notify(0, label, "HDR is not supported by this screen"); return
            on = set_hdr(st, m, "toggle")
            notify(100 if on else 0, f"{label} HDR {'on' if on else 'off'}", "")
            return
        cur = info(st, m)
        sign = 1 if cmd == "up" else -1
        if cur["hdr"] and not cur["internal"]:
            d, top = entry(st, m), cur["nits_max"]
            d["nits"] = max(NITS_MIN, min(top, d["nits"] + sign * NITS_STEP))
            save(st); reload()
            notify(nits_to_pct(d["nits"], top), f"{label} HDR", f'Brightness {d["nits"]} nits')
        else:
            pct = set_pct(st, m, cur["pct"] + sign * DDC_STEP)
            notify(pct, f"{label} brightness", f"{pct}%")
    elif cmd == "live":
        apply_live(st, json.load(sys.stdin))      # live only, nothing saved
    elif cmd == "restore":
        restore_live(st)                          # revert live to the known-good base
    else:
        print("usage: screenctl.py list | set OUT PCT | hdr OUT on|off|toggle | mode OUT WxH@HZ SCALE"
              " | live (JSON on stdin) | restore | up|down|toggle [OUT]", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main(sys.argv[1:])
