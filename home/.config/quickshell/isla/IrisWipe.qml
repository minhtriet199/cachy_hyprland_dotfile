import QtQuick
import QtQuick.Shapes

// Animal Crossing–style scene change: the screen closes into a shrinking circle onto cream,
// a leaf pops in the middle, then the circle opens onto the next screen.
// t: 0 → 1. mode: "coverL"/"coverR" = closing · "revealL"/"revealR" = opening · "full" = cream + leaf · "none"
// (same mode names as the old stripe wipe, so shell.qml drives it unchanged)
Item {
    id: iw
    property real t: 0
    property string mode: "none"
    readonly property var bg: Prefs.wipeBgs[Prefs.wipeBg] || Prefs.wipeBgs.cream
    property color fill: bg[0]
    visible: mode !== "none"
    readonly property bool closing: mode === "coverL" || mode === "coverR"
    readonly property bool opening: mode === "revealL" || mode === "revealR"
    function easeIn(x) { return x * x * x }
    function easeOut(x) { return 1 - Math.pow(1 - x, 3) }
    readonly property real maxR: Math.hypot(width, height) / 2 + 8
    // hole radius: closing shrinks (ease-in, it speeds up at the end), opening grows (ease-out)
    readonly property real hole: mode === "full" ? 0 : closing ? maxR * (1 - easeIn(Math.min(1, t))) : opening ? maxR * easeOut(Math.min(1, t)) : maxR
    readonly property real cx: width / 2
    readonly property real cy: height / 2

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: iw.fill; strokeColor: "transparent"; fillRule: ShapePath.OddEvenFill
            // whole screen …
            startX: 0; startY: 0
            PathLine { x: iw.width; y: 0 }
            PathLine { x: iw.width; y: iw.height }
            PathLine { x: 0; y: iw.height }
            PathLine { x: 0; y: 0 }
            // … minus the circle
            PathMove { x: iw.cx + Math.max(0.01, iw.hole); y: iw.cy }
            PathArc { x: iw.cx - Math.max(0.01, iw.hole); y: iw.cy; radiusX: Math.max(0.01, iw.hole); radiusY: Math.max(0.01, iw.hole) }
            PathArc { x: iw.cx + Math.max(0.01, iw.hole); y: iw.cy; radiusX: Math.max(0.01, iw.hole); radiusY: Math.max(0.01, iw.hole) }
        }
    }
    // soft dots on the cream, like ACNH paper
    UiDots { anchors.fill: parent; visible: iw.hole < 4; dot: iw.bg[1]; step: 34; r: 3 }

    // the leaf: pops in when the screen is closed, shrinks away as it opens
    Item {
        id: leaf
        readonly property real show: iw.mode === "full" ? 1 : iw.closing ? Math.max(0, (iw.t - 0.82) / 0.18) : iw.opening ? Math.max(0, 1 - iw.t / 0.35) : 0
        width: 150; height: 150; anchors.centerIn: parent
        visible: show > 0.01
        scale: iw.closing ? 0.4 + 0.75 * iw.easeOut(show) - 0.15 * Math.max(0, show - 0.8) * 5 : show
        rotation: Math.sin((iw.t + (iw.opening ? 1 : 0)) * Math.PI * 4) * 8 * show
        WipeIcon { anchors.fill: parent; name: Prefs.wipeIcon }
    }
}
