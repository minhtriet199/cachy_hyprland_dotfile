#!/usr/bin/env python3
# Privacy page: which apps are using the microphone, camera or screen right now.
#   inuse.py → {"mic": [names], "camera": [names], "screen": [names]}
# Mic = recording streams from a real input (not a speaker "monitor", e.g. the bar's visualizer);
# camera = processes holding /dev/video*; screen = PipeWire video capture streams (screen sharing).
import glob, json, os, subprocess


def sh(*cmd):
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=5).stdout
    except Exception:
        return ""


def nice(props):
    return props.get("application.name") or props.get("application.process.binary") or props.get("node.name") or "an app"


mic, screen, camera = set(), set(), set()
try:
    objs = json.loads(sh("pw-dump") or "[]")
except ValueError:
    objs = []
props = {o["id"]: ((o.get("info") or {}).get("props") or {}) for o in objs if o.get("type", "").endswith(":Node")}
for o in objs:
    if not o.get("type", "").endswith(":Link"):
        continue
    i = o.get("info") or {}
    src, dst = props.get(i.get("output-node-id"), {}), props.get(i.get("input-node-id"), {})
    if dst.get("media.class") == "Stream/Input/Audio" and src.get("media.class", "").startswith("Audio/Source"):
        mic.add(nice(dst))
for p in props.values():
    if p.get("media.class") == "Stream/Input/Video":
        screen.add(nice(p))
for dev in glob.glob("/dev/video*"):
    try:
        real = os.path.realpath(dev)
        for fd in glob.glob("/proc/[0-9]*/fd/*"):
            try:
                if os.readlink(fd) == real:
                    camera.add(open(fd.split("/fd/")[0] + "/comm").read().strip())
            except OSError:
                pass
    except OSError:
        pass
print(json.dumps({"mic": sorted(mic), "camera": sorted(camera), "screen": sorted(screen)}))
