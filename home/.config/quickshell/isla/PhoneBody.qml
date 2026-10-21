import QtQuick
import Quickshell.Widgets
import QtQuick.Shapes

// Pixel-style phone body (portrait 390×844 or landscape 920×440), screen paper, camera hole.
// Put the screen content inside: it fills `screen` (inside the 3px screen border).
Item {
    id: f
    property bool landscape: false
    readonly property bool isNavZone: true    // keyboard: Tab / arrows stay inside the phone screen
    property bool showKeys: true          // flat side keys (hidden in 3D, the side wall shows them)
    property color ink: Theme.inkPhone
    property color shadowColor: ink
    property var bodyColors: [Theme.phoneA, Theme.phoneB]
    readonly property bool bgPhoto: Prefs.phoneBg.startsWith("/")
    readonly property var bgPair: Theme.adapt(Prefs.phoneBgs[Prefs.phoneBg] || Prefs.phoneBgs.cream)
    property color paper: bgPair[0]
    property color dotColor: bgPair[1]
    Behavior on paper { ColorAnimation { duration: 300 } }
    property real screenInset: 12
    property real screenRadius: 42
    property color screenBorder: ink
    default property alias content: inner.data
    // empty screen space: swallow clicks (so they don't close the phone); double-click = big ↔ small phone
    MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onWheel: w => w.accepted = true
        onDoubleClicked: m => { if (m.button === Qt.LeftButton && !Prefs.phoneWindow) Services.phoneBig = !Services.phoneBig } }
    readonly property alias screen: inner
    readonly property real bw: landscape ? 920 : 390
    readonly property real bh: landscape ? 430 : 834
    width: bw; height: bh + 10

    // side keys (behind the body)
    Repeater {
        model: f.showKeys ? 2 : 0
        delegate: Rectangle {
            required property int index
            x: f.landscape ? (index ? 250 : 170) : 386
            y: f.landscape ? -9 : (index ? 262 : 176)
            width: f.landscape ? (index ? 118 : 58) : 9
            height: f.landscape ? 9 : (index ? 118 : 58)
            radius: 4; color: Theme.phoneKey; border.width: 2; border.color: f.ink
        }
    }
    Rectangle { y: 10; width: f.bw; height: f.bh; radius: 54; color: f.shadowColor }
    // body with a diagonal (135°) gradient
    Rectangle { width: f.bw; height: f.bh; radius: 54; color: f.ink }
    Shape {
        id: bodyShape
        x: 3; y: 3; width: f.bw - 6; height: f.bh - 6
        preferredRendererType: Shape.CurveRenderer
        readonly property real gl: (width + height) * 0.7071 / 2
        ShapePath {
            strokeColor: "transparent"; strokeWidth: 0
            fillGradient: LinearGradient {
                x1: (f.bw - 6) / 2 - 0.7071 * bodyShape.gl; y1: (f.bh - 6) / 2 - 0.7071 * bodyShape.gl
                x2: (f.bw - 6) / 2 + 0.7071 * bodyShape.gl; y2: (f.bh - 6) / 2 + 0.7071 * bodyShape.gl
                GradientStop { position: 0; color: f.bodyColors[0] }
                GradientStop { position: 1; color: f.bodyColors[1] }
            }
            PathRectangle { width: f.bw - 6; height: f.bh - 6; radius: 51 }
        }
    }
    // inset ring (4px white .16) + top gloss (6px white .25)
    Rectangle { x: 3; y: 3; width: f.bw - 6; height: f.bh - 6; radius: 51; color: "transparent"; border.width: 4; border.color: Qt.rgba(1, 1, 1, 0.16) }
    Item {
        x: 3; y: 3; width: f.bw - 6; height: 30; clip: true
        Shape {
            preferredRendererType: Shape.CurveRenderer
            ShapePath { strokeColor: "transparent"; strokeWidth: 0; fillColor: Qt.rgba(1, 1, 1, 0.25)
                PathSvg { path: "M0 51a51 51 0 0 1 51 -51h" + (f.bw - 108) + "a51 51 0 0 1 51 51v0a51 45 0 0 0 -51 -45h-" + (f.bw - 108) + "a51 45 0 0 0 -51 45z" } }
        }
    }
    // screen
    Rectangle {
        id: scr
        x: f.screenInset; y: f.screenInset
        width: f.bw - 2 * f.screenInset; height: f.bh - 2 * f.screenInset
        radius: f.screenRadius; color: f.screenBorder
        Rectangle { id: paperRect; x: 3; y: 3; width: parent.width - 6; height: parent.height - 6; radius: f.screenRadius - 3; color: f.paper }
        UiDots { visible: !f.bgPhoto; x: 3; y: 3; width: parent.width - 6; height: parent.height - 6; radius: f.screenRadius - 3; dot: f.dotColor; step: 24; r: 2.6 }
        // picture background: soft paper veil on top so the text stays readable
        ClippingRectangle {
            visible: f.bgPhoto
            x: 3; y: 3; width: parent.width - 6; height: parent.height - 6; radius: f.screenRadius - 3; color: "transparent"
            Image { anchors.fill: parent; fillMode: Image.PreserveAspectCrop; asynchronous: true; source: f.bgPhoto ? "file://" + Prefs.phoneBg : ""
                sourceSize: Qt.size(780, 1700) }
            Rectangle { anchors.fill: parent; color: Theme.cream; opacity: 0.62 }
        }
        Item { id: inner; x: 3; y: 3; width: parent.width - 6; height: parent.height - 6 }
        // camera punch hole
        Rectangle {
            z: 50
            width: 22; height: 22; radius: 11; color: f.ink
            x: f.landscape ? 12 - 3 + 3 : (parent.width - 22) / 2
            y: f.landscape ? (parent.height - 22) / 2 : 12
            Rectangle { anchors.fill: parent; radius: 11; color: f.landscape ? Qt.rgba(1, 1, 1, 0.18) : "#2E5560" }
            Rectangle { anchors.centerIn: parent; width: 14; height: 14; radius: 7; color: f.ink }
        }
    }
}
