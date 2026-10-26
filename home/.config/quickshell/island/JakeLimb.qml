import QtQuick
import QtQuick.Shapes
import "JakeShapes.js" as J

// One noodle limb of the Jake puppet (JakeWipe): from the shoulder / hip at (x, y), upper part at angle `a`, lower part
// bent by `b` at the elbow / knee (degrees, 0 = straight down, + = clockwise), then a paw or a foot. Drawn as one
// thick ink stroke with the fur stroke on top, so the bend has no seams.
Item {
    id: lm
    property real a: 0
    property real b: 0
    property real len1: 40
    property real len2: 40
    property real w: 11
    property bool foot: false
    function dx(deg) { return -Math.sin(deg * Math.PI / 180) }
    function dy(deg) { return Math.cos(deg * Math.PI / 180) }
    readonly property real ex: len1 * dx(a)
    readonly property real ey: len1 * dy(a)
    readonly property real hx: ex + len2 * dx(a + b)
    readonly property real hy: ey + len2 * dy(a + b)
    Shape {
        preferredRendererType: Shape.CurveRenderer
        ShapePath { fillColor: "transparent"; strokeColor: J.ink; strokeWidth: lm.w + 2 * J.line; capStyle: ShapePath.RoundCap; joinStyle: ShapePath.RoundJoin
            startX: 0; startY: 0; PathQuad { controlX: lm.ex; controlY: lm.ey; x: lm.hx; y: lm.hy } }
        ShapePath { fillColor: "transparent"; strokeColor: J.fur; strokeWidth: lm.w; capStyle: ShapePath.RoundCap; joinStyle: ShapePath.RoundJoin
            startX: 0; startY: 0; PathQuad { controlX: lm.ex; controlY: lm.ey; x: lm.hx; y: lm.hy } }
    }
    // paw: small round · foot: flat oval pointing along the lower part, turned forward
    Rectangle {
        readonly property real fw: lm.foot ? J.leg.footW : 2 * J.arm.hand
        readonly property real fh: lm.foot ? J.leg.footH : 2 * J.arm.hand
        x: lm.hx - (lm.foot ? fh / 2 : fw / 2); y: lm.hy - fh / 2; width: fw; height: fh; radius: fh / 2
        rotation: lm.foot ? lm.a + lm.b : 0; transformOrigin: Item.Left
        color: J.fur; border.width: J.line; border.color: J.ink
    }
}
