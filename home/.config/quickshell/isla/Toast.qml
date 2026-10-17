import QtQuick

// A notification as a dialogue bubble with a tilted name tag (canvas "Docker" toast).
Item {
    id: t
    property string app: ""
    property string body: ""
    property color tint: Theme.peach
    property bool compact: false          // phone list version
    property bool expanded: false         // long message opened with the › button
    onBodyChanged: expanded = false
    signal clicked()
    signal dismissed()
    width: 430
    height: bubble.y + bubble.height + (compact ? 3 : 6)
    readonly property real tagH: compact ? 20 : 30
    UiCandy {
        id: bubble
        y: t.compact ? 13 : 15
        width: t.width
        height: msg.implicitHeight + (t.compact ? 35 : 46)
        radius: t.compact ? 20 : 28
        bw: t.compact ? 2.5 : 3
        drop: t.compact ? 3 : 6
        hi: 0
        ink: t.compact ? Theme.inkPhone : Theme.ink
        fill: Theme.cream
        pressable: true
        onClicked: t.clicked()
        onRightClicked: t.dismissed()
        UiText {
            id: msg
            x: t.compact ? 16.5 : 22; y: t.compact ? 20.5 : 26
            width: parent.width - x - (t.compact ? 16.5 : 52)   // room for the › button
            text: t.body; fam: "n"; w: 800; px: t.compact ? 13 : 14
            wrapMode: Text.Wrap; maximumLineCount: t.compact ? 3 : (t.expanded ? 12 : 2); elide: Text.ElideRight
            lineHeightMode: Text.FixedHeight; lineHeight: t.compact ? 17.5 : 19.5
            verticalAlignment: Text.AlignTop
        }
        // › only when the text is cut off: opens the rest of the message
        UiCandy {
            id: more
            visible: !t.compact && (msg.truncated || t.expanded)
            anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: msg.verticalCenter
            width: 28; height: 28; bw: 2; drop: 0; hi: 0; fill: Theme.paper; pressable: true
            onClicked: t.expanded = !t.expanded
            Glyph { anchors.centerIn: parent; name: "arrowRight"; size: 13; stroke: 2.8; rotation: t.expanded ? -90 : 90 }
        }
    }
    UiTag {
        x: t.compact ? 12 : 18; y: 0
        text: t.app; px: t.compact ? 12 : 14; padX: t.compact ? 11 : 13
        height: t.compact ? 22 : 28
        bw: t.compact ? 2 : 2.5
        drop: t.compact ? 0 : 3
        tilt: t.compact ? (t.app.length % 2 ? 3 : -4) : -4
        fill: t.tint
        ink: t.compact ? Theme.inkPhone : Theme.ink
    }
}
