import QtQuick

// To-do card (bar ✓): the board you had open last (a new blank one the first time). Header: board name (click to
// rename), progress, ☰ all boards, ⤢ big window, pin (stays up over other windows; opening a file pins it until
// that window closes). Boards list: name, last change, progress; + New; trash asks once more.
DropCard {
    id: d
    property var svc
    readonly property var todo: svc.todo
    property bool listing: false
    property string sure: ""                       // board waiting for the second tap on its trash
    width: 380; headerH: 96
    height: headerH + 8 + (listing ? Math.min(420, boardsCol.implicitHeight) : board.implicitHeight) + 16
    Component.onCompleted: { todo.start(); board.focusField() }
    function ago(ms) { return svc.ago(ms) || Qt.formatDateTime(new Date(ms), "d MMM yyyy") }

    // ── header ──
    Item {
        x: 24; y: 18; width: d.width - 48 - btns.width - 8; height: 62
        UiText { text: d.listing ? d.todo.boards.length + " boards" : d.todo.items.length ? d.todo.done + " / " + d.todo.items.length + " done" : "To-do"
            fam: "n"; px: 12; w: 900; track: 1; color: Theme.textDeep }
        UiStrokeText { visible: !nameIn.visible; y: 18; width: parent.width; text: d.listing ? "Boards" : d.todo.name || "…"; px: 30; weight: 700; strokeW: 6; strokeColor: Theme.ink
            MouseArea { anchors.fill: parent; enabled: !d.listing; cursorShape: Qt.IBeamCursor
                onClicked: { nameIn.text = d.todo.name; nameIn.visible = true; nameIn.forceActiveFocus(); nameIn.selectAll() } } }
        TextInput { id: nameIn; visible: false; y: 22; width: parent.width; clip: true
            font.family: Theme.display; font.weight: 700; font.pixelSize: 26; color: Theme.textDeep
            onAccepted: { d.todo.rename(text); visible = false }
            onActiveFocusChanged: if (!activeFocus) visible = false
            Keys.onEscapePressed: visible = false }
    }
    Row {
        id: btns
        x: d.width - width - 24; y: 40; spacing: 6
        Repeater {
            model: [["list", () => { d.listing = !d.listing; if (d.listing) d.todo.list() }, d.listing],
                    ["full", () => d.todo.bigOpen = true, false],
                    ["pushpin", () => d.todo.pinned = !d.todo.pinned, d.todo.pinned]]
            delegate: UiCandy {
                id: hb
                required property var modelData
                width: 32; height: 32; radius: 16; bw: 2.5; drop: modelData[2] ? 0 : 2; hi: 0; fill: modelData[2] ? Theme.inkPhone : Theme.paper; pressable: true
                onClicked: modelData[1]()
                Glyph { anchors.centerIn: parent; name: modelData[0]; size: 14; stroke: 2.6; rotation: modelData[0] === "pushpin" ? 30 : 0; color: hb.modelData[2] ? "#FFFFFF" : Theme.text }
            }
        }
    }

    // ── the board ──
    TodoBoard {
        id: board
        visible: !d.listing
        x: 14; y: d.headerH + 8; width: d.width - 28; listH: 360
        todo: d.todo
    }

    // ── all boards ──
    Flickable {
        visible: d.listing
        x: 14; y: d.headerH + 8; width: d.width - 28; height: Math.min(420, boardsCol.implicitHeight)
        contentHeight: boardsCol.implicitHeight; clip: true; boundsBehavior: Flickable.StopAtBounds
        Column {
            id: boardsCol
            width: parent.width; spacing: 6
            Repeater {
                model: d.todo.boards
                delegate: UiCandy {
                    id: br
                    required property var modelData
                    readonly property bool cur: modelData.path === d.todo.path
                    width: boardsCol.width; height: 58; radius: 14; bw: 2.5; drop: cur ? 3 : 0; hi: 0
                    fill: cur ? Theme.gLilac : Theme.cream; pressable: true
                    onClicked: { d.todo.open(modelData.path); d.listing = false }
                    Column {
                        x: 12; y: 8; width: parent.width - 24 - trash.width - 8; spacing: 4
                        Item { width: parent.width; height: 18
                            UiText { width: parent.width - pc.width - 8; text: br.modelData.name; px: 14; w: 700 }
                            UiText { id: pc; anchors.right: parent.right; text: br.modelData.done + "/" + br.modelData.total; fam: "n"; px: 11; w: 900; color: Theme.textSoft } }
                        Item { width: parent.width; height: 16
                            UiText { width: parent.width - 98; text: "updated " + d.ago(br.modelData.time); fam: "n"; px: 10.5; w: 800; color: Theme.textSoft }
                            // progress bar
                            Rectangle { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; width: 90; height: 8; radius: 4; color: Theme.sand; border.width: 1.5; border.color: Theme.ink
                                Rectangle { x: 1.5; y: 1.5; height: parent.height - 3; radius: 3; color: Theme.leaf
                                    width: (parent.width - 3) * (br.modelData.total ? br.modelData.done / br.modelData.total : 0) } } }
                    }
                    UiCandy {
                        id: trash
                        readonly property bool ask: d.sure === br.modelData.path
                        x: parent.width - width - 10; anchors.verticalCenter: parent.verticalCenter
                        width: ask ? st.implicitWidth + 16 : 28; height: 28; radius: 10; bw: 2; drop: 0; hi: 0; fill: ask ? Theme.pinkSoft : Theme.paper; pressable: true
                        onClicked: { if (ask) { d.todo.removeBoard(br.modelData.path); d.sure = "" } else d.sure = br.modelData.path }
                        Glyph { visible: !trash.ask; anchors.centerIn: parent; name: "trash"; size: 12; stroke: 2.6 }
                        UiText { id: st; visible: trash.ask; anchors.centerIn: parent; text: "Delete?"; px: 11; w: 700 }
                    }
                }
            }
            UiCandy {
                width: boardsCol.width; height: 40; radius: 14; bw: 2.5; drop: 3; hi: 3; fill: Theme.gLeaf; pressable: true
                onClicked: { d.todo.newBoard(); d.listing = false }
                UiText { anchors.centerIn: parent; text: "+ New board"; px: 14; w: 700 }
            }
        }
    }
}
