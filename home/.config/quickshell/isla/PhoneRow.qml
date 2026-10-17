import QtQuick

// Result row: coloured icon box + title + subtitle. `selected` = green candy row with ↵.
UiCandy {
    id: r
    property string glyph: "grid"
    property color tint: Theme.sea
    property string iconSource: ""
    property string title: ""
    property string sub: ""
    property bool selected: false
    property color rowInk: Theme.ink
    width: parent ? parent.width : 324
    height: 44 + 16 + 5
    radius: 20; ink: rowInk
    drop: selected ? 5 : 3
    hi: selected ? 4 : 0; hiColor: Qt.rgba(1, 1, 1, 0.35)
    fill: selected ? Theme.gGo : Theme.paper
    pressable: true
    scale: selected ? 1.02 : 1
    Behavior on scale { NumberAnimation { duration: 120 } }
    UiCandy {
        x: 8 + 2.5; anchors.verticalCenter: parent.verticalCenter
        width: 44; height: 44; radius: 15; ink: r.rowInk; drop: 0; hi: 0
        fill: r.selected || r.iconSource !== "" ? "#FFFFFF" : r.tint
        Glyph { anchors.centerIn: parent; visible: r.iconSource === ""; name: r.glyph; size: r.selected ? 24 : 22; stroke: 2.5; color: r.selected ? r.tint : "#FFFFFF" }
        Image { anchors.centerIn: parent; visible: r.iconSource !== ""; source: r.iconSource; width: 28; height: 28; sourceSize: Qt.size(64, 64) }
    }
    Column {
        x: 8 + 2.5 + 44 + 12; anchors.verticalCenter: parent.verticalCenter
        width: r.width - x - (r.selected ? 50 : 16)
        UiText { width: parent.width; text: r.title; px: r.selected ? 17 : 16; w: r.selected ? 700 : 600; color: r.selected ? "#FFFFFF" : Theme.text }
        UiText { width: parent.width; text: r.sub; visible: text !== ""; fam: "n"; w: 800; px: 12; color: r.selected ? "#FFFFFF" : Theme.textSoft }
    }
    PhoneKeycap { visible: r.selected; anchors.right: parent.right; anchors.rightMargin: 14.5; anchors.verticalCenter: parent.verticalCenter
        text: "↵"; px: 13; fill: Theme.leafDeep; textColor: "#FFFFFF"; ink: r.rowInk }
}
