import QtQuick

// Settings toggle pill (icon box + title + ON/OFF).
UiCandy {
    id: t
    property string glyph: "bell"
    property string title: ""
    property string sub: ""
    property bool on: false
    property bool link: false
    height: 42
    ink: Theme.inkPhone; drop: 3; hiColor: Qt.rgba(1, 1, 1, 0.7)
    fill: on && !link ? Theme.gOn : Theme.paper
    pressable: true
    Rectangle { x: 7 + 2.5; anchors.verticalCenter: parent.verticalCenter; width: 26; height: 26; radius: 9; color: Theme.inkPhone
        Rectangle { anchors.fill: parent; anchors.margins: 2; radius: 7; color: Theme.paper }
        Glyph { anchors.centerIn: parent; name: t.glyph; size: 14; stroke: 2.6 } }
    Column { x: 7 + 2.5 + 26 + 8; anchors.verticalCenter: parent.verticalCenter
        UiText { text: t.title; px: 13.5; w: 700; color: Theme.textDeep; height: 14.8 }
        UiText { text: t.sub !== "" ? t.sub : (t.on ? "ON" : "OFF"); fam: "n"; w: 900; px: 10; color: Theme.textMuted } }
}
