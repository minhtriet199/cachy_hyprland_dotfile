import QtQuick
import Quickshell
import Quickshell.Io
import Qt.labs.folderlistmodel

// Isla View: pictures open as an instant-camera photo (thick bottom edge with the name, washi tape, a little tilt).
// Its own small Quickshell window (tools/isla-view.sh starts it; a second open just switches the picture).
// ←/→ browse the folder · scroll / + − zoom (drag to move) · 0 fit · Q open in qView · Esc close.
ShellRoot {
    id: root
    property string file: Quickshell.env("ISLA_VIEW") || ""
    readonly property string dir: file.substring(0, file.lastIndexOf("/"))
    IpcHandler { target: "view"; function open(path: string): void { root.file = path } }

    FolderListModel {
        id: pics
        folder: root.dir ? "file://" + root.dir : ""
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.gif", "*.bmp", "*.avif", "*.tif", "*.tiff", "*.PNG", "*.JPG", "*.JPEG"]
        showDirs: false; sortField: FolderListModel.Name
    }
    readonly property int idx: { pics.count; for (let k = 0; k < pics.count; k++) if (pics.get(k, "filePath") === file) return k; return -1 }
    function step(d) { if (pics.count > 1 && idx >= 0) { file = pics.get((idx + d + pics.count) % pics.count, "filePath"); flip = -flip } }
    property int flip: 1                                   // the photo leans the other way after each step

    FloatingWindow {
        id: win
        title: "Isla View"
        color: "transparent"
        visible: true
        // the photo fits in ~60% of the screen; frame edges like an Instax: thin sides/top, thick bottom
        readonly property real maxW: (screen ? screen.width : 1920) * 0.58
        readonly property real maxH: (screen ? screen.height : 1080) * 0.62
        readonly property real iw: Math.max(1, pic.implicitWidth)
        readonly property real ih: Math.max(1, pic.implicitHeight)
        readonly property real fit: Math.min(maxW / iw, maxH / ih, Math.max(1, 360 / iw))
        readonly property real pw: Math.round(iw * fit)
        readonly property real ph: Math.round(ih * fit)
        readonly property real side: Math.max(16, Math.round(Math.min(pw, ph) * 0.055))
        readonly property real foot: Math.max(76, Math.round(ph * 0.2))
        implicitWidth: pw + 2 * side + 70; implicitHeight: ph + side + foot + 70

        Item {
            id: keys
            anchors.fill: parent; focus: true
            Keys.onLeftPressed: root.step(-1)
            Keys.onRightPressed: root.step(1)
            Keys.onEscapePressed: Qt.quit()
            Keys.onPressed: e => {
                if (e.key === Qt.Key_Q) qview.running = true
                else if (e.key === Qt.Key_Plus || e.key === Qt.Key_Equal) view.zoomBy(1.25)
                else if (e.key === Qt.Key_Minus) view.zoomBy(0.8)
                else if (e.key === Qt.Key_0) view.reset()
                else return
                e.accepted = true
            }
        }
        Process { id: qview; command: ["qview", root.file] }

        UiCandy {
            id: card
            anchors.centerIn: parent
            width: win.pw + 2 * win.side; height: win.ph + win.side + win.foot
            radius: 10; bw: 3; drop: 7; hi: 0; ink: Theme.inkPhone; fill: Theme.paper
            rotation: -1.4 * root.flip
            Behavior on rotation { SpringAnimation { spring: 3; damping: 0.25 } }
            // drag the photo by its frame to move the window
            MouseArea { anchors.fill: parent; z: -1; onPressed: win.startSystemMove() }

            // the picture: scroll zooms around the pointer, drag moves it when zoomed, double-click = fit / 2×
            Rectangle {
                id: view
                x: win.side; y: win.side; width: win.pw; height: win.ph
                color: Theme.inkPhone; clip: true
                property real zm: 1
                function zoomBy(f, px, py) {
                    px = px === undefined ? width / 2 : px; py = py === undefined ? height / 2 : py
                    const nz = Math.max(1, Math.min(8, zm * f)), k = nz / zm
                    pic.x = Math.min(0, Math.max(width - width * nz, px - (px - pic.x) * k))
                    pic.y = Math.min(0, Math.max(height - height * nz, py - (py - pic.y) * k)); zm = nz
                }
                function reset() { zm = 1; pic.x = 0; pic.y = 0 }
                Image {
                    id: pic
                    width: view.width * view.zm; height: view.height * view.zm
                    source: root.file ? "file://" + root.file : ""
                    fillMode: Image.PreserveAspectFit; asynchronous: true; smooth: true; mipmap: true; autoTransform: true
                    onSourceChanged: view.reset()
                }
                // a soft inner edge, like the print sits under the frame
                Rectangle { anchors.fill: parent; color: "transparent"; border.width: 2; border.color: Qt.rgba(0, 0, 0, 0.18) }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: view.zm > 1 ? (pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor) : Qt.ArrowCursor
                    property real sx: 0
                    property real sy: 0
                    onPressed: m => { if (view.zm <= 1) { win.startSystemMove(); return } sx = m.x - pic.x; sy = m.y - pic.y }
                    onPositionChanged: m => { if (view.zm <= 1) return
                        pic.x = Math.min(0, Math.max(view.width - pic.width, m.x - sx)); pic.y = Math.min(0, Math.max(view.height - pic.height, m.y - sy)) }
                    onDoubleClicked: m => view.zm > 1 ? view.reset() : view.zoomBy(2, m.x, m.y)
                    onWheel: w => view.zoomBy(w.angleDelta.y > 0 ? 1.2 : 1 / 1.2, w.x, w.y)
                }
            }

            // the thick bottom edge: name like it was written on, details, and the buttons
            Column {
                x: win.side + 4; y: win.side + win.ph + (win.foot - height) / 2 - 2
                width: win.pw - btns.width - 16; spacing: 2
                UiText { width: parent.width; elide: Text.ElideMiddle; text: root.file.substring(root.file.lastIndexOf("/") + 1); px: 19; w: 700; color: Theme.textDeep }
                UiText { width: parent.width; elide: Text.ElideRight; fam: "n"; px: 11; w: 800; color: Theme.textSoft
                    text: (root.idx >= 0 ? (root.idx + 1) + " / " + pics.count + "  ·  " : "") + pic.implicitWidth + " × " + pic.implicitHeight
                          + (view.zm > 1 ? "  ·  " + Math.round(view.zm * 100) + "%" : "") }
            }
            Row {
                id: btns
                anchors.right: parent.right; anchors.rightMargin: win.side; y: win.side + win.ph + (win.foot - height) / 2 - 2
                spacing: 6
                Repeater {
                    model: [["prev", () => root.step(-1)], ["next", () => root.step(1)], ["external", () => qview.running = true], ["close", () => Qt.quit()]]
                    delegate: UiCandy {
                        required property var modelData
                        width: 34; height: 34; radius: 12; bw: 2.5; drop: hovered ? 3 : 2; hi: 2; ink: Theme.inkPhone
                        fill: modelData[0] === "close" ? Theme.gBerry : Theme.paper; pressable: true
                        onClicked: modelData[1]()
                        Glyph { anchors.centerIn: parent; name: modelData[0]; size: 16; stroke: 2.6; color: modelData[0] === "close" ? "#FFFFFF" : Theme.textDeep }
                    }
                }
            }
        }
        // washi tape holding the photo
        Rectangle {
            x: card.x + card.width / 2 - width / 2 + 8 * root.flip; y: card.y - 12
            width: Math.min(120, card.width * 0.28); height: 26; radius: 3
            rotation: 4 * root.flip; color: Theme.pinkSoft; opacity: 0.85
            Behavior on rotation { SpringAnimation { spring: 3; damping: 0.25 } }
            Rectangle { anchors.fill: parent; anchors.margins: 4; color: "transparent"; border.width: 1.5; border.color: "#FFFFFF"; opacity: 0.6; radius: 2 }
        }
    }
}
