import QtQuick
import QtQuick.Layouts

// One candy pill in the top bar. Put icons/text inside; it sizes itself.
Item {
    id: p
    property var fill: Theme.gSea
    property real padL: 16
    property real padR: 16
    property real gap: 8
    property real hiAlpha: 0.75
    property real h: 42
    property bool pressable: false
    signal clicked()
    signal rightClicked()
    signal wheel(real dy)
    default property alias items: row.data
    implicitWidth: row.implicitWidth + padL + padR
    implicitHeight: h
    width: implicitWidth; height: implicitHeight
    UiCandy {
        anchors.fill: parent
        fill: p.fill
        hiColor: Qt.rgba(1, 1, 1, p.hiAlpha)
        pressable: p.pressable
        onClicked: p.clicked()
        onRightClicked: p.rightClicked()
        RowLayout { id: row; x: p.padL; anchors.verticalCenter: parent.verticalCenter; spacing: p.gap }
    }
    WheelHandler { onWheel: e => p.wheel(e.angleDelta.y) }
}
