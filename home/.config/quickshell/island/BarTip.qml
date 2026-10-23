import QtQuick
import Quickshell

// Sticker tooltip for a bar icon, in its own little window (the bar window is only as tall as the bar).
// Shows while `target.hovered`; under the icon, or above it when the bar is at the bottom.
PopupWindow {
    id: tp
    property Item target
    property string text: ""
    property real k: 1                       // bar scale (design px → screen px)
    property bool up: false
    visible: text !== "" && !!target && target.hovered
    color: "transparent"
    anchor.item: target
    anchor.edges: up ? Edges.Top : Edges.Bottom
    anchor.gravity: up ? Edges.Top : Edges.Bottom
    implicitWidth: Math.ceil((tag.width + 16) * k)
    implicitHeight: Math.ceil((tag.height + 24) * k)
    Item {
        width: tag.width + 16; height: tag.height + 24
        scale: tp.k; transformOrigin: Item.TopLeft
        UiTag { id: tag; x: 8; y: tp.up ? 4 : 12; text: tp.text; px: 16; padX: 14; tilt: -4; fill: Theme.paper; ink: Theme.ink; textColor: Theme.textDeep }
    }
}
