pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Read-only copy of Isla's prefs for the login screen. isla-greeter-sync copies the user's
// ~/.local/state/isla/prefs.json into the data dir (the greeter user can't read your home).
Singleton {
    id: p
    property string displayName: ""
    property string lockWallpaper: ""
    property string avatar: "smile"
    property string phoneBg: "cream"
    readonly property var phoneBgs: ({ cream: ["#FFF9EC", "#F1E2C2"], sky: ["#E2F5F8", "#BFE4EA"], lilac: ["#F1ECFE", "#D9CEFA"],
                                       peach: ["#FDECE3", "#F6CDB9"], mint: ["#E7F6E7", "#C3E6C5"], sun: ["#FFF6D6", "#F5DE95"] })
    property bool h24: false
    property string theme: "isla"
    property real themeHue: 0.85
    property string boxStyle: "candy"
    property bool dark: false
    property string wipeBg: "cream"
    property string wipeIcon: "leaf"
    property var wipeAuto: ["#FFF4E0", "#F1E2C2"]
    readonly property var wipeBgs: ({ cream: ["#FFF4E0", "#F1E2C2"], sky: ["#D3EAF0", "#B9DDE6"], lilac: ["#EEE8FD", "#D9CEFA"], peach: ["#FDE7DC", "#F6CDB9"],
                                      mint: ["#E3F4E3", "#C3E6C5"], sun: ["#FFF4CF", "#F5DE95"], night: ["#213F48", "#2F5A65"] })
    readonly property var wipeColors: wipeBg === "wallpaper" ? wipeAuto : (wipeBgs[wipeBg] || wipeBgs.cream)
    property bool ready: false
    readonly property var keys: ["displayName", "lockWallpaper", "avatar", "phoneBg", "h24", "theme", "themeHue", "boxStyle", "dark", "wipeBg", "wipeIcon", "wipeAuto"]
    readonly property string dir: Quickshell.env("ISLA_GREETER_DATA") || "/var/lib/isla-greeter"

    FileView {
        path: p.dir + "/prefs.json"
        blockLoading: true                  // first frame already has your colours
        printErrors: false
        onLoaded: {
            try {
                const o = JSON.parse(text());
                for (const k of p.keys) if (o[k] !== undefined) p[k] = o[k];
                // the picture itself was copied next to prefs.json
                if (p.lockWallpaper !== "") p.lockWallpaper = p.dir + "/lock-wallpaper";
                if (p.phoneBg.startsWith("/")) p.phoneBg = p.dir + "/phone-bg";
            } catch (e) {}
            p.ready = true;
        }
        onLoadFailed: p.ready = true
    }
}
