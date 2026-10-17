import QtQuick

// Chunky level bar (volume, brightness). Click or drag to set.
Item {
    id: l
    property real value: 0.5
    property color color: Theme.sea
    property color ink: Theme.inkPhone
    signal picked(real v)
    height: 10
    // fully round: frame, track and fill all use half their height as radius
    Rectangle { anchors.fill: parent; radius: height / 2; color: l.ink }
    Rectangle { id: track; anchors.fill: parent; anchors.margins: 2; radius: height / 2; color: Theme.sand }
    Rectangle {
        x: track.x; y: track.y; height: track.height; radius: height / 2; color: l.color
        width: Math.max(height, track.width * Math.max(0, Math.min(1, l.value)))   // never thinner than a round dot
        visible: l.value > 0.005
        Behavior on width { NumberAnimation { duration: 120 } }
    }
    MouseArea {
        anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor
        function pick(m) { l.picked(Math.max(0, Math.min(1, (m.x - 8) / (l.width - 4)))) }
        onPressed: m => pick(m)
        onPositionChanged: m => { if (pressed) pick(m) }
    }
}
