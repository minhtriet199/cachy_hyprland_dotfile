#!/usr/bin/env python3
# Island → Wi-Fi → network details: settings + live info for one Wi-Fi network (by SSID), as JSON.
import json, subprocess, sys

def nm(*a):
    return subprocess.run(["nmcli", *a], capture_output=True, text=True).stdout

ssid = sys.argv[1]
name = ""
# the connection in use wins when several saved profiles share one SSID (e.g. "TRIET" and "TRIET 5ghz")
cur = nm("-g", "GENERAL.CONNECTION", "dev", "show", "wlan0").strip()
if cur and nm("-g", "802-11-wireless.ssid", "con", "show", cur).strip() == ssid:
    name = cur
for line in ([] if name else nm("-t", "-f", "NAME,TYPE", "con", "show").splitlines()):
    n, _, t = line.rpartition(":")
    n = n.replace("\\:", ":")
    if t == "802-11-wireless" and nm("-g", "802-11-wireless.ssid", "con", "show", n).strip() == ssid:
        name = n
        break
out = {"ssid": ssid, "name": name, "saved": bool(name)}
if name:
    keys = ["ipv4.method", "ipv4.addresses", "ipv4.gateway", "ipv4.dns", "ipv4.ignore-auto-dns", "ipv6.method",
            "connection.autoconnect", "802-11-wireless.cloned-mac-address", "connection.metered", "802-11-wireless-security.key-mgmt"]
    vals = nm("-g", ",".join(keys), "con", "show", name).splitlines()
    out.update({k: (vals[i] if i < len(vals) else "") for i, k in enumerate(keys)})
# live info when this network is the one in use
dev = nm("-t", "-f", "GENERAL.CONNECTION,IP4.ADDRESS,IP4.GATEWAY,IP4.DNS,IP6.ADDRESS", "dev", "show", "wlan0")
live = {}
for line in dev.splitlines():
    k, _, v = line.partition(":")
    live.setdefault(k.split("[")[0], []).append(v)
out["active"] = bool(name) and live.get("GENERAL.CONNECTION", [""])[0] == name
if out["active"]:
    out["ip"] = (live.get("IP4.ADDRESS") or [""])[0]
    out["gw"] = (live.get("IP4.GATEWAY") or [""])[0]
    out["dnsNow"] = ", ".join(x for x in live.get("IP4.DNS", []) if x)
    out["ip6"] = (live.get("IP6.ADDRESS") or [""])[0]
for line in nm("-t", "-f", "SSID,SIGNAL,FREQ,SECURITY,CHAN", "dev", "wifi", "list").splitlines():
    f = line.replace("\\:", "\x00").split(":")
    f = [x.replace("\x00", ":") for x in f]
    if f and f[0] == ssid:
        out.update({"signal": f[1], "freq": f[2], "security": f[3], "chan": f[4]})
        break
print(json.dumps(out))
