import QtQuick

// Bar dropdown card: paper card with the header as an inset box (SekaiPop style).
UiCandy {
    id: c
    property color headerColor: Theme.gActive[0]      // same accent on every card (the music card tints it with the cover)
    property real headerH: 90
    default property alias body: holder2.data
    radius: 24; bw: 3; ink: Theme.ink; drop: 6; hi: 0
    fill: Theme.paper
    readonly property real r2: radius - bw
    // header: a box inside the card (SekaiPop style) — its own ink outline, soft gradient, halftone dots
    Rectangle {
        x: c.bw + 7; y: c.bw + 7; width: c.width - 2 * (c.bw + 7); height: c.headerH - c.bw - 10
        radius: c.r2 - 5; border.width: 2.5; border.color: c.ink
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.lighter(c.headerColor, 1.12) }
            GradientStop { position: 1; color: c.headerColor }
        }
        UiDots { anchors.fill: parent; anchors.margins: 2.5; radius: parent.radius - 2.5; dot: Qt.rgba(1, 1, 1, 0.5); step: 9; r: 1.4 }
    }
    Item { id: holder2; anchors.fill: parent }
    // swallow clicks so they don't reach the scrim behind
    MouseArea { anchors.fill: parent; z: -1; acceptedButtons: Qt.AllButtons }
}
