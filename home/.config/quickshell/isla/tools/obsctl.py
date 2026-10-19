#!/usr/bin/env python3
# OBS remote for Isla's record button (obs-websocket v5 on localhost; Python standard library only).
#   obsctl.py toggle   recording → stop it · not recording → open OBS (tray) if needed, ask which screen/app
#                      (Isla's picker, through the screen-share portal), then start
#   obsctl.py status   {"rec": true/false, "ms": elapsed}
# The picker answers in $XDG_RUNTIME_DIR/isla-share/result (tools/share-pick.sh writes "pick" or "cancel").
import base64, fcntl, hashlib, json, os, socket, struct, subprocess, sys, time

CONF = os.path.expanduser("~/.config/obs-studio/plugin_config/obs-websocket/config.json")
KIND = "pipewire-screen-capture-source"
NAME = "Isla capture"
RESULT = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "isla-share", "result")
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


def start():
    c = conf()
    if not c.get("server_enabled"):
        if obs_running():
            notify("Close OBS once", "Isla turns on OBS's remote control the next time it opens OBS")
            return
        c["server_enabled"] = True
        json.dump(c, open(CONF, "w"), indent=2)
    if not obs_running():
        subprocess.Popen(["obs", "--minimize-to-tray", "--disable-shutdown-check"], stdout=subprocess.DEVNULL,
                         stderr=subprocess.DEVNULL, start_new_session=True)
    o = connect(wait=25)
    if not o:
        notify("OBS didn't answer", "Try again in a moment")
        return
    os.makedirs(os.path.dirname(RESULT), exist_ok=True)
    try:
        os.remove(RESULT)
    except FileNotFoundError:
        pass
    # a fresh screen-capture source each time: making it is what asks the portal → Isla's picker
    # (pressing an old source's "Reload" opens a session that never asks)
    scene = o.req("GetCurrentProgramScene")["currentProgramSceneName"]
    for i in o.req("GetInputList", {"inputKind": KIND}).get("inputs", []):
        o.req("RemoveInput", {"inputName": i["inputName"]})
    time.sleep(0.3)
    src = NAME
    asked = os.path.join(os.path.dirname(RESULT), "windows")             # share-pick.sh writes it when the portal asks
    for tryno in (1, 2):
        t0 = time.time()
        o.req("CreateInput", {"sceneName": scene, "inputName": src, "inputKind": KIND, "inputSettings": {"ShowCursor": True}})
        while time.time() - t0 < 10 and not (os.path.exists(asked) and os.path.getmtime(asked) >= t0 - 0.5):
            time.sleep(0.2)
        if os.path.exists(asked) and os.path.getmtime(asked) >= t0 - 0.5:
            break
        # xdg-desktop-portal-hyprland sometimes hangs after sharing a window: restart it and ask again
        o.req("RemoveInput", {"inputName": src})
        subprocess.run(["systemctl", "--user", "restart", "xdg-desktop-portal-hyprland"])
        time.sleep(1.5)
    else:
        notify("Screen picker didn't open", "Try the record button again")
        return
    end = time.time() + 120
    while not os.path.exists(RESULT) and time.time() < end:
        time.sleep(0.2)
    if not os.path.exists(RESULT) or open(RESULT).read().strip() != "pick":
        return
    time.sleep(1.2)                                   # let the new stream start before recording
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


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    if cmd == "status":
        o = connect() if obs_running() else None
        st = o.req("GetRecordStatus") if o else {}
        print(json.dumps({"rec": bool(st.get("outputActive")), "ms": st.get("outputDuration", 0)}))
    elif cmd == "toggle":
        os.makedirs(os.path.dirname(RESULT), exist_ok=True)
        lock = open(RESULT + ".lock", "w")
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)     # already waiting on the picker: ignore extra taps
        except OSError:
            return
        o = connect() if obs_running() else None
        if o and o.req("GetRecordStatus").get("outputActive"):
            path = o.req("StopRecord").get("outputPath", "")
            notify("Recording saved", path)
        else:
            start()
    else:
        sys.exit("usage: obsctl.py toggle | status")


if __name__ == "__main__":
    main()
