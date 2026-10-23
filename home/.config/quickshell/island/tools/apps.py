#!/usr/bin/env python3
# Apps page: default apps (xdg-mime) and startup apps (Island's own list, started by hypr/config/startup_island.lua).
#   apps.py get                      → {"defaults": [{cat, label, cur, curName, options:[{id,name}]}], "startup": [...], "system": [...]}
#   apps.py default CAT DESKTOP_ID   → make it the default for that kind of file
#   apps.py add NAME CMD | toggle N | remove N     → change the startup list (~/.local/state/hypr/startup)
import glob, json, os, re, subprocess, sys

CATS = [  # cat, label, mime types it covers (first = the one we read back)
    ("browser", "Web browser", ["x-scheme-handler/https", "x-scheme-handler/http", "text/html", "x-scheme-handler/about", "x-scheme-handler/unknown"]),
    ("files", "Files", ["inode/directory"]),
    ("video", "Videos", ["video/mp4", "video/x-matroska", "video/webm", "video/quicktime", "video/x-msvideo"]),
    ("music", "Music", ["audio/mpeg", "audio/flac", "audio/ogg", "audio/x-wav", "audio/mp4"]),
    ("images", "Pictures", ["image/png", "image/jpeg", "image/webp", "image/gif"]),
    ("pdf", "PDF", ["application/pdf"]),
    ("text", "Text files", ["text/plain", "text/markdown"]),
]
DIRS = ["/usr/share/applications", os.path.expanduser("~/.local/share/applications"),
        "/var/lib/flatpak/exports/share/applications", os.path.expanduser("~/.local/share/flatpak/exports/share/applications")]
STATE = os.path.expanduser("~/.local/state/hypr/startup")
AUTOSTART = os.path.expanduser("~/.config/hypr/config/autostart.lua")


def sh(*cmd):
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=8).stdout.strip()
    except Exception:
        return ""


def apps():
    out = {}
    for d in DIRS:
        for p in glob.glob(d + "/*.desktop"):
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
                continue
            if e.get("NoDisplay") == "true" or e.get("Hidden") == "true" or e.get("Type", "Application") != "Application":
                continue
            out[os.path.basename(p)] = {"name": e.get("Name", ""), "mimes": e.get("MimeType", "").split(";"),
                                        "cats": e.get("Categories", "").split(";")}
    return out


def startup_list():
    rows = []
    try:
        for line in open(STATE):
            on, _, rest = line.rstrip("\n").partition("|")
            name, _, cmd = rest.partition("|")
            if cmd:
                rows.append({"on": on == "1", "name": name, "cmd": cmd})
    except FileNotFoundError:
        pass
    return rows


def startup_save(rows):
    os.makedirs(os.path.dirname(STATE), exist_ok=True)
    with open(STATE + ".tmp", "w") as f:
        for r in rows:
            f.write(("1" if r["on"] else "0") + "|" + r["name"].replace("|", " ") + "|" + r["cmd"].replace("\n", " ") + "\n")
    os.replace(STATE + ".tmp", STATE)


def system_list():
    # what hypr/config/autostart.lua always starts (shown, not changeable here)
    rows = []
    try:
        for line in open(AUTOSTART):
            m = re.search(r'hl\.exec_cmd\("([^"]+)"\)\s*(?:--\s*(.*))?', line)
            if m and not line.strip().startswith("--"):
                rows.append({"cmd": m.group(1), "note": (m.group(2) or "").strip()})
    except FileNotFoundError:
        pass
    return rows


def main(a):
    cmd = a[0] if a else "get"
    if cmd == "get":
        al, res = apps(), []
        for cat, label, mimes in CATS:
            cur = sh("xdg-mime", "query", "default", mimes[0])
            opts = sorted(({"id": k, "name": v["name"]} for k, v in al.items() if any(m in v["mimes"] for m in mimes)), key=lambda o: o["name"].lower())
            res.append({"cat": cat, "label": label, "cur": cur, "curName": al.get(cur, {}).get("name", cur or "Not set"), "options": opts})
        print(json.dumps({"defaults": res, "startup": startup_list(), "system": system_list()}))
    elif cmd == "default" and len(a) == 3:
        cat = next((c for c in CATS if c[0] == a[1]), None)
        if not cat or not re.fullmatch(r"[\w.+-]+\.desktop", a[2]):
            sys.exit("bad")
        if cat[0] == "browser":
            sh("xdg-settings", "set", "default-web-browser", a[2])
        if cat[2]:
            sh("xdg-mime", "default", a[2], *cat[2])
    elif cmd == "add" and len(a) == 3:
        rows = startup_list(); rows.append({"on": True, "name": a[1].strip() or a[2], "cmd": a[2].strip()}); startup_save(rows)
    elif cmd in ("toggle", "remove") and len(a) == 2 and a[1].isdigit():
        rows, i = startup_list(), int(a[1])
        if 0 <= i < len(rows):
            if cmd == "toggle":
                rows[i]["on"] = not rows[i]["on"]
            else:
                rows.pop(i)
            startup_save(rows)
    else:
        sys.exit("usage: apps.py get | default CAT ID | add NAME CMD | toggle N | remove N")


if __name__ == "__main__":
    main(sys.argv[1:])
