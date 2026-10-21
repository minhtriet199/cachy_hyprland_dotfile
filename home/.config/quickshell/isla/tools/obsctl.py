#!/usr/bin/env python3
# OBS remote for Isla's record button (obs-websocket v5 on localhost; Python standard library only).
#   obsctl.py toggle   recording → stop it · not recording → (re)open OBS in the tray so it asks which screen/app
#                      (Isla's picker, through the screen-share portal), then start
#                      OBS already open and still showing the last pick → just start recording (no restart)
#   obsctl.py pick     same, but always ask again (right-click on the record button)
#   obsctl.py status   {"rec": true/false, "ms": elapsed}
# The picker answers in $XDG_RUNTIME_DIR/isla-share/result (tools/share-pick.sh writes "pick" or "cancel").
import base64, fcntl, hashlib, json, os, socket, struct, subprocess, sys, time

CONF = os.path.expanduser("~/.config/obs-studio/plugin_config/obs-websocket/config.json")
KIND = "pipewire-screen-capture-source"
NAME = "Isla capture"
RESULT = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "isla-share", "result")
REC = os.path.join(os.path.dirname(RESULT), "rec")          # "<start ms>" while recording, "0" after: Isla's bar timer watches it
VIDEOS = os.path.expanduser("~/Videos")


def obs_running():
    return subprocess.run(["pgrep", "-x", "obs"], stdout=subprocess.DEVNULL).returncode == 0


def conf():
    try:
        return json.load(open(CONF))
    except (OSError, ValueError):
        return {}


class Obs:
    """Just enough WebSocket (RFC 6455, client side) for obs-websocket's JSON messages."""
    def __init__(self, port, password):
        self.s = socket.create_connection(("127.0.0.1", port), timeout=5)
        key = base64.b64encode(os.urandom(16)).decode()
        self.s.sendall(("GET / HTTP/1.1\r\nHost: 127.0.0.1:%d\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n"
                        "Sec-WebSocket-Key: %s\r\nSec-WebSocket-Version: 13\r\nSec-WebSocket-Protocol: obswebsocket.json\r\n\r\n"
                        % (port, key)).encode())
        head = b""
        while b"\r\n\r\n" not in head:
            c = self.s.recv(1)
            if not c:
                raise OSError("no handshake")
            head += c
        if b" 101 " not in head.split(b"\r\n")[0]:
            raise OSError("handshake refused")
        hello = self.recv()["d"]
        ident = {"rpcVersion": 1, "eventSubscriptions": 0}
        if "authentication" in hello:
            a = hello["authentication"]
            secret = base64.b64encode(hashlib.sha256((password + a["salt"]).encode()).digest())
            ident["authentication"] = base64.b64encode(hashlib.sha256(secret + a["challenge"].encode()).digest()).decode()
        self.send({"op": 1, "d": ident})
        if self.recv()["op"] != 2:
            raise OSError("not identified")
        self.n = 0

    def exact(self, n):
        b = b""
        while len(b) < n:
            c = self.s.recv(n - len(b))
            if not c:
                raise OSError("closed")
            b += c
        return b

    def send(self, obj):
        p = json.dumps(obj).encode()
        h = bytes([0x81])
        h += bytes([0x80 | len(p)]) if len(p) < 126 else (bytes([0x80 | 126]) + struct.pack("!H", len(p)) if len(p) < 65536
                                                          else bytes([0x80 | 127]) + struct.pack("!Q", len(p)))
        m = os.urandom(4)
        self.s.sendall(h + m + bytes(b ^ m[i % 4] for i, b in enumerate(p)))

    def recv(self):
        while True:
            b0, b1 = self.exact(2)
            n = b1 & 0x7F
            n = struct.unpack("!H", self.exact(2))[0] if n == 126 else struct.unpack("!Q", self.exact(8))[0] if n == 127 else n
            data = self.exact(n)
            if b0 & 0x0F == 8:
                raise OSError("closed by OBS")
            if b0 & 0x0F == 1:
                return json.loads(data)

    def req(self, kind, data=None):
        self.n += 1
        self.send({"op": 6, "d": {"requestType": kind, "requestId": str(self.n), "requestData": data or {}}})
        while True:
            m = self.recv()
            if m["op"] == 7 and m["d"]["requestId"] == str(self.n):
                return m["d"].get("responseData") or {}


def connect(wait=0):
    c = conf()
    end = time.time() + wait
    while True:
        try:
            return Obs(int(c.get("server_port", 4455)), c.get("server_password", ""))
        except OSError:
            if time.time() >= end:
                return None
            time.sleep(0.5)


def notify(title, body=""):
    subprocess.Popen(["notify-send", "-a", "OBS", "-i", "com.obsproject.Studio", title, body])


def collection():
    """Path of OBS's current scene collection (basic/scenes/<name>.json)."""
    name = "Untitled.json"
    try:
        for line in open(os.path.expanduser("~/.config/obs-studio/user.ini")):
            if line.startswith("SceneCollectionFile="):
                name = line.split("=", 1)[1].strip()
    except OSError:
        pass
    return os.path.expanduser("~/.config/obs-studio/basic/scenes/" + name)


def quit_obs():
    subprocess.run(["pkill", "-TERM", "-x", "obs"])
    for _ in range(40):
        if not obs_running():
            return
        time.sleep(0.25)


def launch():
    subprocess.Popen(["obs", "--minimize-to-tray", "--disable-shutdown-check"], stdout=subprocess.DEVNULL,
                     stderr=subprocess.DEVNULL, start_new_session=True)
    return connect(wait=25)


def fit_and_record(o, scene, src):
    # fit whatever was picked (screen or window, any size) into the canvas
    v = o.req("GetVideoSettings")
    for it in o.req("GetSceneItemList", {"sceneName": scene}).get("sceneItems", []):
        if it.get("sourceName") == src:
            o.req("SetSceneItemTransform", {"sceneName": scene, "sceneItemId": it["sceneItemId"], "sceneItemTransform": {
                "positionX": 0, "positionY": 0, "boundsType": "OBS_BOUNDS_SCALE_INNER", "boundsAlignment": 0,
                "boundsWidth": v["baseWidth"], "boundsHeight": v["baseHeight"]}})
    os.makedirs(VIDEOS, exist_ok=True)
    o.req("SetRecordDirectory", {"recordDirectory": VIDEOS})
    o.req("StartRecord")
    open(REC, "w").write(str(int(time.time() * 1000)))


def live(o):
    """(scene, source) when the current scene's capture source still has a picture (0×0 = nothing picked / stream ended)."""
    scene = o.req("GetCurrentProgramScene")["currentProgramSceneName"]
    for it in o.req("GetSceneItemList", {"sceneName": scene}).get("sceneItems", []):
        if it.get("inputKind") == KIND and it.get("sceneItemEnabled"):
            t = o.req("GetSceneItemTransform", {"sceneName": scene, "sceneItemId": it["sceneItemId"]})["sceneItemTransform"]
            if t.get("sourceWidth", 0) > 0:
                return scene, it["sourceName"]
    return None


def start(repick=False):
    c = conf()
    if not c.get("server_enabled"):
        if obs_running():
            notify("Close OBS once", "Isla turns on OBS's remote control the next time it opens OBS")
            return
        c["server_enabled"] = True
        json.dump(c, open(CONF, "w"), indent=2)
    o = connect() if obs_running() and not repick else None
    hit = o and live(o)
    if hit:
        fit_and_record(o, *hit)
        subprocess.Popen(["notify-send", "-a", "OBS", "-i", "com.obsproject.Studio", "-t", "3000", "Recording",
                          "Same screen as last time · right-click the record button to pick another"])
        return
    # OBS only asks "which screen?" for a capture source it loads at start-up (one made or reloaded through the
    # remote control waits forever). So: make sure the current scene has one, close OBS, forget the old choice,
    # open OBS again — it asks the portal → Isla's picker (tools/share-pick.sh) → we start recording.
    subprocess.Popen(["notify-send", "-a", "OBS", "-i", "com.obsproject.Studio", "-t", "3000", "Getting OBS ready…", "The picker opens in a moment"])
    f = collection()
    try:
        saved = next((x["name"] for x in json.load(open(f)).get("sources", []) if x.get("id") == KIND), None)
    except (OSError, ValueError):
        saved = None
    if obs_running() or not saved:                  # (OBS closed with a capture source saved: skip straight to the restart)
        o = connect() if obs_running() else launch()
        if not o:
            notify("OBS didn't answer", "Try again in a moment")
            return
        scene = o.req("GetCurrentProgramScene")["currentProgramSceneName"]
        src = next((i["inputName"] for i in o.req("GetInputList", {"inputKind": KIND}).get("inputs", [])), None)
        if not src:
            src = NAME
            o.req("CreateInput", {"sceneName": scene, "inputName": src, "inputKind": KIND, "inputSettings": {"ShowCursor": True}})
        elif not any(i.get("sourceName") == src for i in o.req("GetSceneItemList", {"sceneName": scene}).get("sceneItems", [])):
            o.req("CreateSceneItem", {"sceneName": scene, "sourceName": src})
        quit_obs()
    else:
        src = saved
    try:
        d = json.load(open(f))
        for x in d.get("sources", []):
            if x.get("id") == KIND:
                x.setdefault("settings", {})["RestoreToken"] = ""
        json.dump(d, open(f, "w"))
    except (OSError, ValueError):
        pass
    os.makedirs(os.path.dirname(RESULT), exist_ok=True)
    try:
        os.remove(RESULT)
    except FileNotFoundError:
        pass
    o = launch()
    if not o:
        notify("OBS didn't answer", "Try again in a moment")
        return
    scene = o.req("GetCurrentProgramScene")["currentProgramSceneName"]
    end = time.time() + 120
    while not os.path.exists(RESULT) and time.time() < end:
        time.sleep(0.2)
    if not os.path.exists(RESULT) or open(RESULT).read().strip() != "pick":
        return
    time.sleep(1.2)                                   # let the new stream start before recording
    fit_and_record(o, scene, src)


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    if cmd == "status":
        o = connect() if obs_running() else None
        st = o.req("GetRecordStatus") if o else {}
        print(json.dumps({"rec": bool(st.get("outputActive")), "ms": st.get("outputDuration", 0)}))
    elif cmd in ("toggle", "pick"):
        os.makedirs(os.path.dirname(RESULT), exist_ok=True)
        lock = open(RESULT + ".lock", "w")
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)     # already waiting on the picker: ignore extra taps
        except OSError:
            return
        o = connect() if obs_running() else None
        if o and o.req("GetRecordStatus").get("outputActive"):
            path = o.req("StopRecord").get("outputPath", "")
            open(REC, "w").write("0")
            notify("Recording saved", path)
        else:
            start(repick=cmd == "pick")
    else:
        sys.exit("usage: obsctl.py toggle | pick | status")


if __name__ == "__main__":
    main()
