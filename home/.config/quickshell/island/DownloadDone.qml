import QtQuick

// Download mode finished: what finished + a 2 min countdown to shut down. Keep using (Enter / Esc) cancels it.
UiCandy {
    id: dd
    property var svc
    readonly property var d: svc.download
    width: 440; height: col.implicitHeight + 40; radius: 26; bw: 3; ink: Theme.inkPhone; drop: 6; hi: 0; fill: Theme.cream
    focus: true
    Keys.onReturnPressed: d.keepUsing()
    Keys.onEnterPressed: d.keepUsing()
    Keys.onEscapePressed: d.keepUsing()
    Column {
        id: col
        x: 22; y: 20; width: parent.width - 44; spacing: 12
        Row {
            spacing: 12
            UiCandy { width: 46; height: 46; radius: 23; bw: 3; ink: Theme.inkPhone; drop: 0; hi: 0; fill: Theme.gOn
                Glyph { anchors.centerIn: parent; name: "check"; size: 22; stroke: 3 } }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                UiText { text: "Downloads finished"; px: 22; w: 700; color: Theme.textDeep }
                UiText { text: "Done at " + dd.d.doneTime; fam: "n"; px: 12; w: 800; color: Theme.textSoft }
            }
        }
        Repeater {
            model: dd.d.doneNames
            delegate: Row {
                required property string modelData
                spacing: 8
                Glyph { anchors.verticalCenter: parent.verticalCenter; name: "check"; size: 13; stroke: 3; color: Theme.seaDeep }
                UiText { width: col.width - 24; elide: Text.ElideRight; text: modelData; fam: "n"; px: 13; w: 800 }
            }
        }
        // countdown
        Column {
            width: parent.width; spacing: 6
            UiText { fam: "n"; px: 13; w: 900; color: Theme.berry
                text: "Shutting down in " + Math.floor(dd.d.countdown / 60) + ":" + String(dd.d.countdown % 60).padStart(2, "0") }
            Rectangle { width: parent.width; height: 8; radius: 4; color: Theme.sand
                Rectangle { width: parent.width * dd.d.countdown / 120; height: parent.height; radius: 4; color: Theme.berry } }
        }
        Row {
            spacing: 10
            UiCandy { width: 190; height: 44; radius: 14; bw: 3; drop: 3; hi: 3; ink: Theme.inkPhone; fill: Theme.gGo; pressable: true
                onClicked: dd.d.keepUsing()
                UiText { anchors.centerIn: parent; text: "Keep using"; px: 15; w: 700; color: "#FFFFFF" } }
            UiCandy { width: 190; height: 44; radius: 14; bw: 2.5; drop: 2; hi: 0; ink: Theme.inkPhone; fill: Theme.paper; pressable: true
                onClicked: dd.d.shutDownNow()
                Row { anchors.centerIn: parent; spacing: 6
                    Glyph { anchors.verticalCenter: parent.verticalCenter; name: "power"; size: 14; stroke: 2.6 }
                    UiText { anchors.verticalCenter: parent.verticalCenter; text: "Shut down now"; px: 14; w: 700 } } }
        }
    }
}
