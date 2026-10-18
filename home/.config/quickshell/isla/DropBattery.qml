import QtQuick

// Battery dropdown: big %, charge state, life gauge (10 cells), power mode (asusctl profiles), screen brightness.
// The Power settings page shows its own brightness slider, so it turns ours off (showBrightness).
DropCard {
    id: d
    property var svc
    readonly property var bat: svc.battery
    readonly property int pct: bat.percent
    property bool showBrightness: true
    width: 340; height: showBrightness ? 312 : 250
    headerColor: Theme.gLeaf[1]; headerH: 92

    function timeText(m) { return m < 60 ? m + " min" : Math.floor(m / 60) + " h " + (m % 60) + " min" }
    readonly property string line1: bat.status === "Charging" ? "Charging" : (bat.plugged ? "Plugged in" : "On battery")
    readonly property string line2: bat.minutes > 0
        ? (bat.status === "Charging" ? "full in " + timeText(bat.minutes) : timeText(bat.minutes) + " left")
        : (bat.plugged ? (pct >= 95 ? "Fully charged" : "Not charging · charge limit") : "")
    readonly property var tag: pct >= 80 ? ["GREAT", Theme.berry] : pct >= 50 ? ["GOOD", Theme.sea] : pct >= 20 ? ["LOW", Theme.orange] : ["CHARGE", Theme.berry]

    UiStrokeText { id: big; x: 16; y: 18; text: d.pct + "%"; px: 46; weight: 700; strokeW: 7; strokeColor: Theme.ink }
    Column {
        x: big.x + big.width + 14; y: 30; spacing: 2
        UiText { text: d.line1; px: 15; w: 700 }
        UiText { text: d.line2; fam: "n"; px: 11; w: 800; color: Theme.textSoft }
    }
    UiTag { x: d.width - width - 18; y: 18; text: d.tag[0]; fill: d.tag[1]; ink: Theme.ink; tilt: 6; px: 13 }

    // life gauge
    UiText { x: 20; y: 108; text: "LIFE GAUGE"; fam: "n"; px: 11; w: 900; track: 1.4; color: Theme.textSoft }
    UiText { x: d.width - width - 20; y: 108; text: "health " + d.bat.health + "%"; fam: "n"; px: 11; w: 800; color: Theme.textSoft }
    Row {
        x: 20; y: 128 + (25 - height) / 2; spacing: 6
        Repeater {
            model: 10
            delegate: Rectangle {
                required property int index
                readonly property bool lit: index < Math.round(d.pct / 10)
                readonly property bool last: index === Math.max(0, Math.round(d.pct / 10) - 1)
                width: Math.min(25, (d.width - 40 - 54) / 10); height: width; radius: 6
                color: lit ? Theme.leaf : Theme.sand
                border.width: last ? 3 : 2; border.color: last ? Theme.sunDeep : Theme.ink
            }
        }
    }

    // power mode
    UiText { x: 20; y: 168; text: "POWER MODE"; fam: "n"; px: 11; w: 900; track: 1.4; color: Theme.textSoft }
    Row {
        x: 20; y: 190; spacing: 8
        Repeater {
            model: [["Silent", "Quiet"], ["Performance", "Balanced"], ["Turbo", "Performance"]]
            delegate: UiCandy {
                required property var modelData
                readonly property bool sel: d.svc.powerProfile === modelData[1]
                width: (d.width - 40 - 16) / 3; height: 38; radius: 12; bw: 2.5; drop: 3; hi: sel ? 3 : 0
                fill: sel ? Theme.gGo : Theme.paper; pressable: true
                onClicked: d.svc.setProfile(modelData[1])
                UiText { anchors.centerIn: parent; width: parent.width - 8; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
                    text: modelData[0]; px: 13; w: 700; color: sel ? "#FFFFFF" : Theme.text }
            }
        }
    }

    // screen brightness (laptop screen)
    UiText { visible: d.showBrightness; x: 20; y: 244; text: "SCREEN BRIGHTNESS · " + Math.round(d.svc.brightness * 100) + "%"; fam: "n"; px: 11; w: 900; track: 1.4; color: Theme.textSoft }
    UiSlider { visible: d.showBrightness; x: 20; y: 266; width: d.width - 40; value: d.svc.brightness; color: Theme.sunDeep
        onPicked: v => d.svc.setBrightness(Math.max(0.05, v)) }
}
