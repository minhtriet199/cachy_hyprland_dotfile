import QtQuick
import Quickshell
import Quickshell.Io

// Recovery page: snapshots of the whole setup (tools/snapshot.py). "+ Snapshot" saves one now (optional name);
// Restore asks once more, saves the current setup first ("Before restoring …"), puts the snapshot back and restarts Island.
Item {
    id: rc
    property var svc
    implicitHeight: col.implicitHeight
    property var list: []
    property bool adding: false
    property string sure: ""            // id waiting for the second tap on Restore
    property string restoring: ""
    readonly property string tool: Quickshell.shellDir + "/tools/snapshot.py"
    function load() { getP.running = true }
    Component.onCompleted: load()
    Process { id: getP; command: ["python3", rc.tool, "list"]
        stdout: StdioCollector { onStreamFinished: { try { rc.list = JSON.parse(this.text) } catch (e) {} } } }
    Process { id: act; onExited: rc.load() }
    function run(args) { if (act.running) return; act.command = ["python3", tool].concat(args); act.running = true }
    function restore(s) {
        if (sure !== s.id) { sure = s.id; sureT.restart(); return }
        sure = ""; restoring = s.id
        Quickshell.execDetached(["python3", tool, "restore", s.id])     // detached: it restarts Island
    }
    Timer { id: sureT; interval: 3000; onTriggered: rc.sure = "" }
    function size(b) { return b < 1048576 ? Math.round(b / 1024) + " KB" : (b / 1048576).toFixed(1) + " MB" }

    component Label: UiText { fam: "n"; px: 11; w: 900; track: 1.4; color: Theme.textSoft; height: 18 }

    Column {
        id: col
        width: rc.width; spacing: 8

        Item {
            width: parent.width; height: 30
            Label { anchors.verticalCenter: parent.verticalCenter; text: "SNAPSHOTS · " + rc.list.length }
            UiCandy {
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                width: addT.implicitWidth + 22; height: 30; radius: 10; bw: 2.5; drop: rc.adding ? 0 : 3; hi: 3
                fill: rc.adding ? Theme.gOn : Theme.gLeaf; pressable: !act.running
                onClicked: { rc.adding = !rc.adding; if (rc.adding) nameIn.forceActiveFocus() }
                UiText { id: addT; anchors.centerIn: parent; text: act.running ? "Saving…" : rc.adding ? "Cancel" : "+ Snapshot"; px: 12.5; w: 700 }
            }
        }
        // new snapshot: optional name
        UiCandy {
            visible: rc.adding
            width: parent.width; height: 52; radius: 14; bw: 2.5; drop: 3; hi: 0; fill: Theme.gSun
            UiCandy {
                x: 10; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 20 - saveBtn.width - 8; height: 32; radius: 10; bw: 2; drop: 0; hi: 0; fill: Theme.paper
                TextInput {
                    id: nameIn; x: 10; width: parent.width - 20; anchors.verticalCenter: parent.verticalCenter; clip: true
                    font.family: Theme.body; font.weight: 800; font.pixelSize: 12; color: Theme.text
                    onAccepted: saveBtn.save()
                    Keys.onEscapePressed: rc.adding = false
                    UiText { visible: !nameIn.text; text: "Name (optional), e.g. Before new theme"; fam: "n"; px: 11; w: 800; color: Theme.textSoft; anchors.verticalCenter: parent.verticalCenter }
                }
            }
            UiCandy {
                id: saveBtn
                function save() { rc.run(["create", nameIn.text.trim()]); nameIn.text = ""; rc.adding = false }
                x: parent.width - width - 10; anchors.verticalCenter: parent.verticalCenter
                width: svT.implicitWidth + 28; height: 32; radius: 10; bw: 2.5; drop: 3; hi: 3; fill: Theme.gGo; pressable: true
                onClicked: save()
                UiText { id: svT; anchors.centerIn: parent; text: "Save"; px: 13; w: 700; color: "#FFFFFF" }
            }
        }

        Repeater {
            model: rc.list
            delegate: UiRow {
                id: row
                required property var modelData
                readonly property string when: Qt.formatDateTime(new Date(modelData.time * 1000), rc.svc.h24 ? "d MMM yyyy · HH:mm" : "d MMM yyyy · h:mm AP")
                width: col.width; glyph: modelData.auto ? "reload" : "undo"; pressable: false
                title: modelData.name || row.when
                sub: (modelData.name ? row.when + " · " : "") + rc.size(modelData.size) + (modelData.auto ? " · automatic" : "")
                busy: rc.restoring === modelData.id; busyText: "Restoring… Island restarts"
                UiCandy {
                    readonly property bool ask: rc.sure === row.modelData.id
                    width: rt.implicitWidth + 20; height: 28; radius: 10; bw: 2; drop: ask ? 0 : 2; hi: 0
                    fill: ask ? Theme.pinkSoft : Theme.paper; pressable: rc.restoring === ""
                    onClicked: rc.restore(row.modelData)
                    UiText { id: rt; anchors.centerIn: parent; text: parent.ask ? "Sure? Tap again" : "Restore"; px: 12; w: 700 }
                }
                UiCandy { width: 28; height: 28; bw: 2; drop: 0; hi: 0; fill: Theme.paper; pressable: rc.restoring === ""
                    onClicked: rc.run(["delete", row.modelData.id])
                    Glyph { anchors.centerIn: parent; name: "trash"; size: 12; stroke: 2.6 } }
            }
        }
        UiText { visible: rc.list.length === 0 && !rc.adding; width: parent.width; text: "No snapshots yet · press + Snapshot"; fam: "n"; px: 11.5; w: 800; color: Theme.textSoft }

        UiText {
            width: parent.width; wrapMode: Text.WordWrap; fam: "n"; px: 10.5; w: 800; color: Theme.textSoft
            text: "Saves Island, the login screen, Hyprland (keys, windows, displays), themes and your Island settings. Not your clipboard or wallpapers. Restoring saves the current setup first, so you can always go back. The newest 10 automatic snapshots are kept."
        }
    }
}
