import QtQuick
import Quickshell
import Quickshell.Io

// Disk map page: how your home folder uses space as boxes sized by space (tap = look inside, ‹ = back),
// the biggest folders (games…), and things that can be cleaned. Safe ones (your own caches) are ticked and
// cleaned with a double tap; ones that need a password or a look open a terminal / the folder instead.
// Scans only while the page is open (tools/diskmap.py, ~1 s).
Item {
    id: dm
    property var svc
    readonly property bool wide: width >= 700
    implicitHeight: col.implicitHeight
    readonly property string tool: Quickshell.shellDir + "/tools/diskmap.py"
    readonly property string home: Quickshell.env("HOME")
    property var d: null
    property var recs: []
    property var picked: ({})              // rec id → ticked
    property bool confirm: false
    property var trail: []                 // folders above the one shown (for ‹ Back)
    function scan(p) { d = null; scanP.command = ["python3", tool, "scan", p]; scanP.running = true }
    Component.onCompleted: { scan(home); recP.running = true }
    Process { id: scanP; stdout: StdioCollector { onStreamFinished: { try { dm.d = JSON.parse(this.text) } catch (e) {} } } }
    Process { id: recP; command: ["python3", dm.tool, "recs"]
        stdout: StdioCollector { onStreamFinished: { try { dm.recs = JSON.parse(this.text); const p = {}; for (const r of dm.recs) if (r.safe) p[r.id] = true; dm.picked = p } catch (e) {} } } }
    Process { id: cleanP; onExited: { dm.confirm = false; recP.running = true; dm.scan(dm.d ? dm.d.path : dm.home) } }

    function gb(b) { return b >= 1e12 ? (b / 1e12).toFixed(1) + " TB" : b >= 1e9 ? (b / 1e9).toFixed(1) + " GB" : b >= 1e6 ? Math.round(b / 1e6) + " MB" : Math.round(b / 1e3) + " KB" }
    function short(p) { return p.replace(home, "~") }
    readonly property real safeSize: recs.filter(r => r.safe).reduce((a, r) => a + r.size, 0)
    readonly property real reviewSize: recs.filter(r => !r.safe).reduce((a, r) => a + r.size, 0)
    readonly property real pickedSize: recs.filter(r => picked[r.id]).reduce((a, r) => a + r.size, 0)
    // kind of folder → colour (games, caches, coding, pictures/music, documents, the rest)
    function kind(n, p) {
        const s = (p || "") + "/" + n;
        if (/Steam|steamapps|Games|lutris|heroic|compatdata/i.test(s)) return Theme.gPeach;
        if (/\/\.cache|cache|Trash/i.test(s)) return Theme.gLeaf;
        if (/node_modules|\.cargo|\.rustup|\.npm|\/go\/|\.gradle|\.m2|\.dotnet|\.vscode|JetBrains|\.git\b|paru/.test(s)) return Theme.gSea;
        if (/Pictures|Videos|Music|Photos|Wallpapers/.test(s)) return Theme.gLilac;
        if (/Documents|Downloads|Desktop/.test(s)) return Theme.gSun;
        return [Theme.cream, Theme.paper];
    }
    // squarified treemap: boxes as close to square as possible, biggest first
    function boxes(items, x, y, w, h) {
        const list = items.filter(i => i.size > 0), total = list.reduce((a, i) => a + i.size, 0), out = [];
        if (!total || w <= 0 || h <= 0) return out;
        let rest = list.map(i => ({ it: i, a: i.size * w * h / total }));
        const worst = (r, side) => { const s = r.reduce((a, q) => a + q.a, 0); let mx = 0, mn = 1e18; for (const q of r) { mx = Math.max(mx, q.a); mn = Math.min(mn, q.a) }
            return Math.max(side * side * mx / (s * s), s * s / (side * side * mn)) };
        while (rest.length) {
            const side = Math.min(w, h); let n = 1;
            while (n < rest.length && worst(rest.slice(0, n + 1), side) <= worst(rest.slice(0, n), side)) n++;
            const row = rest.slice(0, n), s = row.reduce((a, q) => a + q.a, 0);
            if (w >= h) { const cw = s / h; let cy = y; for (const q of row) { out.push({ it: q.it, x: x, y: cy, w: cw, h: q.a / cw }); cy += q.a / cw } x += cw; w -= cw }
            else { const rh = s / w; let cx = x; for (const q of row) { out.push({ it: q.it, x: cx, y: y, w: q.a / rh, h: rh }); cx += q.a / rh } y += rh; h -= rh }
            rest = rest.slice(n);
        }
        return out;
    }

    component Label: UiText { fam: "n"; px: 11; w: 900; track: 1.4; color: Theme.textSoft; height: 18 }
    component Stat: Column {
        property string title
        property string value
        property color dot: "transparent"
        width: (col.width - 3 * 8) / (dm.wide ? 4 : 2); spacing: 2
        Row { spacing: 5
            Rectangle { visible: parent.parent.dot.a > 0; width: 8; height: 8; radius: 4; color: parent.parent.dot; anchors.verticalCenter: parent.verticalCenter }
            UiText { text: parent.parent.title; fam: "n"; px: 10.5; w: 800; color: Theme.textSoft } }
        UiText { text: parent.value; px: 22; w: 700 }
    }

    Column {
        id: col
        width: dm.width; spacing: 10

        // ── numbers ──
        Flow {
            width: parent.width; spacing: 8
            Stat { title: "Free right now"; value: dm.d ? dm.gb(dm.d.disk.free) : "…" }
            Stat { title: "Safe to remove"; value: dm.gb(dm.safeSize); dot: Theme.leaf }
            Stat { title: "Needs a look"; value: dm.gb(dm.reviewSize); dot: Theme.orange }
            Stat { title: "System & apps"; value: dm.d && dm.trail.length === 0 ? dm.gb(Math.max(0, dm.d.disk.used - dm.d.size)) : "—" }
        }

        // ── map ──
        Item {
            width: parent.width; height: 26
            UiCandy {
                visible: dm.trail.length > 0
                width: bk.implicitWidth + 22; height: 26; radius: 9; bw: 2; drop: 2; hi: 0; fill: Theme.paper; pressable: true
                onClicked: { const t = dm.trail.slice(); const p = t.pop(); dm.trail = t; dm.scan(p) }
                UiText { id: bk; anchors.centerIn: parent; text: "‹ Back"; px: 12; w: 700 }
            }
            UiText { x: dm.trail.length ? bk.implicitWidth + 32 : 0; anchors.verticalCenter: parent.verticalCenter; width: parent.width - x
                elide: Text.ElideLeft; text: dm.d ? dm.short(dm.d.path) + " · " + dm.gb(dm.d.size) : "Scanning…"; px: 13; w: 700 }
        }
        UiCandy {
            id: mapBox
            width: parent.width; height: dm.wide ? 340 : 300; radius: 16; bw: 2.5; drop: 3; hi: 0; ink: Theme.inkPhone; fill: Theme.paper
            Item {
                id: map
                x: 6; y: 6; width: parent.width - 12; height: parent.height - 12; clip: true
                UiText { visible: !dm.d; anchors.centerIn: parent; text: "Scanning…"; fam: "n"; px: 13; w: 800; color: Theme.textSoft }
                Repeater {
                    model: dm.d ? dm.boxes(dm.d.children, 0, 0, map.width, map.height) : []
                    delegate: Rectangle {
                        id: tile
                        required property var modelData
                        readonly property var it: modelData.it
                        readonly property var g: dm.kind(it.name, dm.d.path)
                        readonly property bool roomy: width > 110 && height > 80 && it.children && it.children.length > 0
                        x: modelData.x + 2; y: modelData.y + 2; width: Math.max(0, modelData.w - 4); height: Math.max(0, modelData.h - 4)
                        radius: 8; border.width: 2; border.color: Theme.inkPhone
                        gradient: Gradient { GradientStop { position: 0; color: tile.g[0] } GradientStop { position: 1; color: tile.g[1] } }
                        opacity: it.more ? 0.6 : 1
                        UiText { visible: tile.width > 46 && tile.height > 30; x: 7; y: 5; width: tile.width - 14; elide: Text.ElideRight; text: tile.it.name; px: 12; w: 700 }
                        UiText { visible: tile.width > 46 && tile.height > 48; x: 7; anchors.bottom: parent.bottom; anchors.bottomMargin: 4
                            text: dm.gb(tile.it.size); px: Math.max(12, Math.min(26, tile.height / 5)); w: 700; color: Theme.textDeep }
                        // what's inside, drawn smaller (only if there is room)
                        Item {
                            visible: tile.roomy
                            x: 6; y: 24; width: tile.width - 12; height: tile.height - 24 - 34
                            Repeater {
                                model: tile.roomy ? dm.boxes(tile.it.children, 0, 0, parent.width, parent.height) : []
                                delegate: Rectangle {
                                    required property var modelData
                                    x: modelData.x + 1; y: modelData.y + 1; width: Math.max(0, modelData.w - 2); height: Math.max(0, modelData.h - 2)
                                    radius: 5; color: Qt.rgba(1, 1, 1, 0.45); border.width: 1.5; border.color: Qt.rgba(33 / 255, 63 / 255, 72 / 255, 0.45)
                                    UiText { visible: parent.width > 40 && parent.height > 18; x: 4; y: 2; width: parent.width - 8; elide: Text.ElideRight
                                        text: modelData.it.name + (parent.height > 32 ? "\n" + dm.gb(modelData.it.size) : ""); fam: "n"; px: 9.5; w: 800; color: Theme.textDeep }
                                }
                            }
                        }
                        MouseArea { anchors.fill: parent; enabled: !tile.it.more && !!tile.it.path; cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: { dm.trail = dm.trail.concat([dm.d.path]); dm.scan(tile.it.path) } }
                    }
                }
            }
        }
        Flow {
            width: parent.width; spacing: 10
            Repeater {
                model: [["Games", Theme.gPeach], ["Caches", Theme.gLeaf], ["Coding", Theme.gSea], ["Pictures & music", Theme.gLilac], ["Documents", Theme.gSun], ["Apps & settings", [Theme.cream, Theme.paper]]]
                delegate: Row { required property var modelData; spacing: 4
                    Rectangle { width: 12; height: 12; radius: 3; border.width: 1.5; border.color: Theme.inkPhone; color: modelData[1][1]; anchors.verticalCenter: parent.verticalCenter }
                    UiText { text: modelData[0]; fam: "n"; px: 10.5; w: 800; color: Theme.textSoft } }
            }
        }

        // ── biggest folders ──
        Item { width: 1; height: 2 }
        Label { text: "BIGGEST FOLDERS" }
        Repeater {
            model: dm.d ? dm.d.biggest : []
            delegate: Item {
                required property var modelData
                width: col.width; height: 30
                Rectangle { y: 2; width: parent.width; height: 26; radius: 8; color: Theme.cream; border.width: 2; border.color: Theme.inkPhone
                    Rectangle { x: 2; y: 2; height: parent.height - 4; radius: 6; width: Math.max(8, (parent.width - 4) * modelData.size / Math.max(1, dm.d.biggest[0].size))
                        gradient: Gradient { orientation: Gradient.Horizontal; GradientStop { position: 0; color: dm.kind("", modelData.path)[1] } GradientStop { position: 1; color: dm.kind("", modelData.path)[0] } } }
                    UiText { x: 10; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 90; elide: Text.ElideMiddle
                        text: modelData.path.split("/").pop() + "  ·  " + dm.short(modelData.path).split("/").slice(0, -1).join("/"); px: 12; w: 700 }
                    UiText { anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter; text: dm.gb(modelData.size); px: 12.5; w: 700 } }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: dm.svc.openApp("dolphin " + JSON.stringify(modelData.path)) }
            }
        }

        // ── clean up ──
        Item { width: 1; height: 2 }
        Label { text: "CLEAN UP" }
        Repeater {
            model: dm.recs
            delegate: UiCandy {
                required property var modelData
                readonly property bool on: !!dm.picked[modelData.id]
                width: col.width; height: 48; radius: 14; bw: 2.5; drop: 0; hi: 0
                fill: modelData.safe ? (on ? Theme.gOn : Theme.cream) : Theme.cream; pressable: true
                onClicked: {
                    if (modelData.safe) { const p = Object.assign({}, dm.picked); p[modelData.id] = !p[modelData.id]; dm.picked = p; dm.confirm = false }
                    else if (modelData.cmd.startsWith("sudo")) Quickshell.execDetached(["kitty", "--title", modelData.label, "sh", "-c", modelData.cmd + "; echo; echo 'Done — press Enter to close'; read x"])
                    else dm.svc.openApp(modelData.cmd.startsWith("dolphin") ? modelData.cmd : "dolphin " + modelData.cmd.replace(/^rm -rf /, "").replace(/\/\*.*$/, ""))
                }
                // tick box (safe) or a "look" mark
                Rectangle { x: 12; anchors.verticalCenter: parent.verticalCenter; width: 22; height: 22; radius: 7; border.width: 2; border.color: Theme.inkPhone
                    color: modelData.safe ? (parent.on ? Theme.leaf : Theme.paper) : Theme.sun
                    UiText { anchors.centerIn: parent; text: modelData.safe ? (parent.parent.on ? "✓" : "") : "!"; px: 12; w: 700; color: modelData.safe ? "#FFFFFF" : Theme.text } }
                Column { x: 44; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 44 - 80
                    UiText { width: parent.width; elide: Text.ElideRight; text: modelData.label; px: 13; w: 700; height: 17 }
                    UiText { width: parent.width; elide: Text.ElideRight; text: modelData.note; fam: "n"; px: 10.5; w: 800; color: Theme.textSoft; height: 14 } }
                UiText { anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter; text: dm.gb(modelData.size); px: 13; w: 700 }
            }
        }
        UiText { visible: dm.recs.length === 0; text: recP.running ? "Looking…" : "Nothing big to clean ✓"; fam: "n"; px: 12; w: 800; color: Theme.textSoft }
        Row {
            visible: dm.recs.some(r => r.safe)
            anchors.right: parent.right; spacing: 8
            UiCandy {
                width: cpT.implicitWidth + 26; height: 38; radius: 12; bw: 2.5; drop: 3; hi: 0; fill: Theme.paper; pressable: true
                onClicked: Quickshell.execDetached(["wl-copy", dm.recs.filter(r => dm.picked[r.id]).map(r => r.cmd).join("\n")])
                UiText { id: cpT; anchors.centerIn: parent; text: "Copy commands"; px: 13; w: 700 }
            }
            UiCandy {
                width: clT.implicitWidth + 28; height: 38; radius: 12; bw: 2.5; drop: 3; hi: 3; pressable: dm.pickedSize > 0 && !cleanP.running
                fill: dm.confirm ? [Theme.berry, Theme.berry] : Theme.gGo
                onClicked: { if (!dm.confirm) { dm.confirm = true; return }
                    cleanP.command = ["python3", dm.tool, "clean"].concat(Object.keys(dm.picked).filter(k => dm.picked[k])); cleanP.running = true }
                UiText { id: clT; anchors.centerIn: parent; color: "#FFFFFF"; px: 13; w: 700
                    text: cleanP.running ? "Cleaning…" : dm.confirm ? "Tap again to delete " + dm.gb(dm.pickedSize) : "Clean " + dm.gb(dm.pickedSize) }
            }
        }
    }
}
