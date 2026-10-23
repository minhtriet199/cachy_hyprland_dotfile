import QtQuick

// Under a dock app: dot = open, long green bar = the app you are using.
Item {
    property bool running: false
    property bool active: false
    width: 22; height: 5
    Rectangle { anchors.centerIn: parent; visible: parent.running || parent.active
        width: parent.active ? 20 : 6; height: parent.active ? 5 : 6; radius: 3
        color: parent.active ? Theme.leafDeep : Theme.ink
        Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutBack } } }
}
