import QtQuick
import Quickshell
import Quickshell.Io

// Windows page: how app windows look in Hyprland — see-through when focused / not focused, dark or light backdrop,
// border colours and thickness, corner radius, gaps. Changes show at once and are saved
// (~/.local/state/hypr/look via hypr/scripts/lookctl.py, read back by hypr/config/look.lua).
Item {
    id: wp
    property var svc
    readonly property bool narrow: width < 560
    implicitHeight: col.implicitHeight
    readonly property string tool: Quickshell.env("HOME") + "/.config/hypr/scripts/lookctl.py"
    property var v: ({ active_opacity: 0.95, inactive_opacity: 0.9, border_size: 2, rounding: 10, gaps_in: 3, gaps_out: 8,
                       active1: "82dccc", active2: "007d6f", inactive: "798bb2", backdrop: "dark", terminal_opacity: 0.88 })
    property bool loaded: false
    function num(k) { return parseFloat(v[k]) }

    Process { id: getP; running: true; command: [wp.tool, "get"]
        stdout: StdioCollector { onStreamFinished: { try { wp.v = JSON.parse(this.text); wp.loaded = true } catch (e) {} } } }
    // sliders send many values while dragging: keep the newest and apply ~8 times a second
    property var pending: ({})
    function put(k, val) { const n = Object.assign({}, v); n[k] = val; v = n; const p = pending; p[k] = val; pending = p; if (!sendT.running) sendT.start() }
    Timer { id: sendT; interval: 120; onTriggered: {
        if (setP.running) { restart(); return }
        const args = Object.keys(wp.pending).map(k => k + "=" + wp.pending[k]); wp.pending = ({})
        setP.command = [wp.tool, "set"].concat(args); setP.running = true } }
    Process { id: setP }
    function hex(c) { return String(c).slice(1, 7) }

    component Label: UiText { fam: "n"; px: 11; w: 900; track: 1.4; color: Theme.textSoft; height: 18 }
    // [name, top colour, bottom colour] for the focused border (two-tone, like the stickers)
    readonly property var activeSets: [
        ["Cachy", "#82DCCC", "#007D6F"], ["Sea", Theme.sea, Theme.seaDeep], ["Lilac", Theme.lilac, Theme.purple],
        ["Leaf", Theme.leaf, Theme.leafDeep], ["Sun", Theme.sun, Theme.orange], ["Peach", Theme.peach, Theme.berry],
        ["Berry", Theme.pinkSoft, Theme.berry], ["Ink", Theme.ink, Theme.inkPhone]]
    readonly property var inactiveSets: [["Grey", "#798BB2"], ["Ink", Theme.ink], ["Soft", Theme.textSoft], ["Sand", Theme.sand],
        ["Sea", Theme.seaSoft], ["Lilac", Theme.lilacSoft], ["Cream", Theme.cream]]

    component Slide: Column {
        id: sl
        property string key
        property string title
        property real lo: 0
        property real hi: 10
        property bool pct: false
        property color tint: Theme.sea
        width: parent.width; spacing: 4
        Label { text: sl.title }
        Item {
            width: parent.width; height: 30
            UiSlider { width: parent.width - nb.width - 12; anchors.verticalCenter: parent.verticalCenter; max: sl.hi; step: sl.pct ? 0.05 : 1; color: sl.tint; value: wp.num(sl.key)
                onPicked: x => wp.put(sl.key, sl.pct ? Math.max(sl.lo, Math.round(x * 100) / 100) : Math.max(sl.lo, Math.round(x))) }
            WinNumBox { id: nb; page: wp; anchors.right: parent.right; key: sl.key; pct: sl.pct; vmin: sl.lo; vmax: sl.hi }
        }
    }

    Column {
        id: col
        width: wp.width; spacing: 12

        // live preview: two little windows using the current look
        UiCandy {
            width: parent.width; height: 118; radius: 16; bw: 2.5; drop: 3; hi: 0; ink: Theme.inkPhone; fill: Theme.gSea
            Item {
                id: pv
                readonly property real s: 0.6          // preview is drawn a bit smaller than real
                readonly property real go: wp.num("gaps_out") * s
                readonly property real gi: wp.num("gaps_in") * s
                readonly property real bw: Math.max(wp.num("border_size") * s, wp.num("border_size") > 0 ? 1 : 0)
                readonly property real rr: wp.num("rounding") * s
                x: 10; y: 10; width: parent.width - 20; height: parent.height - 20; clip: true
                Repeater {
                    model: 2
                    delegate: Rectangle {
                        required property int index
                        readonly property bool isFocus: index === 0
                        x: pv.go + (index === 0 ? 0 : (pv.width - 2 * pv.go - pv.gi) / 2 + pv.gi)
                        y: pv.go; width: (pv.width - 2 * pv.go - pv.gi) / 2; height: pv.height - 2 * pv.go
                        radius: pv.rr + pv.bw; color: "transparent"
                        border.width: pv.bw
                        border.color: isFocus ? "#" + wp.v.active1 : "#" + wp.v.inactive
                        Rectangle { anchors.fill: parent; anchors.margins: pv.bw; radius: pv.rr
                            color: Theme.paper; opacity: wp.num(parent.isFocus ? "active_opacity" : "inactive_opacity")
                            UiText { anchors.centerIn: parent; text: parent.parent.isFocus ? "Focused" : "Not focused"; fam: "n"; px: 11; w: 900; color: Theme.text } }
                    }
                }
            }
        }

        Label { text: "SEE-THROUGH" }
        Slide { key: "active_opacity"; title: "FOCUSED WINDOW"; lo: 0.3; hi: 1; pct: true; tint: Theme.sea }
        Slide { key: "inactive_opacity"; title: "OTHER WINDOWS"; lo: 0.3; hi: 1; pct: true; tint: Theme.lilac }
        Slide { key: "terminal_opacity"; title: "TERMINAL BACKGROUND"; lo: 0.3; hi: 1; pct: true; tint: Theme.peach }
        UiText { width: parent.width; wrapMode: Text.Wrap; fam: "n"; px: 10.5; w: 800; color: Theme.textSoft
            text: "100% = solid. The terminal (kitty) only fades its background, so text stays sharp — focused or not. Firefox, video players and full-screen games always stay solid." }
        SetSeg { width: parent.width; label: "Behind"; options: ["Dark", "Light"]; current: wp.v.backdrop === "light" ? "Light" : "Dark"
            onPicked: x => wp.put("backdrop", x.toLowerCase()) }
        UiText { width: parent.width; wrapMode: Text.Wrap; fam: "n"; px: 10.5; w: 800; color: Theme.textSoft
            text: "What shows through see-through windows: Dark dims the blur so dark apps stay easy to read, Light frosts it for light apps." }

        Item { width: 1; height: 2 }
        Label { text: "SHAPE" }
        Slide { key: "border_size"; title: "BORDER THICKNESS"; lo: 0; hi: 8; tint: Theme.purple }
        Slide { key: "rounding"; title: "CORNER RADIUS"; lo: 0; hi: 30; tint: Theme.peach }
        Slide { key: "gaps_in"; title: "GAP BETWEEN WINDOWS"; lo: 0; hi: 30; tint: Theme.leaf }
        Slide { key: "gaps_out"; title: "GAP TO SCREEN EDGE"; lo: 0; hi: 60; tint: Theme.sunDeep }

        Item { width: 1; height: 2 }
        Label { text: "FOCUSED BORDER" }
        Flow {
            width: parent.width; spacing: 8
            Repeater {
                model: wp.activeSets
                delegate: UiCandy {
                    required property var modelData
                    readonly property bool on: wp.v.active1.toLowerCase() === wp.hex(modelData[1]).toLowerCase() && wp.v.active2.toLowerCase() === wp.hex(modelData[2]).toLowerCase()
                    width: 72; height: 34; radius: 12; bw: on ? 3 : 2; drop: on ? 0 : 2; hi: 2; ink: Theme.inkPhone
                    fill: [modelData[1], modelData[2]]; pressable: true
                    onClicked: { wp.put("active1", wp.hex(modelData[1])); wp.put("active2", wp.hex(modelData[2])); wheel.load() }
                    UiText { anchors.centerIn: parent; text: (on ? "✓ " : "") + modelData[0]; px: 12; w: 700; color: "#FFFFFF" }
                }
            }
        }
        Label { text: "OTHER WINDOWS' BORDER" }
        Flow {
            width: parent.width; spacing: 8
            Repeater {
                model: wp.inactiveSets
                delegate: UiCandy {
                    required property var modelData
                    readonly property bool on: wp.v.inactive.toLowerCase() === wp.hex(modelData[1]).toLowerCase()
                    width: 72; height: 34; radius: 12; bw: on ? 3 : 2; drop: on ? 0 : 2; hi: 0; ink: Theme.inkPhone
                    fill: modelData[1]; pressable: true
                    onClicked: { wp.put("inactive", wp.hex(modelData[1])); wheel.load() }
                    UiText { anchors.centerIn: parent; text: (on ? "✓ " : "") + modelData[0]; px: 12; w: 700
                        color: Qt.colorEqual(modelData[1], Theme.ink) || Qt.colorEqual(modelData[1], Theme.textSoft) || modelData[0] === "Grey" ? "#FFFFFF" : Theme.text }
                }
            }
        }

        Item { width: 1; height: 2 }
        Label { text: "PICK ANY COLOUR" }
        // which colour the wheel changes: focused border (top / bottom of its two-tone) or other windows
        Flow {
            width: parent.width; spacing: 8
            Repeater {
                model: [["active1", "Focused · 1"], ["active2", "Focused · 2"], ["inactive", "Other windows"]]
                delegate: UiCandy {
                    id: chip
                    required property var modelData
                    readonly property bool on: wheel.target === modelData[0]
                    width: chipT.implicitWidth + 44; height: 32; radius: 12; bw: on ? 2.5 : 2; drop: on ? 0 : 2; hi: 0; ink: Theme.inkPhone
                    fill: on ? Theme.gActive : Theme.paper; pressable: true
                    onClicked: wheel.target = modelData[0]
                    Rectangle { x: 9; anchors.verticalCenter: parent.verticalCenter; width: 16; height: 16; radius: 8
                        color: "#" + wp.v[chip.modelData[0]]; border.width: 2; border.color: Theme.inkPhone }
                    UiText { id: chipT; x: 31; anchors.verticalCenter: parent.verticalCenter; text: chip.modelData[1]; px: 12; w: 700 }
                }
            }
        }
        WinColorWheel { id: wheel; page: wp; width: parent.width }

        Item { width: 1; height: 2 }
        UiRow {
            width: parent.width; glyph: "reload"; title: "Reset to default"; sub: "95% / 90%, terminal 88%, dark backdrop, 2 px border, 10 px corners, gaps 3 / 8"
            onClicked: { wp.put("active_opacity", 0.95); wp.put("inactive_opacity", 0.9); wp.put("border_size", 2); wp.put("rounding", 10)
                         wp.put("gaps_in", 3); wp.put("gaps_out", 8); wp.put("active1", "82dccc"); wp.put("active2", "007d6f"); wp.put("inactive", "798bb2"); wp.put("backdrop", "dark"); wp.put("terminal_opacity", 0.88); wheel.load() }
        }
    }
}
