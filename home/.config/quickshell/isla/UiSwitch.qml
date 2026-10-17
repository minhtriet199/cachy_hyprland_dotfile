import QtQuick

// Candy on/off switch.
UiCandy {
    id: sw
    property bool on: false
    property color onColor: Theme.leaf
    signal toggled()
    width: 52; height: 28; bw: 2.5; drop: 2; hi: 0
    fill: on ? onColor : Theme.sand; pressable: true
    onClicked: sw.toggled()
    Rectangle { y: 4; x: sw.on ? sw.width - width - 4 : 4; width: 20; height: 20; radius: 10
        color: Theme.paper; border.width: 2; border.color: sw.ink
        Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutBack } } }
}
