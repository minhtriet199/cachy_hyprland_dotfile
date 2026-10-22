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
    property var calcHistory: []            // phone calculator: [[sum, answer], …], newest first (max 30)
    property string phoneSpot: "Low"        // small upright phone height: Low (as designed) / Middle / High
    property bool phoneWindow: false        // phone opens as a normal app window (move / focus / close it like any app)
    property var clipPins: []               // pinned clipboard items (cliphist preview text, so a re-copy stays pinned)
    property int clipDays: 15               // unpinned clipboard items older than this are deleted (tools/clip-prune.sh)
    // idle timers in minutes (0 = never), like Windows: [plugged in, on battery]
    property var idleLock: [15, 5]
    property var idleScreen: [10, 3]
    property var idleSleep: [0, 15]
    property var lidClose: ["sleep", "sleep"]
    property bool h24: false                    // 24-hour clock
    property bool location: true                // weather / time zone may use this connection's location (IP)
    property bool weatherAuto: true             // weather for where you are (needs location) instead of the city below
    property string city: "Ho Chi Minh City"    // weather city when not automatic
    property bool autoTz: false                 // set the time zone from your location when the network changes
    property bool dndGaming: true               // no pop-ups while a game is focused
    property string theme: "isla"               // colour theme (Theme.palettes)
    property real themeHue: 0.85                // hue for the "Custom" theme (0…1)
    property string boxStyle: "candy"           // "candy" or "ring"
    property bool dark: false                   // Isla itself in dark mode (works with every colour theme)
    property bool appsDark: false               // apps (Qt/KDE/GTK, browsers) in dark mode — separate from Isla     // plugged in, on battery: sleep / screen / lock / nothing
    property string wipeBg: "cream"         // lock / unlock scene change: background (key of wipeBgs)
    property string wipeIcon: "leaf"        // … and the icon in the middle (WipeIcon names)
    property var wipeAuto: ["#FFF4E0", "#F1E2C2"]   // wipeBg "wallpaper": pastel of the wallpaper's main colour (SvcPalette keeps it fresh)
    readonly property var wipeBgs: ({ cream: ["#FFF4E0", "#F1E2C2"], sky: ["#D3EAF0", "#B9DDE6"], lilac: ["#EEE8FD", "#D9CEFA"], peach: ["#FDE7DC", "#F6CDB9"],
                                      mint: ["#E3F4E3", "#C3E6C5"], sun: ["#FFF4CF", "#F5DE95"], night: ["#213F48", "#2F5A65"] })
    readonly property var wipeColors: wipeBg === "wallpaper" ? wipeAuto : (wipeBgs[wipeBg] || wipeBgs.cream)
    property string phoneBg: "cream"        // phone screen: a colour name below, or a picture path
    readonly property var phoneBgs: ({ cream: ["#FFF9EC", "#F1E2C2"], sky: ["#E2F5F8", "#BFE4EA"], lilac: ["#F1ECFE", "#D9CEFA"],
                                       peach: ["#FDECE3", "#F6CDB9"], mint: ["#E7F6E7", "#C3E6C5"], sun: ["#FFF6D6", "#F5DE95"] })
    property bool gameMode: false           // Game mode (Settings → Quick): Hyprland animations off, phone light mode, bar animations paused
    property bool phoneLite: false          // phone light mode (side button ⚡): fewer, shorter animations, lighter drawing
    property bool ready: false

    readonly property var keys: ["notifications", "dock", "bar", "size", "barStyle", "barPos", "wallpaper", "wallDir", "displayName", "avatar", "phoneBg", "lockWallpaper", "wipeBg", "wipeIcon", "idleLock", "idleScreen", "idleSleep", "phoneLite", "lidClose", "h24", "location", "weatherAuto", "city", "autoTz", "dndGaming", "theme", "boxStyle", "themeHue", "dark", "appsDark", "gameMode", "calcHistory", "clipPins", "clipDays", "phoneSpot", "wipeAuto", "phoneWindow"]
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
        blockLoading: true                  // first frame (boot cover) already has your colours
        printErrors: false
        onLoaded: {
            try { const o = JSON.parse(text()); for (const k of p.keys) if (o[k] !== undefined) p[k] = o[k] } catch (e) {}
            p.ready = true; p.borrow();
        }
        onLoadFailed: { p.ready = true; p.borrow() }
    }
    // scene-change cover colour for Hyprland's background (misc.lua) and the login screen: boot goes greeter → Hyprland → Isla in one colour
    onWipeColorsChanged: if (ready) coverFile.setText(wipeColors[0] + "\n")
    onReadyChanged: if (ready) coverFile.setText(wipeColors[0] + "\n")
    FileView { id: coverFile; path: p.dir + "/../hypr/cover"; printErrors: false }
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
