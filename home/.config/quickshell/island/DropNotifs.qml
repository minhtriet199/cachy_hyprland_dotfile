import QtQuick

// Notifications dropdown (bell): header with count + Do not disturb switch, list (click = open, × = dismiss), Clear all.
DropCard {
    id: d
    property var svc
    readonly property var items: svc.notifications
    readonly property real rowH: 74
    // one long message can be opened (↓) to read all of it; its extra height grows the card
    property var openId: null
    property real openExtra: 0
    onItemsChanged: if (openId !== null && !items.some(x => x.id === openId)) { openId = null; openExtra = 0 }
    readonly property real listH: items.length === 0 ? 110 : Math.min(items.length, 5) * (rowH + 8) - 8 + 5 + openExtra   // +5: last row's border + shadow
    width: 360; height: 84 + 14 + listH + 14 + 40 + 16
    headerH: 84

    function ago(t) {
        if (!t) return "";
        const m = Math.floor((d.svc.now.getTime() - t.getTime()) / 60000);
        return m < 1 ? "now" : m < 60 ? m + "m" : m < 1440 ? Math.floor(m / 60) + "h" : Math.floor(m / 1440) + "d";
    }

    // header
    UiCandy {
        x: 22; y: 19; width: 46; height: 46; bw: 2.5; drop: 3; hi: 0; fill: Theme.paper
        Glyph { anchors.centerIn: parent; name: d.svc.dnd ? "bellOff" : "bell"; size: 24; stroke: 2.4 }
        UiCandy { visible: d.items.length > 0; x: parent.width - 16; y: -6; width: Math.max(22, cnt.implicitWidth + 10); height: 22
            bw: 2; drop: 0; hi: 0; fill: Theme.berry
            UiText { id: cnt; anchors.centerIn: parent; text: d.items.length; px: 12; w: 700; color: "#FFFFFF" } }
    }
    Column {
        x: 80; y: 22; spacing: 2
        UiText { text: "Notifications"; px: 22; w: 700 }
        UiText { text: d.items.length ? d.items.length + " waiting for you" : "All caught up"; fam: "n"; px: 11; w: 800; color: Theme.textMuted }
    }
    // Do not disturb switch
    Item {
        x: d.width - 84; y: 18; width: 68; height: 48
        UiText { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: "QUIET"; fam: "n"; px: 9; w: 900; track: 1.2; color: Theme.textMuted }
        UiCandy {
            y: 16; anchors.horizontalCenter: parent.horizontalCenter; width: 56; height: 28; bw: 2.5; drop: 2; hi: 0
            fill: d.svc.dnd ? Theme.lilac : Theme.sand; pressable: true
            onClicked: d.svc.toggle("dnd")
            Rectangle { y: 4; x: d.svc.dnd ? parent.width - width - 4 : 4; width: 20; height: 20; radius: 10
                color: Theme.paper; border.width: 2; border.color: Theme.ink
                Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutBack } } }
        }
    }

    // list
    ListView {
        id: list
        x: 16; y: 84 + 14; width: d.width - 32; height: d.listH
        clip: true; spacing: 8; boundsBehavior: Flickable.StopAtBounds
        model: d.items
        delegate: UiCandy {
            id: row
            required property var modelData
            readonly property bool open: d.openId !== null && d.openId === modelData.id
            width: list.width; height: open ? Math.max(d.rowH, 33 + body.implicitHeight + 10) : d.rowH
            radius: 16; bw: 2.5; drop: 3; hi: 0; fill: Theme.cream; pressable: true
            onHeightChanged: if (open) d.openExtra = height - d.rowH
            onClicked: d.svc.activateNotification(modelData)
            onRightClicked: d.svc.dismissNotification(modelData)
            UiTag { x: 10; y: 9; text: row.modelData.app; fill: row.modelData.tint; ink: Theme.ink; px: 11; padX: 9; tilt: -3 }
            UiText { x: parent.width - width - (more.visible ? 70 : 40); y: 10; text: d.ago(row.modelData.time); fam: "n"; px: 10; w: 800; color: Theme.textSoft }
            UiText {
                id: body
                x: 12; y: 33; width: parent.width - 24
                text: row.modelData.body; fam: "n"; px: 12; w: 800
                wrapMode: Text.Wrap; maximumLineCount: row.open ? 10 : 2; elide: Text.ElideRight; verticalAlignment: Text.AlignTop
            }
            // ↓ only when the text is cut off: shows the rest of the message (↑ closes it)
            UiCandy {
                id: more
                visible: body.truncated || row.open
                x: parent.width - 64; y: 8; width: 24; height: 24; bw: 2; drop: 0; hi: 0; fill: Theme.paper; pressable: true
                onClicked: { d.openExtra = 0; d.openId = row.open ? null : row.modelData.id }
                Glyph { anchors.centerIn: parent; name: "arrowRight"; size: 12; stroke: 2.8; rotation: row.open ? -90 : 90 }
            }
            UiCandy {
                x: parent.width - 34; y: 8; width: 24; height: 24; bw: 2; drop: 0; hi: 0; fill: Theme.paper; pressable: true
                onClicked: d.svc.dismissNotification(row.modelData)
                Glyph { anchors.centerIn: parent; name: "close"; size: 12; stroke: 2.8 }
            }
        }
    }
    Column {
        visible: d.items.length === 0
        x: 0; y: 84 + 14 + 22; width: d.width; spacing: 6
        UiText { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: "✿"; px: 30; w: 700; color: Theme.lilac }
        UiText { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: "Nothing new on the island"; fam: "n"; px: 13; w: 800; color: Theme.textSoft }
    }

    // footer
    UiText { x: 18; y: d.height - 16 - 40; height: 40; text: "Right-click a bubble to dismiss"; fam: "n"; px: 10; w: 800; color: Theme.textSoft }
    UiCandy {
        x: d.width - width - 16; y: d.height - 16 - 38; width: 110; height: 36; radius: 12; bw: 2.5; drop: 3; rotation: Theme.tilt(1)
        hi: 0; fill: Theme.inkPhone; pressable: d.items.length > 0
        opacity: d.items.length ? 1 : 0.5
        onClicked: d.svc.clearNotifications()
        UiText { anchors.centerIn: parent; text: "Clear all"; px: 13; w: 700; color: "#FFFFFF" }
    }
}
