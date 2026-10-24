import QtQuick

// Before Download mode starts: what to do when the downloads finish. Keep using (Enter) · Shut down · Esc = don't start.
UiCandy {
    id: da
    property var svc
    readonly property var d: svc.download
    width: 440; height: col.implicitHeight + 40; radius: 26; bw: 3; ink: Theme.inkPhone; drop: 6; hi: 0; fill: Theme.cream
    focus: true
    Keys.onReturnPressed: d.begin("keep")
    Keys.onEnterPressed: d.begin("keep")
    Keys.onEscapePressed: d.cancelChoose()
    Column {
        id: col
        x: 22; y: 20; width: parent.width - 44; spacing: 12
        Row {
            spacing: 12
            UiCandy { width: 46; height: 46; radius: 23; bw: 3; ink: Theme.inkPhone; drop: 0; hi: 0; fill: Theme.gOn
                Glyph { anchors.centerIn: parent; name: "download"; size: 22; stroke: 3 } }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                UiText { text: "Download mode"; px: 22; w: 700; color: Theme.textDeep }
                UiText { text: "When the downloads finish…"; fam: "n"; px: 12; w: 800; color: Theme.textSoft }
            }
        }
        Row {
            spacing: 10
            UiCandy { width: 190; height: 44; radius: 14; bw: 3; drop: 3; hi: 3; ink: Theme.inkPhone; fill: Theme.gGo; pressable: true
                onClicked: da.d.begin("keep")
                UiText { anchors.centerIn: parent; text: "Keep using"; px: 15; w: 700; color: "#FFFFFF" } }
            UiCandy { width: 190; height: 44; radius: 14; bw: 2.5; drop: 2; hi: 0; ink: Theme.inkPhone; fill: Theme.paper; pressable: true
                onClicked: da.d.begin("shutdown")
                Row { anchors.centerIn: parent; spacing: 6
                    Glyph { anchors.verticalCenter: parent.verticalCenter; name: "power"; size: 14; stroke: 2.6 }
                    UiText { anchors.verticalCenter: parent.verticalCenter; text: "Shut down"; px: 14; w: 700 } } }
        }
        UiText { anchors.horizontalCenter: parent.horizontalCenter; text: "Esc · cancel"; fam: "n"; px: 11; w: 800; color: Theme.textSoft
            MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: da.d.cancelChoose() } }
    }
}
