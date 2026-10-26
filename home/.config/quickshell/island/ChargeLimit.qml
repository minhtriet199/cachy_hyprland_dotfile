import QtQuick

// Battery charge limit (asusctl): 60 / 80 / 100 %. Power page.
Column {
    id: sp
    property var svc
    readonly property var v: svc.sys
    readonly property real colW: width
    spacing: 8
    Component.onCompleted: svc.loadSys()
    UiText { text: "BATTERY CHARGE LIMIT · " + (sp.v.limit || "?") + "%"; fam: "n"; px: 11; w: 900; track: 1.4; color: Theme.textSoft; height: 16 }
    Row {
        spacing: 6
        Repeater {
            model: [60, 80, 100]
            delegate: UiCandy {
                required property int modelData
                readonly property bool picked: String(modelData) === sp.v.limit
                width: (sp.colW - 12) / 3; height: 32; radius: 10; bw: 2.5; drop: picked ? 2 : 0; hi: 0
                fill: picked ? Theme.gGo : Theme.cream; pressable: true
                onClicked: sp.svc.sysCmd(["asusctl", "battery", "limit", String(modelData)])
                UiText { anchors.centerIn: parent; text: modelData + "%"; px: 13; w: 700; color: parent.picked ? "#FFFFFF" : Theme.text }
            }
        }
    }
    UiText { text: "60–80% keeps the battery healthy when you stay plugged in"; fam: "n"; px: 10; w: 800; color: Theme.textSoft; width: parent.width; wrapMode: Text.Wrap }
}
