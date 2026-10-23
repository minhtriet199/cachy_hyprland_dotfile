import QtQuick
import QtQuick.Shapes

// One pass of one sticker-clock digit. pass: "drop" | "ink" | "cream" | "fill"
Item {
    id: d
    property string ch: "0"
    property string pass: "fill"
    property real tilt: 0
    property real lift: 0
    property var colors: ["#FFFFFF", "#CCCCCC"]
    // Titan One glyph boxes (font units): [advance, xMin, yMin, xMax, yMax]
    readonly property var m: ({ "0": [726, 30, -9, 696, 721], "1": [453, 15, 0, 413, 712], "2": [614, 30, 0, 584, 721], "3": [609, 30, -9, 579, 721],
        "4": [618, 15, 0, 578, 712], "5": [611, 30, -9, 581, 712], "6": [662, 30, -9, 632, 722], "7": [539, 10, 0, 529, 712],
        "8": [659, 30, -9, 629, 721], "9": [662, 30, -9, 632, 722] })
    readonly property real px: 150
    readonly property real k: px / 1000
    readonly property var g: m[ch] || m["0"]
    readonly property real baseY: (150 - (970 + 175) * k) / 2 + 970 * k   // CSS line-height 1
    readonly property real gy: baseY - g[4] * k                          // glyph top inside the 150px box
    readonly property color ink: Theme.inkClock
    width: g[0] * k
    height: 150
    y: lift
    rotation: tilt

    // drop / ink / cream: one thick stroked silhouette
    Shape {
        visible: d.pass !== "fill"
        y: d.gy + (d.pass === "drop" ? 12 : 0)
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: d.pass === "cream" ? Theme.cream : d.ink
            fillColor: d.pass === "cream" ? Theme.cream : d.ink
            strokeWidth: d.pass === "cream" ? 28 : 40
            joinStyle: ShapePath.RoundJoin
            PathText { text: d.ch; font.family: Theme.candy; font.pixelSize: d.px }
        }
    }
    // fill: thin ink outline + candy gradient + glossy top
    Shape {
        visible: d.pass === "fill"
        y: d.gy
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: d.ink; fillColor: d.ink; strokeWidth: 12; joinStyle: ShapePath.RoundJoin
            PathText { text: d.ch; font.family: Theme.candy; font.pixelSize: d.px }
        }
        ShapePath {
            strokeColor: "transparent"; strokeWidth: 0
            fillGradient: LinearGradient {
                x1: 0; y1: -d.gy + 0.18 * 150; x2: 0; y2: -d.gy + 0.92 * 150
                GradientStop { position: 0; color: d.colors[0] }
                GradientStop { position: 1; color: d.colors[1] }
            }
            PathText { text: d.ch; font.family: Theme.candy; font.pixelSize: d.px }
        }
    }
    Item {
        visible: d.pass === "fill"
        width: d.width; height: 150
        opacity: 0.7
        transform: [ Scale { origin.x: d.width / 2; origin.y: 30; xScale: 0.94; yScale: 0.94 }, Translate { x: -3; y: -3 } ]
        Item {
            width: d.width; height: 45; clip: true
            Shape {
                y: d.gy
                preferredRendererType: Shape.CurveRenderer
                ShapePath { strokeColor: "transparent"; strokeWidth: 0; fillColor: "#FFFFFF"
                    PathText { text: d.ch; font.family: Theme.candy; font.pixelSize: d.px } }
            }
        }
    }
}
