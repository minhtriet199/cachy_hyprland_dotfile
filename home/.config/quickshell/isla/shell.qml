import QtQuick
import Quickshell
ShellRoot {
    FloatingWindow {
        title: "isla-test"; implicitWidth: 940; implicitHeight: 460; color: "#D3EAF0"
        Rectangle { x: 10; y: 10; width: 920; height: 440; radius: 40; color: Theme.paper
            ScrWallpapers { anchors.fill: parent; svc: Services; prefs: Prefs } }
    }
}
