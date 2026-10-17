pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Isla settings you change from the phone. Saved to ~/.local/state/isla/prefs.json
Singleton {
    id: p
    property bool notifications: true      // show notification bubbles on the desktop
    property bool dock: true
    property bool bar: true
    property real size: 0.75               // "Shell size" (0.5 – 1.5)
    property string barStyle: "Transparent" // Float · Straight · Transparent
    property string barPos: "Top"          // Top · Bottom
    property string wallpaper: ""
    property string wallDir: Quickshell.env("HOME") + "/Pictures/Wallpapers"
    property string displayName: ""         // name shown on the profile card ("" = system full name)
    property string avatar: "smile"         // profile glyph
    property string lockWallpaper: ""       // lock screen picture ("" = Isla's sky with blobs)
    property string wipeBg: "cream"         // lock / unlock scene change: background (key of wipeBgs)
    property string wipeIcon: "leaf"        // … and the icon in the middle (WipeIcon names)
    readonly property var wipeBgs: ({ cream: ["#FFF4E0", "#F1E2C2"], sky: ["#D3EAF0", "#B9DDE6"], lilac: ["#EEE8FD", "#D9CEFA"], peach: ["#FDE7DC", "#F6CDB9"],
                                      mint: ["#E3F4E3", "#C3E6C5"], sun: ["#FFF4CF", "#F5DE95"], night: ["#213F48", "#2F5A65"] })
    property string phoneBg: "cream"        // phone screen: a colour name below, or a picture path
    readonly property var phoneBgs: ({ cream: ["#FFF9EC", "#F1E2C2"], sky: ["#E2F5F8", "#BFE4EA"], lilac: ["#F1ECFE", "#D9CEFA"],
                                       peach: ["#FDECE3", "#F6CDB9"], mint: ["#E7F6E7", "#C3E6C5"], sun: ["#FFF6D6", "#F5DE95"] })
    property bool ready: false

    readonly property var keys: ["notifications", "dock", "bar", "size", "barStyle", "barPos", "wallpaper", "wallDir", "displayName", "avatar", "phoneBg", "lockWallpaper", "wipeBg", "wipeIcon"]
    readonly property string dir: Quickshell.env("HOME") + "/.local/state/isla"

    function set(k, v) { p[k] = v; save() }
    function flip(k) { p[k] = !p[k]; save() }
    function setSize(v) { size = Math.round(Math.max(0.5, Math.min(1.5, v)) * 100) / 100; save() }
    function save() { if (ready) saveTimer.restart() }
    Timer { id: saveTimer; interval: 300; onTriggered: {
        const o = {}; for (const k of p.keys) o[k] = p[k];
        Quickshell.execDetached(["mkdir", "-p", p.dir]);
        file.setText(JSON.stringify(o, null, 2) + "\n");
    } }

    FileView {
        id: file
        path: p.dir + "/prefs.json"
        printErrors: false
        onLoaded: {
            try { const o = JSON.parse(text()); for (const k of p.keys) if (o[k] !== undefined) p[k] = o[k] } catch (e) {}
            p.ready = true; p.borrow();
        }
        onLoadFailed: { p.ready = true; p.borrow() }
    }
    // First run: borrow the wallpaper end-4 (illogical-impulse) was using.
    property string iiWall: ""
    function borrow() {
        if (!ready || wallpaper !== "" || iiWall === "") return;
        wallpaper = iiWall; wallDir = iiWall.substring(0, iiWall.lastIndexOf("/")); save();
    }
    FileView {
        path: Quickshell.env("HOME") + "/.config/illogical-impulse/config.json"
        printErrors: false
        onLoaded: {
            try { const o = JSON.parse(text()); const w = (o.background && o.background.wallpaperPath) || ""; p.iiWall = w.replace(/^file:\/\//, "") } catch (e) {}
            p.borrow();
        }
    }
}
