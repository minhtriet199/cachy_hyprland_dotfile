#!/usr/bin/env python3
# Isla → Screen time page: today's total, top apps (nice names), and the last 7 days, as JSON.
import datetime as dt, importlib.util, json, os

path = os.path.expanduser("~/.config/hypr/scripts/screentime.py")
spec = importlib.util.spec_from_file_location("screentime", path)
st = importlib.util.module_from_spec(spec)
spec.loader.exec_module(st)

def read(p):
    try:
        return json.load(open(p))
    except (OSError, ValueError):
        return {}

arc, live = read(st.ARCHIVE), read(st.SRC)
days = dict(arc)
for k, v in live.items():
    if k not in days or st.day_total(v) >= st.day_total(days[k]):
        days[k] = v
try:
    games = st.steam_games()
except Exception:
    games = {}

def nice(app):
    if app.startswith("steam_app_"):
        return games.get(app[len("steam_app_"):], "Steam game")
    if app.startswith("title:"):
        return app[6:]
    name = app.split(".")[-1] if "." in app and not app.endswith((".x86_64", ".exe")) else app
    return name.replace(".x86_64", "").replace(".exe", "").replace("-", " ").strip().title() if name.islower() else name.replace(".x86_64", "")

today = dt.date.today()
out = []
for i in range(6, -1, -1):
    d = today - dt.timedelta(days=i)
    day = days.get(d.isoformat(), {})
    apps = sorted(day.get("apps", {}).items(), key=lambda x: -x[1])[:10]
    out.append({
        "label": "Today" if i == 0 else d.strftime("%a"), "date": d.strftime("%a %d %b"),
        "total": st.day_total(day), "hourly": day.get("hourly", [0] * 24),
        "apps": [{"id": a, "name": nice(a), "sec": s, "hourly": day.get("app_hourly", {}).get(a, [0] * 24)} for a, s in apps],
    })
print(json.dumps({"days": out}))
