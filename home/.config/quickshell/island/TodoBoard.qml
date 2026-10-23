import QtQuick
import Quickshell
import Quickshell.Io

// One to-do board (Services.todo): items with a tick box, text (click to change), ✕; under an item its pictures /
// videos as thumbnails and other files as links (click = open, Ctrl+click = show in Dolphin). Below: write a new item,
// Paste a picture or attach Files, Add. k = text size (1 in the bar card, bigger in the big window).
// Deleting asks once more: ✕ turns into "Delete?" (right-click on a file: "Remove?") for 3 s.
Item {
    id: b
    property var todo
    property real k: 1
    property real listH: 300
    property int editing: -1
    property var pending: []                      // files for the item being written
    implicitHeight: col.implicitHeight
    function focusField() { field.forceActiveFocus() }
    function addNow() { todo.add(field.text, pending); field.text = ""; pending = [] }
    Connections { target: b.todo; function onPicked(f) { b.pending = b.pending.concat(f) } }
    property string sure: ""                      // what waits for the second click
    property string sureAtPress: ""               // what was waiting when this click started
    Timer { id: sureT; interval: 3000; onTriggered: b.sure = "" }
    function ask(key, act) { if (sureAtPress === key) { sure = ""; act() } else { sure = key; sureT.restart() } }
    // on top of everything, passive: sees every press first, clears the question, lets the click go on to its button
    Item { anchors.fill: parent; z: 100
        // PointHandler only watches (a TapHandler here swallowed every click — checked with qmltestrunner)
        PointHandler { acceptedButtons: Qt.LeftButton | Qt.RightButton
            onActiveChanged: if (active) { b.sureAtPress = b.sure; b.sure = "" } } }

    // video: a frame made once with ffmpegthumbnailer (~/.cache/island/todo-thumbs)
    component VideoThumb: Image {
        id: vt
        property string file
        readonly property string out: Quickshell.env("HOME") + "/.cache/island/todo-thumbs/" + Qt.md5(file) + ".png"
        height: 70 * b.k; width: height * 16 / 9; fillMode: Image.PreserveAspectCrop; asynchronous: true
        Process { running: true; command: ["sh", "-c", '[ -s "$1" ] || { mkdir -p "${1%/*}"; ffmpegthumbnailer -i "$0" -o "$1" -s 320 2>/dev/null; }', vt.file, vt.out]
            onExited: vt.source = "file://" + vt.out }
        Rectangle { anchors.centerIn: parent; width: 26 * b.k; height: width; radius: width / 2; color: Qt.rgba(0, 0, 0, 0.55)
            Glyph { anchors.centerIn: parent; name: "play"; size: 12 * b.k; stroke: 2.4; color: "#FFFFFF" } }
    }

    Column {
        id: col
        width: b.width; spacing: 8 * b.k

        Flickable {
            width: parent.width; height: Math.min(b.listH, items.implicitHeight); contentHeight: items.implicitHeight
            clip: true; boundsBehavior: Flickable.StopAtBounds
            Column {
                id: items
                width: parent.width; spacing: 6 * b.k
                Repeater {
                    model: b.todo.items
                    delegate: UiCandy {
                        id: row
                        required property var modelData
                        required property int index
                        width: items.width; height: inner.implicitHeight + 14 * b.k; radius: 12 * b.k; bw: 2; drop: 0; hi: 0
                        fill: modelData.done ? Theme.sand : Theme.cream
                        // tick box
                        UiCandy { x: 8 * b.k; y: 7 * b.k; width: 22 * b.k; height: width; radius: 7 * b.k; bw: 2; drop: 0; hi: 0
                            fill: row.modelData.done ? Theme.gLeaf : Theme.paper; pressable: true
                            onClicked: b.todo.toggle(row.index)
                            Glyph { visible: row.modelData.done; anchors.centerIn: parent; name: "check"; size: 13 * b.k; stroke: 3 } }
                        Column {
                            id: inner
                            x: 38 * b.k; y: 7 * b.k; width: row.width - x - 34 * b.k; spacing: 6 * b.k
                            // text, or a box to change it
                            UiText { visible: b.editing !== row.index; width: parent.width; text: row.modelData.text || " "; wrapMode: Text.Wrap; elide: Text.ElideNone
                                fam: "n"; px: 13 * b.k; w: 800; font.strikeout: row.modelData.done; color: row.modelData.done ? Theme.textSoft : Theme.text
                                MouseArea { anchors.fill: parent; cursorShape: Qt.IBeamCursor; onClicked: m => { b.editing = row.index; ed.text = row.modelData.text; ed.forceActiveFocus(); ed.cursorPosition = ed.positionAt(m.x, m.y) } } }   // cursor where you clicked
                            // editing: same font, size and line breaks as the text, so the row keeps its look · Enter saves, Esc cancels
                            TextEdit { id: ed; visible: b.editing === row.index; width: parent.width; wrapMode: TextEdit.Wrap
                                font.family: Theme.body; font.weight: 800; font.pixelSize: 13 * b.k; color: Theme.text; selectByMouse: true
                                Keys.onReturnPressed: { b.todo.edit(row.index, text); b.editing = -1 }
                                Keys.onEnterPressed: { b.todo.edit(row.index, text); b.editing = -1 }
                                onActiveFocusChanged: if (!activeFocus && b.editing === row.index) b.editing = -1
                                Keys.onEscapePressed: b.editing = -1 }
                            // pictures / videos (thumbnails) and files (links)
                            Flow {
                                visible: row.modelData.files.length > 0
                                width: parent.width; spacing: 6 * b.k
                                Repeater {
                                    model: row.modelData.files
                                    delegate: Loader {
                                        id: fi
                                        required property string modelData
                                        sourceComponent: ({ img: cImg, video: cVideo, file: cLink })[b.todo.kind(modelData)]
                                        Component { id: cImg; Image { height: 70 * b.k; width: Math.max(70 * b.k, Math.min(160 * b.k, height * implicitWidth / Math.max(1, implicitHeight)))
                                            source: "file://" + fi.modelData; sourceSize.height: 160; fillMode: Image.PreserveAspectFit; asynchronous: true } }   // whole picture, odd shapes too
                                        Component { id: cVideo; VideoThumb { file: fi.modelData } }
                                        Component { id: cLink; UiText { text: "📄 " + fi.modelData.split("/").pop(); fam: "n"; px: 12 * b.k; w: 800
                                            color: Theme.seaDeep; font.underline: true; elide: Text.ElideMiddle; width: Math.min(implicitWidth, inner.width) } }
                                        // click = open · Ctrl+click = show in Dolphin · right click = take it off
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; acceptedButtons: Qt.LeftButton | Qt.RightButton
                                            onClicked: m => { if (m.button === Qt.RightButton) b.ask("f" + row.index + fi.modelData, () => b.todo.unattach(row.index, fi.modelData))
                                                              else b.todo.openFile(fi.modelData, m.modifiers & Qt.ControlModifier) } }
                                        UiTag { visible: b.sure === "f" + row.index + fi.modelData; anchors.centerIn: parent; text: "Remove?"; fill: Theme.pinkSoft; ink: Theme.ink; textColor: Theme.textDeep; px: 11 * b.k; tilt: -4 }
                                    }
                                }
                            }
                        }
                        UiCandy {
                            id: del
                            readonly property bool asking: b.sure === "i" + row.index
                            x: row.width - width - 8 * b.k; y: 7 * b.k; width: asking ? dq.implicitWidth + 16 * b.k : 22 * b.k; height: 22 * b.k; radius: height / 2
                            bw: 2; drop: 0; hi: 0; fill: asking ? Theme.pinkSoft : Theme.paper; pressable: true
                            onClicked: b.ask("i" + row.index, () => b.todo.remove(row.index))
                            Glyph { visible: !del.asking; anchors.centerIn: parent; name: "close"; size: 10 * b.k; stroke: 2.8 }
                            UiText { id: dq; visible: del.asking; anchors.centerIn: parent; text: "Delete?"; px: 11 * b.k; w: 700 } }
                    }
                }
                UiText { visible: b.todo.items.length === 0; width: parent.width; height: 30 * b.k; horizontalAlignment: Text.AlignHCenter
                    text: "Nothing to do yet · write one below"; fam: "n"; px: 12 * b.k; w: 800; color: Theme.textSoft }
            }
        }

        // write a new item
        UiCandy {
            width: parent.width; height: cc.implicitHeight + 20 * b.k; radius: 14 * b.k; bw: 2.5; drop: 3; hi: 0; fill: Theme.cream
            Column {
                id: cc
                x: 10 * b.k; y: 10 * b.k; width: parent.width - 20 * b.k; spacing: 8 * b.k
                UiCandy {
                    width: parent.width; height: Math.max(34 * b.k, field.contentHeight + 14 * b.k); radius: 10 * b.k; bw: 2; drop: 0; hi: 0; fill: Theme.paper
                    TextEdit { id: field; x: 9 * b.k; y: 7 * b.k; width: parent.width - 18 * b.k; wrapMode: TextEdit.Wrap
                        font.family: Theme.body; font.weight: 800; font.pixelSize: 13 * b.k; color: Theme.text
                        Keys.onReturnPressed: e => { if (e.modifiers & Qt.ShiftModifier) e.accepted = false; else b.addNow() }
                        // Ctrl+V: a picture on the clipboard is attached; text still pastes as text
                        Keys.onPressed: e => { if ((e.modifiers & Qt.ControlModifier) && e.key === Qt.Key_V) b.todo.pasteImage(); e.accepted = false }
                        UiText { visible: !field.text; width: parent.width; text: "New to-do… (Ctrl+V a picture · Shift+Enter = new line)"; fam: "n"; px: 12 * b.k; w: 800; color: Theme.textSoft } }
                }
                // files waiting to go with it (click one to drop it)
                Flow {
                    visible: b.pending.length > 0; width: parent.width; spacing: 6
                    Repeater { model: b.pending
                        delegate: UiCandy { required property string modelData; required property int index
                            width: pt.implicitWidth + 20; height: 24 * b.k; radius: 8; bw: 2; drop: 0; hi: 0; fill: Theme.paper; pressable: true
                            onClicked: b.pending = b.pending.filter((x, i) => i !== index)
                            UiText { id: pt; anchors.centerIn: parent; text: modelData.split("/").pop() + "  ✕"; fam: "n"; px: 11 * b.k; w: 800; width: Math.min(implicitWidth, cc.width - 30) } } }
                }
                Row {
                    spacing: 6 * b.k
                    Repeater { model: [["clipboard", "Paste", () => b.todo.pasteImage()], ["box", "File", () => b.todo.chooseFiles()]]
                        delegate: UiCandy { required property var modelData
                            width: bl.implicitWidth + 36 * b.k; height: 30 * b.k; radius: 10; bw: 2; drop: 2; hi: 0; fill: Theme.paper; pressable: true; onClicked: modelData[2]()
                            Glyph { x: 8 * b.k; anchors.verticalCenter: parent.verticalCenter; name: modelData[0]; size: 14 * b.k; stroke: 2.4 }
                            UiText { id: bl; x: 26 * b.k; anchors.verticalCenter: parent.verticalCenter; text: modelData[1]; px: 12 * b.k; w: 700 } } }
                    UiCandy { width: 64 * b.k; height: 30 * b.k; radius: 10; bw: 2.5; drop: 2; hi: 3; fill: Theme.gGo; pressable: true; onClicked: b.addNow()
                        UiText { anchors.centerIn: parent; text: "Add"; px: 13 * b.k; w: 700; color: "#FFFFFF" } }
                }
            }
        }
    }
}
