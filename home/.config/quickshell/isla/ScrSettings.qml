import QtQuick

// Settings menu (landscape, canvas "Settings-Home").
Item {
    id: st
    property var svc
    signal go(string screen)
    signal close()
    signal back()
    signal soon(string what)
    readonly property bool narrow: width < 600                     // shown on the upright phone
    readonly property real cx: narrow ? 18 : 56
    readonly property real cw: width - cx - (narrow ? 18 : 26)
    readonly property real topPad: narrow ? 26 : 0                     // below the punch hole
    // [number, title, line, colour, glyph, phone screen or "app:<name>" for the user's own settings apps]
    readonly property var cats: [
        ["01", "Wi-Fi", "Networks and passwords", "#55BFC6", "wifi", "settingsWifi"],
        ["02", "Bluetooth", "Earbuds, pads, devices", "#7C83F0", "bluetooth", "settingsBt"],
        ["03", "Sound", "Output, input, app mixer", "#7CC47F", "volume", "settingsSound"],
        ["04", "Power", "Battery, mode, brightness", "#FFC23C", "battery", "settingsPower"],
        ["05", "Shell", "Bar, dock, notifications", "#EE7D9C", "barIcon", "settingsQuick"],
        ["06", "Wallpaper", "Pick your island view", "#A08AEA", "wallpaper", "wallpapers"],
        ["07", "Displays", "Layout, HDR, refresh", "#8E7BE6", "monitor", "settingsDisplays"],
        ["08", "Keyboard", "Shortcuts and keys", "#F7A982", "keyboard", "settingsKeys"],
        ["09", "Screen time", "Hours per app", "#2F9EAB", "chart", "settingsTime"],
        ["10", "System", "Charge limit, firewall, about", "#5E7A84", "gear", "settingsSystem"],
        ["11", "Windows", "See-through, borders, gaps", "#55BFC6", "sliders", "settingsWindows"],
        ["12", "Time & language", "Clock, time zone, typing", "#7CC47F", "globe", "settingsTimeLang"],
        ["13", "Mouse & touchpad", "Speed, tap, cursor size", "#8E7BE6", "crosshair", "settingsMouse"],
        ["14", "Apps", "Default apps, startup", "#F7A982", "box", "settingsApps"],
        ["15", "Privacy & location", "Mic, camera, location", "#EE7D9C", "shield", "settingsPrivacy"],
        ["16", "Disk map", "What fills your drive", "#FFC23C", "chart", "settingsDiskMap"]
    ]
    function openCat(c) { st.go(c[5]) }
    // header
    Item {
        x: st.cx; y: 20 + st.topPad; width: st.cw; height: 46
        UiCandy {
            width: tcol.implicitWidth + 8 + 30 + 10 + 18 + 5; height: 46
            radius: 16; ink: Theme.inkPhone; hiColor: Qt.rgba(1, 1, 1, 0.6); fill: Theme.gOn; pressable: true
            onClicked: st.back()
            Rectangle { x: 8 + 2.5; anchors.verticalCenter: parent.verticalCenter; width: 30; height: 30; radius: 10; color: Theme.inkPhone; rotation: 45
                Rectangle { anchors.fill: parent; anchors.margins: 2; radius: 8; color: Theme.paper }
                Glyph { anchors.centerIn: parent; rotation: -45; name: "back"; size: 15; stroke: 3 } }
            Column { id: tcol; x: 8 + 2.5 + 30 + 10; anchors.verticalCenter: parent.verticalCenter
                UiText { text: "Settings"; px: 18; w: 700; color: Theme.textDeep; height: 19 }
                UiText { text: "Pick what you want to change"; fam: "n"; w: 800; px: 10.5; color: "#3F5F69" } }
        }
        SetHeaderBtn { anchors.right: parent.right; y: (parent.height - height) / 2; clockOnly: st.narrow; svc: st.svc; onClose: st.close() }
    }
    // cards (5 × 2)
    Flickable {
        id: cardsFl
        x: st.cx; y: 20 + st.topPad + 46 + 14; width: st.cw; height: st.height - y - 14 - (st.svc && st.svc.phoneBig && st.narrow ? 64 : 0)
        contentHeight: cardsGrid.height + 14; clip: true; boundsBehavior: Flickable.StopAtBounds   // + 14 = room for the last row's shadow
    Grid {
        id: cardsGrid
        columns: st.narrow ? 2 : 5; rowSpacing: 12; columnSpacing: 12
        Repeater {
            model: st.cats
            delegate: UiCandy {
                id: card
                required property var modelData
                readonly property bool ext: modelData[5].startsWith("app:")
                width: st.narrow ? (st.cw - 12) / 2 : (st.cw - 48) / 5; height: st.narrow ? 132 : (st.height - 20 - 46 - 14 - 12 - 20) / 2
                radius: 20; ink: Theme.inkPhone; drop: 4; hi: 4; hiColor: Qt.rgba(1, 1, 1, 0.9); pressable: true
                onClicked: st.openCat(modelData)
                // hover / focus / press: the card's colour slides in from the left (empty by default)
                readonly property bool lit: hovered || down || activeFocus
                Rectangle {
                    x: card.bw; y: card.bw; height: card.height - 2 * card.bw; radius: card.ir
                    width: (card.width - 2 * card.bw) * slide
                    property real slide: card.lit ? 1 : 0
                    Behavior on slide { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
                    visible: slide > 0.005
                    color: Qt.rgba(Qt.color(card.modelData[3]).r, Qt.color(card.modelData[3]).g, Qt.color(card.modelData[3]).b, Prefs.dark ? 0.32 : 0.26)
                }
                Item { x: 14; y: 14; width: 32; height: 32
                    Rectangle { y: 3; anchors.horizontalCenter: parent.horizontalCenter; width: 32; height: 32; radius: 10; color: Theme.inkPhone; rotation: 45 }
                    Rectangle { anchors.fill: parent; radius: 10; color: Theme.inkPhone; rotation: 45
                        Rectangle { anchors.fill: parent; anchors.margins: 2.5; radius: 8; color: card.modelData[3] } }
                    Glyph { anchors.centerIn: parent; name: card.modelData[4]; size: 16; stroke: 2.6; color: "#FFFFFF" } }
                UiText { anchors.right: parent.right; anchors.rightMargin: 14; y: 8; text: card.modelData[0]; px: 24; w: 700; color: Theme.adapt("#E6DCC6") }
                UiCandy { visible: card.ext; anchors.right: parent.right; anchors.rightMargin: 12; y: 40; width: 24; height: 24; bw: 2; drop: 0; hi: 0; fill: Theme.paper
                    Glyph { anchors.centerIn: parent; name: "external"; size: 12; stroke: 2.6 } }
                Column { x: 14; anchors.bottom: parent.bottom; anchors.bottomMargin: 14; width: parent.width - 28
                    UiText { width: parent.width; text: card.modelData[1]; px: 17; w: 700; color: Theme.textDeep; height: 20 }
                    UiText { width: parent.width; text: card.modelData[2]; fam: "n"; w: 800; px: 10; color: Theme.textSoft; wrapMode: Text.Wrap; maximumLineCount: 2 } }
            }
        }
    }
    }
    focus: true
    Keys.onEscapePressed: st.close()
}
