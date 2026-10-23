import QtQuick
import QtQuick.Shapes

// Text with a thick round outline painted behind the fill (CSS text-stroke + paint-order).
Item {
    id: s
    property string text: ""
    property string family: Theme.display
    property int weight: 700
    property real px: 18
    property color fillColor: "#FFFFFF"
    property color strokeColor: Theme.inkPhone
    property real strokeW: 5
    implicitWidth: tm.advanceWidth + strokeW
    implicitHeight: tm.height + strokeW
    TextMetrics { id: tm; text: s.text; font.family: s.family; font.weight: s.weight; font.pixelSize: s.px }
    Shape {
        x: s.strokeW / 2; y: s.strokeW / 2
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: s.strokeColor; strokeWidth: s.strokeW; fillColor: s.strokeColor; joinStyle: ShapePath.RoundJoin
            PathText { text: s.text; font.family: s.family; font.weight: s.weight; font.pixelSize: s.px }
        }
        ShapePath {
            strokeColor: "transparent"; strokeWidth: 0; fillColor: s.fillColor
            PathText { text: s.text; font.family: s.family; font.weight: s.weight; font.pixelSize: s.px }
        }
    }
}
