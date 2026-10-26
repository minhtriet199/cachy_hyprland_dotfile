#!/usr/bin/env python3
# Renders the Jake lock-screen picture sharp at any size from JakeShapes.js (same shapes the "Jake" transition draws).
#   jake-wallpaper.py OUT.png [WIDTH HEIGHT]      default 2560 x 1440 (2K)
# The face keeps its place and size relative to the original 1301 x 808 picture (centred, 140/1301 of the width).
import os, re, subprocess, sys, tempfile
src = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "JakeShapes.js")).read()
def var(name):
    return re.search(r"^var %s = (.+?)(?:\s*//.*)?$" % name, src, re.M).group(1).strip()
def obj(name):
    return {k: float(v) for k, v in re.findall(r"(\w+): (-?[\d.]+)", var(name))}
def circle(cx, cy, r):
    return "M %g %g a %g %g 0 1 0 %g 0 a %g %g 0 1 0 %g 0 Z" % (cx - r, cy, r, r, 2 * r, r, r, -2 * r)
out = sys.argv[1]; W, H = (int(sys.argv[2]), int(sys.argv[3])) if len(sys.argv) > 3 else (2560, 1440)
box = obj("box"); bg, ink = var("bg").strip('"'), var("ink").strip('"')
k = W / box["srcW"]                                            # picture px per box unit
x0 = (box["srcX"] - box["srcW"] / 2) * k + W / 2               # box placed like in the original, centred
y0 = (box["srcY"] - 808 / 2) * k + H / 2
eyes = ""
for e in (obj("eyeL"), obj("eyeR")):
    eyes += '<path d="%s" fill="%s"/>' % (circle(e["cx"] + e["sx"], e["cy"] + e["sy"], e["r"] + 1.5), ink)
    eyes += '<path d="%s" fill="#FFFFFF" stroke="%s" stroke-width="%s"/>' % (circle(e["cx"], e["cy"], e["r"]), ink, var("line"))
nose = re.search(r'ellipse\(([\d.]+), ([\d.]+), ([\d.]+), ([\d.]+)\)', var("nose")).groups()
svg = ('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d"><rect width="100%%" height="100%%" fill="%s"/>'
       '<g transform="translate(%g %g) scale(%g)">%s'
       '<path d="%s" fill="%s" stroke="%s" stroke-width="%s" stroke-linejoin="round"/>'
       '<path d="%s" stroke="%s" stroke-width="%s" stroke-linecap="round" fill="none"/>'
       '<ellipse cx="%s" cy="%s" rx="%s" ry="%s" fill="%s"/></g></svg>') % (
    W, H, bg, x0, y0, k, eyes, var("muzzle").strip('"'), var("fur").strip('"'), ink, var("line"), var("mouth").strip('"'), ink, var("line"), *nose, ink)
with tempfile.NamedTemporaryFile("w", suffix=".svg", delete=False) as f:
    f.write(svg)
subprocess.run(["rsvg-convert", "-o", out, f.name], check=True)
os.unlink(f.name)
