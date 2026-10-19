import QtQuick
import QtQuick.Shapes

// Hourly temperature line (weather card): icons on top, each temperature just above its point, the hour below.
// points: [{ label: "15:00", temp: 28, glyph: "cloud" }, …] (SvcWeather's weather.line)
Item {
    id: wl
    property var points: []
    property color lineColor: Theme.sunDeep
    readonly property int n: points.length
    readonly property real headH: 34                      // icon row + room for the temperature over the highest point
    readonly property real span: height - headH - 22      // room for the line itself
    readonly property real lo: n ? Math.min(...points.map(p => p.temp)) : 0
    readonly property real hi: n ? Math.max(...points.map(p => p.temp)) : 1
    function px(i) { return n < 2 ? width / 2 : 14 + i * (width - 28) / (n - 1) }
    function py(t) { return headH + (hi === lo ? span / 2 : (1 - (t - lo) / (hi - lo)) * span) }

    Shape {
        anchors.fill: parent; preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: wl.lineColor; strokeWidth: 3; fillColor: "transparent"; joinStyle: ShapePath.RoundJoin; capStyle: ShapePath.RoundCap
            PathPolyline { path: wl.points.map((p, i) => Qt.point(wl.px(i), wl.py(p.temp))) }
        }
    }
    Repeater {
        model: wl.points
        delegate: Item {
            required property var modelData
            required property int index
            Glyph { x: wl.px(index) - 8; y: 0; name: modelData.glyph; size: 16; stroke: 2.2 }
            UiText { x: wl.px(index) - 16; y: wl.py(modelData.temp) - 19; width: 32; horizontalAlignment: Text.AlignHCenter; text: modelData.temp + "°"; fam: "n"; px: 11; w: 900 }
            Rectangle { x: wl.px(index) - 5; y: wl.py(modelData.temp) - 5; width: 10; height: 10; rotation: 45
                color: index === 0 ? wl.lineColor : Theme.paper; border.width: 2.5; border.color: Theme.ink }
            UiText { x: wl.px(index) - 20; y: wl.height - 16; width: 40; horizontalAlignment: Text.AlignHCenter; text: modelData.label
                fam: "n"; px: 9; w: 800; color: Theme.textMuted }
        }
    }
}
