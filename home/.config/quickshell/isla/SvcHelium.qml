import QtQuick
import Quickshell
import Quickshell.Io

// Part of Services: an Isla browser theme for Helium (any Chromium) in ~/.local/share/isla/browser-theme, rewritten
// whenever the palette, dark mode or wallpaper changes. Chromium themes are colours + images only (no outlines/fonts).
// Load once: chrome://extensions → Developer mode → Load unpacked → that folder. After a change: Reload it there.
Scope {
    id: h
    readonly property string dir: Quickshell.env("HOME") + "/.local/share/isla/browser-theme"
    function rgb(x) { const c = Qt.lighter(x, 1.0); return [Math.round(c.r * 255), Math.round(c.g * 255), Math.round(c.b * 255)] }
    readonly property string wall: Prefs.wallpaper
    readonly property string wallExt: (/\.(jpe?g|png)$/i.exec(wall) || [""])[0].toLowerCase()   // Chromium: jpg / png only
    readonly property string manifest: JSON.stringify({
        manifest_version: 3, name: "Isla", version: "1.0", description: "Isla colours (made by Isla, SvcHelium.qml)",
        theme: {
            images: wallExt ? { theme_ntp_background: "ntp" + wallExt } : {},
            properties: { ntp_background_alignment: "center", ntp_background_repeat: "no-repeat" },
            colors: {
                frame: rgb(Theme.gSettings[1]), frame_inactive: rgb(Theme.gSettings[0]),          // tab strip
                frame_incognito: rgb(Theme.phoneB), frame_incognito_inactive: rgb(Theme.phoneWallB),
                toolbar: rgb(Theme.paper), toolbar_text: rgb(Theme.textDeep), toolbar_button_icon: rgb(Theme.inkPhone),
                tab_text: rgb(Theme.textDeep), tab_background_text: rgb(Theme.text), tab_background_text_inactive: rgb(Theme.textSoft),
                bookmark_text: rgb(Theme.textDeep),
                omnibox_background: rgb(Theme.gChip[0]), omnibox_text: rgb(Theme.textDeep),          // search bar
                ntp_background: rgb(Theme.cream), ntp_text: rgb(Theme.textDeep), ntp_link: rgb(Theme.seaDeep),
                button_background: rgb(Theme.gTab[0])
            }
        }
    }, null, 2) + "\n"
    // write a moment after the last change (dragging the hue slider changes it many times)
    onManifestChanged: save.restart()
    Timer { id: save; interval: 1500
        onTriggered: Quickshell.execDetached(["sh", "-c", "mkdir -p \"$0\" && rm -f \"$0\"/ntp.* && { [ -z \"$2\" ] || cp \"$1\" \"$0/ntp$2\"; } && printf '%s' \"$3\" > \"$0/manifest.json\"",
                                              h.dir, h.wall, h.wallExt, h.manifest]) }
}
