#!/usr/bin/env python3
# System page: storage and updates.
#   storage.py disks    → {"disks": [{mount, size, used, free, pct}], "pkgCache": bytes, "userCache": bytes, "lastUpdate": "…"}
#   storage.py updates  → {"repo": [{name, old, new}], "aur": [...], "error": ""}   (only when you press Check — no background service)
import json, os, re, subprocess, sys


def sh(*cmd, timeout=10):
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        return r.stdout, r.returncode
    except Exception as e:
        return "", -1


def du(path):
    out, _ = sh("du", "-sb", path, timeout=20)
    try:
        return int(out.split()[0])
    except (IndexError, ValueError):
        return 0


def parse(lines):
    res = []
    for l in lines.splitlines():
        m = re.match(r"(\S+)\s+(\S+)\s+->\s+(\S+)", l)
        if m:
            res.append({"name": m.group(1), "old": m.group(2), "new": m.group(3)})
    return res


cmd = sys.argv[1] if len(sys.argv) > 1 else "disks"
if cmd == "disks":
    out, _ = sh("df", "-B1", "--output=target,size,used,avail,fstype", "-x", "tmpfs", "-x", "devtmpfs", "-x", "efivarfs", "-x", "overlay", "-x", "squashfs")
    disks, seen = [], set()
    for line in out.splitlines()[1:]:
        p = line.split()
        if len(p) < 5 or p[0].startswith(("/boot", "/efi", "/run", "/var/lib/docker")):
            continue
        size, used, free = int(p[1]), int(p[2]), int(p[3])
        if size < 1 << 30 or (size, used) in seen:          # skip tiny and the same btrfs volume mounted twice
            continue
        seen.add((size, used))
        disks.append({"mount": p[0], "size": size, "used": used, "free": free, "pct": round(used * 100 / max(1, size))})
    last = ""
    try:
        for line in open("/var/log/pacman.log", errors="ignore"):
            if "starting full system upgrade" in line:
                last = line[1:20].replace("T", " ")
    except OSError:
        pass
    print(json.dumps({"disks": disks, "pkgCache": du("/var/cache/pacman/pkg"), "userCache": du(os.path.expanduser("~/.cache")), "lastUpdate": last}))
elif cmd == "updates":
    repo_out, code = sh("checkupdates", timeout=120)          # 0 = updates, 2 = none, 1 = error
    aur_out, _ = sh("paru", "-Qua", timeout=60)
    err = "" if code in (0, 2) else "Couldn't check — no internet?"
    print(json.dumps({"repo": parse(repo_out), "aur": parse(aur_out), "error": err}))
