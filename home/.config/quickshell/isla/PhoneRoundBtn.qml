import QtQuick

// Round 46px candy button with a glyph.
UiCandy {
    id: b
    property string glyph: "gear"
    property color glyphColor: Theme.text
    property real glyphStroke: 2.4
    property real glyphSize: 21
    width: 46; height: 46
    ink: Theme.inkPhone; hiColor: Qt.rgba(1, 1, 1, 0.9); fill: Theme.paper; pressable: true
    Glyph { anchors.centerIn: parent; name: b.glyph; size: b.glyphSize; stroke: b.glyphStroke; color: b.glyphColor }
}
