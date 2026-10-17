import QtQuick

// Quick panel (canvas "Phone-Quick").
Item {
    id: q
    property var svc
    signal go(string screen)
    readonly property real cw: width - 32
    Column {
        x: 16; y: 18; width: q.cw
        spacing: 11
        PhoneStatus { svc: q.svc; right2: "↓ " + q.svc.netDown + "  ↑ " + q.svc.netUp }
        // profile + round actions
        Item {
            width: parent.width; height: 62 + 4 + 15 + 4
            Column {
                y: 4; width: 78; spacing: 4
                UiCandy {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 62; height: 62; bw: 3; ink: Theme.inkPhone; hi: 5; hiColor: Qt.rgba(1, 1, 1, 0.5); fill: Theme.sun; pressable: true
                    onClicked: q.go("profile")
                    Glyph { anchors.centerIn: parent; name: Prefs.avatar || "smile"; size: 34; stroke: 2.2; color: Theme.inkPhone }
                }
                UiText { anchors.horizontalCenter: parent.horizontalCenter; text: q.svc.userHost; px: 12; w: 600 }
            }
            Row {
                x: 78 + 10; width: parent.width - 88
                y: parent.height - 20 - 46 - 4
                spacing: (width - 4 * 46) / 3
                PhoneRoundBtn { glyph: "gear"; onClicked: q.go("settings") }
                PhoneRoundBtn { glyph: "reload"; onClicked: q.svc.reloadShell() }
                PhoneRoundBtn { glyph: q.svc.dnd ? "bellOff" : "bell"; fill: q.svc.dnd ? Theme.gTab : Theme.gChip; hiColor: Qt.rgba(1, 1, 1, 0.5)
                    glyphColor: q.svc.dnd ? "#FFFFFF" : Theme.textDeep; glyphStroke: 2.6; onClicked: q.svc.toggle("dnd") }   // Do not disturb
                PhoneRoundBtn { glyph: "ring"; onClicked: q.svc.tool("record")
                    Rectangle { anchors.centerIn: parent; width: 8; height: 8; radius: 4; color: q.svc.recording ? "#E2607F" : Theme.berry } }
            }
        }
        // toggles: 2 wide per row
        Grid {
            columns: 2; rowSpacing: 10; columnSpacing: 10
            readonly property real wideW: (q.cw - 10) / 2
            PhoneToggleTile { width: parent.wideW; glyph: "wifi"; title: "Wi-Fi"; on: q.svc.wifi.on; sub: q.svc.wifi.on ? (q.svc.wifi.ssid || "On") : "Off"; onClicked: q.svc.toggle("wifi"); onRightClicked: q.go("settingsWifi") }
            PhoneToggleTile { width: parent.wideW; glyph: "bluetooth"; title: "Bluetooth"; on: q.svc.bluetooth.on; sub: q.svc.bluetooth.on ? (q.svc.bluetooth.name || "On") : "Off"; onClicked: q.svc.toggle("bt"); onRightClicked: q.go("settingsBt") }
            PhoneToggleTile { width: parent.wideW; glyph: "mic"; title: "Microphone"; on: q.svc.micOn; sub: Math.round(q.svc.micVolume * 100) + "%"; level: q.svc.micVolume; levelColor: Theme.berry
                onClicked: q.svc.toggle("mic"); onRightClicked: q.go("settingsSound"); onLevelPicked: v => q.svc.setMicVolume(v) }
            PhoneToggleTile { width: parent.wideW; glyph: q.svc.muted ? "mute" : "volume"; title: "Speaker"; on: !q.svc.muted; sub: Math.round(q.svc.volume * 100) + "%"; level: q.svc.volume; levelColor: Theme.leaf
                onClicked: q.svc.toggle("mute"); onRightClicked: q.go("settingsSound"); onLevelPicked: v => q.svc.setVolume(v) }
            PhoneToggleTile { width: parent.wideW; glyph: "cloud"; title: "Cloudflare WARP"; on: q.svc.warp.connected; sub: q.svc.warp.connected ? "Connected" : "Disconnected"; onClicked: q.svc.toggle("warp") }
            PhoneToggleTile { width: parent.wideW; glyph: "fx"; title: "Easy Effects"; on: q.svc.easyEffects; onClicked: q.svc.toggle("fx") }

        }
        // gamma / brightness
        Column {
            width: parent.width; spacing: 6
            topPadding: 2
            Item { width: parent.width; height: 16
                UiText { x: 4; text: "◐ Gamma " + Math.round(q.svc.gamma * 100) + "%"; px: 13; w: 600 }
                UiText { anchors.right: parent.right; anchors.rightMargin: 4; text: "☼ Brightness " + Math.round(q.svc.brightness * 100) + "%"; px: 13; w: 600 } }
            Row {
                spacing: 10
                PhoneLevel { width: (q.cw - 10) / 2; height: 12; value: q.svc.gamma; color: "#A08AEA"; onPicked: v => q.svc.setGamma(v) }
                PhoneLevel { width: (q.cw - 10) / 2; height: 12; value: q.svc.brightness; color: Theme.sunDeep; onPicked: v => q.svc.setBrightness(v) }
            }
        }
        // notifications
        Item {
            width: parent.width
            height: q.height - y - 18 - 14 - 12 - (q.svc.phoneBig ? 50 : 0)   // big mode: stop above the nav bar
            Behavior on height { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
            UiCandy {
                y: 12; width: parent.width; height: parent.height
                radius: 26; ink: Theme.inkPhone; drop: 0; hi: 0; fill: Qt.rgba(1, 253 / 255, 246 / 255, 0.85)
                Flickable {
                    id: nf
                    x: 12; y: 2.5 + 22 + 8 - 13; width: parent.width - 24; height: parent.height - y - 14
                    contentHeight: nCol.height; clip: true; boundsBehavior: Flickable.StopAtBounds
                    // empty space in the box: small phone → big phone (notifications themselves keep their own clicks)
                    MouseArea {
                        z: -1; width: nf.width; height: Math.max(nf.height, nCol.height)
                        enabled: !q.svc.phoneBig
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: q.svc.phoneBig = true
                    }
                    Column {
                        id: nCol; width: nf.width; spacing: 2; topPadding: 6   // tilted tag of the first bubble needs a few px
                        Repeater {
                            model: q.svc.notifications
                            delegate: Toast {
                                required property var modelData
                                width: nCol.width - 4; x: 2; compact: true
                                app: modelData.app; body: modelData.body; tint: modelData.tint
                                onClicked: q.svc.activateNotification(modelData)
                                onDismissed: q.svc.dismissNotification(modelData)
                            }
                        }
                        UiText { visible: q.svc.notifications.length === 0; width: nCol.width; topPadding: 30; horizontalAlignment: Text.AlignHCenter
                            text: "All quiet on the island ✿"; fam: "n"; w: 800; px: 13; color: Theme.textSoft }
                    }
                }
            }
            UiCandy {
                anchors.horizontalCenter: parent.horizontalCenter; y: 12 - 15
                width: nt.implicitWidth + 32 + 5; height: 30
                ink: Theme.inkPhone; drop: 3; hi: 0; pressable: q.svc.notifications.length > 0
                onClicked: q.svc.clearNotifications()
                UiText { id: nt; anchors.centerIn: parent; text: "Notifications"; px: 14; w: 700 }
            }
        }
    }
}
