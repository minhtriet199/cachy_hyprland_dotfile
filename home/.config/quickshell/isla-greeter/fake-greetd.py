#!/usr/bin/env python3
"""Pretend greetd for check.sh: speaks the greetd IPC protocol on a unix socket, accepts only the password
"isla-test", and writes every request it got to a JSON file. Usage: fake-greetd.py <socket> <log.json>"""
import json, os, socket, struct, sys

sock_path, log_path = sys.argv[1], sys.argv[2]
got = []

def save():
    with open(log_path, "w") as f:
        json.dump(got, f)

def send(c, obj):
    data = json.dumps(obj).encode()
    c.sendall(struct.pack("=I", len(data)) + data)

def recv(c):
    head = b""
    while len(head) < 4:
        part = c.recv(4 - len(head))
        if not part:
            return None
        head += part
    n = struct.unpack("=I", head)[0]
    body = b""
    while len(body) < n:
        part = c.recv(n - len(body))
        if not part:
            return None
        body += part
    return json.loads(body)

if os.path.exists(sock_path):
    os.unlink(sock_path)
srv = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
srv.bind(sock_path)
srv.listen(1)
srv.settimeout(60)
save()
c, _ = srv.accept()
c.settimeout(60)
while True:
    try:
        req = recv(c)
    except OSError:
        break
    if req is None:
        break
    got.append(req)
    save()
    t = req.get("type")
    if t == "create_session":
        send(c, {"type": "auth_message", "auth_message_type": "secret", "auth_message": "Password: "})
    elif t == "post_auth_message_response":
        if req.get("response") == "isla-test":
            send(c, {"type": "success"})
        else:
            send(c, {"type": "error", "error_type": "auth_error", "description": "pam_authenticate: AUTH_ERR"})
    elif t in ("start_session", "cancel_session"):
        send(c, {"type": "success"})
    else:
        send(c, {"type": "error", "error_type": "error", "description": "unknown request"})
save()
