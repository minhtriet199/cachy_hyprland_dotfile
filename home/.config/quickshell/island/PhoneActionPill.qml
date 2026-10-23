import QtQuick

// Rounded action row with icon + title + subtitle (launcher suggestions).
UiCandy {
    id: p
    property string glyph: "info"
    property string title: ""
    property string sub: ""
    property color subColor: Theme.textSoft
    property real hiAlpha: 0.8
    height: 46
    ink: Theme.inkPhone; hiColor: Qt.rgba(1, 1, 1, hiAlpha); pressable: true
    Glyph { x: 14; anchors.verticalCenter: parent.verticalCenter; name: p.glyph; size: 19; stroke: 2.5 }
    Column {
        x: 14 + 19 + 10; anchors.verticalCenter: parent.verticalCenter
        UiText { text: p.title; px: 15; w: 700; height: 16.5 }
        UiText { text: p.sub; fam: "n"; w: 800; px: 11; color: p.subColor; width: p.width - 60 }
    }
}
