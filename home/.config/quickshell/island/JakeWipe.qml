import QtQuick
import QtQuick.Shapes
import "JakeShapes.js" as J
import "assets/jake/frames.js" as F

// "Jake" scene change (Settings → Shell → Lock & unlock transition → Type: Jake), played like a cartoon: 12 drawings
// a second, each a hand-drawn frame from assets/jake (tools/jake-frames.py). Same driver as IrisWipe (mode + t), so
// shell.qml's lock / unlock sequences run it unchanged — t just picks the drawing:
//   coverL  (lock screen, after the password)   the Jake picture fades in over the lock screen
//   revealR (desktop, right after unlocking)    Jake winks · the orange shrinks into him · he falls, arms up · splats on
//                                               the bottom of the screen · gets up · runs off on four legs — left if you
//                                               typed on the left screen, else right
//   coverR  (desktop, before locking)           runs in on four legs · stands · hops up · grows into the picture
//   revealL (lock screen, after locking)        the picture fades out onto the lock screen
//   full                                        just the picture
// The big face is the vector one from JakeShapes.js, exactly where the lock picture (jake-the-dog-2k.png) has it.
Item {
    id: jw
    property real t: 0
    property string mode: "none"
    property bool runLeft: false
    visible: mode !== "none"

    // ── sizes ──
    readonly property real kBig: Math.max(width / 2560, height / 1440) * 2560 / J.box.srcW      // picture: px per face unit
    readonly property var standBox: F.M.seq.stand_frames[0]
    readonly property real ds: height * 0.36 / standBox[3]                                       // drawings: screen px per drawing px
    readonly property real u: F.M.scale * ds                                                      // drawings: screen px per Jake unit
    readonly property real cx: width / 2
    readonly property real cy: height / 2
    readonly property real floorY: height - 18
    // where the picture's face pivot is (big) and where the standing drawing has it (small)
    readonly property real bigFx: cx + (J.box.srcX - J.box.srcW / 2 + J.pivot.x) * kBig
    readonly property real bigFy: cy + (J.box.srcY - 404 + J.pivot.y) * kBig
    readonly property real smallFx: cx + F.M.face.x * u
    readonly property real smallFy: cy + F.M.face.y * u
    readonly property real smallK: F.M.face.sc * u

    // ── timelines: one entry per drawing (12 a second) ──
    // pic: picture → Jake amount (0 = full picture, 1 = orange is his bean), wink 0..1; or a drawing: seq / i at (x, y)
    // (y: anchor height, or floor: true = the drawing's lowest point stands on the bottom of the screen); dir = facing
    function ease(x) { return x < 0.5 ? 4 * x * x * x : 1 - Math.pow(-2 * x + 2, 3) / 2 }
    function outLine() {                                        // 45 drawings ≈ 3.8 s (shell revealMs)
        const L = [], d = runLeft ? -1 : 1, off = width / 2 + 420 * ds;
        for (const w of [0.5, 1, 1, 0.5]) L.push({ pic: 0, wink: w });
        for (let k = 1; k <= 6; k++) L.push({ pic: ease(k / 6), wink: 0 });
        for (let k = 0; k < 2; k++) L.push({ seq: "stand", i: 0, x: cx, y: cy, dir: d });
        for (let k = 0; k < 7; k++) L.push({ seq: "fall", i: k, x: cx, y: cy + (floorY - 300 * u - cy) * Math.pow((k + 1) / 7, 2), dir: d });
        for (let k = 0; k < 6; k++) L.push({ seq: "splat", i: k, x: cx, floor: true, dir: d });
        for (let k = 0; k < 4; k++) L.push({ seq: "getup", i: k, x: cx, floor: true, dir: d });
        for (let k = 0; k < 16; k++) L.push({ seq: "run", i: k % 6, x: cx + d * off * Math.pow((k + 1) / 16, 1.3), floor: true, dir: d });
        return L;
    }
    function inLine() {                                         // 21 drawings ≈ 1.8 s (shell coverMs)
        const L = [], off = width / 2 + 420 * ds;
        for (let k = 0; k < 12; k++) L.push({ seq: "run", i: k % 6, x: cx - off * Math.pow(1 - k / 11, 1.2), floor: true, dir: 1 });
        L.push({ seq: "getup", i: 3, x: cx, floor: true, dir: 1 });
        L.push({ seq: "stand", i: 0, x: cx, floor: true, dir: 1 });
        L.push({ seq: "fall", i: 0, x: cx, y: (cy + floorY - 200 * u) / 2, dir: 1 });
        L.push({ seq: "stand", i: 0, x: cx, y: cy, dir: 1 });
        for (let k = 5; k >= 1; k--) L.push({ pic: ease((k - 1) / 5), wink: 0 });
        return L;
    }
    readonly property var line: mode === "revealR" ? outLine() : mode === "coverR" ? inLine() : [{ pic: 0, wink: 0 }]
    readonly property var step: line[Math.max(0, Math.min(line.length - 1, Math.floor(t * line.length)))]
    readonly property bool drawing: step.seq !== undefined
    // fades on the lock screen, also in steps of 1/12 s
    opacity: mode === "coverL" ? Math.round(t * 7) / 7 : mode === "revealL" ? 1 - Math.round(t * 7) / 7 : 1

    // ── the picture (and the orange shrinking into Jake's bean) ──
    readonly property real p: drawing ? 1 : step.pic
    Rectangle {
        visible: !jw.drawing
        readonly property real bx: jw.cx + F.M.bean.x0 * jw.u
        readonly property real by: jw.cy + F.M.bean.y0 * jw.u
        readonly property real bw: (F.M.bean.x1 - F.M.bean.x0) * jw.u
        readonly property real bh: (F.M.bean.y1 - F.M.bean.y0) * jw.u
        x: bx * jw.p; y: by * jw.p
        width: jw.width + (bw - jw.width) * jw.p; height: jw.height + (bh - jw.height) * jw.p
        radius: Math.min(width, height) / 2 * jw.p
        color: J.bg
    }
    Item {
        visible: !jw.drawing
        x: jw.bigFx + (jw.smallFx - jw.bigFx) * jw.p - J.pivot.x; y: jw.bigFy + (jw.smallFy - jw.bigFy) * jw.p - J.pivot.y
        transform: Scale { origin.x: J.pivot.x; origin.y: J.pivot.y; xScale: jw.kBig + (jw.smallK - jw.kBig) * jw.p; yScale: xScale }
        Shape {
            preferredRendererType: Shape.CurveRenderer
            ShapePath { fillColor: J.ink; strokeColor: "transparent"; PathSvg { path: J.circle(J.eyeL.cx + J.eyeL.sx, J.eyeL.cy + J.eyeL.sy, J.eyeL.r + 1.5) } }
            ShapePath { fillColor: "#FFFFFF"; strokeColor: J.ink; strokeWidth: J.line; PathSvg { path: J.circle(J.eyeL.cx, J.eyeL.cy, J.eyeL.r) } }
        }
        // winking eye: the white closes to a line (half-shut on the in-between drawing)
        Shape {
            visible: jw.step.wink < 1
            preferredRendererType: Shape.CurveRenderer
            transform: Scale { origin.x: J.eyeR.cx; origin.y: J.eyeR.cy + 4; yScale: 1 - 0.6 * (jw.step.wink || 0) }
            ShapePath { fillColor: J.ink; strokeColor: "transparent"; PathSvg { path: J.circle(J.eyeR.cx + J.eyeR.sx, J.eyeR.cy + J.eyeR.sy, J.eyeR.r + 1.5) } }
            ShapePath { fillColor: "#FFFFFF"; strokeColor: J.ink; strokeWidth: J.line; PathSvg { path: J.circle(J.eyeR.cx, J.eyeR.cy, J.eyeR.r) } }
        }
        Shape {
            visible: jw.step.wink >= 1
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

    // ── the drawings: all loaded once (small, cropped), only the current one shown ──
    Repeater {
        model: Object.keys(F.M.seq).filter(k => !k.endsWith("_frames")).reduce((a, s) => a.concat(F.M.seq[s + "_frames"].map((b, i) => ({ seq: s, i: i, b: b }))), [])
        delegate: Image {
            required property var modelData
            readonly property var b: modelData.b
            readonly property bool cur: jw.drawing && jw.step.seq === modelData.seq && jw.step.i === modelData.i
            visible: cur
            source: "assets/jake/" + modelData.seq + "_" + String(modelData.i).padStart(2, "0") + ".png"
            sourceSize: Qt.size(Math.ceil(b[2] * jw.ds), Math.ceil(b[3] * jw.ds))
            width: b[2] * jw.ds; height: b[3] * jw.ds
            smooth: true; mipmap: true
            mirror: cur && jw.step.dir < 0
            // anchor (canvas ax, ay) goes to the step's point; floor steps: lowest pixel on the bottom of the screen
            readonly property real ay: cur ? (jw.step.floor ? jw.floorY - (b[1] + b[3] - F.M.ay) * jw.ds : jw.step.y) : 0
            x: cur ? (mirror ? jw.step.x - (b[0] + b[2] - F.M.ax) * jw.ds : jw.step.x + (b[0] - F.M.ax) * jw.ds) : 0
            y: ay + (b[1] - F.M.ay) * jw.ds
        }
    }
}
