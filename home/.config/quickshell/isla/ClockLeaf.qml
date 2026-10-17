import QtQuick
import QtQuick.Shapes

// Leaf used as the clock colon.
Item {
    id: l
    property color leafColor: "#8FD48F"
    property real size: 44
    width: size; height: size
    Shape {
        width: 24; height: 24; scale: l.size / 24; transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer
        ShapePath { fillColor: l.leafColor; strokeColor: Theme.inkClock; strokeWidth: 2.4; joinStyle: ShapePath.RoundJoin
            PathSvg { path: "M12 2c5 3 8 7 8 11a8 8 0 0 1-16 0c0-4 3-8 8-11z" } }
        ShapePath { fillColor: "transparent"; strokeColor: Theme.inkClock; strokeWidth: 2; capStyle: ShapePath.RoundCap
            PathSvg { path: "M12 6v14" } }
        ShapePath { fillColor: "transparent"; strokeColor: "#FFFFFF"; strokeWidth: 1.8; capStyle: ShapePath.RoundCap
            PathSvg { path: "M8.5 9.5c1 .3 1.6 .8 1.8 1.6" } }
    }
}
