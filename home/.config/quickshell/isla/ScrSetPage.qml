import QtQuick

// One settings page in the landscape phone: back to Settings, title, then the panel.
// kind: "wifi" · "bt" · "sound" · "power"
Item {
    id: pg
    property var svc
    property var prefs
    property string kind: "wifi"
    signal go(string screen)
    signal close()
    signal back()
    readonly property real cx: 56
    readonly property real cw: width - 56 - 26
    readonly property var info: ({
        wifi:  ["Wi-Fi", "Networks and passwords", "wifi", Theme.gOn],
        bt:    ["Bluetooth", "Earbuds, pads, devices", "bluetooth", Theme.gLilac],
        sound: ["Sound", "Output, input and app mixer", "volume", Theme.gLeaf],
        power: ["Power", "Battery, mode and brightness", "battery", Theme.gSun],
        displays: ["Displays", "Layout, brightness, HDR, resolution", "monitor", Theme.gSettings],
        keys: ["Keyboard", "Click a shortcut to change it", "keyboard", Theme.gPeach],
        time: ["Screen time", "How long you used each app", "chart", Theme.gOn],
        system: ["System", "Charge limit, firewall, about", "gear", Theme.gChip]
    })[kind] || ["", "", "gear", Theme.gOn]

    // header
    Item {
        x: pg.cx; y: 18; width: pg.cw; height: 44
        UiCandy {
            width: tcol.implicitWidth + 8 + 28 + 10 + 18 + 5; height: 44
            radius: 16; ink: Theme.inkPhone; hiColor: Qt.rgba(1, 1, 1, 0.6); fill: pg.info[3]; pressable: true
            onClicked: pg.back()
            Rectangle { x: 10.5; anchors.verticalCenter: parent.verticalCenter; width: 28; height: 28; radius: 10; color: Theme.inkPhone
                Rectangle { anchors.fill: parent; anchors.margins: 2; radius: 8; color: Theme.paper }
                Glyph { anchors.centerIn: parent; name: "back"; size: 15; stroke: 3 } }
            Column { id: tcol; x: 48.5; anchors.verticalCenter: parent.verticalCenter
                UiText { text: pg.info[0]; px: 18; w: 700; color: Theme.textDeep; height: 19 }
                UiText { text: pg.info[1]; fam: "n"; w: 800; px: 10.5; color: Theme.textMuted } }
        }
        SetHeaderBtn { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; svc: pg.svc; onClose: pg.close() }
    }

    // body (scrolls if it is taller than the screen)
    Flickable {
        id: fl
        x: pg.cx; y: 18 + 44 + 14; width: pg.cw; height: pg.height - y - 18
        clip: true; contentHeight: body.height; boundsBehavior: Flickable.StopAtBounds
        Loader {
            id: body
            focus: true
            width: fl.width
            height: item ? item.implicitHeight : 0
            sourceComponent: ({ wifi: cWifi, bt: cBt, sound: cSound, power: cPower, displays: cDisplays, keys: cKeys, time: cTime, system: cSystem })[pg.kind] || cWifi
        }
    }
    Component { id: cWifi; WifiPanel { svc: pg.svc; listH: fl.height - 100 } }
    Component { id: cBt; BtPanel { svc: pg.svc; listH: fl.height - 50 } }
    Component { id: cSound; SoundPanel { svc: pg.svc; wide: true } }
    Component { id: cPower; PowerPanel { svc: pg.svc } }
    Component { id: cDisplays; DisplaysPanel { svc: pg.svc } }
    Component { id: cKeys; KeysPanel { svc: pg.svc; listH: fl.height - 46; focus: true } }
    Component { id: cTime; TimePanel { svc: pg.svc } }
    Component { id: cSystem; SystemPanel { svc: pg.svc } }

    focus: true
    Keys.onEscapePressed: pg.close()
}
