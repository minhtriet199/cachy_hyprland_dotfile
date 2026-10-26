import QtQuick
import QtQuick.Shapes
import "JakeShapes.js" as J

// "Jake" scene change (Settings → Shell → Lock & unlock transition → Type: Jake). Same driver as IrisWipe (mode + t),
// so shell.qml's lock / unlock sequences run it unchanged:
//   coverL  (lock screen, after the password)   the Jake picture fades in over the lock screen
//   revealR (desktop, right after unlocking)    Jake winks · the orange shrinks into his body in the middle · he falls,
//                                               arms up · slams the bottom of the screen (splat) · pops up and runs off
//                                               on four legs — left if you typed on the left screen, else right
//   coverR  (desktop, before locking)           runs in on four legs · stands · jumps up · grows into the picture
//   revealL (lock screen, after locking)        the picture fades out onto the lock screen
//   full                                        just the picture
// The face sits exactly where the lock-screen picture (~/Pictures/Wallpapers/jake-the-dog-2k.png, centre-cropped) has it.
Item {
    id: jw
    property real t: 0
    property string mode: "none"
    property bool runLeft: false
    visible: mode !== "none"
    readonly property bool out: mode === "revealR"
    readonly property bool come: mode === "coverR"
    function ph(a, b) { return Math.max(0, Math.min(1, (t - a) / (b - a))) }      // 0..1 inside [a, b] of t
    function io(x) { return x < 0.5 ? 4 * x * x * x : 1 - Math.pow(-2 * x + 2, 3) / 2 }
    function mix(a, b, x) { return a + (b - a) * x }

    // ── the story, as 0..1 amounts over t ──
    readonly property real wink: out ? Math.sin(Math.PI * ph(0.01, 0.1)) : 0
    // picture (0) → small Jake (1)
    readonly property real shrink: out ? io(ph(0.1, 0.28)) : come ? 1 - io(ph(0.72, 0.97)) : 0
    readonly property real limbs: out ? io(ph(0.22, 0.3)) : come ? 1 - io(ph(0.66, 0.74)) : 0
    readonly property real fall: out ? Math.pow(ph(0.3, 0.46), 2) : 0                  // gravity: slow, then fast
    readonly property real armsUp: out ? io(ph(0.28, 0.36)) * (1 - io(ph(0.46, 0.5))) : 0
    readonly property real splat: out ? io(ph(0.46, 0.5)) * (1 - io(ph(0.58, 0.64))) : 0
    readonly property real runPose: out ? io(ph(0.62, 0.7)) : come ? 1 - io(ph(0.4, 0.5)) : 0
    readonly property real run: out ? Math.pow(ph(0.68, 1), 1.4) : come ? 1 - (1 - Math.pow(1 - ph(0, 0.42), 1.4)) : 0   // 0 = middle, 1 = off screen
    readonly property real hopUp: come ? io(ph(0.5, 0.64)) : 0                          // coming: floor → middle
    readonly property real gait: t * (out ? 30 : 22) * Math.PI                          // leg cycle while running
    readonly property real fade: mode === "coverL" ? t : mode === "revealL" ? 1 - t : 1
    opacity: fade

    // ── sizes and places ──
    readonly property real kBig: Math.max(width / 2560, height / 1440) * 2560 / J.box.srcW     // as on the lock picture
    readonly property real kSmall: height * 0.34 / (J.feet - J.bean.y)                          // Jake ≈ a third of the screen tall
    readonly property real k: mix(kBig, kSmall, shrink)
    // where the picture has the face, as the place of the puppet's pivot
    readonly property real picX: width / 2 + (J.box.srcX - J.box.srcW / 2) * k + J.pivot.x * k
    readonly property real picY: height / 2 + (J.box.srcY - 404) * k + J.pivot.y * k
    readonly property real floorY: height - 14 - (J.feet - J.pivot.y) * kSmall      // pivot height when standing on the bottom
    readonly property real dir: runLeft ? -1 : 1
    readonly property real offX: (width / 2 + 260 * kSmall) * (come ? -1 : dir)         // off screen (coming in: from the left)
    readonly property real px: mix(picX, width / 2, shrink) + run * offX
    readonly property real py: mix(picY, height / 2, shrink)
                               + (out ? fall : come ? 1 - hopUp : 0) * (floorY - height / 2)                 // down to the floor / up from it
                               - runPose * Math.abs(Math.sin(jw.gait)) * 14 * kSmall                       // gallop bounce
    readonly property real rot: (out ? Math.sin(fall * Math.PI * 3) * 14 * armsUp : 0) + runPose * 78
    readonly property bool mirror: out ? runLeft : false

    // the orange: whole screen, shrinking into Jake's bean (then the puppet's own bean takes over)
    Rectangle {
        visible: jw.shrink < 1
        readonly property real bw: J.bean.w * jw.k
        readonly property real bh: J.bean.h * jw.k
        readonly property real bx: jw.px + (J.bean.x - J.pivot.x) * jw.k
        readonly property real by: jw.py + (J.bean.y - J.pivot.y) * jw.k
        x: bx * jw.shrink; y: by * jw.shrink
        width: jw.width + (bw - jw.width) * jw.shrink; height: jw.height + (bh - jw.height) * jw.shrink
        radius: Math.min(width, height) / 2 * jw.shrink
        color: J.bg
    }

    // the puppet, in box units, pivot placed at (px, py)
    Item {
        id: fig
        width: J.box.w; height: J.box.h
        x: jw.px - J.pivot.x; y: jw.py - J.pivot.y
        transform: [
            Scale { origin.x: J.pivot.x; origin.y: J.pivot.y; xScale: jw.k * (jw.mirror ? -1 : 1); yScale: jw.k },
            Rotation { origin.x: J.pivot.x; origin.y: J.pivot.y; angle: jw.rot * (jw.mirror ? -1 : 1) }
        ]
        // body: squashes flat on the slam (from the feet), stretches a bit while falling
        Item {
            transform: Scale { origin.x: J.pivot.x; origin.y: J.feet
                xScale: 1 + 0.45 * jw.splat - 0.06 * jw.fall; yScale: 1 - 0.55 * jw.splat + 0.1 * jw.fall }
            Item {
                opacity: jw.limbs; visible: opacity > 0
                Shape { preferredRendererType: Shape.CurveRenderer
                    ShapePath { fillColor: "transparent"; strokeColor: J.ink; strokeWidth: J.leg.w + 2 * J.line; capStyle: ShapePath.RoundCap; PathSvg { path: J.tail } }
                    ShapePath { fillColor: "transparent"; strokeColor: J.fur; strokeWidth: J.leg.w; capStyle: ShapePath.RoundCap; PathSvg { path: J.tail } } }
                // legs: standing straight · kicking while falling · splayed on the slam · galloping (back legs)
                Repeater {
                    model: 2
                    delegate: JakeLimb {
                        required property int index
                        readonly property real side: index ? -1 : 1
                        x: jw.mix(J.hips[index].x, 100, jw.runPose); y: jw.mix(J.hips[index].y, 196 + index * 14, jw.runPose)
                        len1: J.leg.len * 0.55; len2: J.leg.len * 0.45; w: J.leg.w; foot: true
                        a: jw.mix(jw.mix(jw.mix(0, side * (12 + Math.sin(jw.t * 60) * 10), jw.armsUp), side * 72, jw.splat),
                                  -90 + Math.sin(jw.gait + index * 0.7) * 38, jw.runPose)
                        b: jw.mix(0, -30 + Math.sin(jw.gait + index * 0.7) * 25, jw.runPose)
                    }
                }
            }
            Rectangle { x: J.bean.x; y: J.bean.y; width: J.bean.w; height: J.bean.h; radius: width / 2; z: 0
                visible: jw.shrink > 0.95; color: J.fur; border.width: J.line; border.color: J.ink }
            // arms: elbows bent inward · up while falling · out on the slam · front legs when galloping
            Repeater {
                model: 2
                delegate: JakeLimb {
                    required property int index
                    readonly property real side: index ? -1 : 1
                    opacity: jw.limbs; visible: opacity > 0
                    z: jw.runPose > 0.5 ? -1 : 1
                    x: jw.mix(J.arms[index].x, 104, jw.runPose); y: jw.mix(J.arms[index].y, 62 + index * 16, jw.runPose)
                    len1: J.arm.up; len2: J.arm.low; w: J.arm.w
                    a: jw.mix(jw.mix(jw.mix(side * 8, side * 168, jw.armsUp), side * 96, jw.splat),
                              -90 + Math.sin(jw.gait + Math.PI + index * 0.7) * 40, jw.runPose)
                    b: jw.mix(jw.mix(jw.mix(-side * 105, side * 10, jw.armsUp), 0, jw.splat), 25, jw.runPose)
                }
            }
            // face
            Shape {
                z: 2
                preferredRendererType: Shape.CurveRenderer
                ShapePath { fillColor: J.ink; strokeColor: "transparent"; PathSvg { path: J.circle(J.eyeL.cx + J.eyeL.sx, J.eyeL.cy + J.eyeL.sy, J.eyeL.r + 1.5) } }
                ShapePath { fillColor: "#FFFFFF"; strokeColor: J.ink; strokeWidth: J.line; PathSvg { path: J.circle(J.eyeL.cx, J.eyeL.cy, J.eyeL.r) } }
                ShapePath { fillColor: J.ink; strokeColor: "transparent"; PathSvg { path: J.circle(J.eyeR.cx + J.eyeR.sx, J.eyeR.cy + J.eyeR.sy, J.eyeR.r + 1.5) } }
            }
            // the winking eye: the white closes to a line, then opens again
            Shape {
                z: 2
                preferredRendererType: Shape.CurveRenderer
                transform: Scale { origin.x: J.eyeR.cx; origin.y: J.eyeR.cy + 4; yScale: Math.max(0.06, 1 - jw.wink) }
                ShapePath { fillColor: "#FFFFFF"; strokeColor: J.ink; strokeWidth: J.line; PathSvg { path: J.circle(J.eyeR.cx, J.eyeR.cy, J.eyeR.r) } }
            }
            Shape {
                z: 2
                visible: jw.wink > 0.75
                preferredRendererType: Shape.CurveRenderer
                ShapePath { fillColor: "transparent"; strokeColor: J.ink; strokeWidth: J.line * 1.6; capStyle: ShapePath.RoundCap; PathSvg { path: J.winkLine } }
            }
            Shape {
                z: 2
                preferredRendererType: Shape.CurveRenderer
                ShapePath { fillColor: J.fur; strokeColor: J.ink; strokeWidth: J.line; joinStyle: ShapePath.RoundJoin; PathSvg { path: J.muzzle } }
                ShapePath { fillColor: "transparent"; strokeColor: J.ink; strokeWidth: J.line; capStyle: ShapePath.RoundCap; PathSvg { path: J.mouth } }
                ShapePath { fillColor: J.ink; strokeColor: "transparent"; PathSvg { path: J.nose } }
            }
        }
    }
}
