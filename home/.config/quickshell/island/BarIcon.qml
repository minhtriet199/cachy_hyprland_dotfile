import QtQuick

// A clickable icon inside a bar pill.
Item {
    id: i
    property string name: "info"
    property string under: ""            // faint icon drawn behind (e.g. all Wi-Fi bars behind the lit ones)
    property bool pulse: false            // gentle blink (Bluetooth searching)
    property string badge: ""             // "!" in the corner: "nointernet" (orange) · "error" (red)
    property real size: 19
    readonly property bool hovered: ma.containsMouse
    signal clicked()
    signal wheel(real dy)
    implicitWidth: size; implicitHeight: size
    Glyph { visible: i.under !== ""; anchors.centerIn: parent; name: i.under || "info"; size: i.size; stroke: 2.3; opacity: 0.28 }
    SequentialAnimation on opacity { running: i.pulse; loops: Animation.Infinite
        NumberAnimation { to: 0.35; duration: 600; easing.type: Easing.InOutSine } NumberAnimation { to: 1; duration: 600; easing.type: Easing.InOutSine }
        onRunningChanged: if (!running) i.opacity = 1 }
    Glyph { anchors.centerIn: parent; name: i.name; size: i.size; stroke: 2.3; scale: ma.pressed ? 0.85 : (ma.containsMouse ? 1.12 : 1)
        Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutBack } } }
    MouseArea { id: ma; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: i.clicked(); onWheel: w => i.wheel(w.angleDelta.y) }
    Rectangle {
        visible: i.badge !== ""
        x: i.width - 5; y: -5; width: 11; height: 11; radius: 5.5
        color: i.badge === "error" ? Theme.berry : Theme.orange; border.width: 1.5; border.color: Theme.ink
        UiText { anchors.centerIn: parent; text: "!"; px: 9; w: 700; color: "#FFFFFF"; height: 10 }
    }
}
