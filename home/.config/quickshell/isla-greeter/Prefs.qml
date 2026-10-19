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
    property bool h24: false
    property string theme: "isla"
    property real themeHue: 0.85
    property string boxStyle: "candy"
    property bool dark: false
    property string wipeBg: "cream"
    property string wipeIcon: "leaf"
    readonly property var wipeBgs: ({ cream: ["#FFF4E0", "#F1E2C2"], sky: ["#D3EAF0", "#B9DDE6"], lilac: ["#EEE8FD", "#D9CEFA"], peach: ["#FDE7DC", "#F6CDB9"],
                                      mint: ["#E3F4E3", "#C3E6C5"], sun: ["#FFF4CF", "#F5DE95"], night: ["#213F48", "#2F5A65"] })
    property bool ready: false
    readonly property var keys: ["displayName", "lockWallpaper", "h24", "theme", "themeHue", "boxStyle", "dark", "wipeBg", "wipeIcon"]
    readonly property string dir: Quickshell.env("ISLA_GREETER_DATA") || "/var/lib/isla-greeter"

    FileView {
        path: p.dir + "/prefs.json"
        printErrors: false
        onLoaded: {
            try {
                const o = JSON.parse(text());
                for (const k of p.keys) if (o[k] !== undefined) p[k] = o[k];
                // the picture itself was copied next to prefs.json
                if (p.lockWallpaper !== "") p.lockWallpaper = p.dir + "/lock-wallpaper";
            } catch (e) {}
            p.ready = true;
        }
        onLoadFailed: p.ready = true
    }
}
