import QtQuick

// Header pieces for the landscape screens: clock box and round close button.
Row {
    id: h
    property var svc
    property real clockH: 42
    property real timePx: 15
    property real closeSize: 40
    property bool showClose: false
    property bool clockOnly: false      // upright phone: ↻ and ⛶ already live in the side buttons / bottom bar     // every landscape screen has a Back button now; Esc / click outside still close
    signal close()
    spacing: 10
    // ↻ turn the phone upright (every screen works both ways)
    UiCandy {
        visible: !!h.svc && !h.clockOnly
        anchors.verticalCenter: parent.verticalCenter
        width: h.closeSize; height: h.closeSize; ink: Theme.inkPhone; drop: 3; hi: 0; fill: Theme.paper; pressable: true
        onClicked: h.svc.rotatePhone()
        Glyph { anchors.centerIn: parent; name: "rotate"; size: 17; stroke: 2.4 }
    }
    // big mode: phone grows to ~3/4 of the screen and lies flat
    UiCandy {
        visible: !!h.svc && h.svc.phoneBig !== undefined && !h.clockOnly
        anchors.verticalCenter: parent.verticalCenter
        width: h.closeSize; height: h.closeSize; ink: Theme.inkPhone; drop: 3; hi: 0
        fill: h.svc && h.svc.phoneBig ? Theme.gOn : Theme.paper; pressable: true
        onClicked: h.svc.phoneBig = !h.svc.phoneBig
        Glyph { anchors.centerIn: parent; name: "full"; size: 17; stroke: 2.6 }
    }
    UiCandy {
        anchors.verticalCenter: parent.verticalCenter
        width: hc.implicitWidth + 28; height: h.clockH
        radius: 14; ink: Theme.inkPhone; drop: 3; hi: 0
        Column { id: hc; anchors.centerIn: parent
            UiText { anchors.horizontalCenter: parent.horizontalCenter; text: h.svc.timeText; px: h.timePx; w: 700; height: h.timePx }
            UiText { anchors.horizontalCenter: parent.horizontalCenter; text: h.svc.phoneDate; fam: "n"; w: 800; px: h.timePx < 15 ? 9 : 9.5; color: Theme.textSoft } }
    }
    UiCandy {
        visible: h.showClose
        anchors.verticalCenter: parent.verticalCenter
        width: h.closeSize; height: h.closeSize; ink: Theme.inkPhone; drop: 3; hi: 0; pressable: true
        onClicked: h.close()
        Glyph { anchors.centerIn: parent; name: "close"; size: h.closeSize < 40 ? 15 : 16; stroke: 3 }
    }
}
