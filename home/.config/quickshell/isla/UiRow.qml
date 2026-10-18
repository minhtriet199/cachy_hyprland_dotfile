import QtQuick

// List row for the Wi-Fi / Bluetooth / Sound panels: icon bubble, title, small line, right side slot.
UiCandy {
    id: r
    property string glyph: "wifi"
    property string title: ""
    property string sub: ""
    property bool active: false
    property bool busy: false
    property string busyText: "Working…"
    property color subColor: Theme.textSoft
    default property alias trailing: slot.data
    height: 50; radius: 15; bw: 2.5; drop: active ? 3 : 0; hi: 0
    fill: active ? Theme.gOn : Theme.cream; pressable: true
    UiCandy { x: 9; y: (r.height - 32) / 2; width: 32; height: 32; bw: 2; drop: 0; hi: 0
        fill: r.active ? Theme.ink : Theme.paper
        Glyph { anchors.centerIn: parent; name: r.glyph; size: 16; stroke: 2.4; color: r.active ? "#FFF3C4" : Theme.text } }
    Column {
        x: 50; y: (r.height - implicitHeight) / 2; width: r.width - 50 - slot.width - (spin.visible ? spin.width + 6 : 0) - 14
        UiText { width: parent.width; text: r.title; px: 14; w: 700; height: 17 }
        UiText { visible: text !== ""; width: parent.width; text: r.busy ? r.busyText : r.sub; fam: "n"; px: 10.5; w: 800; color: r.busy ? Theme.seaDeep : r.subColor; height: 14 }
    }
    Row { id: slot; x: r.width - width - 10; y: (r.height - height) / 2; spacing: 6 }
    // spinner while busy (connecting, pairing…), just left of the buttons
    Glyph { id: spin; visible: r.busy; x: slot.x - width - (slot.width > 0 ? 6 : 0); y: (r.height - height) / 2
        name: "reload"; size: 15; stroke: 2.6; color: Theme.seaDeep
        RotationAnimation on rotation { running: spin.visible; loops: Animation.Infinite; from: 0; to: 360; duration: 900 } }
}
