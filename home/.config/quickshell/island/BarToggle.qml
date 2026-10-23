import QtQuick

// Small toggle inside the lilac pill: dark ink bubble when on.
Item {
    id: t
    property string name: "moon"
    property bool on: false
    signal clicked()
    implicitWidth: 32; implicitHeight: 28
    Rectangle { anchors.fill: parent; radius: 14; color: Theme.ink; opacity: t.on ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 160 } } }
    Glyph { anchors.centerIn: parent; name: t.name; size: 17; stroke: t.on ? 2.4 : 2.3; color: t.on ? "#FFF3C4" : Theme.text }
    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: t.clicked() }
}
