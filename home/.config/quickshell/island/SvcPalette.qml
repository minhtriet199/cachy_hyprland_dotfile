import QtQuick
import Quickshell
import Quickshell.Io

// Part of Services: the Palette card's data — 5 colours from the wallpaper, the song's cover or at random.
// Apply = Island's "Custom" theme on the picked colour's hue; Undo = the theme you had before.
// Use it through Services.palette (this object).
Scope {
    id: pl
    property string wallpaper: ""
    property string art: ""
    property string source: "wallpaper"          // wallpaper · music · random
    property var colors: []
    property var wallColors: []                  // the wallpaper's own 5 colours (kept even while the card shows music / random)
    property int sel: 0
    property bool loading: false
    property var undo: null                      // { theme, hue } from before the first Apply
    readonly property real selHue: colors.length ? Math.max(0, Qt.color(colors[sel]).hslHue) : -1
    readonly property real applyHue: Math.round(selHue * 200) / 200
    readonly property bool applied: selHue >= 0 && Prefs.theme === "custom" && Math.abs(Prefs.themeHue - applyHue) < 0.003

    function load(src) {
        source = src;
        if (src === "random") { random(); return }
        if (src === "wallpaper" && wallColors.length) { colors = wallColors; pickBest(); return }
        const f = src === "music" ? art : wallpaper;
        if (!f) { colors = []; return }
        loading = true; proc.command = ["bash", Quickshell.shellDir + "/tools/palette.sh", f]; proc.running = true;
    }
    // the most colourful one is picked first (the one that makes the nicest theme)
    function pickBest() { sel = bestOf(colors) }
    function bestOf(list) {
        let best = 0, score = -1;
        list.forEach((c, i) => { const q = Qt.color(c), v = q.hslSaturation * (1 - Math.abs(q.hslLightness - 0.55)); if (v > score) { score = v; best = i } });
        return best;
    }
    // lock / unlock wipe on "Wallpaper": a pastel paper + dots of the wallpaper's most colourful colour
    function setWipe() {
        if (!wallColors.length || !Prefs.ready) return;
        const q = Qt.color(wallColors[bestOf(wallColors)]), h = Math.max(0, q.hslHue), sat = q.hslSaturation < 0.08 ? 0.1 : Math.min(0.6, Math.max(0.35, q.hslSaturation));   // a clear tint, unless the picture is grey
        const pair = [Qt.hsla(h, sat, 0.88, 1).toString(), Qt.hsla(h, sat, 0.79, 1).toString()];
        if (pair[0] !== Prefs.wipeAuto[0] || pair[1] !== Prefs.wipeAuto[1]) Prefs.set("wipeAuto", pair);
    }
    Connections { target: Prefs; function onReadyChanged() { pl.setWipe() } }
    function random() {
        const h = Math.random();
        colors = [0, 1, 2, 3, 4].map(i => Qt.hsla((h + i * 0.13) % 1, 0.62, i % 2 ? 0.80 : 0.70, 1).toString());
        sel = 0;
    }
    function shuffle() {
        if (source === "random") { random(); return }
        if (colors.length < 2) return;
        let n; do n = Math.floor(Math.random() * colors.length); while (n === sel); sel = n;
    }
    function apply() {
        if (selHue < 0) return;
        if (!undo) undo = { theme: Prefs.theme, hue: Prefs.themeHue };
        Prefs.themeHue = applyHue; Prefs.set("theme", "custom");
    }
    function revert() { if (!undo) return; Prefs.themeHue = undo.hue; Prefs.set("theme", undo.theme); undo = null }

    Process { id: proc
        stdout: StdioCollector { onStreamFinished: { const c = this.text.split("\n").filter(x => /^#[0-9A-Fa-f]{6}$/.test(x)); pl.loading = false; if (c.length) { pl.colors = c; pl.pickBest() } } }
        onExited: pl.loading = false }
    Process { id: wallProc
        stdout: StdioCollector { onStreamFinished: { const c = this.text.split("\n").filter(x => /^#[0-9A-Fa-f]{6}$/.test(x)); if (!c.length) return
            pl.wallColors = c; pl.setWipe(); if (pl.source === "wallpaper") { pl.colors = c; pl.pickBest() } } } }
    function loadWall() { wallColors = []; if (!wallpaper) return; wallProc.running = false; wallProc.command = ["bash", Quickshell.shellDir + "/tools/palette.sh", wallpaper]; wallProc.running = true }
    onWallpaperChanged: loadWall()
    onArtChanged: if (source === "music") load("music")
    Component.onCompleted: { loadWall(); if (source !== "wallpaper") load(source) }
}
