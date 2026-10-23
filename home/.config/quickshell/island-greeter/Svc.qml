pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The few things LockScreen.qml asks its `svc` for: clock, battery, who logs in, restart / shut down.
Singleton {
    id: s
    readonly property bool h24: Prefs.h24
    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property date now: clock.date ?? new Date()
    readonly property string clockH: { const h = now.getHours(); const v = h24 ? h : (h % 12 || 12); return (v < 10 ? "0" : "") + v }
    readonly property string clockM: Qt.formatTime(now, "mm")
    readonly property string ampm: now.getHours() < 12 ? "AM" : "PM"
    readonly property var media: null
    // battery straight from sysfs (Quickshell's UPower gives no data on this laptop), every 30 s
    property var battery: ({ percent: 100, charging: false })
    Process {
        id: batP
        command: ["bash", "-c", "for d in /sys/class/power_supply/BAT*; do read -r c < $d/capacity; read -r st < $d/status; echo \"$c $st\"; break; done"]
        stdout: StdioCollector { onStreamFinished: {
            const t = this.text.trim(); if (!t) return;
            const i = t.indexOf(" "); s.battery = { percent: parseInt(t) || 0, charging: /^(Charging|Full|Not charging)$/.test(t.slice(i + 1)) };
        } }
    }
    Timer { interval: 30000; running: true; repeat: true; triggeredOnStart: true; onTriggered: batP.running = true }
    // user.json: { "user": "gamer", "full": "…", "users": [{ user, full }, …] } written by island-greeter-sync
    property var profile: ({ user: "", full: "" })
    property var users: []
    function loadProfile() {}
    FileView {
        path: Prefs.dir + "/user.json"
        printErrors: false
        onLoaded: { try { const o = JSON.parse(text()); s.profile = { user: o.user || "", full: o.full || "" }; s.users = (o.users || []).length ? o.users : [s.profile] } catch (e) {} }
    }
    function power(what) {
        if (what === "reboot") Quickshell.execDetached(["systemctl", "reboot"]);
        else if (what === "shutdown") Quickshell.execDetached(["systemctl", "poweroff"]);
    }
}
