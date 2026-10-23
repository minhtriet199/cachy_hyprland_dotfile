import QtQuick
import Quickshell.Wayland

// Hover tooltip above a dock app (like the Windows taskbar): app name + a live picture of each window.
// Click a picture to go to that window, × closes it. Not running → just the name.
UiCandy {
    id: p
    property var svc
    property string name: ""
    property var wins: []
    signal picked()
    readonly property var shown: wins.slice(0, 4)
    readonly property real thumbW: 230
    width: shown.length ? shown.length * (thumbW + 10) - 10 + 24 : label.implicitWidth + 28
    height: shown.length ? 40 + 164 + 14 : 38
    radius: shown.length ? 20 : 14; bw: 2.5; drop: 4; hi: 0; fill: Theme.cream

    UiText { id: label; x: 14; y: shown.length ? 10 : 0; height: shown.length ? 22 : p.height
        width: p.width - 28; text: p.name + (p.wins.length > 1 ? "  ·  " + p.wins.length + " windows" : ""); px: 15; w: 700 }

    Row {
        visible: p.shown.length > 0
        x: 12; y: 40; spacing: 10
        Repeater {
            model: p.shown
            delegate: Item {
                id: th
                required property var modelData
                width: p.thumbW; height: 164
                UiCandy {
                    width: parent.width; height: 124; radius: 12; bw: 2.5; drop: 0; hi: 0
                    ink: th.modelData.activated ? Theme.leafDeep : Theme.ink
                    fill: Theme.sand; pressable: true
                    onClicked: { th.modelData.activate(); p.picked() }
                    ScreencopyView {
                        id: cap
                        anchors.fill: parent; anchors.margins: 4
                        captureSource: th.modelData
                        live: true
                        constraintSize: Qt.size(460, 248)
                    }
                    UiCandy {
                        x: parent.width - 30; y: 6; width: 24; height: 24; bw: 2; drop: 0; hi: 0; fill: Theme.paper; pressable: true
                        onClicked: th.modelData.close()
                        Glyph { anchors.centerIn: parent; name: "close"; size: 11; stroke: 2.8 }
                    }
                }
                UiMarquee { y: 128; width: parent.width; height: 18; text: th.modelData.title; px: 12; w: 700 }
                UiText { y: 147; width: parent.width; height: 15; text: p.svc ? p.svc.whereIs(th.modelData) : ""; fam: "n"; px: 10; w: 800; color: Theme.textSoft }
            }
        }
    }
}
