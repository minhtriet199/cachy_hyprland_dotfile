#!/usr/bin/env python3
"""Download mode watcher (only runs while Download mode is on): every 3 s prints one JSON line
{"items": [{"name", "app", "done", "total"}], "speed": bytes/s, "busy": bool}.
Steam: appmanifest_*.acf BytesDownloaded / BytesToDownload in every library. Browsers: *.crdownload (Chromium,
Helium), *.part (Firefox), *.download in ~/Downloads (size only; they don't store the total). Any other app shows
up in the network speed. busy = something is downloading or the network is still pulling > 150 KB/s."""
import glob, json, os, re, sys, time

HOME = os.path.expanduser("~")
STEAM = os.path.join(HOME, ".local/share/Steam")
DL_DIRS = [os.path.join(HOME, "Downloads")]


def libraries():
    libs = {os.path.join(STEAM, "steamapps")}
    try:
        for p in re.findall(r'"path"\s+"([^"]+)"', open(os.path.join(STEAM, "steamapps/libraryfolders.vdf")).read()):
            libs.add(os.path.join(p, "steamapps"))
    except OSError:
        pass
    return libs


def steam_items(libs):
    out = []
    for lib in libs:
        for f in glob.glob(os.path.join(lib, "appmanifest_*.acf")):
            try:
                t = open(f, errors="ignore").read()
            except OSError:
                continue
            v = dict(re.findall(r'"(name|BytesToDownload|BytesDownloaded)"\s+"([^"]*)"', t))
            total, done = int(v.get("BytesToDownload") or 0), int(v.get("BytesDownloaded") or 0)
            if total and done < total:
                out.append({"name": v.get("name", "Steam game"), "app": "Steam", "done": done, "total": total})
    return out


def file_items():
    out = []
    for d in DL_DIRS:
        for pat, app in (("*.crdownload", "Browser"), ("*.part", "Browser"), ("*.download", "Browser")):
            for f in glob.glob(os.path.join(d, pat)):
                try:
                    st = os.stat(f)
                except OSError:
                    continue
                if time.time() - st.st_mtime < 120:          # still being written
                    name = re.sub(r"\.(crdownload|part|download)$", "", os.path.basename(f))
                    out.append({"name": name, "app": app, "done": st.st_size, "total": 0})
    return out


def rx():
    n = 0
    for line in open("/proc/net/dev").readlines()[2:]:
        name, data = line.split(":", 1)
        if name.strip() != "lo":
            n += int(data.split()[0])
    return n


libs, last, speeds, prev = libraries(), rx(), [], {}
while True:
    time.sleep(3)
    now = rx()
    speeds = (speeds + [(now - last) / 3])[-10:]          # 30 s window
    last = now
    items = steam_items(libs) + file_items()
    for it in items:                                     # each download's own speed (its bytes since the last check)
        key = it["app"] + it["name"]
        it["rate"] = max(0, int((it["done"] - prev[key]) / 3)) if key in prev else 0
    prev = {it["app"] + it["name"]: it["done"] for it in items}
    avg = sum(speeds) / len(speeds)
    print(json.dumps({"items": items, "speed": int(speeds[-1]), "busy": bool(items) or avg > 150_000}), flush=True)
    if sys.stdout.closed:
        break
