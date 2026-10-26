import QtQuick
import Quickshell
import Quickshell.Io

// Mouse & touchpad page: pointer speed + acceleration, touchpad (tap, natural scroll, typing guard,
// scroll speed), and cursor size. (Text size in apps moved to the Windows page.) Changes show at once and
// are saved (~/.local/state/hypr/input via hypr/scripts/inputctl.py, read back by config/input_island.lua).
Item {
    id: mp
    property var svc
    implicitHeight: col.implicitHeight
    readonly property string tool: Quickshell.env("HOME") + "/.config/hypr/scripts/inputctl.py"
    property var v: ({ sensitivity: "0", accel: "flat", natural_scroll: "0", tap_to_click: "1", dwt: "1", tp_scroll: "1", cursor_size: "24", text_scale: "1" })
    function num(k) { return parseFloat(v[k]) }
    function on(k) { return v[k] === "1" }

    Process { running: true; command: ["python3", mp.tool, "get"]
        stdout: StdioCollector { onStreamFinished: { try { mp.v = JSON.parse(this.text) } catch (e) {} } } }
    // sliders send many values while dragging: keep the newest and apply ~8 times a second
    property var pending: ({})
    function put(k, val) { if (k === "cursor_size") cursorDirty = true; const n = Object.assign({}, v); n[k] = String(val); v = n; const p = pending; p[k] = val; pending = p; if (!sendT.running) sendT.start() }
    Timer { id: sendT; interval: 120; onTriggered: {
        if (setP.running) { restart(); return }
        const args = Object.keys(mp.pending).map(k => k + "=" + mp.pending[k]); mp.pending = ({})
        setP.command = ["python3", mp.tool, "set"].concat(args); setP.running = true } }
    Process { id: setP; onExited: if (mp.cursorDirty) { mp.cursorDirty = false; reshape.enabled = true; reshapeT.restart() } }
    // Hyprland only redraws the cursor at the new size when the window asks for a shape again, so briefly ask
    // for another shape and then the normal one (else the old size stays until the pointer leaves the phone)
    property bool cursorDirty: false
    Timer { id: reshapeT; interval: 60; onTriggered: reshape.enabled = false }

    component Label: UiText { fam: "n"; px: 11; w: 900; track: 1.4; color: Theme.textSoft; height: 18 }
    // slider with a label + value on the right; lo/hi are the real values, the slider runs 0…1
    component Slide: Column {
        id: sl
        property string key
        property string title
        property real lo: 0
        property real hi: 1
        property real step: 0.05
        property color tint: Theme.sea
        property var fmt: x => x.toFixed(2)
        width: parent.width; spacing: 4
        Item {
            width: parent.width; height: 18
            UiText { text: sl.title; px: 13; w: 700 }
            UiText { anchors.right: parent.right; text: sl.fmt(mp.num(sl.key)); fam: "n"; px: 11.5; w: 900; color: Theme.textSoft }
        }
        UiSlider { width: parent.width; color: sl.tint; step: sl.step / (sl.hi - sl.lo)
            value: (mp.num(sl.key) - sl.lo) / (sl.hi - sl.lo)
            onPicked: x => mp.put(sl.key, Math.round((sl.lo + x * (sl.hi - sl.lo)) / sl.step) * sl.step) }
    }
    component Toggle: UiRow {
        id: tg
        property string key
        width: parent.width; active: mp.on(key)
        onClicked: mp.put(key, mp.on(key) ? 0 : 1)
        UiSwitch { on: mp.on(tg.key); onToggled: mp.put(tg.key, mp.on(tg.key) ? 0 : 1) }
    }

    MouseArea { id: reshape; anchors.fill: parent; z: 100; enabled: false; hoverEnabled: true; acceptedButtons: Qt.NoButton; cursorShape: Qt.CrossCursor }

    Column {
        id: col
        width: mp.width; spacing: 10

        Label { text: "MOUSE" }
        Slide { key: "sensitivity"; title: "Pointer speed"; lo: -1; hi: 1; step: 0.05; tint: Theme.sea
            fmt: x => x === 0 ? "normal" : (x > 0 ? "+" : "") + Math.round(x * 100) + "%" }
        UiRow {
            width: parent.width; glyph: "crosshair"; title: "Speed up with fast moves"
            sub: mp.v.accel === "adaptive" ? "On · fast flicks go further" : "Off · same distance every time (best for games)"
            active: mp.v.accel === "adaptive"
            onClicked: mp.put("accel", mp.v.accel === "adaptive" ? "flat" : "adaptive")
            UiSwitch { on: mp.v.accel === "adaptive"; onToggled: mp.put("accel", mp.v.accel === "adaptive" ? "flat" : "adaptive") }
        }

        Item { width: 1; height: 2 }
        Label { text: "TOUCHPAD" }
        Toggle { key: "tap_to_click"; glyph: "smile"; title: "Tap to click"; sub: mp.on("tap_to_click") ? "A light tap clicks" : "Press the pad down to click" }
        Toggle { key: "natural_scroll"; glyph: "arrowRight"; title: "Natural scrolling"; sub: mp.on("natural_scroll") ? "Content follows your fingers (like a phone)" : "Fingers down = page down" }
        Toggle { key: "dwt"; glyph: "keyboard"; title: "Ignore touchpad while typing"; sub: mp.on("dwt") ? "No stray clicks from your palm" : "Off" }
        Slide { key: "tp_scroll"; title: "Scroll speed"; lo: 0.2; hi: 3; step: 0.1; tint: Theme.leaf; fmt: x => x.toFixed(1) + "×" }
        UiText { width: parent.width; wrapMode: Text.Wrap; fam: "n"; px: 10.5; w: 800; color: Theme.textSoft
            text: "Gestures: 4 fingers sideways = workspaces, 3 down = close, 3 up = full screen, 3 right = back, 3 left = forward (browsers, Dolphin). In the browser 2 fingers sideways also go back / forward." }

        Item { width: 1; height: 2 }
        Label { text: "EASY TO SEE" }
        Slide { key: "cursor_size"; title: "Cursor size"; lo: 16; hi: 64; step: 4; tint: Theme.purple; fmt: x => Math.round(x) + " px" }
        UiRow {
            width: parent.width; glyph: "reload"; title: "Reset to default"; sub: "Normal speed, tap to click, 24 px cursor"
            onClicked: { mp.put("sensitivity", 0); mp.put("accel", "flat"); mp.put("tap_to_click", 1); mp.put("natural_scroll", 0)
                         mp.put("dwt", 1); mp.put("tp_scroll", 1); mp.put("cursor_size", 24) }
        }
    }
}
