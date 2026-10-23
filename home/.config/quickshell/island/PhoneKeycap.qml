import QtQuick

// Small keyboard key label ("Super ␣", "Esc", "↵").
Rectangle {
    id: k
    property string text: ""
    property color textColor: Theme.text
    property color fill: Theme.sand
    property color ink: Theme.inkPhone
    property real px: 11
    signal clicked()
    width: lbl.implicitWidth + 16; height: lbl.implicitHeight + 6
    radius: 8; color: fill; border.width: 2; border.color: ink
    UiText { id: lbl; anchors.centerIn: parent; text: k.text; px: k.px; w: 700; color: k.textColor }
    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: k.clicked() }
}
