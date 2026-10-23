#!/usr/bin/env python3
# Recovery page backend: snapshots of the whole setup (Island, greeter sources, Hyprland, themes, saved settings)
# in ~/.local/state/island-snapshots/<id>.tar.gz (+ <id>.json: name, auto, paths).
#   snapshot.py list                 JSON, newest first
#   snapshot.py create [name] [auto]
#   snapshot.py restore <id>         saves the current setup first ("Before restore"), puts the snapshot back, restarts Island
#   snapshot.py delete <id>
# Not included: clipboard history/pins, wallpapers, caches.
import glob, json, os, shutil, subprocess, sys, tarfile, time

H = os.path.expanduser("~")
DIR = os.path.join(H, ".local/state/island-snapshots")
KEEP_AUTO = 10
PATHS = [".config/quickshell/island", ".config/quickshell/island-greeter", ".config/hypr", ".config/Kvantum", ".config/qt6ct",
         ".config/kdeglobals", ".config/dolphinrc", ".config/kitty", ".config/systemd/user",
         ".config/gtk-3.0/gtk.css", ".config/gtk-3.0/settings.ini", ".config/gtk-4.0/gtk.css", ".config/gtk-4.0/settings.ini",
         ".local/state/island/prefs.json", ".local/state/island/schedule.json", ".local/state/hypr",
         ".local/share/icons/Island", ".local/share/color-schemes"]
PATHS += [os.path.relpath(p, H) for p in glob.glob(H + "/.config/gtk-[34].0/island*.css")]


def skip(t):
    b = os.path.basename(t.name)
    return None if ".bak" in b or b == "__pycache__" or b.endswith(".pyc") else t


def meta(i):
    try:
        return json.load(open(os.path.join(DIR, i + ".json")))
    except (OSError, ValueError):
        return {}


def snaps():
    out = []
    for f in sorted(glob.glob(DIR + "/*.tar.gz"), reverse=True):
        i = os.path.basename(f)[:-7]
        m = meta(i)
        out.append({"id": i, "name": m.get("name", ""), "auto": m.get("auto", False), "time": int(os.path.getmtime(f)), "size": os.path.getsize(f)})
    return out


def create(name="", auto=False):
    os.makedirs(DIR, exist_ok=True)
    i = base = time.strftime("%Y%m%d-%H%M%S")
    n = 1
    while os.path.exists(os.path.join(DIR, i + ".tar.gz")):       # two in the same second
        n += 1; i = f"{base}-{n}"
    paths = [p for p in PATHS if os.path.lexists(os.path.join(H, p))]
    part = os.path.join(DIR, i + ".tar.gz.part")
    with tarfile.open(part, "w:gz") as t:
        for p in paths:
            t.add(os.path.join(H, p), arcname=p, filter=skip)
    json.dump({"name": name, "auto": auto, "paths": paths}, open(os.path.join(DIR, i + ".json"), "w"))
    os.rename(part, part[:-5])
    for s in [s for s in snaps() if s["auto"]][KEEP_AUTO:]:      # only the newest automatic ones are kept
        delete(s["id"])
    return i


def delete(i):
    for ext in (".tar.gz", ".json"):
        try:
            os.remove(os.path.join(DIR, os.path.basename(i) + ext))
        except FileNotFoundError:
            pass


def restore(i):
    f = os.path.join(DIR, os.path.basename(i) + ".tar.gz")
    if not os.path.exists(f):
        sys.exit("no such snapshot")
    m = meta(i)
    when = time.strftime("%d %b %H:%M", time.localtime(os.path.getmtime(f)))
    create("Before restoring " + (m.get("name") or when), auto=True)
    subprocess.run(["qs", "-c", "island", "kill"], capture_output=True)
    time.sleep(1)
    with tarfile.open(f) as t:
        for p in m.get("paths") or sorted({n.name.split("/")[0] for n in t.getmembers()}):
            q = os.path.join(H, p)
            if os.path.isdir(q) and not os.path.islink(q):
                shutil.rmtree(q)
            elif os.path.lexists(q):
                os.remove(q)
        t.extractall(H, filter="tar")
    subprocess.run(["systemctl", "--user", "daemon-reload"], capture_output=True)
    subprocess.run(["hyprctl", "reload"], capture_output=True)
    subprocess.run(["hyprctl", "dispatch", 'hl.dsp.exec_cmd("env MALLOC_ARENA_MAX=2 qs -c island -d")'], capture_output=True)


if __name__ == "__main__":
    a = sys.argv[1:] or ["list"]
    if a[0] == "list":
        print(json.dumps(snaps()))
    elif a[0] == "create":
        print(create(a[1] if len(a) > 1 else "", len(a) > 2 and a[2] == "auto"))
    elif a[0] == "restore":
        restore(a[1])
    elif a[0] == "delete":
        delete(a[1])
