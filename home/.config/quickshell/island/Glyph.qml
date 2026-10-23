import QtQuick
import QtQuick.Shapes
import "Glyphs.js" as G

// Vector icon from the Island set (24×24 grid, round strokes) — sharp at any scale.
Item {
    id: root
    property string name: "info"
    property real size: 20
    property color color: Theme.text
    property real stroke: 2.4
    implicitWidth: size; implicitHeight: size
    readonly property var g: G.get(name)
    Shape {
        width: 24; height: 24
        scale: root.size / 24
        transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: root.g.s.length ? root.color : "transparent"; strokeWidth: root.stroke
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap; joinStyle: ShapePath.RoundJoin
            PathSvg { path: root.g.s.length ? root.g.s : "M0 0" }
        }
        ShapePath {
            strokeColor: "transparent"; strokeWidth: 0
            fillColor: root.g.f.length ? root.color : "transparent"
            PathSvg { path: root.g.f.length ? root.g.f : "M0 0" }
        }
    }
}
