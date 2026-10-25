#!/usr/bin/env python3
# Disk map page (read-only scan; only runs while the page is open).
#   diskmap.py scan [PATH]   → {"path", "size", "children": [{name, path, size, in, children: [...]}], "biggest": [{path, size}], "disk": {size, used, free},
#                               "overview": [{id, label, size}] (home only)}
#   diskmap.py recs          → [{id, label, note, size, safe, cmd}]  things that can be cleaned
#   diskmap.py clean ID ...  → empties the SAFE ones (your own caches, no password); others are never touched
import json, os, subprocess, sys

HOME = os.path.expanduser("~")
H = lambda p: os.path.join(HOME, p)
# id, label, paths, safe, note, command shown / run (safe ones: contents deleted, folder kept)
RECS = [
    ("paru", "AUR build files", [H(".cache/paru/clone")], True, "paru downloads + builds, made again when needed", "rm -rf ~/.cache/paru/clone/*"),
    ("thumbs", "Picture thumbnails", [H(".cache/thumbnails")], True, "small previews, made again when needed", "rm -rf ~/.cache/thumbnails/*"),
    ("npm", "npm cache", [H(".npm/_cacache")], True, "npm cache clean --force", "rm -rf ~/.npm/_cacache/*"),
    ("pnpm", "pnpm store", [H(".local/share/pnpm/store")], True, "pnpm store prune", "rm -rf ~/.local/share/pnpm/store/*"),
    ("yarn", "Yarn cache", [H(".cache/yarn")], True, "yarn cache clean", "rm -rf ~/.cache/yarn/*"),
    ("pip", "pip cache", [H(".cache/pip")], True, "pip cache purge", "rm -rf ~/.cache/pip/*"),
    ("uv", "uv cache", [H(".cache/uv")], True, "uv cache clean", "rm -rf ~/.cache/uv/*"),
    ("go", "Go build cache", [H(".cache/go-build")], True, "go clean -cache", "rm -rf ~/.cache/go-build/*"),
    ("cargo", "Rust download cache", [H(".cargo/registry/cache")], True, "crates download again when needed", "rm -rf ~/.cargo/registry/cache/*"),
    ("trash", "Trash", [H(".local/share/Trash/files"), H(".local/share/Trash/info")], True, "files you already deleted", "rm -rf ~/.local/share/Trash/files/* ~/.local/share/Trash/info/*"),
    ("helium", "Helium browser cache", [H(".cache/net.imput.helium")], False, "close the browser first; sites load slower once", "rm -rf ~/.cache/net.imput.helium/*"),
    ("jetbrains", "Rider / JetBrains caches", [H(".cache/JetBrains")], False, "close Rider first; it re-indexes", "rm -rf ~/.cache/JetBrains/*"),
    ("shader", "Steam shader cache", [H(".local/share/Steam/steamapps/shadercache")], False, "games rebuild it (first launch stutters)", "rm -rf ~/.local/share/Steam/steamapps/shadercache/*"),
    ("pacman", "Old app downloads (pacman)", ["/var/cache/pacman/pkg"], False, "needs your password", "sudo paccache -rk1 && sudo paccache -ruk0"),
    ("journal", "System logs", ["/var/log/journal"], False, "keeps the newest 200 MB; needs your password", "sudo journalctl --vacuum-size=200M"),
    ("downloads", "Downloads folder", [H("Downloads")], False, "look through it yourself", "dolphin ~/Downloads"),
]


def du(path, depth=0):
    try:
        out = subprocess.run(["du", "-x", "-B1", "-d", str(depth), path], capture_output=True, text=True, timeout=120).stdout
    except Exception:
        return []
    rows = []
    for line in out.splitlines():
        size, _, p = line.partition("\t")
        if size.isdigit():
            rows.append((p, int(size)))
    return rows


def biggest(path, sizes):
    # the folders that really take the space: ≥ 1 GB and as deep as possible
    # (a folder is dropped when one of its sub-folders is on the list: a game, not "steamapps/common")
    cand = {p: s for p, s in sizes.items() if p != path and s >= 1 << 30}
    parents = {os.path.dirname(p) for p in cand}
    out = {}
    for p, s in cand.items():
        if p in parents:
            continue
        # climb while the parent is about the same size ("ELDEN RING/Game" → "ELDEN RING")
        while os.path.dirname(p) != path and sizes.get(os.path.dirname(p), 1 << 62) < s * 1.15:
            p = os.path.dirname(p)
        out[p] = sizes.get(p, s)
    return sorted(({"path": p, "size": s} for p, s in out.items()), key=lambda r: -r["size"])[:10]


# whole-disk overview (like Windows / Android storage): your home split by kind, then what's outside it
KINDS = [  # id, label, folders in home (a folder inside another one counts only for its own kind)
    ("games", "Games", [".local/share/Steam", "Games", ".local/share/lutris", ".config/heroic", ".local/share/faugus"]),
    ("cache", "Caches & trash", [".cache", ".local/share/Trash", ".npm", ".nuget/packages", ".local/share/pnpm"]),
    ("code", "Coding", ["Documents/Code", ".cargo", ".rustup", ".dotnet", "go", ".gradle", ".m2", ".vscode", ".local/share/JetBrains"]),
    ("media", "Pictures & music", ["Pictures", "Videos", "Music"]),
    ("docs", "Documents & downloads", ["Documents", "Downloads", "Desktop"]),
    ("data", "App data", [".config", ".local", ".var", ".mozilla"]),
]


def overview(home, sizes, disk):
    rules = [(k, os.path.join(home, r)) for k, _, rs in KINDS for r in rs if os.path.join(home, r) in sizes]
    paths = [p for _, p in rules]
    got = {k: 0 for k, _, _ in KINDS}
    for k, p in rules:
        got[k] += sizes[p] - sum(sizes[q] for q in paths if q.startswith(p + "/"))
    rows = [{"id": k, "label": l, "size": got[k]} for k, l, _ in KINDS]
    rows.append({"id": "other", "label": "Other in home", "size": max(0, sizes.get(home, 0) - sum(got.values()))})
    apps = 0
    for line in subprocess.run(["pacman", "-Qi"], capture_output=True, text=True, env=dict(os.environ, LC_ALL="C")).stdout.splitlines():
        if line.startswith("Installed Size"):
            n, u = line.split(":", 1)[1].split()
            apps += float(n) * {"B": 1, "KiB": 1 << 10, "MiB": 1 << 20, "GiB": 1 << 30}.get(u, 1)
    rows.append({"id": "apps", "label": "Installed apps & system", "size": int(apps)})
    # what's left: Btrfs snapshots (old copies kept after updates / deletes), root-only folders, filesystem extras
    rows.append({"id": "hidden", "label": "Snapshots & hidden", "size": max(0, disk["used"] - sizes.get(home, 0) - int(apps))})
    return [r for r in rows if r["size"] > 0]


def scan(path):
    sizes = dict(du(path, 7))                      # one pass: the map, the biggest list and the overview all come from it
    total = sizes.get(path, 0)
    kids = {}
    for p, s in sizes.items():
        kids.setdefault(os.path.dirname(p), []).append(p)

    def node(p, root, deep):
        n = {"name": os.path.basename(p), "path": p, "size": sizes[p], "in": os.path.relpath(os.path.dirname(p), root)}
        if deep:
            inner = [node(c, p, False) for c in kids.get(p, []) if sizes[c] > 0]
            loose = sizes[p] - sum(c["size"] for c in inner)          # files straight in it (a game's big data files)
            if loose > sizes[p] * 0.02:
                inner.append({"name": "files", "path": "", "size": loose})
            n["children"] = trim(inner, 8) if len(inner) > 1 else []
        return n

    def trim(items, keep):
        items.sort(key=lambda k: -k["size"])
        big, rest = items[:keep], items[keep:]
        small = sum(k["size"] for k in rest)
        if small > 0:
            big.append({"name": "%d more" % len(rest), "path": "", "size": small, "children": [], "more": True})
        return big

    # top tiles; a folder that holds most of the space is opened up in place (".local" → "share" → "Steam" → the games),
    # so the map shows what is really big instead of one giant box
    top = [c for c in kids.get(path, []) if c != path and sizes[c] > 0]
    for _ in range(8):
        big = max(top, key=lambda c: sizes[c], default=None)
        inner = [c for c in kids.get(big, []) if sizes[c] > 0] if big else []
        if not big or sizes[big] < total * 0.5 or not inner:
            break
        top.remove(big)
        top += inner
        loose = sizes[big] - sum(sizes[c] for c in inner)
        if loose > total * 0.01:
            top.append(("files", big, loose))
    items = []
    for c in top:
        if isinstance(c, tuple):
            items.append({"name": "files in " + os.path.basename(c[1]), "path": "", "size": c[2], "children": [], "more": True})
        else:
            items.append(node(c, path, True))
    files = total - sum(i["size"] for i in items)
    if files > 0:
        items.append({"name": "files here", "path": "", "size": files, "children": [], "more": True})
    st = os.statvfs(path)
    disk = {"size": st.f_blocks * st.f_frsize, "free": st.f_bavail * st.f_frsize, "used": (st.f_blocks - st.f_bfree) * st.f_frsize}
    return {"path": path, "size": total, "children": trim(items, 16), "biggest": biggest(path, sizes), "disk": disk,
            "overview": overview(path, sizes, disk) if path == HOME else []}


def recs():
    out = []
    for rid, label, paths, safe, note, cmd in RECS:
        size = sum(s for p in paths if os.path.exists(p) for _, s in du(p, 0)[-1:])
        if size >= 20 << 20:                       # skip things under 20 MB
            out.append({"id": rid, "label": label, "note": note, "size": size, "safe": safe, "cmd": cmd})
    return sorted(out, key=lambda r: (not r["safe"], -r["size"]))


def clean(ids):
    for rid, label, paths, safe, note, cmd in RECS:
        if rid in ids and safe:
            for p in paths:
                if p.startswith(HOME + os.sep) and os.path.isdir(p):
                    subprocess.run(["find", p, "-mindepth", "1", "-maxdepth", "1", "-exec", "rm", "-rf", "--", "{}", "+"])


cmd = sys.argv[1] if len(sys.argv) > 1 else "scan"
if cmd == "scan":
    p = os.path.abspath(os.path.expanduser(sys.argv[2])) if len(sys.argv) > 2 else HOME
    print(json.dumps(scan(p if os.path.isdir(p) else HOME)))
elif cmd == "recs":
    print(json.dumps(recs()))
elif cmd == "clean":
    clean(set(sys.argv[2:]))
