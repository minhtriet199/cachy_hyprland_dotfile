import QtQuick

// Quick panel for the sideways phone: header (back · ↻ ⛶ clock), left = profile + round buttons + toggles + levels,
// right = notifications. Same controls as the upright Quick, laid out for a wide screen.
Item {
    id: q
    property var svc
    signal go(string screen)
    signal back()
    signal close()
    readonly property real cx: 56
    readonly property real cw: width - cx - 26
    readonly property real leftW: cw * 0.56
    readonly property real rightX: cx + leftW + 18
    readonly property real rightW: cw - leftW - 18

    // header
    Item {
        x: q.cx; y: 18; width: q.cw; height: 44
        UiCandy {
            width: tcol.implicitWidth + 48 + 18; height: 44
            radius: 16; ink: Theme.inkPhone; hiColor: Qt.rgba(1, 1, 1, 0.6); fill: Theme.gOn; pressable: true
            onClicked: q.back()
            Rectangle { x: 10.5; anchors.verticalCenter: parent.verticalCenter; width: 28; height: 28; radius: 10; color: Theme.inkPhone
                Rectangle { anchors.fill: parent; anchors.margins: 2; radius: 8; color: Theme.paper }
                Glyph { anchors.centerIn: parent; name: "back"; size: 15; stroke: 3 } }
            Column { id: tcol; x: 48.5; anchors.verticalCenter: parent.verticalCenter
                UiText { text: "Quick"; px: 18; w: 700; color: Theme.textDeep; height: 19 }
                UiText { text: q.svc.userHost + " · ↓ " + q.svc.netDown + "  ↑ " + q.svc.netUp; fam: "n"; w: 800; px: 10.5; color: Theme.textMuted } }
        }
        SetHeaderBtn { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; svc: q.svc; onClose: q.close() }
    }

    // left column
    Column {
        x: q.cx; y: 18 + 44 + 14; width: q.leftW; spacing: 10
        // round buttons
        Row {
            spacing: 10
            UiCandy {
                width: 46; height: 46; bw: 3; ink: Theme.inkPhone; hi: 5; hiColor: Qt.rgba(1, 1, 1, 0.5); fill: Theme.sun; pressable: true
                onClicked: q.go("profile")
                Glyph { anchors.centerIn: parent; name: Prefs.avatar || "smile"; size: 26; stroke: 2.2; color: Theme.inkPhone }
            }
            PhoneRoundBtn { glyph: "gear"; onClicked: q.go("settings") }
            PhoneRoundBtn { glyph: "reload"; onClicked: q.svc.reloadShell() }
            PhoneRoundBtn { glyph: q.svc.dnd ? "bellOff" : "bell"; fill: q.svc.dnd ? Theme.gTab : Theme.gChip; hiColor: Qt.rgba(1, 1, 1, 0.5)
                glyphColor: q.svc.dnd ? "#FFFFFF" : Theme.textDeep; glyphStroke: 2.6; onClicked: q.svc.toggle("dnd") }
            PhoneRoundBtn { glyph: "ring"; onClicked: q.svc.tool("record"); onRightClicked: q.svc.tool("recordPick")
                Rectangle { anchors.centerIn: parent; width: 8; height: 8; radius: 4; color: q.svc.recording ? "#E2607F" : Theme.berry } }
        }
        // brightness (gamma lives in Settings → Displays)
        Column {
            spacing: 4
            UiText { text: "☼ Brightness " + Math.round(q.svc.brightness * 100) + "%"; px: 12; w: 600; height: 14 }
            PhoneLevel { width: q.leftW; height: 12; value: q.svc.brightness; color: Theme.sunDeep; onPicked: v => q.svc.setBrightness(v) }
        }
        // chips, 2 per row (same as upright): click opens its settings page, right-click switches it on / off
        Grid {
            columns: 2; rowSpacing: 8; columnSpacing: 8
            readonly property real tw: (q.leftW - 8) / 2
            PhoneToggleTile { width: parent.tw; glyph: "wifi"; title: "Wi-Fi"; on: q.svc.wifi.on; sub: q.svc.wifi.on ? (q.svc.wifi.ssid || "On") : "Off"; onClicked: q.go("settingsWifi"); onRightClicked: q.svc.toggle("wifi") }
            PhoneToggleTile { width: parent.tw; glyph: "bluetooth"; title: "Bluetooth"; on: q.svc.bluetooth.on; sub: q.svc.bluetooth.on ? (q.svc.bluetooth.name || "On") : "Off"; onClicked: q.go("settingsBt"); onRightClicked: q.svc.toggle("bt") }
            // Sound = speaker + mic: bars speaker (left) | mic (right); right-click mutes the speaker
            PhoneToggleTile { width: parent.tw; glyph: q.svc.muted ? "mute" : "volume"; title: "Sound"; on: !q.svc.muted
                sub: Math.round(q.svc.volume * 100) + "% · mic " + (q.svc.micOn ? Math.round(q.svc.micVolume * 100) + "%" : "off")
                level: q.svc.volume; levelColor: Theme.leaf; level2: q.svc.micVolume; level2Color: Theme.berry
                onClicked: q.go("settingsSound"); onRightClicked: q.svc.toggle("mute"); onLevelPicked: v => q.svc.setVolume(v); onLevel2Picked: v => q.svc.setMicVolume(v) }
            PhoneToggleTile { width: parent.tw; glyph: "cloud"; title: "Cloudflare WARP"; on: q.svc.warp.connected; sub: q.svc.warp.connected ? "Connected" : "Disconnected"; onClicked: q.svc.toggle("warp") }
        }
    }

    // right column: notifications
    Item {
        x: q.rightX; y: 18 + 44 + 14; width: q.rightW; height: q.height - y - 20
        UiCandy {
            y: 12; width: parent.width; height: parent.height - 12
            radius: 22; ink: Theme.inkPhone; drop: 0; hi: 0; fill: Qt.rgba(1, 253 / 255, 246 / 255, 0.85)
            Flickable {
                id: nf
                x: 10; y: 22; width: parent.width - 20; height: parent.height - y - 10
                contentHeight: nCol.height; clip: true; boundsBehavior: Flickable.StopAtBounds
                Column {
                    id: nCol; width: nf.width; spacing: 2; topPadding: 6
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
                    UiText { visible: q.svc.notifications.length === 0; width: nCol.width; topPadding: 40; horizontalAlignment: Text.AlignHCenter
                        text: "All quiet on the island ✿"; fam: "n"; w: 800; px: 13; color: Theme.textSoft }
                }
            }
        }
        UiCandy {
            anchors.horizontalCenter: parent.horizontalCenter; y: -3
            width: nt.implicitWidth + 37; height: 30
            ink: Theme.inkPhone; drop: 3; hi: 0; pressable: q.svc.notifications.length > 0
            onClicked: q.svc.clearNotifications()
            UiText { id: nt; anchors.centerIn: parent; text: q.svc.notifications.length ? "Clear notifications" : "Notifications"; px: 13; w: 700 }
        }
    }
}
