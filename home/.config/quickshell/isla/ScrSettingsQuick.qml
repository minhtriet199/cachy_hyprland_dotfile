import QtQuick

// Settings → Quick (landscape, canvas "Settings-Quick").
Item {
    id: sq
    property var svc
    property var prefs
    signal go(string screen)
    signal close()
    signal back()
    signal soon(string what)
    readonly property bool narrow: width < 600                     // shown on the upright phone
    readonly property real cx: narrow ? 18 : 56
    readonly property real cw: width - cx - (narrow ? 18 : 26)
    readonly property real topPad: narrow ? 40 : 0                     // below the punch hole
    Flickable {
        id: page
        anchors.fill: parent; contentHeight: pageCol.height + 36; clip: true; boundsBehavior: Flickable.StopAtBounds
        WheelHandler { onWheel: e => page.contentY = Math.max(0, Math.min(Math.max(0, page.contentHeight - page.height), page.contentY - e.angleDelta.y / 2)) }
    Column {
        id: pageCol
        x: sq.cx; y: 18 + sq.topPad; width: sq.cw
        spacing: 14
        // header
        Item {
            width: parent.width; height: 44
            UiCandy {
                width: qcol.implicitWidth + 8 + 28 + 10 + 18 + 5; height: 44
                radius: 16; ink: Theme.inkPhone; hiColor: Qt.rgba(1, 1, 1, 0.6); fill: Theme.gSettings; pressable: true
                onClicked: sq.back()
                Rectangle { x: 8 + 2.5; anchors.verticalCenter: parent.verticalCenter; width: 28; height: 28; radius: 10; color: Theme.inkPhone
                    Rectangle { anchors.fill: parent; anchors.margins: 2; radius: 8; color: Theme.paper }
                    Glyph { anchors.centerIn: parent; name: "back"; size: 15; stroke: 3 } }
                Column { id: qcol; x: 8 + 2.5 + 28 + 10; anchors.verticalCenter: parent.verticalCenter
                    UiText { text: "Shell"; px: 18; w: 700; color: Theme.textDeep; height: 19 }
                    UiText { text: "Bar, dock and notifications"; fam: "n"; w: 800; px: 10.5; color: "#4A3F78" } }
            }
            Row {
                anchors.right: parent.right; y: sq.narrow ? -50 : (parent.height - height) / 2
                spacing: 10
                UiCandy {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 12 + 14 + 7 + ml.implicitWidth + 12 + 5; height: 36
                    radius: 12; ink: Theme.inkPhone; drop: 3; hi: 0; pressable: true
                    onClicked: sq.go("settings")
                    Glyph { x: 12 + 2.5; anchors.verticalCenter: parent.verticalCenter; name: "menu9"; size: 14 }
                    UiText { id: ml; x: 12 + 2.5 + 14 + 7; anchors.verticalCenter: parent.verticalCenter; text: "Menu"; px: 13; w: 600 }
                }
                SetHeaderBtn { anchors.verticalCenter: parent.verticalCenter; svc: sq.svc; clockH: 40; timePx: 14; closeSize: 38; onClose: sq.close() }
            }
        }
        // Shell
        SetSection {
            title: "Shell"; tagColor: Theme.pinkSoft; stripes: true
            Grid {
                columns: sq.narrow ? 1 : 3; rowSpacing: 10; columnSpacing: 12
                readonly property real tw: sq.narrow ? sq.cw - 33 : (sq.cw - 33 - 24) / 3
                SetToggle { width: parent.tw; glyph: "bell"; title: "Notifications"; on: sq.prefs.notifications; onClicked: sq.prefs.flip("notifications") }
                SetToggle { width: parent.tw; glyph: "moon"; title: "Night light"; on: sq.svc.nightLight; onClicked: sq.svc.toggle("night") }
                SetToggle { width: parent.tw; glyph: "bolt"; title: "Keep awake"; on: sq.svc.keepAwake; onClicked: sq.svc.toggle("awake") }
                SetToggle { width: parent.tw; glyph: "gamepad2"; title: "Game mode"; on: sq.svc.gameMode; onClicked: sq.svc.toggle("game") }
                SetToggle { width: parent.tw; glyph: "wallpaper"; title: "Wallpapers"; sub: "Open the picker"; link: true; onClicked: sq.go("wallpapers") }
                SetToggle { width: parent.tw; glyph: "dock"; title: "Dock"; on: sq.prefs.dock; onClicked: sq.prefs.flip("dock") }
                SetToggle { width: parent.tw; glyph: "barThin"; title: "Bar"; on: sq.prefs.bar; onClicked: sq.prefs.flip("bar") }
                UiCandy {
                    width: parent.tw; height: 42; ink: Theme.inkPhone; drop: 3; hi: 0
                    Rectangle { x: 7 + 2.5; anchors.verticalCenter: parent.verticalCenter; width: 26; height: 26; radius: 9; color: Theme.inkPhone
                        Rectangle { anchors.fill: parent; anchors.margins: 2; radius: 7; color: Theme.paper }
                        Glyph { anchors.centerIn: parent; name: "resize"; size: 14; stroke: 2.6 } }
                    Column { x: 7 + 2.5 + 26 + 8; anchors.verticalCenter: parent.verticalCenter
                        UiText { text: "Shell size"; px: 13.5; w: 700; color: Theme.textDeep; height: 14.8 }
                        UiText { text: sq.prefs.size.toFixed(2) + "×"; fam: "n"; w: 900; px: 10; color: Theme.textMuted } }
                    Row {
                        anchors.right: parent.right; anchors.rightMargin: 8 + 2.5; anchors.verticalCenter: parent.verticalCenter; spacing: 8
                        Repeater { model: ["−", "+"]
                            delegate: Rectangle { required property string modelData; required property int index
                                width: 26; height: 26; radius: 13; color: Theme.inkPhone
                                Rectangle { anchors.fill: parent; anchors.margins: 2; radius: 11; color: Theme.paper }
                                UiText { anchors.centerIn: parent; text: modelData; px: 15; w: 700 }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: sq.prefs.setSize(sq.prefs.size + (index ? 0.05 : -0.05)) } } }
                    }
                }
            }
        }
        // Bar
        SetSection {
            title: "Bar"; tagColor: "#FFE39A"; padTop: 20
            Column {
                spacing: 9
                SetSeg { label: "Style"; options: ["Float", "Straight", "Transparent"]; current: sq.prefs.barStyle; onPicked: v => sq.prefs.set("barStyle", v) }
                SetSeg { label: "Position"; options: ["Top", "Right", "Bottom", "Left"]; current: sq.prefs.barPos
                    onPicked: v => (v === "Top" || v === "Bottom") ? sq.prefs.set("barPos", v) : sq.soon("Side bar") }
            }
        }
        // Transition (lock / unlock / login scene change)
        SetSection {
            title: "Transition"; tagColor: "#BFE6C2"; padTop: 20
            Column {
                spacing: 10
                Row {
                    spacing: 10
                    UiText { width: 84; height: 30; text: "Background"; px: 13; w: 700; color: Theme.textDeep }
                    Repeater {
                        model: Object.keys(sq.prefs.wipeBgs)
                        delegate: UiCandy {
                            required property string modelData
                            readonly property bool picked: sq.prefs.wipeBg === modelData
                            width: 34; height: 30; radius: 10; bw: picked ? 3 : 2; ink: picked ? Theme.purple : Theme.inkPhone; drop: picked ? 2 : 0; hi: 0
                            fill: sq.prefs.wipeBgs[modelData][0]; pressable: true
                            onClicked: sq.prefs.set("wipeBg", modelData)
                        }
                    }
                }
                Row {
                    spacing: 10
                    UiText { width: 84; height: 38; text: "Icon"; px: 13; w: 700; color: Theme.textDeep }
                    Repeater {
                        model: ["leaf", "star", "bell", "apple", "flower", "heart", "shell", "none"]
                        delegate: UiCandy {
                            required property string modelData
                            readonly property bool picked: sq.prefs.wipeIcon === modelData
                            width: 38; height: 38; radius: 12; bw: picked ? 3 : 2; ink: picked ? Theme.purple : Theme.inkPhone; drop: picked ? 2 : 0; hi: 0
                            fill: (sq.prefs.wipeBgs[sq.prefs.wipeBg] || sq.prefs.wipeBgs.cream)[0]; pressable: true
                            onClicked: sq.prefs.set("wipeIcon", modelData)
                            WipeIcon { visible: modelData !== "none"; anchors.centerIn: parent; width: 26; height: 26; name: modelData }
                            UiText { visible: modelData === "none"; anchors.centerIn: parent; text: "—"; px: 14; w: 700 }
                        }
                    }
                }
                UiCandy {
                    width: 150; height: 32; radius: 11; bw: 2.5; ink: Theme.inkPhone; drop: 3; hi: 3; fill: Theme.gOn; pressable: true
                    onClicked: sq.svc.previewWipe()
                    UiText { anchors.centerIn: parent; text: "▶  Preview"; px: 13; w: 700 }
                }
            }
        }
    }
    }
    focus: true
    Keys.onEscapePressed: sq.close()
}
