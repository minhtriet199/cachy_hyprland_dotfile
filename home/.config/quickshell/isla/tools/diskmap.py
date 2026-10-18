#!/usr/bin/env python3
# Disk map page (read-only scan; only runs while the page is open).
#   diskmap.py scan [PATH]   → {"path", "size", "children": [{name, path, size, children: [...]}], "biggest": [{path, size}], "disk": {size, used, free}}
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


def biggest(path):
    # the folders that really take the space: ≥ 1 GB and as deep as possible
    # (a folder is dropped when one of its sub-folders is on the list: a game, not "steamapps/common")
    sizes = dict(du(path, 7))
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


def scan(path):
    rows = du(path, 2)
    sizes = dict(rows)
    total = sizes.get(path, 0)
    kids = {}
    for p, s in rows:
        rel = os.path.relpath(p, path)
        if rel == ".":
            continue
        parts = rel.split(os.sep)
        if len(parts) == 1:
            kids.setdefault(parts[0], {"name": parts[0], "path": p, "size": s, "children": []})["size"] = s
        else:
            kids.setdefault(parts[0], {"name": parts[0], "path": os.path.join(path, parts[0]), "size": 0, "children": []})["children"].append(
                {"name": parts[1], "path": p, "size": s})

    def trim(items, keep):
        items.sort(key=lambda k: -k["size"])
        big, rest = items[:keep], items[keep:]
        small = sum(k["size"] for k in rest)
        if small > 0:
            big.append({"name": "%d more" % len(rest), "path": "", "size": small, "children": [], "more": True})
        return big

    top = [k for k in kids.values() if k["size"] > 0]
    for k in top:
        k["children"] = trim([c for c in k["children"] if c["size"] > 0], 8)
    files = total - sum(k["size"] for k in top)
    if files > 0:
        top.append({"name": "files here", "path": "", "size": files, "children": [], "more": True})
    st = os.statvfs(path)
    return {"path": path, "size": total, "children": trim(top, 16), "biggest": biggest(path),
            "disk": {"size": st.f_blocks * st.f_frsize, "free": st.f_bavail * st.f_frsize, "used": (st.f_blocks - st.f_bfree) * st.f_frsize}}


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
