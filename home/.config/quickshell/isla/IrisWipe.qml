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
    function easeInOut(x) { return x < 0.5 ? 4 * x * x * x : 1 - Math.pow(-2 * x + 2, 3) / 2 }
    readonly property real maxR: Math.hypot(width, height) / 2 + 8
    // hole radius: closing shrinks (ease-in), opening grows gently (ease-in-out, mirrors the close instead of bursting open)
    readonly property real hole: mode === "full" ? 0 : closing ? maxR * (1 - easeIn(Math.min(1, t))) : opening ? maxR * easeInOut(Math.min(1, t)) : maxR
    readonly property real cx: width / 2
    readonly property real cy: height / 2

    // cover = a ring whose inner edge is the hole (a huge border is sturdier than a path with a hole in it)
    Item {
        anchors.fill: parent; clip: true
        Rectangle {
            readonly property real ring: iw.maxR + 4
            width: 2 * (Math.max(8, iw.hole) + ring); height: width; radius: width / 2      // never a zero hole (it stops drawing)
            x: iw.cx - width / 2; y: iw.cy - height / 2
            color: "transparent"; border.width: ring; border.color: iw.fill
        }
    }
    // fully closed: a plain cover (the ring can't draw a hole of size 0)
    Rectangle { anchors.fill: parent; visible: iw.hole < 10; color: iw.fill }
    // soft dots on the cream, like ACNH paper
    // painted once ahead of time at normal size (painting a huge canvas at the closing moment stalled the screen)
    UiDots { anchors.fill: parent; res: 1; opacity: iw.hole < 4 ? 1 : 0; dot: iw.bg[1]; step: 34; r: 3 }

    // the leaf: pops in when the screen is closed, shrinks away as it opens
    Item {
        id: leaf
        readonly property real show: iw.mode === "full" ? 1 : iw.closing ? Math.max(0, Math.min(1, (iw.t - 0.62) / 0.38)) : iw.opening ? Math.max(0, 1 - iw.t / 0.4) : 0
        function backOut(x) { const c = 1.6; return 1 + (c + 1) * Math.pow(x - 1, 3) + c * Math.pow(x - 1, 2) }
        width: 150; height: 150; anchors.centerIn: parent
        visible: show > 0.01
        scale: iw.closing ? backOut(show) : iw.opening ? iw.easeOut(show) : 1
        opacity: Math.min(1, show * 2)
        rotation: Math.sin((iw.t + (iw.opening ? 1 : 0)) * Math.PI * 4) * 8 * show
        WipeIcon { anchors.fill: parent; name: Prefs.wipeIcon }
    }
}
