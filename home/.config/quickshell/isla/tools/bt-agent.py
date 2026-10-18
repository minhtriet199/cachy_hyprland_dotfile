#!/usr/bin/env python3
# Bluetooth pairing agent for Isla. BlueZ asks it "is this code right?" when a phone/PC pairs;
# it asks Isla (stdout) and waits for the answer (stdin), so the code shows in a dialog.
#   out: {"id": n, "kind": "confirm"|"pairreq"|"authorize"|"display"|"cancel", "name": ..., "addr": ..., "key": "123456"}
#   in:  "<id> yes" / "<id> no" / "<id> trust" (yes + mark the device trusted)
# Only trusted devices connect by themselves; an untrusted one asks first. One answer covers all the
# profiles (audio, controls, calls…) the device opens right after, for a short while.
import json, sys, time
import dbus, dbus.service, dbus.mainloop.glib
from gi.repository import GLib

PATH = "/isla/agent"
dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
bus = dbus.SystemBus()
waiting = {}   # id → {"dev": path, "cbs": [(ok, err), …]}
allowed = {}   # device path → time it was allowed (covers its next profiles)
counter = 0


class Rejected(dbus.DBusException):
    _dbus_error_name = "org.bluez.Error.Rejected"


def info(dev):
    try:
        p = dbus.Interface(bus.get_object("org.bluez", dev), "org.freedesktop.DBus.Properties").GetAll("org.bluez.Device1")
    except dbus.DBusException:
        p = {}
    return p, str(p.get("Alias") or p.get("Name") or p.get("Address") or "device"), str(p.get("Address", ""))


def say(kind, dev, key=None, ok=None, err=None):
    global counter
    counter += 1
    _, name, addr = info(dev) if dev else ({}, "", "")
    if ok:
        waiting[counter] = {"dev": dev, "cbs": [(ok, err)]}
    print(json.dumps({"id": counter, "kind": kind, "name": name, "addr": addr, "key": key}), flush=True)


class Agent(dbus.service.Object):
    @dbus.service.method("org.bluez.Agent1", in_signature="", out_signature="")
    def Release(self):
        pass

    @dbus.service.method("org.bluez.Agent1", in_signature="ou", out_signature="",
                         async_callbacks=("ok", "err"))
    def RequestConfirmation(self, dev, passkey, ok, err):
        say("confirm", dev, "%06d" % passkey, ok, err)

    @dbus.service.method("org.bluez.Agent1", in_signature="o", out_signature="",
                         async_callbacks=("ok", "err"))
    def RequestAuthorization(self, dev, ok, err):      # a device with no screen asks to pair
        say("pairreq", dev, None, ok, err)

    @dbus.service.method("org.bluez.Agent1", in_signature="os", out_signature="",
                         async_callbacks=("ok", "err"))
    def AuthorizeService(self, dev, uuid, ok, err):
        p, _, _ = info(dev)
        if p.get("Trusted") or time.time() - allowed.get(dev, 0) < 20:
            ok()
            return
        for w in waiting.values():        # same device already asking: wait for that answer
            if w["dev"] == dev:
                w["cbs"].append((ok, err))
                return
        say("authorize", dev, None, ok, err)

    # old devices with a fixed PIN (most use 0000)
    @dbus.service.method("org.bluez.Agent1", in_signature="o", out_signature="s")
    def RequestPinCode(self, dev):
        return "0000"

    @dbus.service.method("org.bluez.Agent1", in_signature="o", out_signature="u")
    def RequestPasskey(self, dev):
        return dbus.UInt32(0)

    @dbus.service.method("org.bluez.Agent1", in_signature="ouq", out_signature="")
    def DisplayPasskey(self, dev, passkey, entered):
        say("display", dev, "%06d" % passkey)

    @dbus.service.method("org.bluez.Agent1", in_signature="os", out_signature="")
    def DisplayPinCode(self, dev, pin):
        say("display", dev, str(pin))

    @dbus.service.method("org.bluez.Agent1", in_signature="", out_signature="")
    def Cancel(self):
        for w in waiting.values():
            for ok, err in w["cbs"]:
                err(Rejected("Cancelled"))
        waiting.clear()
        say("cancel", None)


def answer(src, cond):
    line = sys.stdin.readline()
    if not line:
        loop.quit()
        return False
    parts = line.split()
    if len(parts) == 2 and parts[0].isdigit() and int(parts[0]) in waiting:
        w = waiting.pop(int(parts[0]))
        yes = parts[1] in ("yes", "trust")
        if yes:
            allowed[w["dev"]] = time.time()
        if parts[1] == "trust":
            try:
                dbus.Interface(bus.get_object("org.bluez", w["dev"]), "org.freedesktop.DBus.Properties").Set(
                    "org.bluez.Device1", "Trusted", dbus.Boolean(True))
            except dbus.DBusException:
                pass
        for ok, err in w["cbs"]:
            ok() if yes else err(Rejected("Rejected by user"))
    return True


Agent(bus, PATH)
mgr = dbus.Interface(bus.get_object("org.bluez", "/org/bluez"), "org.bluez.AgentManager1")
mgr.RegisterAgent(PATH, "DisplayYesNo")
mgr.RequestDefaultAgent(PATH)
GLib.io_add_watch(sys.stdin, GLib.IO_IN | GLib.IO_HUP, answer)
loop = GLib.MainLoop()
loop.run()
