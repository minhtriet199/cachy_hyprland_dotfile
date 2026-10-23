import QtQuick
import QtQuick.Shapes

// Rounded box with a dashed outline (empty workspace, drop targets).
Shape {
    id: s
    property real radius: 999
    property real bw: 2.5
    property color color: Theme.ink
    property color fillColor: "transparent"
    readonly property real rr: Math.min(radius, Math.min(width, height) / 2) - bw / 2
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
        strokeColor: s.color; strokeWidth: s.bw; fillColor: s.fillColor
        strokeStyle: ShapePath.DashLine; dashPattern: [2.2, 1.6]; capStyle: ShapePath.FlatCap
        PathRectangle { x: s.bw / 2; y: s.bw / 2; width: s.width - s.bw; height: s.height - s.bw; radius: s.rr }
    }
}
