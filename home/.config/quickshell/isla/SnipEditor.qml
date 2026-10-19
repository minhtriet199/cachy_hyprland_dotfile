import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

// Snip editor (Print → pick a region): the cut opens right where it was, over the frozen screen.
// Draw on it, then Enter = save to ~/Pictures/screenshot + copy · Esc = copy only (with the drawing, if any).
// Loaded only while snipping (shell.qml LazyLoader); hypr/scripts/snip.sh hands over the files.
PanelWindow {
    id: ed
    property string crop                          // the cut (device px png)
    property string shot                          // whole screen behind it ("" = none)
    property rect sel                             // where the cut sits, in this screen's logical px
    property real dpr: 1                          // device px per logical px
    signal done()
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "isla-snip"

    readonly property var tools: [["pen", "pencil"], ["mark", "marker"], ["arrow", "arrowTool"], ["rect", "rectTool"], ["oval", "ovalTool"],
                                  ["text", "textTool"], ["num", "numTool"], ["pix", "pixelTool"]]
    readonly property var colors: [Theme.berry, Theme.orange, Theme.sun, Theme.leaf, Theme.sea, Theme.purple, "#FFFFFF", Theme.inkPhone]
    property string tool: "pen"
    property color ink: Theme.berry
    property int size: 1                          // 0 thin · 1 medium · 2 thick
    readonly property real w: [3, 6, 11][size] * dpr
    property var items: []                        // finished marks, oldest first
    property var redoList: []
    property var cur: null                        // the mark being drawn
    property bool busy: false
    function push(it) { items = items.concat([it]); redoList = []; cur = null; paper.requestPaint() }
    function undo() { if (!items.length) return; redoList = redoList.concat([items[items.length - 1]]); items = items.slice(0, -1); paper.requestPaint() }
    function redo() { if (!redoList.length) return; items = items.concat([redoList[redoList.length - 1]]); redoList = redoList.slice(0, -1); paper.requestPaint() }
    readonly property int nextNum: items.filter(i => i.t === "num").length + 1

    // finish: save = also keep a file in the screenshot folder. Untouched cuts go out as they are.
    function finish(save) {
        if (busy) return; busy = true; commitText()
        if (!items.length) return send(crop, save)
        photo.grabToImage(r => { const f = crop.replace(/\.png$/, "-edit.png"); r.saveToFile(f); send(f, save) })
    }
    function send(file, save) { out.command = ["sh", "-c", 'f="$1"; if [ "$2" = 1 ]; then d="$HOME/Pictures/screenshot"; mkdir -p "$d"
        n="$d/snip-$(date +%Y%m%d-%H%M%S).png"; cp "$f" "$n"; wl-copy --type image/png < "$f"; notify-send -a Screenshot -i "$n" "Snip saved + copied" "$n"
        else wl-copy --type image/png < "$f"; notify-send -a Screenshot -i "$f" "Snip copied" "Paste with Ctrl + V"; fi', "_", file, save ? "1" : "0"]
        out.running = true; ed.visible = false }
    Process { id: out; onExited: ed.done() }

    // ── frozen screen, dimmed; the cut stays bright ──
    Image { anchors.fill: parent; source: ed.shot ? "file://" + ed.shot : ""; cache: false; asynchronous: false }
    Rectangle { anchors.fill: parent; color: "#000000"; opacity: 0.45 }
    MouseArea { anchors.fill: parent }           // clicks outside the cut do nothing

    // size tag
    UiCandy { x: ed.sel.x; y: Math.max(4, ed.sel.y - 34); width: szT.implicitWidth + 22; height: 26; radius: 13; bw: 2; drop: 2; hi: 0; ink: Theme.inkPhone; fill: Theme.paper
        UiText { id: szT; anchors.centerIn: parent; text: Math.round(ed.sel.width * ed.dpr) + " × " + Math.round(ed.sel.height * ed.dpr); px: 12; w: 700 } }

    // the cut + drawing, kept in device px (scaled down to fit) so the saved picture stays sharp
    Rectangle { x: ed.sel.x - 3; y: ed.sel.y - 3; width: ed.sel.width + 6; height: ed.sel.height + 6; color: "transparent"; border.width: 3; border.color: "#FFFFFF"; radius: 2 }
    Item {
        id: photo
        x: ed.sel.x; y: ed.sel.y; width: ed.sel.width * ed.dpr; height: ed.sel.height * ed.dpr
        scale: 1 / ed.dpr; transformOrigin: Item.TopLeft
        Image { id: base; anchors.fill: parent; source: ed.crop ? "file://" + ed.crop : ""; cache: false; smooth: true }
        // pixelate boxes: the same picture at 1/14 size, blown back up without smoothing
        Repeater {
            model: ed.items.concat(ed.cur ? [ed.cur] : []).filter(i => i.t === "pix")
            delegate: Item {
                required property var modelData
                x: Math.min(modelData.x1, modelData.x2); y: Math.min(modelData.y1, modelData.y2)
                width: Math.abs(modelData.x2 - modelData.x1); height: Math.abs(modelData.y2 - modelData.y1); clip: true
                Image { x: -parent.x; y: -parent.y; width: photo.width; height: photo.height; source: base.source; smooth: false
                    sourceSize: Qt.size(Math.max(1, photo.width / 14), Math.max(1, photo.height / 14)) }
            }
        }
        Canvas {
            id: paper
            anchors.fill: parent
            onPaint: {
                const g = getContext("2d"); g.reset(); g.lineCap = "round"; g.lineJoin = "round"
                for (const i of ed.items.concat(ed.cur ? [ed.cur] : [])) {
                    g.globalAlpha = i.t === "mark" ? 0.4 : 1; g.strokeStyle = i.c; g.fillStyle = i.c; g.lineWidth = i.t === "mark" ? i.w * 3 : i.w
                    if (i.t === "pen" || i.t === "mark") { g.beginPath(); g.moveTo(i.p[0], i.p[1]); for (let k = 2; k < i.p.length; k += 2) g.lineTo(i.p[k], i.p[k + 1]); g.stroke() }
                    else if (i.t === "rect") g.strokeRect(Math.min(i.x1, i.x2), Math.min(i.y1, i.y2), Math.abs(i.x2 - i.x1), Math.abs(i.y2 - i.y1))
                    else if (i.t === "oval") { g.beginPath(); g.ellipse(Math.min(i.x1, i.x2), Math.min(i.y1, i.y2), Math.abs(i.x2 - i.x1), Math.abs(i.y2 - i.y1)); g.stroke() }
                    else if (i.t === "arrow") {
                        const a = Math.atan2(i.y2 - i.y1, i.x2 - i.x1), h = i.w * 3 + 10 * ed.dpr
                        g.beginPath(); g.moveTo(i.x1, i.y1); g.lineTo(i.x2 - Math.cos(a) * h * 0.6, i.y2 - Math.sin(a) * h * 0.6); g.stroke()
                        g.beginPath(); g.moveTo(i.x2, i.y2); g.lineTo(i.x2 - h * Math.cos(a - 0.45), i.y2 - h * Math.sin(a - 0.45))
                        g.lineTo(i.x2 - h * Math.cos(a + 0.45), i.y2 - h * Math.sin(a + 0.45)); g.closePath(); g.fill()
                    } else if (i.t === "num") {
                        const r = 13 * ed.dpr + i.w
                        g.beginPath(); g.arc(i.x1, i.y1, r, 0, 2 * Math.PI); g.fill(); g.lineWidth = 2.5 * ed.dpr; g.strokeStyle = String(Theme.inkPhone); g.stroke()
                        g.fillStyle = i.c === "#ffffff" ? String(Theme.inkPhone) : "#FFFFFF"; g.font = "700 " + Math.round(r * 1.15) + "px \"" + Theme.display + "\""
                        g.textAlign = "center"; g.textBaseline = "middle"; g.fillText(String(i.n), i.x1, i.y1 + r * 0.05)
                    } else if (i.t === "text") {
                        g.font = "700 " + Math.round(i.w * 2.4 + 12 * ed.dpr) + "px \"" + Theme.display + "\""; g.textBaseline = "top"; g.textAlign = "left"
                        g.lineWidth = Math.max(2, i.w * 0.6); g.strokeStyle = i.c === "#ffffff" ? String(Theme.inkPhone) : "#FFFFFF"; g.strokeText(i.s, i.x1, i.y1); g.fillText(i.s, i.x1, i.y1)
                    }
                }
            }
        }
        // typing a label (Text tool): Enter keeps it, Esc drops it
        TextInput {
            id: typer
            visible: false; color: ed.ink; font.family: Theme.display; font.weight: 700; font.pixelSize: Math.round(ed.w * 2.4 + 12 * ed.dpr)
            Keys.onReturnPressed: ed.commitText()
            Keys.onEscapePressed: { text = ""; visible = false; keys.forceActiveFocus() }
        }
        MouseArea {
            anchors.fill: parent; cursorShape: ed.tool === "text" ? Qt.IBeamCursor : Qt.CrossCursor
            onPressed: m => {
                ed.commitText()
                if (ed.tool === "text") { typer.x = m.x; typer.y = m.y; typer.text = ""; typer.visible = true; typer.forceActiveFocus(); return }
                if (ed.tool === "num") { ed.push({ t: "num", c: String(ed.ink), w: ed.w, x1: m.x, y1: m.y, n: ed.nextNum }); return }
                ed.cur = ed.tool === "pen" || ed.tool === "mark" ? { t: ed.tool, c: String(ed.ink), w: ed.w, p: [m.x, m.y] }
                       : { t: ed.tool, c: String(ed.ink), w: ed.w, x1: m.x, y1: m.y, x2: m.x, y2: m.y }
            }
            onPositionChanged: m => { if (!ed.cur) return; const c = Object.assign({}, ed.cur)
                if (c.p) c.p = c.p.concat([m.x, m.y]); else { c.x2 = m.x; c.y2 = m.y }
                ed.cur = c; paper.requestPaint() }
            onReleased: { const c = ed.cur; if (!c) return
                if (c.p ? c.p.length > 2 : Math.abs(c.x2 - c.x1) + Math.abs(c.y2 - c.y1) > 4) ed.push(c); else { ed.cur = null; paper.requestPaint() } }
        }
    }
    function commitText() {
        if (!typer.visible) return
        if (typer.text.trim()) push({ t: "text", c: String(ink), w: w, x1: typer.x, y1: typer.y, s: typer.text })
        typer.visible = false; typer.text = ""; keys.forceActiveFocus()
    }

    // ── toolbar: below the cut, or above it, or inside its bottom edge when there's no room ──
    Column {
        id: bar
        readonly property real below: ed.sel.y + ed.sel.height + 14
        x: Math.max(8, Math.min(ed.width - width - 8, ed.sel.x + ed.sel.width / 2 - width / 2))
        y: below + height < ed.height - 8 ? below : ed.sel.y - height - 44 > 8 ? ed.sel.y - height - 44 : ed.sel.y + ed.sel.height - height - 10
        spacing: 6
        UiCandy {
            width: row.implicitWidth + 20; height: 50; radius: 25; bw: 3; drop: 5; hi: 3; ink: Theme.inkPhone; fill: Theme.paper
            Row {
                id: row; anchors.centerIn: parent; spacing: 4
                Repeater { model: ed.tools
                    delegate: UiCandy { required property var modelData
                        readonly property bool on: ed.tool === modelData[0]
                        width: 36; height: 36; radius: 12; bw: on ? 2.5 : 0; drop: on ? 2 : 0; hi: 0; ink: Theme.inkPhone; fill: on ? Theme.gOn : "transparent"; pressable: true
                        onClicked: { ed.commitText(); ed.tool = modelData[0] }
                        Glyph { anchors.centerIn: parent; name: modelData[1]; size: 18; stroke: 2.4; color: Theme.textDeep } } }
                Rectangle { width: 2; height: 26; radius: 1; color: Theme.inkPhone; opacity: 0.25; anchors.verticalCenter: parent.verticalCenter }
                Repeater { model: ed.colors
                    delegate: Item { required property var modelData
                        width: 26; height: 36
                        Rectangle { anchors.centerIn: parent; readonly property bool on: Qt.colorEqual(ed.ink, modelData)
                            width: on ? 24 : 18; height: width; radius: width / 2; color: modelData; border.width: on ? 3 : 2; border.color: Theme.inkPhone
                            Behavior on width { NumberAnimation { duration: 120 } } }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: ed.ink = modelData } } }
                UiCandy { width: 36; height: 36; radius: 12; bw: 0; drop: 0; hi: 0; fill: "transparent"; pressable: true; onClicked: ed.size = (ed.size + 1) % 3
                    Rectangle { anchors.centerIn: parent; width: [6, 11, 17][ed.size]; height: width; radius: width / 2; color: ed.ink; border.width: 2; border.color: Theme.inkPhone } }
                Rectangle { width: 2; height: 26; radius: 1; color: Theme.inkPhone; opacity: 0.25; anchors.verticalCenter: parent.verticalCenter }
                Repeater { model: [["undo", () => ed.undo(), ed.items.length > 0], ["redo", () => ed.redo(), ed.redoList.length > 0]]
                    delegate: UiCandy { required property var modelData
                        width: 36; height: 36; radius: 12; bw: 0; drop: 0; hi: 0; fill: "transparent"; pressable: true; opacity: modelData[2] ? 1 : 0.35
                        onClicked: modelData[1]()
                        Glyph { anchors.centerIn: parent; name: modelData[0]; size: 18; stroke: 2.4; color: Theme.textDeep } } }
                Item { width: 4; height: 1 }
                UiCandy { width: 74; height: 36; radius: 18; bw: 2.5; drop: 3; hi: 2; ink: Theme.inkPhone; fill: Theme.paper; pressable: true; onClicked: ed.finish(true)
                    UiText { anchors.centerIn: parent; text: "Save"; px: 14; w: 700 } }
                UiCandy { width: 74; height: 36; radius: 18; bw: 2.5; drop: 3; hi: 3; ink: Theme.inkPhone; fill: Theme.gOn; pressable: true; onClicked: ed.finish(false)
                    UiText { anchors.centerIn: parent; text: "Copy"; px: 14; w: 700; color: Theme.textDeep } }
            }
        }
        UiText { anchors.horizontalCenter: parent.horizontalCenter; text: "Enter  save + copy  ·  Esc  copy  ·  Ctrl+Z  undo"; fam: "n"; px: 11; w: 800; color: "#FFFFFF"; opacity: 0.85 }
    }

    Item {
        id: keys
        focus: true
        Component.onCompleted: forceActiveFocus()
        Keys.onReturnPressed: ed.finish(true)
        Keys.onEnterPressed: ed.finish(true)
        Keys.onEscapePressed: ed.finish(false)
        Keys.onPressed: e => {
            const ctrl = e.modifiers & Qt.ControlModifier
            if (ctrl && e.key === Qt.Key_Z) e.modifiers & Qt.ShiftModifier ? ed.redo() : ed.undo()
            else if (ctrl && e.key === Qt.Key_Y) ed.redo()
            else if (ctrl && e.key === Qt.Key_S) ed.finish(true)
            else if (ctrl && e.key === Qt.Key_C) ed.finish(false)
            else return
            e.accepted = true
        }
    }
}
