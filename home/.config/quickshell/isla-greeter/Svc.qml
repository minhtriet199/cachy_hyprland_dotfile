pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

// The few things LockScreen.qml asks its `svc` for: clock, battery, who logs in, restart / shut down.
Singleton {
    id: s
    readonly property bool h24: Prefs.h24
    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property date now: clock.date
    readonly property string clockH: { const h = now.getHours(); const v = h24 ? h : (h % 12 || 12); return (v < 10 ? "0" : "") + v }
    readonly property string clockM: Qt.formatTime(now, "mm")
    readonly property string ampm: now.getHours() < 12 ? "AM" : "PM"
    readonly property var media: null
    readonly property var dev: UPower.displayDevice
    readonly property var battery: ({ percent: dev && dev.ready ? Math.round(dev.percentage * 100) : 100,
                                      charging: !!dev && dev.state === UPowerDeviceState.Charging })
    // user.json: { "user": "gamer", "full": "…" } written by isla-greeter-sync
    property var profile: ({ user: "", full: "" })
    function loadProfile() {}
    FileView {
        path: Prefs.dir + "/user.json"
        printErrors: false
        onLoaded: { try { const o = JSON.parse(text()); s.profile = { user: o.user || "", full: o.full || "" } } catch (e) {} }
    }
    function power(what) {
        if (what === "reboot") Quickshell.execDetached(["systemctl", "reboot"]);
        else if (what === "shutdown") Quickshell.execDetached(["systemctl", "poweroff"]);
    }
}
