#!/usr/bin/env python3
# Time & language page: prints one JSON with the clock, time zone, region format and typing setup.
#   timelang.py           → {ntp, tz, zones[], lang, region, regions[], ims[], trigger, share}
#   timelang.py share All|No → same EN/VI in every window or per window
#   timelang.py autotz    → the time zone of this internet connection (ipapi.co), "" if offline
import json, os, re, subprocess, sys, urllib.request


def put(path, text):
    """Rewrite a file other apps own: skip if unchanged, keep the previous copy as <file>.bak-island, temp + rename."""
    old = open(path).read() if os.path.exists(path) else None
    if old == text:
        return
    if old is not None:
        with open(path + ".bak-island", "w") as f:
            f.write(old)
    with open(path + ".tmp", "w") as f:
        f.write(text)
    os.replace(path + ".tmp", path)

def sh(*cmd):
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=8).stdout
    except Exception:
        return ""


def ini(path):
    d, sec = {}, ""
    try:
        for line in open(os.path.expanduser(path)):
            line = line.strip()
            if line.startswith("["):
                sec = line.strip("[]")
            elif "=" in line and not line.startswith("#"):
                k, _, v = line.partition("=")
                d.setdefault(sec, {})[k.strip()] = v.strip()
    except FileNotFoundError:
        pass
    return d


# timelang.py share All|No → same EN/VI state in every window (fcitx5 ShareInputState), reloads fcitx5
if len(sys.argv) > 2 and sys.argv[1] == "share":
    path, val = os.path.expanduser("~/.config/fcitx5/config"), ("All" if sys.argv[2] == "All" else "No")
    text = open(path).read() if os.path.exists(path) else ""
    if re.search(r"^ShareInputState=.*$", text, re.M):
        text = re.sub(r"^ShareInputState=.*$", "ShareInputState=" + val, text, flags=re.M)
    elif "[Behavior]" in text:
        text = text.replace("[Behavior]", "[Behavior]\nShareInputState=" + val, 1)
    else:
        text += "\n[Behavior]\nShareInputState=" + val + "\n"
    put(path, text)
    sh("fcitx5-remote", "-r")
    sys.exit()

if len(sys.argv) > 1 and sys.argv[1] == "autotz":
    try:
        print(urllib.request.urlopen("https://ipapi.co/timezone", timeout=8).read().decode().strip())
    except Exception:
        print("")
    sys.exit()

loc = dict(l.strip().split("=", 1) for l in sh("localectl", "status").splitlines()
           if "=" in l for l in [l.split(":", 1)[-1] if l.strip().startswith("System Locale") else l])
regions = sorted({re.sub(r"\.utf-?8$", "", l, flags=re.I) for l in sh("locale", "-a").split()
                  if l not in ("C", "POSIX") and not l.startswith("C.")})
prof = ini("~/.config/fcitx5/profile")
ims = [v["Name"] for k, v in sorted(prof.items()) if re.fullmatch(r"Groups/0/Items/\d+", k) and "Name" in v]
cfg = ini("~/.config/fcitx5/config")
trig = cfg.get("Hotkey/TriggerKeys", {}).get("0", "Control+space")
print(json.dumps({
    "ntp": sh("timedatectl", "show", "-p", "NTP", "--value").strip() == "yes",
    "synced": sh("timedatectl", "show", "-p", "NTPSynchronized", "--value").strip() == "yes",
    "tz": sh("timedatectl", "show", "-p", "Timezone", "--value").strip(),
    "zones": sh("timedatectl", "list-timezones").split(),
    "lang": loc.get("LANG", ""),
    "region": loc.get("LC_TIME", loc.get("LANG", "")),
    "locale": loc,
    "regions": regions,
    "ims": ims,
    "trigger": trig,
    "share": cfg.get("Behavior", {}).get("ShareInputState", "No"),
}))
