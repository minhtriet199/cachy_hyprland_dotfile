import QtQuick

// Quick panel (canvas "Phone-Quick").
Item {
    id: q
    property var svc
    signal go(string screen)
    readonly property real cw: width - 32
    property bool editing: false              // pencil button: edit the chips
    onVisibleChanged: if (!visible) editing = false
    Column {
        x: 16; y: 18; width: q.cw
        spacing: 11
        PhoneStatus { svc: q.svc; right2: "↓ " + q.svc.netDown + "  ↑ " + q.svc.netUp }
        // brightness (gamma lives in Settings → Displays)
        Column {
            width: parent.width; spacing: 6
            UiText { x: 4; text: "☼ Brightness " + Math.round(q.svc.brightness * 100) + "%"; px: 13; w: 600; height: 16 }
            PhoneLevel { width: parent.width; height: 12; value: q.svc.brightness; color: Theme.sunDeep; onPicked: v => q.svc.setBrightness(v) }
        }
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
                PhoneRoundBtn { glyph: q.editing ? "check" : "pencil"; fill: q.editing ? Theme.gOn : Theme.paper; onClicked: q.editing = !q.editing }   // edit chips (reload lives in Settings → System)
                PhoneRoundBtn { glyph: q.svc.dnd ? "bellOff" : "bell"; fill: q.svc.dnd ? Theme.gTab : Theme.gChip; hiColor: Qt.rgba(1, 1, 1, 0.5)
                    glyphColor: q.svc.dnd ? "#FFFFFF" : Theme.textDeep; glyphStroke: 2.6; onClicked: q.svc.toggle("dnd") }   // Do not disturb
                PhoneRoundBtn { glyph: "ring"; onClicked: q.svc.tool("record"); onRightClicked: q.svc.tool("recordPick")
                    Rectangle { anchors.centerIn: parent; width: 8; height: 8; radius: 4; color: q.svc.recording ? "#E2607F" : Theme.berry } }
            }
        }
        // chips (QuickChips: pages of 2 × 3, pencil = edit)
        QuickChips { width: parent.width; svc: q.svc; editing: q.editing; onGo: s => q.go(s) }
        // notifications
        Item {
            width: parent.width
            height: q.height - y - 18 - 14 - 12 - ((q.svc.phoneBig && q.height > q.width) ? 50 : 0)   // big mode: stop above the nav bar
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
