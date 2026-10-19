import QtQuick

// Desktop wallpaper (Isla draws it itself, like end-4 does). Cross-fades when you pick a new one.
Item {
    id: w
    property string path: ""
    clip: true
    // soft pastel island placeholder when no picture is set
    Rectangle {
        anchors.fill: parent; color: "#D3EAF0"
        visible: w.path === "" || (a.status !== Image.Ready && b.status !== Image.Ready)
        Rectangle { x: -parent.width * 0.083; y: -parent.height * 0.2; width: parent.height * 0.7; height: width; radius: width / 2; color: Theme.adapt("#E4DCFA") }
        Rectangle { x: parent.width - parent.height * 0.44; y: parent.height * 0.11; width: parent.height * 0.63; height: width; radius: width / 2; color: Theme.adapt("#FBE0D2") }
        Rectangle { x: parent.width * 0.27; y: parent.height * 0.72; width: parent.height * 0.9; height: parent.height * 0.67; radius: height / 2; color: "#D3EED6" }
    }
    property bool useA: true
    property bool started: false
    onPathChanged: {
        const src = path ? "file://" + path : "";
        if (!started) { a.source = src; started = true; return }
        if (useA) b.source = src; else a.source = src;
        useA = !useA;
        dropOld.restart();
    }
    // after the cross-fade, let go of the picture that is now hidden (≈ 15 MB per screen)
    Timer { id: dropOld; interval: 900; onTriggered: { if (w.useA) b.source = ""; else a.source = "" } }
    Image { id: a; anchors.fill: parent; fillMode: Image.PreserveAspectCrop; asynchronous: true; cache: false; smooth: true
        sourceSize: Qt.size(w.width, w.height); opacity: w.useA ? 1 : 0; Behavior on opacity { NumberAnimation { duration: 600 } } }
    Image { id: b; anchors.fill: parent; fillMode: Image.PreserveAspectCrop; asynchronous: true; cache: false; smooth: true
        sourceSize: Qt.size(w.width, w.height); opacity: w.useA ? 0 : 1; Behavior on opacity { NumberAnimation { duration: 600 } } }
    Component.onCompleted: { if (path && !started) { a.source = "file://" + path; started = true } }
}
