#!/usr/bin/env python3
# Installed apps (Apps page, like Windows "Installed apps" / Android "App info"). Read-only except clearcache.
#   installed.py list          → [{id, name, kind: app|game|tool|shortcut, source, pkg, version, size, date, icon, exec, desc, removable, appid}]
#   installed.py info ID       → {"dirs": [{label, path, size, cache}], "running": bool}   (only for the app you open)
#   installed.py clearcache ID → empties that app's cache folders (only ~/.cache/… or Steam's shader cache for it)
# Uninstall is done by the page: pacman apps with `pkexec pacman -Rns` (password), Steam games through Steam.
import glob, json, os, re, subprocess, sys, time

HOME = os.path.expanduser("~")
STEAM = os.path.join(HOME, ".local/share/Steam")
# never offered for uninstall: the desktop itself
KEEP = {"hyprland", "quickshell", "quickshell-git", "kitty", "networkmanager", "pipewire", "wireplumber", "sddm", "dolphin", "steam", "fcitx5"}


def sh(*cmd):
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=20, env=dict(os.environ, LC_ALL="C")).stdout
    except Exception:
        return ""


def desktop(p):
    e, sec = {}, False
    try:
        for line in open(p, errors="ignore"):
            line = line.strip()
            if line.startswith("["):
                sec = line == "[Desktop Entry]"
            elif sec and "=" in line:
                k, _, v = line.partition("=")
                e.setdefault(k, v)
    except OSError:
        return None
    if e.get("NoDisplay") == "true" or e.get("Hidden") == "true" or e.get("Type", "Application") != "Application":
        return None
    return e


def steam_games():
    libs = {STEAM}
    try:
        libs |= set(re.findall(r'"path"\s+"([^"]+)"', open(os.path.join(STEAM, "steamapps/libraryfolders.vdf")).read()))
    except OSError:
        pass
    out = []
    for lib in libs:
        for m in glob.glob(os.path.join(lib, "steamapps/appmanifest_*.acf")):
            try:
                kv = dict(re.findall(r'^\s*"(\w+)"\s+"([^"]*)"', open(m, errors="ignore").read(), re.M))
            except OSError:
                continue
            name = kv.get("name", "").strip()
            tool = bool(re.search(r"Proton|Steam Linux Runtime|Steamworks Common", name))
            out.append({"id": "steam:" + kv.get("appid", ""), "appid": kv.get("appid", ""), "name": name, "kind": "tool" if tool else "game",
                        "source": "Steam", "pkg": "", "version": "build " + kv.get("buildid", "?"), "size": int(kv.get("SizeOnDisk", 0) or 0),
                        "date": int(kv.get("LastUpdated", 0) or 0), "played": int(kv.get("LastPlayed", 0) or 0),
                        "icon": "steam_icon_" + kv.get("appid", ""), "exec": "steam steam://rungameid/" + kv.get("appid", ""),
                        "desc": "Steam library: " + lib.replace(HOME, "~"), "removable": True,
                        "dir": os.path.join(lib, "steamapps/common", kv.get("installdir", ""))})
    return out


def pacman_apps():
    files = {}
    for p in glob.glob("/usr/share/applications/*.desktop"):
        e = desktop(p)
        if e:
            files[p] = e
    owners = {}   # desktop file → package
    for line in sh("pacman", "-Qo", *files).splitlines():
        m = re.match(r"(\S+) is owned by (\S+) ", line)
        if m:
            owners[m.group(1)] = m.group(2)
    pkgs = sorted(set(owners.values()))
    info, cur = {}, {}
    for line in sh("pacman", "-Qi", *pkgs).splitlines() + [""]:
        if not line.strip():
            if "Name" in cur:
                info[cur["Name"]] = cur
            cur = {}
        elif " : " in line:
            k, _, v = line.partition(" : ")
            cur[k.strip()] = v.strip()
    aur = set(sh("pacman", "-Qqm").split())
    rows = {}
    for p, e in files.items():
        pkg = owners.get(p)
        if not pkg or pkg not in info:
            continue
        i = info[pkg]
        did = os.path.basename(p)[:-8]
        # one row per package; its main launcher wins the name ("dolphin" over "dolphin-…")
        if pkg in rows and not (did.lower().endswith(pkg.lower()) and not rows[pkg]["did"].lower().endswith(pkg.lower())):
            continue
        try:
            date = int(time.mktime(time.strptime(i.get("Install Date", ""), "%a %b %d %H:%M:%S %Y")))
        except ValueError:
            date = int(os.path.getmtime(p))
        rows[pkg] = {"id": "pkg:" + pkg, "did": did, "name": e.get("Name", pkg), "kind": "game" if "Game" in e.get("Categories", "") else "app",
                     "source": "AUR" if pkg in aur else "pacman", "pkg": pkg, "version": i.get("Version", ""), "size": isize(i.get("Installed Size", "")),
                     "date": date, "icon": e.get("Icon", ""), "exec": re.sub(r"\s*%\w", "", e.get("Exec", "")), "desc": i.get("Description", ""),
                     "removable": i.get("Install Reason", "").startswith("Explicitly") and pkg not in KEEP,
                     "wm": e.get("StartupWMClass", "")}
    return list(rows.values())


def isize(s):
    m = re.match(r"([\d.,]+)\s*(\w+)", s)
    if not m:
        return 0
    n = float(m.group(1).replace(",", "."))
    return int(n * {"B": 1, "KiB": 1 << 10, "MiB": 1 << 20, "GiB": 1 << 30}.get(m.group(2), 1))


def shortcuts():
    # your own launchers (~/.local/share/applications) that are not Steam games
    out = []
    for p in glob.glob(HOME + "/.local/share/applications/*.desktop"):
        e = desktop(p)
        if e and "steam://rungameid" not in e.get("Exec", ""):
            out.append({"id": "desk:" + os.path.basename(p), "name": e.get("Name", ""), "kind": "shortcut", "source": "Shortcut", "pkg": "",
                        "version": "", "size": 0, "date": int(os.path.getmtime(p)), "icon": e.get("Icon", ""),
                        "exec": re.sub(r"\s*%\w", "", e.get("Exec", "")), "desc": p.replace(HOME, "~"), "removable": False})
    return out


def all_apps():
    return steam_games() + pacman_apps() + shortcuts()


def du(p):
    out = sh("du", "-sxB1", p).split("\t")[0]
    return int(out) if out.isdigit() else 0


def dirs(a):
    # where the app keeps its settings / data / cache in your home (names matched without case)
    if a["source"] == "Steam":
        sa = os.path.dirname(os.path.dirname(a["dir"]))
        cand = [("Game files", a["dir"], False), ("Saves & Proton prefix", os.path.join(sa, "compatdata", a["appid"]), False),
                ("Shader cache", os.path.join(sa, "shadercache", a["appid"]), True)]
        return [(l, p, c) for l, p, c in cand if os.path.isdir(p)]
    names = {n.lower() for n in (a.get("pkg"), a.get("did"), a.get("wm"), os.path.basename((a.get("exec") or " ").split()[0]),
                                  (a.get("did") or "").split(".")[-1]) if n and len(n) > 2}
    out = []
    for label, base, cache in (("Cache", ".cache", True), ("Settings", ".config", False), ("Data", ".local/share", False), ("State", ".local/state", False)):
        try:
            for d in os.listdir(os.path.join(HOME, base)):
                if d.lower() in names or d.lower().split(".")[-1] in names:   # "net.imput.helium" → helium
                    out.append((label, os.path.join(HOME, base, d), cache))
        except OSError:
            pass
    return out


def find(aid):
    return next((a for a in all_apps() if a["id"] == aid), None)


cmd = sys.argv[1] if len(sys.argv) > 1 else "list"
if cmd == "list":
    print(json.dumps(all_apps()))
elif cmd == "info" and len(sys.argv) > 2:
    a = find(sys.argv[2]) or {}
    # running = a process named like its command, launcher or package (helium-browser → "helium")
    names = {n[:15] for n in (os.path.basename((a.get("exec") or " ").split()[0]), a.get("did"), a.get("pkg")) if n} if a.get("source") not in (None, "Steam") else set()
    print(json.dumps({"dirs": [{"label": l, "path": p, "size": du(p), "cache": c} for l, p, c in (dirs(a) if a else [])],
                      "running": any(sh("pgrep", "-x", n).strip() for n in names)}))
elif cmd == "clearcache" and len(sys.argv) > 2:
    a = find(sys.argv[2])
    for _, p, cache in (dirs(a) if a else []):
        if cache and (p.startswith(HOME + "/.cache/") or "/steamapps/shadercache/" in p):
            subprocess.run(["find", p, "-mindepth", "1", "-maxdepth", "1", "-exec", "rm", "-rf", "--", "{}", "+"])
