#!/usr/bin/env python3
# Isla screen-time recorder (Noctalia used to do this). Adds seconds to today's entry in
# ~/.local/state/noctalia/screen_time.json, same format, so screentime.py and its archive keep working.
#   screentime-add.py '{"kitty": 30, "helium": 10}'
import datetime as dt, json, os, sys

SRC = os.path.expanduser("~/.local/state/noctalia/screen_time.json")
add = json.loads(sys.argv[1])
now = dt.datetime.now()
day, hour = now.date().isoformat(), now.hour
try:
    data = json.load(open(SRC))
except (OSError, ValueError):
    data = {}
d = data.setdefault(day, {"app_hourly": {}, "apps": {}, "hourly": [0] * 24})
for app, sec in add.items():
    sec = int(sec)
    if sec <= 0:
        continue
    d["app_hourly"].setdefault(app, [0] * 24)[hour] += sec
    d["apps"][app] = d["apps"].get(app, 0) + sec
    d["hourly"][hour] = min(3600, d["hourly"][hour] + sec)
cutoff = (now.date() - dt.timedelta(days=13)).isoformat()      # Noctalia keeps 14 days
data = {k: v for k, v in sorted(data.items()) if k >= cutoff}
os.makedirs(os.path.dirname(SRC), exist_ok=True)
tmp = SRC + ".tmp"
with open(tmp, "w") as f:
    json.dump(data, f)
os.replace(tmp, SRC)
