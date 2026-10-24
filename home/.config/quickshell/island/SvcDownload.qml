import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Part of Services: Download mode (Power mode "Download" / Quick chip). Saves power while something downloads:
// Silent power mode, keyboard light off, Island calm, the other screens off and one screen at 5% showing a dim clock +
// download progress (DownloadScreen.qml). A key / mouse move wakes the screens; 1 min untouched → dim again.
// Done = something was downloading and nothing has for 60 s → everything back to normal + a dialog that shuts the PC
// down after 2 min unless you pick Keep using. Progress comes from tools/dlwatch.py (runs only while this is on).
Scope {
    id: dl
    property var svc
    property bool on: false
    property bool dim: false                 // the dim download screen is showing (vs. normal screens while you use it)
    property var items: []                   // [{ name, app, done, total }] from dlwatch.py
    property real speed: 0                   // bytes / s
    property bool saw: false                 // something has downloaded since the mode started
    property int quiet: 0                    // seconds with nothing downloading (after saw)
    property var names: []                   // everything seen downloading, for the done dialog
    property real startedAt: 0
    // done dialog
    property bool asking: false
    property int countdown: 0
    property var doneNames: []
    property string doneTime: ""

    // the screen that shows the dim download view: the laptop panel unless its lid is closed
    readonly property string aodScreen: {
        const ms = Hyprland.monitors.values.map(m => m.name);
        const lap = ms.find(n => n.startsWith("eDP"));
        return lap && !svc.lidClosed ? lap : (ms.find(n => !n.startsWith("eDP")) || ms[0] || "");
    }
    property var _saved: null                // power mode to put back (brightness + keyboard light: brightnessctl -s / -r)

    function start() {
        if (on) return;
        _saved = { profile: svc.powerProfile };
        svc.run(["sh", "-c", "brightnessctl -d 'asus::kbd_backlight' -s set 0 >/dev/null 2>&1"]);   // -s remembers it
        if (svc.powerProfile !== "Quiet") svc.setProfile("Quiet");
        items = []; speed = 0; saw = false; quiet = 0; names = []; startedAt = Date.now();
        on = true; dim = true;
        // a marker with what to put back: if Island reloads / restarts / crashes mid-mode, the next start restores it
        svc.run(["sh", "-c", "printf '%s\\n' \"$1\" > \"$XDG_RUNTIME_DIR/island-download\"", "x", JSON.stringify(_saved)]);
        svc.powerLog("download mode on");
    }
    function _restore() {
        dim = false;
        svc.run(["sh", "-c", "rm -f \"$XDG_RUNTIME_DIR/island-download\""]);
        svc.run(["sh", "-c", "brightnessctl -d 'asus::kbd_backlight' -r >/dev/null 2>&1"]);
        if (_saved && _saved.profile && _saved.profile !== svc.powerProfile) svc.setProfile(_saved.profile);
    }
    // Island (re)started while a Download mode was left on: screens, brightness, power mode, keyboard light back
    Process { running: true; command: ["sh", "-c", "cat \"$XDG_RUNTIME_DIR/island-download\" 2>/dev/null && rm -f \"$XDG_RUNTIME_DIR/island-download\""]
        stdout: StdioCollector { onStreamFinished: {
            let v; try { v = JSON.parse(this.text) } catch (e) { return }
            dl.svc.powerLog("Island restarted during download mode → screens and settings put back");
            dl.svc.screensOn(); dl.svc.run(["sh", "-c", "[ \"$(brightnessctl -m | cut -d, -f4)\" = 5% ] && brightnessctl -r"]);   // still at the dim 5% → saved level
            if (v.profile && v.profile !== dl.svc.powerProfile) dl.svc.setProfile(v.profile);
            dl.svc.run(["sh", "-c", "brightnessctl -d 'asus::kbd_backlight' -r >/dev/null 2>&1"]);
        } } }
    function stop() { if (!on) return; _restore(); on = false; svc.powerLog("download mode off (by you)") }
    function finish() {
        _restore(); on = false;
        doneNames = names.slice(0, 6); doneTime = Qt.formatTime(new Date(), svc.h24 ? "HH:mm" : "h:mm AP");
        countdown = 120; asking = true;
        svc.powerLog("downloads finished (" + (names.join(", ") || "network") + ") → asking, shut down in 2 min");
    }
    function keepUsing() { asking = false; svc.powerLog("done dialog → keep using") }
    function shutDownNow() { asking = false; svc.powerLog("done dialog → shut down"); svc.power("shutdown") }
    Timer { interval: 1000; repeat: true; running: dl.asking
        onTriggered: { dl.countdown -= 1; if (dl.countdown <= 0) { dl.asking = false; dl.svc.powerLog("no answer in 2 min → shut down"); dl.svc.power("shutdown") } } }

    // dim on / off: the other screens off, the dim screen at 5% (its own brightness comes back when you wake it)
    // the laptop's own brightness is saved / restored by brightnessctl (-s / -r), never from Island's copy (that one
    // is still the 80% default for a moment after a restart)
    property bool _dimmedLaptop: false
    onDimChanged: {
        if (dim) _applyDim();
        else { svc.screensOn(); if (_dimmedLaptop) { _dimmedLaptop = false; svc.run(["brightnessctl", "-r"]) } }
    }
    // lid opened / closed while dim: the dim view moves to the other screen → that one on, the rest off
    onAodScreenChanged: if (on && dim) _applyDim()
    function _dpms(name, state) { svc.run(["hyprctl", "dispatch", "hl.dsp.dpms({ action = \"" + state + "\", monitor = \"" + name + "\" })"]) }
    function _applyDim() {
        for (const m of Hyprland.monitors.values) _dpms(m.name, m.name === aodScreen ? "on" : "off");
        if (aodScreen.startsWith("eDP") && !_dimmedLaptop) { _dimmedLaptop = true; svc.run(["brightnessctl", "-s", "set", "5%"]) }
    }
    // dim: any key / mouse wakes (a 2 s idle watch: its "back" is the first input) · awake: 1 min untouched → dim again
    IdleTimer { respectInhibitors: false; minutes: !dl.on ? 0 : dl.dim ? 2 / 60 : 1
        onBack: if (dl.on && dl.dim) dl.dim = false
        onIdle: if (dl.on && !dl.dim) dl.dim = true }

    Process {
        running: dl.on
        command: ["python3", "-I", Quickshell.shellDir + "/tools/dlwatch.py"]
        stdout: SplitParser { onRead: line => {
            let v; try { v = JSON.parse(line) } catch (e) { return }
            dl.items = v.items; dl.speed = v.speed;
            for (const it of v.items) if (!dl.names.includes(it.name)) dl.names = dl.names.concat([it.name]);
            if (v.busy) { dl.saw = true; dl.quiet = 0 }
            else if (dl.saw) { dl.quiet += 3; if (dl.quiet >= 60) dl.finish() }
        } }
    }
}
