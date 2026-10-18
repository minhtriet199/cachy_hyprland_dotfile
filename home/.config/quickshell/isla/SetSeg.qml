import QtQuick

// Row of segmented choice buttons with a label (Style: Float / Straight / Transparent).
// Wraps onto the next line when there isn't room (upright phone). Give it a width.
Flow {
    id: sg
    property string label: ""
    property var options: []
    property string current: ""
    signal picked(string v)
    spacing: 10
    UiText { width: 70; height: 34; text: sg.label; px: 13; w: 700 }
    Repeater {
        model: sg.options
        delegate: UiCandy {
            required property string modelData
            readonly property bool sel: modelData === sg.current
            width: sl.implicitWidth + 28 + 5; height: 32
            radius: 10; ink: Theme.inkPhone; hi: 0
            drop: sel ? 3 : 2; dropColor: sel ? Theme.inkPhone : Qt.rgba(33 / 255, 63 / 255, 72 / 255, 0.35)
            fill: sel ? Theme.gOn : Theme.paper
            pressable: true
            onClicked: sg.picked(modelData)
            UiText { id: sl; anchors.centerIn: parent; text: modelData; px: 13; w: 600; color: Theme.textDeep }
        }
    }
}
