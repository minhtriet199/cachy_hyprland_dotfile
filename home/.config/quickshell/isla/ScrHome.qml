import QtQuick
import QtQuick.Layouts
import Quickshell

// Phone launcher (canvas "Phone-Home").
Item {
    id: home
    property var svc
    signal go(string screen)
    signal launch(var app)
    signal typed(string t)
    focus: true
    Keys.onPressed: e => { if (e.text && e.text.trim() !== "" && !(e.modifiers & (Qt.ControlModifier | Qt.AltModifier))) { home.typed(e.text); e.accepted = true } }
    Column {
        x: 18; y: 18; width: parent.width - 36
        spacing: 12
        PhoneStatus { svc: home.svc; right2: home.svc.wifi.on ? home.svc.wifi.ssid : "offline" }
        // tabs (6px extra gap above)
        Item { width: parent.width; height: 49 + 6
            PhoneTabs { y: 6; current: 0; onPicked: i => home.go(["home", "quick", "islands"][i]) } }
        // search field (opens Search)
        UiCandy {
            width: parent.width; height: 48
            ink: Theme.inkPhone; hiColor: Qt.rgba(1, 1, 1, 0.9); pressable: true
            onClicked: home.go("search")
            Glyph { x: 16; anchors.verticalCenter: parent.verticalCenter; name: "search"; size: 20; stroke: 2.5 }
            UiText { x: 46; anchors.verticalCenter: parent.verticalCenter; text: "Search apps and actions…"; fam: "n"; w: 800; px: 14; color: Theme.textSoft }
            PhoneKeycap { anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter; text: "Super ␣" }
        }
        // all installed apps, A–Z (scroll for more)
        GridView {
            id: grid
            width: parent.width; height: home.height - y - 18 - (home.svc.phoneBig ? 52 : 4)
            cellWidth: width / 4; cellHeight: 98
            clip: true; boundsBehavior: Flickable.StopAtBounds
            model: home.svc.entries.slice().sort((a, b) => a.name.localeCompare(b.name))
            delegate: Item {
                required property var modelData
                width: grid.cellWidth; height: grid.cellHeight
                readonly property var look: home.svc.lookFor(modelData.startupClass || modelData.id)
                PhoneAppTile {
                    anchors.horizontalCenter: parent.horizontalCenter
                    label: parent.modelData.name
                    glyph: parent.look[0] !== "grid" ? parent.look[0] : "grid"
                    iconSource: parent.look[0] !== "grid" ? "" : Quickshell.iconPath(parent.modelData.icon, "application-x-executable")
                    tint: parent.look[0] !== "grid" ? parent.look[1] : "#FFFFFF"
                    onClicked: home.launch({ entry: parent.modelData })
                }
            }
        }
    }
}
