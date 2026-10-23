import QtQuick

// Launcher icon: paper tile with a coloured rounded square and a white glyph, label under it.
Item {
    id: a
    property string label: ""
    property string glyph: "grid"
    property color tint: Theme.sea
    property string iconSource: ""
    property bool selected: false
    signal clicked()
    width: 81; height: 64 + 7 + 17
    UiCandy {
        id: tile
        anchors.horizontalCenter: parent.horizontalCenter
        width: 64; height: 64; radius: 20; drop: 5; ink: Theme.inkPhone
        hi: 5; hiColor: Qt.rgba(1, 1, 1, 0.85); fill: Theme.paper; pressable: true
        scale: ma.containsMouse || a.selected ? 1.06 : 1
        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }
        onClicked: a.clicked()
        Rectangle { anchors.bottom: parent.bottom; anchors.bottomMargin: 2.5; x: 2.5; width: parent.width - 5; height: 6; radius: 4; color: Qt.rgba(0, 0, 0, 0.06) }
        Rectangle {
            anchors.centerIn: parent; width: 42; height: 42; radius: 13; color: a.tint
            Rectangle { width: parent.width; height: 6; radius: 13; color: Qt.rgba(1, 1, 1, 0.35); visible: false }
            Glyph { anchors.centerIn: parent; visible: a.iconSource === ""; name: a.glyph; size: 24; stroke: 2.5; color: "#FFFFFF" }
            Image { anchors.centerIn: parent; visible: a.iconSource !== ""; source: a.iconSource; width: 28; height: 28; sourceSize: Qt.size(64, 64); smooth: true }
        }
        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
    }
    UiText {
        anchors.horizontalCenter: parent.horizontalCenter; y: 64 + 7
        width: Math.min(implicitWidth, 76); horizontalAlignment: Text.AlignHCenter
        text: a.label; px: 12.5; w: 600
    }
}
