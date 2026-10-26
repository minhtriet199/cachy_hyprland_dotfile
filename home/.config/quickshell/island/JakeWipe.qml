import QtQuick
import QtQuick.Shapes
import "JakeShapes.js" as J

// "Jake" scene change (Settings → Shell → Lock & unlock transition → Type: Jake). Same driver as IrisWipe (mode + t),
// so shell.qml's lock / unlock sequences run it unchanged:
//   coverL  (lock screen, after the password)   the Jake picture fades in over the lock screen
//   revealR (desktop, right after unlocking)    Jake winks, the orange shrinks into his head, he gets his body and
//                                               walks off to the right
//   coverR  (desktop, before locking)           the reverse: Jake walks in, grows into the full orange picture
//   revealL (lock screen, after locking)        the picture fades out onto the lock screen
//   full                                        just the picture
// The face sits exactly where the lock-screen picture (~/Pictures/Wallpapers/jake-the-dog-2k.png, centre-cropped) has it.
Item {
    id: jw
    property real t: 0
    property string mode: "none"
    visible: mode !== "none"
    readonly property bool walkOut: mode === "revealR"
    readonly property bool walkIn: mode === "coverR"
    function ph(a, b) { return Math.max(0, Math.min(1, (t - a) / (b - a))) }     // 0..1 inside [a, b] of t
    function ease(x) { return x < 0.5 ? 4 * x * x * x : 1 - Math.pow(-2 * x + 2, 3) / 2 }
    // shrink = 0: the full picture · 1: small Jake. walk = 0: centre · 1: off screen (right when leaving, left when coming)
    readonly property real shrink: walkOut ? ease(ph(0.2, 0.46)) : walkIn ? 1 - ease(ph(0.55, 0.95)) : 0
    readonly property real bodyIn: walkOut ? ease(ph(0.42, 0.52)) : walkIn ? 1 - ease(ph(0.48, 0.58)) : 0
    readonly property real walk: walkOut ? ph(0.55, 1) : walkIn ? 1 - ph(0, 0.5) : 0
    readonly property real wink: walkOut ? Math.sin(Math.PI * ph(0.02, 0.2)) : 0
    readonly property real fade: mode === "coverL" ? t : mode === "revealL" ? 1 - t : 1

    // picture scale (box units → px) where the lock screen shows it, and the small walking size
    readonly property real kBig: Math.max(width / 2560, height / 1440) * 2560 / J.box.srcW
    readonly property real kSmall: Math.max(0.55, Math.min(1.1, height / 1100))
    readonly property real k: kBig + (kSmall - kBig) * shrink
    // face box centre: centre of the screen, moved like in the picture (face centre is a bit off the middle there)
    readonly property real fcx: width / 2 + (J.box.srcX + J.box.w / 2 - J.box.srcW / 2) * k + walk * (walkIn ? -1 : 1) * (width / 2 + 200 * kSmall)
    readonly property real fcy: height / 2 + (J.box.srcY + J.box.h / 2 - 404) * k - bodyIn * 40 * kSmall
                                + (walk > 0 ? -Math.abs(Math.sin(walk * Math.PI * 9)) * 6 * kSmall : 0)     // little hops while walking
    opacity: fade

    // the orange: whole screen, shrinking into Jake's head around the face
    Rectangle {
        readonly property real hw: J.head.w * jw.k
        readonly property real hh: J.head.h * jw.k
        readonly property real hx: jw.fcx + (J.head.cx - J.box.w / 2) * jw.k - hw / 2
        readonly property real hy: jw.fcy + (J.head.cy - J.box.h / 2) * jw.k - hh / 2
        x: hx * jw.shrink; y: hy * jw.shrink
        width: jw.width + (hw - jw.width) * jw.shrink; height: jw.height + (hh - jw.height) * jw.shrink
        radius: Math.min(width, height) / 2 * jw.shrink
        color: J.bg
        border.width: jw.shrink > 0.85 ? J.line * jw.k : 0; border.color: J.ink
    }
    // Jake, drawn in box units
    Item {
        id: fig
        width: J.box.w; height: J.box.h
        x: jw.fcx - width / 2; y: jw.fcy - height / 2
        scale: jw.k; transformOrigin: Item.Center
        // body (behind the head)
        Item {
            z: -1; opacity: jw.bodyIn; visible: opacity > 0
            transform: Scale { origin.x: 72; origin.y: 100; yScale: 0.3 + 0.7 * jw.bodyIn }
            Repeater {
                model: J.arms
                delegate: Rectangle { required property var modelData; required property int index
                    x: modelData.x; y: modelData.y; width: modelData.w; height: modelData.h; radius: width / 2
                    color: J.fur; border.width: J.line; border.color: J.ink
                    rotation: (index ? -1 : 1) * (12 + Math.sin(jw.walk * Math.PI * 9) * 18); transformOrigin: Item.Top }
            }
            Shape { preferredRendererType: Shape.CurveRenderer
                ShapePath { fillColor: "transparent"; strokeColor: J.ink; strokeWidth: J.line * 2.4; capStyle: ShapePath.RoundCap; PathSvg { path: J.tail } }
                ShapePath { fillColor: "transparent"; strokeColor: J.fur; strokeWidth: J.line * 0.8; capStyle: ShapePath.RoundCap; PathSvg { path: J.tail } } }
            Repeater {
                model: J.legs
                delegate: Rectangle { required property var modelData; required property int index
                    x: modelData.x; y: modelData.y; width: modelData.w; height: modelData.h; radius: width / 2
                    color: J.fur; border.width: J.line; border.color: J.ink
                    rotation: (index ? -1 : 1) * Math.sin(jw.walk * Math.PI * 9) * 24; transformOrigin: Item.Top }
            }
            Shape { preferredRendererType: Shape.CurveRenderer
                ShapePath { fillColor: J.fur; strokeColor: J.ink; strokeWidth: J.line; PathSvg { path: J.body } } }
        }
        // face
        Shape {
            preferredRendererType: Shape.CurveRenderer
            ShapePath { fillColor: J.ink; strokeColor: "transparent"; PathSvg { path: J.circle(J.eyeL.cx + J.eyeL.sx, J.eyeL.cy + J.eyeL.sy, J.eyeL.r + 1.5) } }
            ShapePath { fillColor: "#FFFFFF"; strokeColor: J.ink; strokeWidth: J.line; PathSvg { path: J.circle(J.eyeL.cx, J.eyeL.cy, J.eyeL.r) } }
            ShapePath { fillColor: J.ink; strokeColor: "transparent"; PathSvg { path: J.circle(J.eyeR.cx + J.eyeR.sx, J.eyeR.cy + J.eyeR.sy, J.eyeR.r + 1.5) } }
        }
        // the winking eye: the white closes top-down to a line, then opens again
        Shape {
            preferredRendererType: Shape.CurveRenderer
            transform: Scale { origin.x: J.eyeR.cx; origin.y: J.eyeR.cy + 4; yScale: Math.max(0.06, 1 - jw.wink) }
            ShapePath { fillColor: "#FFFFFF"; strokeColor: J.ink; strokeWidth: J.line; PathSvg { path: J.circle(J.eyeR.cx, J.eyeR.cy, J.eyeR.r) } }
        }
        Shape {
            visible: jw.wink > 0.75
            preferredRendererType: Shape.CurveRenderer
            ShapePath { fillColor: "transparent"; strokeColor: J.ink; strokeWidth: J.line * 1.6; capStyle: ShapePath.RoundCap; PathSvg { path: J.winkLine } }
        }
        Shape {
            preferredRendererType: Shape.CurveRenderer
            ShapePath { fillColor: J.fur; strokeColor: J.ink; strokeWidth: J.line; joinStyle: ShapePath.RoundJoin; PathSvg { path: J.muzzle } }
            ShapePath { fillColor: "transparent"; strokeColor: J.ink; strokeWidth: J.line; capStyle: ShapePath.RoundCap; PathSvg { path: J.mouth } }
            ShapePath { fillColor: J.ink; strokeColor: "transparent"; PathSvg { path: J.nose } }
        }
    }
}
