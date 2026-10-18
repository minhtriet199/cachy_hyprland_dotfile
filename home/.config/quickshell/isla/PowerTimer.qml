import QtQuick

// One Windows-style timer row: "Turn off my screen after" — Plugged in [10 min ▾]  On battery [3 min ▾].
// Clicking a value opens the choices underneath (Never, 1 min … 5 h, Custom…). key = Prefs property (idleLock / idleScreen / idleSleep).
// choices = [[value, label], …] makes it a plain pick list instead of minutes (lid: Sleep / Screen off / …).
Column {
    id: ic
    property string title: ""
    property string glyph: "power"
    property string key: "idleScreen"
    property var choices: null
    property int open: -1                       // which column's choices are showing (0 plugged in, 1 battery)
    readonly property var vals: Prefs[key] || [0, 0]
    readonly property var options: choices ? choices.map(c => c[0]) : [0, 1, 2, 3, 5, 10, 15, 20, 30, 45, 60, 120, 180, 300]
    function label(m) { if (choices) { const c = choices.find(c => c[0] === m); return c ? c[1] : String(m) }
        return m <= 0 ? "Never" : m < 60 ? m + " min" : (m % 60 ? (m / 60).toFixed(1) : m / 60) + " h" }
    function setVal(col, m) { const v = vals.slice(); v[col] = choices ? m : Math.max(0, Math.round(m)); Prefs.set(key, v); open = -1 }
    spacing: 6
    Item {
        width: ic.width; height: 40
        UiCandy { x: 0; y: 4; width: 32; height: 32; bw: 2; drop: 0; hi: 0; fill: Theme.paper
            Glyph { anchors.centerIn: parent; name: ic.glyph; size: 16; stroke: 2.4 } }
        UiText { x: 42; width: ic.width - 42 - picks.width - 8; height: 40; text: ic.title; px: 13; w: 700; wrapMode: Text.Wrap; maximumLineCount: 2 }
        Row {
            id: picks
            anchors.right: parent.right; y: 4; spacing: 6
            Repeater {
                model: 2
                delegate: UiCandy {
                    required property int index
                    readonly property bool openHere: ic.open === index
                    width: 92; height: 32; radius: 10; bw: 2.5; drop: openHere ? 0 : 2; hi: 0
                    fill: openHere ? Theme.gOn : Theme.cream; pressable: true
                    onClicked: ic.open = openHere ? -1 : index
                    Column { anchors.centerIn: parent
                        UiText { anchors.horizontalCenter: parent.horizontalCenter; text: index === 0 ? "PLUGGED IN" : "ON BATTERY"; fam: "n"; px: 7.5; w: 900; color: Theme.textSoft; height: 9 }
                        UiText { anchors.horizontalCenter: parent.horizontalCenter; text: ic.label(ic.vals[index]) + " ▾"; px: 12; w: 700; height: 15 } }
                }
            }
        }
    }
    // choices
    UiCandy {
        visible: ic.open >= 0
        width: ic.width; height: chFlow.implicitHeight + 16; radius: 12; bw: 2; drop: 0; hi: 0; fill: Theme.paper
        Flow {
            id: chFlow; x: 8; y: 8; width: parent.width - 16; spacing: 6
            Repeater {
                model: ic.options
                delegate: UiCandy {
                    required property var modelData
                    readonly property bool picked: ic.open >= 0 && ic.vals[ic.open] === modelData
                    width: cl.implicitWidth + 18; height: 28; radius: 9; bw: 2; drop: picked ? 2 : 0; hi: 0
                    fill: picked ? Theme.gGo : Theme.cream; pressable: true
                    onClicked: ic.setVal(ic.open, modelData)
                    UiText { id: cl; anchors.centerIn: parent; text: ic.label(modelData); px: 12; w: 700; color: parent.picked ? "#FFFFFF" : Theme.text }
                }
            }
            // custom minutes
            UiCandy {
                visible: !ic.choices
                width: 128; height: 28; radius: 9; bw: 2; drop: 0; hi: 0; fill: Theme.cream
                TextInput {
                    id: custom; x: 8; width: parent.width - 16; anchors.verticalCenter: parent.verticalCenter; clip: true
                    font.family: Theme.body; font.weight: 800; font.pixelSize: 12; color: Theme.text
                    validator: IntValidator { bottom: 0; top: 1440 }
                    onAccepted: if (text) { ic.setVal(ic.open, parseInt(text)); text = "" }
                    UiText { visible: !custom.text; text: "Custom min ↵"; fam: "n"; px: 11; w: 800; color: Theme.textSoft; anchors.verticalCenter: parent.verticalCenter }
                }
            }
        }
    }
}
