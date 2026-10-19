#!/usr/bin/env python3
# Keyring password pop-ups in Isla's style. Takes the GNOME keyring's prompter service on the session bus
# (org.gnome.keyring.SystemPrompter, normally gcr-prompter) and hands every request to Isla:
#   out: {"id": n, "kind": "password"|"confirm", "title", "message", "description", "warning", "choice", "new": bool}
#        {"kind": "close"}            the keyring is done with the pop-up
#   in:  "<id> ok <password>"  /  "<id> ok"  (confirm)  /  "<id> cancel"
# Protocol (org.gnome.keyring.internal.Prompter): the keyring calls BeginPrompting(callback) → we answer
# PromptReady("", {}, <exchange begin>); PerformPrompt(callback, "password"|"confirm", props, exchange) → we ask Isla
# and answer PromptReady("yes"|"no", props, <exchange with the password>); StopPrompting → PromptDone().
# The password is handed over with Gcr's secret exchange (encrypted), like gcr-prompter does.
# If Isla isn't running this helper isn't either, and the normal GNOME pop-up starts instead.
import json, sys
import dbus, dbus.service, dbus.mainloop.glib
import gi
gi.require_version("Gcr", "4")
from gi.repository import Gcr, GLib

PATH = "/org/gnome/keyring/Prompter"
IFACE = "org.gnome.keyring.internal.Prompter"
CB_IFACE = "org.gnome.keyring.internal.Prompter.Callback"
dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
bus = dbus.SessionBus()
counter = 0
waiting = {}      # id → (sender, callback path, kind)
active = {}       # (sender, callback path) → Gcr.SecretExchange


def emit(d):
    print(json.dumps(d), flush=True)


def out(d):
    emit(d)


def ready(sender, path, reply, exchange, props=None):
    cb = dbus.Interface(bus.get_object(sender, path, introspect=False), CB_IFACE)
    cb.PromptReady(reply, dbus.Dictionary(props or {}, signature="sv"), exchange,
                   reply_handler=lambda *a: None, error_handler=lambda *a: None)


def text(props, key):
    v = props.get(key, "")
    return str(v) if v is not None else ""


class Prompter(dbus.service.Object):
    @dbus.service.method(IFACE, in_signature="o", out_signature="", sender_keyword="sender")
    def BeginPrompting(self, callback, sender=None):
        ex = Gcr.SecretExchange.new(None)
        active[(sender, str(callback))] = ex
        # answer after this call has returned: the keyring only listens for PromptReady once BeginPrompting is done
        GLib.idle_add(lambda: ready(sender, str(callback), "", ex.begin()) and False)

    @dbus.service.method(IFACE, in_signature="osa{sv}s", out_signature="", sender_keyword="sender")
    def PerformPrompt(self, callback, kind, props, exchange, sender=None):
        global counter
        key = (sender, str(callback))
        ex = active.get(key)
        if ex is None:
            return
        if exchange:
            ex.receive(exchange)
        counter += 1
        waiting[counter] = (sender, str(callback), str(kind))
        out({"id": counter, "kind": "password" if kind == "password" else "confirm",
             "title": text(props, "title"), "message": text(props, "message"), "description": text(props, "description"),
             "warning": text(props, "warning"), "choice": text(props, "choice-label"),
             "new": bool(props.get("password-new", False))})

    @dbus.service.method(IFACE, in_signature="o", out_signature="", sender_keyword="sender")
    def StopPrompting(self, callback, sender=None):
        key = (sender, str(callback))
        active.pop(key, None)
        for i, w in list(waiting.items()):
            if (w[0], w[1]) == key:
                waiting.pop(i)
        out({"kind": "close"})
        cb = dbus.Interface(bus.get_object(sender, str(callback), introspect=False), CB_IFACE)
        cb.PromptDone(reply_handler=lambda *a: None, error_handler=lambda *a: None)


def handle(line):
    parts = line.rstrip("\n").split(" ", 2)
    if len(parts) >= 2 and parts[0].isdigit() and int(parts[0]) in waiting:
        sender, path, kind = waiting.pop(int(parts[0]))
        ex = active.get((sender, path))
        if ex is None:
            return True
        if parts[1] == "ok":
            secret = parts[2] if kind == "password" and len(parts) == 3 else ""
            ready(sender, path, "yes", ex.send(secret, -1) if kind == "password" else ex.send(None, 0))
        else:
            ready(sender, path, "no", ex.send(None, 0))


def start():
    global name
    name = dbus.service.BusName("org.gnome.keyring.SystemPrompter", bus, allow_replacement=True, replace_existing=True, do_not_queue=True)
    Prompter(bus, PATH)


# normally run inside isla-agents.py (one Python for both Isla helpers); can still run on its own
if __name__ == "__main__":
    def answer(src, cond):
        line = sys.stdin.readline()
        if not line:
            loop.quit()
            return False
        handle(line)
        return True
    start()
    GLib.io_add_watch(sys.stdin, GLib.IO_IN | GLib.IO_HUP, answer)
    loop = GLib.MainLoop()
    loop.run()
