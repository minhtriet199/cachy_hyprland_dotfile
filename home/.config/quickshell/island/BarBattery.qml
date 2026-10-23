import QtQuick
import QtQuick.Shapes

// Battery icon whose fill follows the charge.
Item {
    id: b
    property real size: 21
    property real level: 0.6
    property bool charging: false
    property color color: Theme.text
    implicitWidth: size; implicitHeight: size
    Item {
        width: 24; height: 24; scale: b.size / 24; transformOrigin: Item.TopLeft
        Shape {
            anchors.fill: parent; preferredRendererType: Shape.CurveRenderer
            ShapePath { strokeColor: b.color; strokeWidth: 2.3; fillColor: "transparent"; capStyle: ShapePath.RoundCap; joinStyle: ShapePath.RoundJoin
                PathSvg { path: "M5 7h12a3 3 0 0 1 3 3v4a3 3 0 0 1-3 3H5a3 3 0 0 1-3-3v-4a3 3 0 0 1 3-3zM22 11v2" } }
        }
        Rectangle { x: 4.5; y: 9.5; height: 5; radius: 1; color: b.charging ? Theme.leafDeep : b.color
            width: Math.max(1.5, 13 * Math.max(0, Math.min(1, b.level))) }
    }
}
