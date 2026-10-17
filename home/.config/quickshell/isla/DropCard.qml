import QtQuick

// Bar dropdown card (canvas "Bar-Dropdowns"): paper card, coloured dotted header, ink rule under it.
UiCandy {
    id: c
    property color headerColor: Theme.gLeaf[1]
    property real headerH: 90
    default property alias body: holder2.data
    radius: 24; bw: 3; ink: Theme.ink; drop: 6; hi: 0
    fill: Theme.paper
    readonly property real r2: radius - bw
    // header (top corners rounded, bottom square)
    Item {
        x: c.bw; y: c.bw; width: c.width - 2 * c.bw; height: c.headerH - c.bw
        Rectangle { anchors.fill: parent; radius: c.r2; color: c.headerColor }
        Rectangle { y: parent.height - c.r2; width: parent.width; height: c.r2; color: c.headerColor }
        UiDots { anchors.fill: parent; radius: c.r2; dot: Qt.rgba(1, 1, 1, 0.55); step: 14; r: 1.7 }
    }
    Rectangle { x: c.bw; y: c.headerH; width: c.width - 2 * c.bw; height: 3; color: c.ink }
    Item { id: holder2; anchors.fill: parent }
    // swallow clicks so they don't reach the scrim behind
    MouseArea { anchors.fill: parent; z: -1; acceptedButtons: Qt.AllButtons }
}
