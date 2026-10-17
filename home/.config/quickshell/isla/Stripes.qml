import QtQuick

// Stripe wipe: chunky candy blocks of different lengths sweeping across the screen, a little out of step.
// t: 0 → 1. mode: "coverL" (grow from the left) · "revealR" (leave to the right)
//                 "coverR" (grow from the right) · "revealL" (leave to the left) · "full" · "none"
Item {
    id: sw
    property real t: 0
    property string mode: "none"
    property color fill: "#55BFC6"            // one colour for every block (sea blue)
    readonly property var delays: [0.10, 0.00, 0.22, 0.06, 0.28, 0.14, 0.03]      // out of step on purpose
    readonly property real spread: 0.32
    visible: mode !== "none"
    function ease(x) { return x < 0.5 ? 4 * x * x * x : 1 - Math.pow(-2 * x + 2, 3) / 2 }   // in-out cubic
    Repeater {
        model: 7
        delegate: Item {
            required property int index
            readonly property real p: sw.mode === "full" ? 1 : sw.ease(Math.max(0, Math.min(1, (sw.t * (1 + sw.spread) - sw.delays[index]))))
            readonly property real bh: sw.height / 7
            readonly property real sw2: sw.width
            y: index * bh - 1; height: bh + 2
            // bars run past the screen edge on the side they're attached to, so only the moving end is round
            readonly property real l: sw.mode === "coverL" ? -bh : sw.mode === "revealR" ? -bh + p * (sw2 + 2 * bh)
                                    : sw.mode === "coverR" ? sw2 - p * (sw2 + bh) : -bh
            readonly property real r: sw.mode === "coverL" ? p * (sw2 + bh) : sw.mode === "revealL" ? sw2 + bh - p * (sw2 + 2 * bh) : sw2 + bh
            x: l; width: Math.max(0, r - l)
            // one flat colour, thick black outline, solid black shadow
            Rectangle { x: 0; y: 10; width: parent.width + 10; height: parent.height; radius: 10; color: "#111111" }
            Rectangle {
                anchors.fill: parent; radius: 10; color: sw.fill; border.width: 8; border.color: "#111111"
            }
        }
    }
}
