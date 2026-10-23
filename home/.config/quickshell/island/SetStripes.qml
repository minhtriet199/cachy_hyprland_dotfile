import QtQuick

// Three little slanted colour stripes (decoration on cards).
Row {
    property real w: 8
    property real h: 14
    property var colors: [Theme.sunDeep, Theme.berry, "#A08AEA"]
    spacing: 4
    Repeater { model: parent.colors
        delegate: Rectangle { required property var modelData; width: parent.w; height: parent.h; radius: 2; color: modelData
            transform: Matrix4x4 { matrix: Qt.matrix4x4(1, -0.364, 0, parent.h * 0.364 / 2, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) } } }
}
