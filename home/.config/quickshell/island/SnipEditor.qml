import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

// Snip editor (Print → pick a region): the cut opens right where it was, over the frozen screen.
// Draw on it, then Enter = save to ~/Pictures/screenshot + copy · Esc = copy only (with the drawing, if any).
// Handles on the edges resize the cut (it then shows from the whole frozen screen). Select tool: click a mark to
// move it, Delete removes it. Marks are kept in device px from the FIRST cut's corner (dx/dy = how far it moved).
// Loaded only while snipping (shell.qml LazyLoader); hypr/scripts/snip.sh hands over the files.
PanelWindow {
    id: sn
    property string crop                          // the cut (device px png)
    property string shot                          // whole screen behind it ("" = none)
    property rect sel                             // where the cut sits, in this screen's logical px
    property real dpr: 1                          // device px per logical px
    property rect sel0                            // the first cut (marks are measured from its corner)
    Component.onCompleted: sel0 = sel
    readonly property bool reshaped: shot !== "" && (sel.x !== sel0.x || sel.y !== sel0.y || sel.width !== sel0.width || sel.height !== sel0.height)
    readonly property real dx: (sel.x - sel0.x) * dpr
    readonly property real dy: (sel.y - sel0.y) * dpr
    signal done()
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "island-snip"

    readonly property var tools: [["select", "pointer"], ["pen", "pencil"], ["mark", "marker"], ["arrow", "arrowTool"], ["rect", "rectTool"], ["oval", "ovalTool"],
                                  ["text", "textTool"], ["num", "numTool"], ["pix", "pixelTool"]]
    readonly property var colors: [Theme.berry, Theme.orange, Theme.sun, Theme.leaf, Theme.sea, Theme.purple, "#FFFFFF", Theme.inkPhone]
    property string tool: "pen"
    property color ink: Theme.berry
    property int size: 1                          // 0 thin · 1 medium · 2 thick
    readonly property real w: [3, 6, 11][size] * dpr
    property var items: []                        // finished marks, oldest first
    property var undoList: []                     // earlier `items` lists (so moves and deletes undo too)
    property var redoList: []
    property var cur: null                        // the mark being drawn
    property int picked: -1                       // Select tool: index in items
    property bool busy: false
    function snap() { undoList = undoList.concat([items]); redoList = [] }
    function push(it) { snap(); items = items.concat([it]); cur = null; paper.requestPaint() }
    function undo() { if (!undoList.length) return; redoList = redoList.concat([items]); items = undoList[undoList.length - 1]; undoList = undoList.slice(0, -1); picked = -1; paper.requestPaint() }
    function redo() { if (!redoList.length) return; undoList = undoList.concat([items]); items = redoList[redoList.length - 1]; redoList = redoList.slice(0, -1); picked = -1; paper.requestPaint() }
    function removePicked() { if (picked < 0) return; snap(); items = items.filter((x, k) => k !== picked); picked = -1; paper.requestPaint() }
    // a mark's box [x, y, w, h] (mark coords) and "is this point on it"
    function box(i) {
        const fs = Math.round(i.w * 2.4 + 12 * dpr), r = 13 * dpr + i.w
        if (i.p) { let a = Infinity, b = Infinity, c = -Infinity, e = -Infinity
            for (let k = 0; k < i.p.length; k += 2) { a = Math.min(a, i.p[k]); c = Math.max(c, i.p[k]); b = Math.min(b, i.p[k + 1]); e = Math.max(e, i.p[k + 1]) }
            const pad = i.t === "mark" ? i.w * 1.5 : i.w / 2; return [a - pad, b - pad, c - a + 2 * pad, e - b + 2 * pad] }
        if (i.t === "num") return [i.x1 - r, i.y1 - r, 2 * r, 2 * r]
        if (i.t === "text") return [i.x1, i.y1, i.s.length * fs * 0.6, fs * 1.2]
        const pad = i.t === "arrow" ? i.w * 3 + 10 * dpr : i.w / 2
        return [Math.min(i.x1, i.x2) - pad, Math.min(i.y1, i.y2) - pad, Math.abs(i.x2 - i.x1) + 2 * pad, Math.abs(i.y2 - i.y1) + 2 * pad]
    }
    function near(px, py, ax, ay, bx, by) {
        const vx = bx - ax, vy = by - ay, l = vx * vx + vy * vy, t = l ? Math.max(0, Math.min(1, ((px - ax) * vx + (py - ay) * vy) / l)) : 0
        return Math.hypot(px - ax - t * vx, py - ay - t * vy)
    }
    function hit(px, py) {
        const slack = 8 * dpr
        for (let k = items.length - 1; k >= 0; k--) { const i = items[k]
            if (i.p) { const reach = (i.t === "mark" ? i.w * 1.5 : i.w / 2) + slack
                for (let j = 0; j + 3 < i.p.length || j === 0; j += 2) if (near(px, py, i.p[j], i.p[j + 1], i.p[j + 2] ?? i.p[j], i.p[j + 3] ?? i.p[j + 1]) < reach) return k }
            else if (i.t === "arrow") { if (near(px, py, i.x1, i.y1, i.x2, i.y2) < i.w / 2 + slack + 4 * dpr) return k }
            else { const b = box(i); if (px >= b[0] - slack && px <= b[0] + b[2] + slack && py >= b[1] - slack && py <= b[1] + b[3] + slack) return k }
        }
        return -1
    }
    function moved(i, mx, my) { const c = Object.assign({}, i)
        if (c.p) c.p = c.p.map((v, k) => v + (k % 2 ? my : mx))
        else { c.x1 += mx; c.y1 += my; if (c.x2 !== undefined) { c.x2 += mx; c.y2 += my } }
        return c }
    readonly property int nextNum: items.filter(i => i.t === "num").length + 1

    // finish: save = also keep a file in the screenshot folder. Untouched cuts go out as they are.
    function finish(save) {
        if (busy) return; busy = true; commitText(); picked = -1
        if (!items.length && !reshaped) return send(crop, save)
        photo.grabToImage(r => { const f = crop.replace(/\.png$/, "-edit.png"); r.saveToFile(f); send(f, save) })
    }
    function send(file, save) { out.command = ["sh", "-c", 'f="$1"; if [ "$2" = 1 ]; then d="$HOME/Pictures/screenshot"; mkdir -p "$d"
        n="$d/snip-$(date +%Y%m%d-%H%M%S).png"; cp "$f" "$n"; wl-copy --type image/png < "$f"; notify-send -a Screenshot -i "$n" "Snip saved + copied" "$n"
        else wl-copy --type image/png < "$f"; notify-send -a Screenshot -i "$f" "Snip copied" "Paste with Ctrl + V"; fi', "_", file, save ? "1" : "0"]
        out.running = true; sn.visible = false }
    Process { id: out; onExited: sn.done() }

    // ── frozen screen, dimmed; the cut stays bright ──
    Image { anchors.fill: parent; source: sn.shot ? "file://" + sn.shot : ""; cache: false; asynchronous: false }
    Rectangle { anchors.fill: parent; color: Theme.phoneBack; opacity: 0.55 }
    // click outside the cut, or right-click anywhere = same as Esc (copy, close)
    MouseArea { anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton; onClicked: sn.wheelOn ? sn.openWheel(false) : sn.finish(false) }

    // size tag
    UiCandy { x: sn.sel.x; y: Math.max(4, sn.sel.y - 34); width: szT.implicitWidth + 22; height: 26; radius: 13; bw: 2; drop: 2; hi: 0; ink: Theme.inkPhone; fill: Theme.paper
        UiText { id: szT; anchors.centerIn: parent; text: Math.round(sn.sel.width * sn.dpr) + " × " + Math.round(sn.sel.height * sn.dpr); px: 12; w: 700 } }

    // the cut + drawing, kept in device px (scaled down to fit) so the saved picture stays sharp
    Rectangle { x: sn.sel.x - 3; y: sn.sel.y - 3; width: sn.sel.width + 6; height: sn.sel.height + 6; color: "transparent"; border.width: 3; border.color: Theme.paper; radius: 2 }
    Item {
        id: photo
        x: sn.sel.x; y: sn.sel.y; width: sn.sel.width * sn.dpr; height: sn.sel.height * sn.dpr
        scale: 1 / sn.dpr; transformOrigin: Item.TopLeft; clip: true
        // the picture: the cut as it came, or (once resized) the whole frozen screen shifted under it
        readonly property real picX: sn.reshaped ? -sn.sel.x * sn.dpr : 0
        readonly property real picY: sn.reshaped ? -sn.sel.y * sn.dpr : 0
        Image { id: base; x: photo.picX; y: photo.picY; width: sn.reshaped ? implicitWidth : photo.width; height: sn.reshaped ? implicitHeight : photo.height
            source: sn.reshaped ? "file://" + sn.shot : sn.crop ? "file://" + sn.crop : ""; cache: false; smooth: true }
        // pixelate boxes: the same picture at 1/14 size, blown back up without smoothing
        Repeater {
            model: sn.items.concat(sn.cur ? [sn.cur] : []).filter(i => i.t === "pix")
            delegate: Item {
                required property var modelData
                x: Math.min(modelData.x1, modelData.x2) - sn.dx; y: Math.min(modelData.y1, modelData.y2) - sn.dy
                width: Math.abs(modelData.x2 - modelData.x1); height: Math.abs(modelData.y2 - modelData.y1); clip: true
                Image { x: photo.picX - parent.x; y: photo.picY - parent.y; width: base.width; height: base.height; source: base.source; smooth: false
                    sourceSize: Qt.size(Math.max(1, base.width / 14), Math.max(1, base.height / 14)) }
            }
        }
        Canvas {
            id: paper
            anchors.fill: parent
            onPaint: {
                const g = getContext("2d"); g.reset(); g.lineCap = "round"; g.lineJoin = "round"; g.translate(-sn.dx, -sn.dy)
                for (const i of sn.items.concat(sn.cur ? [sn.cur] : [])) {
                    g.globalAlpha = i.t === "mark" ? 0.4 : 1; g.strokeStyle = i.c; g.fillStyle = i.c; g.lineWidth = i.t === "mark" ? i.w * 3 : i.w
                    if (i.t === "pen" || i.t === "mark") { g.beginPath(); g.moveTo(i.p[0], i.p[1]); for (let k = 2; k < i.p.length; k += 2) g.lineTo(i.p[k], i.p[k + 1]); g.stroke() }
                    else if (i.t === "rect") g.strokeRect(Math.min(i.x1, i.x2), Math.min(i.y1, i.y2), Math.abs(i.x2 - i.x1), Math.abs(i.y2 - i.y1))
                    else if (i.t === "oval") { g.beginPath(); g.ellipse(Math.min(i.x1, i.x2), Math.min(i.y1, i.y2), Math.abs(i.x2 - i.x1), Math.abs(i.y2 - i.y1)); g.stroke() }
                    else if (i.t === "arrow") {
                        const a = Math.atan2(i.y2 - i.y1, i.x2 - i.x1), h = i.w * 3 + 10 * sn.dpr
                        g.beginPath(); g.moveTo(i.x1, i.y1); g.lineTo(i.x2 - Math.cos(a) * h * 0.6, i.y2 - Math.sin(a) * h * 0.6); g.stroke()
                        g.beginPath(); g.moveTo(i.x2, i.y2); g.lineTo(i.x2 - h * Math.cos(a - 0.45), i.y2 - h * Math.sin(a - 0.45))
                        g.lineTo(i.x2 - h * Math.cos(a + 0.45), i.y2 - h * Math.sin(a + 0.45)); g.closePath(); g.fill()
                    } else if (i.t === "num") {
                        const r = 13 * sn.dpr + i.w
                        g.beginPath(); g.arc(i.x1, i.y1, r, 0, 2 * Math.PI); g.fill(); g.lineWidth = 2.5 * sn.dpr; g.strokeStyle = String(Theme.inkPhone); g.stroke()
                        g.fillStyle = i.c === "#ffffff" ? String(Theme.inkPhone) : "#FFFFFF"; g.font = "700 " + Math.round(r * 1.15) + "px \"" + Theme.display + "\""
                        g.textAlign = "center"; g.textBaseline = "middle"; g.fillText(String(i.n), i.x1, i.y1 + r * 0.05)
                    } else if (i.t === "text") {
                        g.font = "700 " + Math.round(i.w * 2.4 + 12 * sn.dpr) + "px \"" + Theme.display + "\""; g.textBaseline = "top"; g.textAlign = "left"
                        g.lineWidth = Math.max(2, i.w * 0.6); g.strokeStyle = i.c === "#ffffff" ? String(Theme.inkPhone) : "#FFFFFF"; g.strokeText(i.s, i.x1, i.y1); g.fillText(i.s, i.x1, i.y1)
                    }
                }
            }
        }
        // typing a label (Text tool): Enter keeps it, Esc drops it
        TextInput {
            id: typer
            visible: false; color: sn.ink; font.family: Theme.display; font.weight: 700; font.pixelSize: Math.round(sn.w * 2.4 + 12 * sn.dpr)
            Keys.onReturnPressed: sn.commitText()
            Keys.onEscapePressed: { text = ""; visible = false; keys.forceActiveFocus() }
        }
        MouseArea {
            anchors.fill: parent; cursorShape: sn.tool === "text" ? Qt.IBeamCursor : sn.tool === "select" ? (pressed && sn.picked >= 0 ? Qt.ClosedHandCursor : Qt.ArrowCursor) : Qt.CrossCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            property real lx; property real ly; property bool dragged     // Select tool: last point, moved yet
            onPressed: m => {
                if (m.button === Qt.RightButton) { sn.finish(false); return }
                sn.commitText()
                const x = m.x + sn.dx, y = m.y + sn.dy           // mark coords
                if (sn.tool === "select") { sn.picked = sn.hit(x, y); lx = x; ly = y; dragged = false; return }
                if (sn.tool === "text") { typer.x = m.x; typer.y = m.y; typer.text = ""; typer.visible = true; typer.forceActiveFocus(); return }
                if (sn.tool === "num") { sn.push({ t: "num", c: String(sn.ink), w: sn.w, x1: x, y1: y, n: sn.nextNum }); return }
                sn.cur = sn.tool === "pen" || sn.tool === "mark" ? { t: sn.tool, c: String(sn.ink), w: sn.w, p: [x, y] }
                       : { t: sn.tool, c: String(sn.ink), w: sn.w, x1: x, y1: y, x2: x, y2: y }
            }
            onPositionChanged: m => { const x = m.x + sn.dx, y = m.y + sn.dy
                if (sn.tool === "select") { if (sn.picked < 0) return
                    if (!dragged) { sn.snap(); dragged = true }
                    const k = sn.picked; sn.items = sn.items.map((i, j) => j === k ? sn.moved(i, x - lx, y - ly) : i); lx = x; ly = y; paper.requestPaint(); return }
                if (!sn.cur) return; const c = Object.assign({}, sn.cur)
                if (c.p) c.p = c.p.concat([x, y]); else { c.x2 = x; c.y2 = y }
                sn.cur = c; paper.requestPaint() }
            onReleased: { const c = sn.cur; if (!c) return
                if (c.p ? c.p.length > 2 : Math.abs(c.x2 - c.x1) + Math.abs(c.y2 - c.y1) > 4) sn.push(c); else { sn.cur = null; paper.requestPaint() } }
        }
    }
    // Select tool: dashed box round the picked mark (outside `photo`, so it never ends up in the picture)
    Rectangle {
        readonly property var b: sn.picked >= 0 && sn.picked < sn.items.length ? sn.box(sn.items[sn.picked]) : null
        visible: !!b; color: "transparent"; border.width: 2; border.color: Theme.paper; radius: 4
        x: b ? sn.sel.x + (b[0] - sn.dx) / sn.dpr - 4 : 0; y: b ? sn.sel.y + (b[1] - sn.dy) / sn.dpr - 4 : 0
        width: b ? b[2] / sn.dpr + 8 : 0; height: b ? b[3] / sn.dpr + 8 : 0
        Rectangle { anchors.fill: parent; anchors.margins: -2; color: "transparent"; border.width: 1.5; border.color: Theme.inkPhone; radius: 6 }
    }
    // resize handles (4 corners + 4 edges); needs the whole frozen screen to show what's around the cut
    Repeater {
        model: sn.shot ? [[0, 0], [0.5, 0], [1, 0], [1, 0.5], [1, 1], [0.5, 1], [0, 1], [0, 0.5]] : []
        delegate: UiCandy {
            id: hd
            required property var modelData
            readonly property real fx: modelData[0]
            readonly property real fy: modelData[1]
            x: sn.sel.x + sn.sel.width * fx - width / 2; y: sn.sel.y + sn.sel.height * fy - height / 2
            width: 16; height: 16; radius: 8; bw: 2.5; drop: 0; hi: 0; ink: Theme.inkPhone; fill: Theme.paper
            MouseArea {
                anchors.fill: parent; anchors.margins: -6
                cursorShape: hd.fx === 0.5 ? Qt.SizeVerCursor : hd.fy === 0.5 ? Qt.SizeHorCursor
                           : (hd.fx === hd.fy ? Qt.SizeFDiagCursor : Qt.SizeBDiagCursor)
                property rect start; property point p0
                onPressed: m => { sn.commitText(); start = sn.sel; p0 = mapToItem(null, m.x, m.y) }
                onPositionChanged: m => {
                    const p = mapToItem(null, m.x, m.y), ddx = p.x - p0.x, ddy = p.y - p0.y, min = 16
                    let l = start.x, t = start.y, r = start.x + start.width, b = start.y + start.height
                    if (hd.fx === 0) l = Math.max(0, Math.min(r - min, l + ddx)); else if (hd.fx === 1) r = Math.min(sn.width, Math.max(l + min, r + ddx))
                    if (hd.fy === 0) t = Math.max(0, Math.min(b - min, t + ddy)); else if (hd.fy === 1) b = Math.min(sn.height, Math.max(t + min, b + ddy))
                    sn.sel = Qt.rect(Math.round(l), Math.round(t), Math.round(r - l), Math.round(b - t)); paper.requestPaint()
                }
            }
        }
    }
    function commitText() {
        if (!typer.visible) return
        if (typer.text.trim()) push({ t: "text", c: String(ink), w: w, x1: typer.x + dx, y1: typer.y + dy, s: typer.text })
        typer.visible = false; typer.text = ""; keys.forceActiveFocus()
    }

    // ── toolbar: below the cut, or above it, or inside its bottom edge when there's no room ──
    Column {
        id: bar
        readonly property real below: sn.sel.y + sn.sel.height + 14
        x: Math.max(8, Math.min(sn.width - width - 8, sn.sel.x + sn.sel.width / 2 - width / 2))
        y: below + height < sn.height - 8 ? below : sn.sel.y - height - 44 > 8 ? sn.sel.y - height - 44 : sn.sel.y + sn.sel.height - height - 10
        spacing: 6
        UiCandy {
            width: row.implicitWidth + 20; height: 50; radius: 25; bw: 3; drop: 5; hi: 3; ink: Theme.inkPhone; fill: Theme.paper
            MouseArea { anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton }   // gaps between buttons don't close
            Row {
                id: row; anchors.centerIn: parent; spacing: 4
                Repeater { model: sn.tools
                    delegate: UiCandy { required property var modelData
                        readonly property bool on: sn.tool === modelData[0]
                        width: 36; height: 36; radius: 12; bw: on ? 2.5 : 0; drop: on ? 2 : 0; hi: 0; ink: Theme.inkPhone; fill: on ? Theme.gOn : "transparent"; pressable: true
                        onClicked: { sn.commitText(); sn.picked = -1; sn.tool = modelData[0] }
                        Glyph { anchors.centerIn: parent; name: modelData[1]; size: 18; stroke: 2.4; color: Theme.textDeep } } }
                Rectangle { width: 2; height: 26; radius: 1; color: Theme.inkPhone; opacity: 0.25; anchors.verticalCenter: parent.verticalCenter }
                Repeater { model: sn.colors
                    delegate: Item { required property var modelData
                        width: 26; height: 36
                        Rectangle { anchors.centerIn: parent; readonly property bool on: Qt.colorEqual(sn.ink, modelData)
                            width: on ? 24 : 18; height: width; radius: width / 2; color: modelData; border.width: on ? 3 : 2; border.color: Theme.inkPhone
                            Behavior on width { NumberAnimation { duration: 120 } } }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { sn.ink = modelData; if (sn.wheelOn) sn.openWheel(false) } } } }
                // any colour: the wheel from Settings → Windows, in a little pop-up above the bar
                Item {
                    width: 30; height: 36
                    readonly property bool custom: !sn.colors.some(c => Qt.colorEqual(c, sn.ink))
                    Canvas {
                        anchors.centerIn: parent; width: parent.custom || sn.wheelOn ? 26 : 22; height: width
                        onWidthChanged: requestPaint()
                        onPaint: { const g = getContext("2d"), r = width / 2; g.reset()
                            const cg = g.createConicalGradient(r, r, 0); for (let i = 0; i <= 6; i++) cg.addColorStop(i / 6, Qt.hsva(i / 6, 0.8, 1, 1))
                            g.fillStyle = cg; g.beginPath(); g.arc(r, r, r - 1, 0, Math.PI * 2); g.fill()
                            g.lineWidth = 2.5; g.strokeStyle = String(Theme.inkPhone); g.stroke() }
                    }
                    Rectangle { visible: parent.custom; anchors.centerIn: parent; width: 12; height: 12; radius: 6; color: sn.ink; border.width: 2; border.color: Theme.inkPhone }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: sn.openWheel(!sn.wheelOn) }
                }
                UiCandy { width: 36; height: 36; radius: 12; bw: 0; drop: 0; hi: 0; fill: "transparent"; pressable: true; onClicked: sn.size = (sn.size + 1) % 3
                    Rectangle { anchors.centerIn: parent; width: [6, 11, 17][sn.size]; height: width; radius: width / 2; color: sn.ink; border.width: 2; border.color: Theme.inkPhone } }
                Rectangle { width: 2; height: 26; radius: 1; color: Theme.inkPhone; opacity: 0.25; anchors.verticalCenter: parent.verticalCenter }
                Repeater { model: [["trash", () => sn.removePicked(), sn.picked >= 0], ["undo", () => sn.undo(), sn.undoList.length > 0], ["redo", () => sn.redo(), sn.redoList.length > 0]]
                    delegate: UiCandy { required property var modelData
                        width: 36; height: 36; radius: 12; bw: 0; drop: 0; hi: 0; fill: "transparent"; pressable: true; opacity: modelData[2] ? 1 : 0.35
                        onClicked: modelData[1]()
                        Glyph { anchors.centerIn: parent; name: modelData[0]; size: 18; stroke: 2.4; color: Theme.textDeep } } }
                Item { width: 4; height: 1 }
                UiCandy { width: 74; height: 36; radius: 18; bw: 2.5; drop: 3; hi: 2; ink: Theme.inkPhone; fill: Theme.paper; pressable: true; onClicked: sn.finish(true)
                    UiText { anchors.centerIn: parent; text: "Save"; px: 14; w: 700 } }
                UiCandy { width: 74; height: 36; radius: 18; bw: 2.5; drop: 3; hi: 3; ink: Theme.inkPhone; fill: Theme.gOn; pressable: true; onClicked: sn.finish(false)
                    UiText { anchors.centerIn: parent; text: "Copy"; px: 14; w: 700; color: Theme.textDeep } }
            }
        }
        UiText { anchors.horizontalCenter: parent.horizontalCenter; text: "Enter  save + copy  ·  Esc  copy  ·  Ctrl+Z  undo  ·  drag the edges to resize"; fam: "n"; px: 11; w: 800; color: Theme.paper; opacity: 0.9 }
    }

    // colour wheel pop-up (WinColorWheel talks to a "page": v[target], put(), hex())
    property bool wheelOn: false
    QtObject {
        id: wheelPage
        property var v: ({ c: "ee7d9c" })
        property bool loaded: false
        function hex(c) { return String(c).slice(1, 7) }
        function put(k, h) { v = { c: h }; sn.ink = "#" + h }
    }
    function openWheel(on) { wheelOn = on; if (on) { wheelPage.v = { c: wheelPage.hex(ink) }; wheel.load() } else keys.forceActiveFocus() }
    UiCandy {
        visible: sn.wheelOn
        width: 360; height: 182; radius: 22; bw: 3; drop: 5; hi: 3; ink: Theme.inkPhone; fill: Theme.paper
        x: Math.max(8, Math.min(sn.width - width - 8, bar.x + bar.width - width - 170))
        y: bar.y - height - 10 > 8 ? bar.y - height - 10 : bar.y + bar.height + 10
        MouseArea { anchors.fill: parent }       // keep clicks off the picture under it
        WinColorWheel { id: wheel; x: 16; y: 16; width: parent.width - 32; page: wheelPage; target: "c" }
    }

    Item {
        id: keys
        focus: true
        Component.onCompleted: forceActiveFocus()
        Keys.onReturnPressed: sn.finish(true)
        Keys.onEnterPressed: sn.finish(true)
        Keys.onEscapePressed: sn.wheelOn ? sn.openWheel(false) : sn.picked >= 0 ? sn.picked = -1 : sn.finish(false)
        Keys.onDeletePressed: sn.removePicked()
        Keys.onPressed: e => {
            const ctrl = e.modifiers & Qt.ControlModifier
            if (ctrl && e.key === Qt.Key_Z) e.modifiers & Qt.ShiftModifier ? sn.redo() : sn.undo()
            else if (ctrl && e.key === Qt.Key_Y) sn.redo()
            else if (ctrl && e.key === Qt.Key_S) sn.finish(true)
            else if (ctrl && e.key === Qt.Key_C) sn.finish(false)
            else if (e.key === Qt.Key_Backspace && sn.picked >= 0) sn.removePicked()
            else return
            e.accepted = true
        }
    }
}
