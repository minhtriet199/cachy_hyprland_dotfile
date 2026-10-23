import QtQuick
import QtQuick.Shapes

// The big candy clock: die-cut sticker digits, leaf colon, PM badge and a date ribbon.
// Size in design px: about 447 × 210 (plus badge/stars that stick out).
Item {
    id: clock
    property var svc
    readonly property string digits: svc.clockH + svc.clockM
    readonly property var tilts: [-7, 5, -4, 6]
    readonly property var lifts: [0, -10, 6, -6]
    readonly property var palettes: [["#F3EEFF", "#9C86E6"], ["#FFE8F0", "#EE7D9C"], ["#ECFAE6", "#6BB86F"], ["#E6FBFD", "#36AEB9"]]
    readonly property var passes: ["drop", "ink", "cream", "fill"]
    readonly property var adv: ({ "0": 726, "1": 453, "2": 614, "3": 609, "4": 618, "5": 611, "6": 662, "7": 539, "8": 659, "9": 662 })
    width: (adv[digits.charAt(0)] + adv[digits.charAt(1)] + adv[digits.charAt(2)] + adv[digits.charAt(3)]) * 0.15 + 66
    height: 150 + 14 + 46

    // four passes stacked: every digit's shadow is under every digit's face (one merged sticker)
    Repeater {
        model: clock.passes
        delegate: Row {
            id: passRow
            required property string modelData
            required property int index
            Repeater {
                model: 2
                delegate: ClockDigit { required property int index; ch: clock.digits.charAt(index); pass: passRow.modelData
                    tilt: clock.tilts[index]; lift: clock.lifts[index]; colors: clock.palettes[index] }
            }
            // colon
            Item {
                width: 54 + 12; height: 150
                Repeater {
                    model: 2
                    delegate: Rectangle {
                        required property int index
                        visible: passRow.modelData !== "fill"
                        readonly property real sz: passRow.modelData === "cream" ? 50 : 60
                        width: sz; height: sz; radius: sz / 2
                        x: 6 + (54 - sz) / 2
                        y: (150 - (sz * 2 + 8)) / 2 + index * (sz + 8) + (passRow.modelData === "drop" ? 12 : 0)
                        color: passRow.modelData === "cream" ? Theme.cream : Theme.inkClock
                    }
                }
                ClockLeaf { visible: passRow.modelData === "fill"; x: 6 + 5; y: 27; rotation: -18; leafColor: "#8FD48F" }
                ClockLeaf { visible: passRow.modelData === "fill"; x: 6 + 5; y: 79; rotation: 14; leafColor: Theme.sun }
            }
            Repeater {
                model: 2
                delegate: ClockDigit { required property int index; ch: clock.digits.charAt(index + 2); pass: passRow.modelData
                    tilt: clock.tilts[index + 2]; lift: clock.lifts[index + 2]; colors: clock.palettes[index + 2] }
            }
        }
    }

    // sparkles
    ClockStar { x: -34; y: -6; size: 30; rotation: 10; starColor: Theme.sun }
    ClockStar { x: -8; y: 138; size: 18; rotation: -12; starColor: Theme.pinkSoft }
    ClockStar { x: 372; y: -30; size: 24; rotation: 18; starColor: Theme.seaSoft }

    // AM/PM badge
    Item {
        visible: !clock.svc.h24
        x: clock.width + 18 - 58; y: -26
        width: 58; height: 58
        rotation: 14
        Rectangle { y: 4; width: 58; height: 58; radius: 29; color: Theme.inkClock }
        Rectangle { width: 58; height: 58; radius: 29; color: Theme.inkClock }
        Shape {
            x: 3; y: 3; width: 52; height: 52
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: "transparent"; strokeWidth: 0
                fillGradient: RadialGradient {
                    centerX: 52 * 0.35; centerY: 52 * 0.30; centerRadius: 52 * 0.8; focalX: centerX; focalY: centerY
                    GradientStop { position: 0; color: "#FFE3EC" } GradientStop { position: 1; color: "#EE7D9C" }
                }
                PathAngleArc { centerX: 26; centerY: 26; radiusX: 26; radiusY: 26; startAngle: 0; sweepAngle: 360 }
            }
        }
        Item { x: 3; y: 3; width: 52; height: 52; clip: true
            Rectangle { width: 52; height: 52; radius: 26; color: "transparent"; border.width: 0 }
            Shape { preferredRendererType: Shape.CurveRenderer
                ShapePath { strokeColor: "transparent"; strokeWidth: 0; fillColor: Qt.rgba(1, 1, 1, 0.6)
                    PathSvg { path: "M0 26a26 26 0 0 1 52 0a26 23 0 0 0 -52 0z" } } } }
        UiStrokeText { anchors.centerIn: parent; text: clock.svc.ampm; family: Theme.candy; weight: 400; px: 18; strokeW: 4; strokeColor: Theme.inkClock }
    }

    // date ribbon
    Item {
        x: (clock.width - 300) / 2; y: 150 + 14
        width: 300; height: 46
        rotation: -2
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath { fillColor: "#E8B83A"; strokeColor: Theme.inkClock; strokeWidth: 3; joinStyle: ShapePath.RoundJoin
                PathSvg { path: "M30 10 L4 10 L16 25 L4 40 L44 40 Z" } }
            ShapePath { fillColor: "#E8B83A"; strokeColor: Theme.inkClock; strokeWidth: 3; joinStyle: ShapePath.RoundJoin
                PathSvg { path: "M270 10 L296 10 L284 25 L296 40 L256 40 Z" } }
            ShapePath { fillColor: Theme.sun; strokeColor: Theme.inkClock; strokeWidth: 3
                PathRectangle { x: 26; y: 4; width: 248; height: 34; radius: 8 } }
            ShapePath { fillColor: "transparent"; strokeColor: "#FFF3C4"; strokeWidth: 3; capStyle: ShapePath.RoundCap
                PathSvg { path: "M34 11 H266" } }
        }
        UiText { x: 26; y: 4; width: 248; height: 34; horizontalAlignment: Text.AlignHCenter
            text: clock.svc.ribbonDate; fam: "t"; w: 400; px: 17; track: 1; color: Theme.inkClock }
    }
}
