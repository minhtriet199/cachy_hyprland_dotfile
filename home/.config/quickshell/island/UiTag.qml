import QtQuick

// Little tilted name tag ("Docker", "Notifications", "Calculator"...).
UiCandy {
    id: t
    property string text: ""
    property real px: 13
    property color textColor: "#FFFFFF"
    property real padX: 12
    property real tilt: -4
    width: label.implicitWidth + padX * 2
    height: label.implicitHeight + 4
    rotation: tilt
    bw: 2
    drop: 0
    hi: 0
    UiText { id: label; anchors.centerIn: parent; text: t.text; px: t.px; w: 700; color: t.textColor }
}
