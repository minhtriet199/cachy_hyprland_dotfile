import QtQuick
import Quickshell
import Quickshell.Wayland

// "Where's my mouse?" (double-tap Ctrl → hypr/config/locate.lua → `ipc call isla locate X Y`): candy rings shrink onto
// the pointer, then it closes. Click-through, no keyboard; loaded only while showing (shell.qml LazyLoader).
PanelWindow {
    id: lp
    property point at                             // pointer, in this screen's logical px
    signal done()
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    mask: Region {}
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "isla-locate"

    property real t: 0                            // 0 → 1 over the whole show
    NumberAnimation on t { from: 0; to: 1; duration: 950; running: true; onFinished: lp.done() }

    // three rings, each starting a little later, shrinking from big to just round the pointer
    Repeater {
        model: [[0, Theme.berry], [0.14, Theme.sun], [0.28, Theme.sea]]
        delegate: Rectangle {
            required property var modelData
            readonly property real k: Math.max(0, Math.min(1, (lp.t - modelData[0]) / 0.62))   // this ring's own 0 → 1
            readonly property real e: 1 - Math.pow(1 - k, 3)                                     // ease out
            width: 300 - e * 262; height: width; radius: width / 2
            x: lp.at.x - width / 2; y: lp.at.y - height / 2
            color: "transparent"; border.width: 7 - e * 3; border.color: modelData[1]
            opacity: k <= 0 ? 0 : lp.t > 0.8 ? (1 - lp.t) / 0.2 : 1
            Rectangle { anchors.fill: parent; anchors.margins: -2.5; radius: width / 2; color: "transparent"; border.width: 2.5; border.color: Theme.inkPhone }
        }
    }
    // soft dot that stays under the pointer while the rings land
    Rectangle {
        width: 30; height: 30; radius: 15; x: lp.at.x - 15; y: lp.at.y - 15
        color: Theme.paper; border.width: 3; border.color: Theme.inkPhone
        opacity: lp.t < 0.35 ? 0 : lp.t > 0.8 ? (1 - lp.t) / 0.2 * 0.55 : 0.55
    }
}
