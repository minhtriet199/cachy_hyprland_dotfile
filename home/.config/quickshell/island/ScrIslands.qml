import QtQuick
import Quickshell
import Quickshell.Widgets

// Islands (workspaces). One row: only islands with apps (+ the one you're on) and a "+" tile — three fit,
// scroll sideways for more. Click = show its apps, click again = go there. Hold + drag onto another island = swap them.
// × on an island closes it with everything in it, × on an app closes that app — both ask first.
// The app list takes the rest of the screen; clicking its empty space makes the phone big.
Item {
    id: is
    property var svc
    property string monitor: ""
    property int monIndex: 0
    signal go(string screen)
    signal done()
    readonly property string mon: svc.monitors.length ? svc.monitors[Math.min(monIndex, svc.monitors.length - 1)].name : monitor
    readonly property var tiles: svc.workspacesFor(mon).filter(t => t.kind !== "empty")
    readonly property var cur: svc.workspacesFor(mon).find(t => t.kind === "current")
    readonly property real cw: width - 36
    property int sel: -1                                    // workspace id whose apps are listed (-1 = the current one)
    readonly property int shownId: sel >= 0 && tiles.some(t => t.id === sel) ? sel : (cur ? cur.id : -1)
    readonly property var shownTile: tiles.find(t => t.id === shownId) || null
    readonly property var wins: shownId >= 0 ? svc.windowsOn(shownId) : []
    function pickMonitor() { const i = svc.monitors.findIndex(m => m.name === monitor); monIndex = i >= 0 ? i : 0 }
    Component.onCompleted: pickMonitor()
    onVisibleChanged: if (visible) { sel = -1; pickMonitor() }      // start on the screen the phone is open on
    // confirm popup: { kind: "island" | "app", id, address, title, names }
    property var ask: null
    // drag to swap
    property int dragFrom: -1
    property int dragOver: -1
    function iconFor(cls) { const e = DesktopEntries.byId(cls) || DesktopEntries.heuristicLookup(cls); return Quickshell.iconPath(e ? e.icon : cls, "application-x-executable") }
    function nameFor(cls) { const e = DesktopEntries.byId(cls) || DesktopEntries.heuristicLookup(cls); return e ? e.name : cls }

    Column {
        id: topCol
        x: 18; y: 16; width: is.cw
        spacing: 12
        Item { width: parent.width; height: 20
            UiText { x: 8; text: is.svc.timeText; px: 16; w: 700 }
            UiText { anchors.right: parent.right; anchors.rightMargin: 8; y: 3; text: is.svc.battery.percent + "%"; fam: "n"; w: 900; px: 11 } }
        // header
        Item {
            width: parent.width; height: 46 + 8
            UiCandy { y: 8; width: 46; height: 46; ink: Theme.ink; drop: 3; hi: 0; pressable: true; onClicked: is.go("home")
                Glyph { anchors.centerIn: parent; name: "back"; size: 22; stroke: 2.8 } }
            Column { x: 58; y: 8
                UiText { text: "Islands"; px: 25; w: 700; height: 27.5 }
                UiText { text: "Drag to swap · Super + Tab"; fam: "n"; w: 800; px: 12; color: Theme.textSoft } }
            UiTag { anchors.right: parent.right; y: 18; text: is.tiles.length + " open"; px: 12; padX: 10; tilt: 6; fill: Theme.peach; ink: Theme.ink; drop: 3; height: 24; radius: 10 }
        }
        // monitor tabs
        UiCandy {
            visible: is.svc.monitors.length > 1
            width: parent.width; height: 48
            ink: Theme.ink; drop: 0; hi: 0; fill: Theme.sand
            Row {
                x: 6; y: 5; spacing: 6
                Repeater {
                    model: is.svc.monitors
                    delegate: UiCandy {
                        required property var modelData
                        required property int index
                        readonly property bool picked: is.mon === modelData.name
                        width: (is.cw - 12 - 6 * (is.svc.monitors.length - 1)) / is.svc.monitors.length; height: 36
                        bw: picked ? 2.5 : 0; drop: picked ? 3 : 0; hi: picked ? 3 : 0
                        fill: picked ? Theme.gGo : "transparent"; pressable: true
                        onClicked: { is.monIndex = index; is.sel = -1 }
                        UiText { anchors.centerIn: parent; text: modelData.label; px: 14; w: 700; color: parent.picked ? "#FFFFFF" : Theme.text }
                    }
                }
            }
        }
        // islands row
        ListView {
            id: row
            width: parent.width; height: 118
            orientation: ListView.Horizontal; spacing: 10; clip: true
            boundsBehavior: Flickable.StopAtBounds
            interactive: is.dragFrom < 0
            readonly property real tileW: (width - 20) / 3
            // mouse wheel (up/down) scrolls the row sideways
            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: e => {
                    const d = (Math.abs(e.angleDelta.x) > Math.abs(e.angleDelta.y) ? e.angleDelta.x : e.angleDelta.y) / 120 * (row.tileW + 10) * 0.6;
                    row.contentX = Math.max(0, Math.min(Math.max(0, row.contentWidth - row.width), row.contentX - d));
                }
            }
            Behavior on contentX { enabled: !row.moving; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            model: is.tiles.concat([{ id: -2, number: 0, kind: "add", tints: [] }])
            delegate: Item {
                id: tileBox
                required property var modelData
                required property int index
                readonly property bool add: modelData.kind === "add"
                readonly property bool here: modelData.kind === "current"
                readonly property bool shown: modelData.id === is.shownId
                width: row.tileW; height: 112
                function tap() {
                    if (add) { const e = is.svc.firstEmptyOn(is.mon); if (e > 0) { is.svc.goWorkspace(e); is.done() } return }
                    if (shown) { is.svc.goWorkspace(modelData.id); is.done() } else is.sel = modelData.id;
                }
                opacity: is.dragFrom === modelData.id ? 0.35 : 1
                UiCandy {
                    y: 4; width: parent.width; height: 104; radius: 22
                    dashed: tileBox.add
                    ink: is.dragOver === tileBox.modelData.id && is.dragFrom >= 0 ? Theme.sunDeep : Theme.ink
                    bw: is.dragOver === tileBox.modelData.id && is.dragFrom >= 0 ? 3.5 : 2.5
                    drop: tileBox.add ? 0 : (tileBox.shown ? 5 : 3); hi: tileBox.add ? 0 : 4
                    fill: tileBox.add ? Qt.rgba(1, 253 / 255, 247 / 255, 0.7) : tileBox.here ? Theme.gGo : tileBox.shown ? Theme.gOn : Theme.paper
                    pressable: true
                    onClicked: tileBox.tap()
                    UiText { visible: !tileBox.add; x: 14; y: 10; text: tileBox.modelData.number; px: 26; w: 700; color: tileBox.here ? "#FFFFFF" : Theme.text }
                    Glyph { visible: tileBox.add; anchors.centerIn: parent; name: "plus"; size: 26; stroke: 2.8; color: Theme.textSoft }
                    UiText { visible: tileBox.add; anchors.horizontalCenter: parent.horizontalCenter; y: parent.height - 26; text: "new island"; fam: "n"; px: 10; w: 900; color: Theme.textSoft }
                    // app dots
                    Row {
                        visible: !tileBox.add
                        x: 14; y: parent.height - 34; spacing: -6
                        Repeater {
                            model: tileBox.modelData.tints.slice(0, 4)
                            delegate: Rectangle { required property string modelData; width: 22; height: 22; radius: 11; color: modelData; border.width: 2; border.color: Theme.ink }
                        }
                    }
                    // close island
                    UiCandy {
                        visible: !tileBox.add && tileBox.modelData.tints.length > 0
                        x: parent.width - 30; y: 8; width: 22; height: 22; bw: 2; drop: 0; hi: 0; fill: Theme.paper; pressable: true
                        onClicked: is.ask = { kind: "island", id: tileBox.modelData.id, number: tileBox.modelData.number,
                                              names: is.svc.windowsOn(tileBox.modelData.id).map(w => is.nameFor(w.cls)) }
                        Glyph { anchors.centerIn: parent; name: "close"; size: 10; stroke: 2.8 }
                    }
                    // drag to swap: starts as soon as the pointer moves ~8 px while pressed (or after a short hold)
                    MouseArea {
                        anchors.fill: parent; z: -1
                        enabled: !tileBox.add
                        pressAndHoldInterval: 150
                        preventStealing: true                                   // the row must not take the drag as a scroll
                        cursorShape: Qt.PointingHandCursor
                        property point p0
                        property bool moved: false
                        onPressed: m => { p0 = Qt.point(m.x, m.y); moved = false }
                        onClicked: if (!moved && is.dragFrom < 0) tileBox.tap()  // a normal click still works
                        onPressAndHold: is.dragFrom = tileBox.modelData.id
                        onPositionChanged: m => {
                            if (is.dragFrom < 0) {
                                if (Math.hypot(m.x - p0.x, m.y - p0.y) < 8) return;
                                is.dragFrom = tileBox.modelData.id
                            }
                            moved = true;
                            const p = mapToItem(is, m.x, m.y); ghost.x = p.x - ghost.width / 2; ghost.y = p.y - ghost.height / 2;
                            const q = mapToItem(row.contentItem, m.x, m.y), i = row.indexAt(q.x, q.y);
                            const t = i >= 0 ? row.model[i] : null; is.dragOver = t && t.kind !== "add" ? t.id : -1;
                        }
                        onReleased: { if (is.dragFrom >= 0 && is.dragOver >= 0) is.svc.swapWorkspaces(is.dragFrom, is.dragOver); is.dragFrom = -1; is.dragOver = -1 }
                        onCanceled: { is.dragFrom = -1; is.dragOver = -1 }
                    }
                }
                // "you are here" pin
                UiCandy { visible: tileBox.here; x: parent.width - 30; y: tileBox.modelData.tints.length ? 36 : 12; width: 22; height: 22; bw: 2; drop: 0; hi: 0; fill: Theme.paper
                    Glyph { anchors.centerIn: parent; name: "pin"; size: 12; stroke: 2.4 } }
            }
        }
        // apps on the shown island
        Item {
            width: parent.width; height: 22
            UiText { text: is.shownTile ? "ON ISLAND " + is.shownTile.number + (is.shownTile.kind === "current" ? " · YOU ARE HERE" : " · CLICK AGAIN TO GO") : "NO ISLAND OPEN"
                fam: "n"; px: 11; w: 900; track: 1.2; color: Theme.textSoft; height: 22 }
        }
    }
    ListView {
        id: apps
        x: 18; y: topCol.y + topCol.height + 6; width: is.cw
        height: is.height - y - ((is.svc.phoneBig && is.height > is.width) ? 64 : 22)
        clip: true; spacing: 8; bottomMargin: is.svc.phoneHide; boundsBehavior: Flickable.StopAtBounds
        model: is.wins
        // empty space → big phone
        MouseArea { z: -1; width: apps.width; height: Math.max(apps.height, apps.contentHeight)
            enabled: !is.svc.phoneBig; onClicked: is.svc.phoneBig = true }
        delegate: UiCandy {
            id: app
            required property var modelData
            width: apps.width; height: 58; radius: 18; bw: 2.5; drop: 3; hi: 0; fill: Theme.cream; pressable: true
            onClicked: { is.svc.focusWindow(modelData.address); is.done() }
            UiCandy { x: 10; y: 9; width: 40; height: 40; radius: 12; bw: 2; drop: 0; hi: 0; fill: Theme.paper
                IconImage { anchors.centerIn: parent; implicitSize: 26; asynchronous: true; source: is.iconFor(app.modelData.cls) } }
            Column { x: 60; y: 10; width: parent.width - 60 - 44
                UiText { width: parent.width; height: 19; text: is.nameFor(app.modelData.cls); px: 15; w: 700 }
                UiMarquee { width: parent.width; height: 16; text: app.modelData.title; fam: "n"; px: 11; w: 800; color: Theme.textSoft } }
            UiCandy { x: parent.width - 36; y: 17; width: 24; height: 24; bw: 2; drop: 0; hi: 0; fill: Theme.paper; pressable: true
                onClicked: is.ask = { kind: "app", address: app.modelData.address, names: [is.nameFor(app.modelData.cls)], title: app.modelData.title }
                Glyph { anchors.centerIn: parent; name: "close"; size: 11; stroke: 2.8 } }
        }
    }
    UiText { visible: is.wins.length === 0; x: 18; width: is.cw; y: apps.y + 30; horizontalAlignment: Text.AlignHCenter
        text: "Nothing on this island ✿"; fam: "n"; px: 13; w: 800; color: Theme.textSoft }

    // drag ghost
    UiCandy {
        id: ghost
        visible: is.dragFrom >= 0; z: 50
        width: row.tileW * 0.8; height: 80; radius: 20; bw: 3; drop: 5; hi: 3; fill: Theme.gSun; opacity: 0.92
        UiText { anchors.centerIn: parent; text: is.dragFrom >= 0 ? (is.tiles.find(t => t.id === is.dragFrom) || { number: "" }).number : ""; px: 26; w: 700 }
    }

    // confirm popup
    Rectangle {
        visible: !!is.ask; z: 60; anchors.fill: parent; color: Qt.rgba(33 / 255, 63 / 255, 72 / 255, 0.35); radius: 30
        MouseArea { anchors.fill: parent; onClicked: is.ask = null }
        UiCandy {
            anchors.centerIn: parent; width: is.cw - 10; height: askCol.implicitHeight + 32; radius: 24; bw: 3; drop: 6; hi: 0; fill: Theme.cream
            MouseArea { anchors.fill: parent; z: -1 }
            Column {
                id: askCol; x: 18; y: 16; width: parent.width - 36; spacing: 10
                UiText { width: parent.width; text: !is.ask ? "" : is.ask.kind === "island" ? "Close island " + is.ask.number + "?" : "Close " + is.ask.names[0] + "?"; px: 20; w: 700; color: Theme.textDeep; wrapMode: Text.Wrap }
                UiText { width: parent.width; fam: "n"; px: 12; w: 800; color: Theme.textMuted; wrapMode: Text.Wrap; maximumLineCount: 4
                    text: !is.ask ? "" : is.ask.kind === "island" ? (is.ask.names.length + " app" + (is.ask.names.length > 1 ? "s" : "") + " will close: " + is.ask.names.join(", ")) : (is.ask.title || "") }
                UiText { width: parent.width; text: "Unsaved work in those apps may be lost."; fam: "n"; px: 11; w: 800; color: Theme.berry; wrapMode: Text.Wrap }
                Row {
                    anchors.right: parent.right; spacing: 10
                    UiCandy { width: 96; height: 38; radius: 12; bw: 2.5; drop: 3; hi: 0; fill: Theme.paper; pressable: true; onClicked: is.ask = null
                        UiText { anchors.centerIn: parent; text: "Cancel"; px: 14; w: 700 } }
                    UiCandy { width: 110; height: 38; radius: 12; bw: 2.5; drop: 3; hi: 3; fill: Theme.gBerry; pressable: true
                        onClicked: { if (is.ask.kind === "island") is.svc.closeWorkspace(is.ask.id); else is.svc.closeWindow(is.ask.address); is.ask = null }
                        UiText { anchors.centerIn: parent; text: is.ask && is.ask.kind === "island" ? "Close all" : "Close"; px: 14; w: 700 } }
                }
            }
        }
    }

    // number keys jump to that island; Esc closes the popup first
    Keys.onPressed: e => {
        if (is.ask && e.key === Qt.Key_Escape) { is.ask = null; e.accepted = true; return }
        if (e.key >= Qt.Key_1 && e.key <= Qt.Key_9 && !(e.modifiers & Qt.ControlModifier)) { is.svc.goWorkspace(is.svc.base(is.mon) + e.key - Qt.Key_0); is.done(); e.accepted = true }
    }
}
