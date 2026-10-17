import QtQuick
import QtQuick.Shapes

// Four-point sparkle.
Item {
    id: s
    property color starColor: Theme.sun
    property real size: 24
    width: size; height: size
    Shape {
        width: 24; height: 24; scale: s.size / 24; transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer
        ShapePath { fillColor: s.starColor; strokeColor: Theme.inkClock; strokeWidth: 2; joinStyle: ShapePath.RoundJoin
            PathSvg { path: "M12 1.5c.8 5.2 2.3 7.7 9.5 10.5-7.2 2.8-8.7 5.3-9.5 10.5C11.2 17.3 9.7 14.8 2.5 12 9.7 9.2 11.2 6.7 12 1.5z" } }
    }
}
