import QtQuick

UiCandy {
    id: b
    property string text: ""
    property real h: 30
    property bool bold: false
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    width: bl.implicitWidth + (bold ? 36 : 24) + 5; height: h
    ink: Theme.inkPhone; drop: 0; hi: 0; pressable: true
    UiText { id: bl; anchors.centerIn: parent; text: b.text; px: b.bold ? 13 : 12; w: b.bold ? 700 : 600 }
}
