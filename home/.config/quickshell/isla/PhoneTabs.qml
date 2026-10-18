import QtQuick

// Apps · Quick · Islands segmented tabs.
UiCandy {
    id: tabs
    property int current: 0
    property var labels: ["Apps", "Quick", "Islands"]
    signal picked(int i)
    width: parent ? parent.width : 324; height: 34 + 10 + 5
    ink: Theme.inkPhone; drop: 0; hi: 0; fill: Theme.sand
    Row {
        x: 5 + 2.5; y: 5 + 2.5 - 2.5
        spacing: 6
        Repeater {
            model: tabs.labels
            delegate: Item {
                required property int index
                required property string modelData
                width: (tabs.width - 15 - 6 * (tabs.labels.length - 1)) / tabs.labels.length; height: 34
                y: 2.5
                UiCandy {
                    anchors.fill: parent; visible: index === tabs.current
                    ink: Theme.inkPhone; drop: 3; hi: 0; fill: Theme.gTab
                }
                UiText { anchors.centerIn: parent; text: modelData; px: 14; w: index === tabs.current ? 700 : 600
                    color: index === tabs.current ? "#FFFFFF" : Theme.textMuted }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: tabs.picked(index) }
            }
        }
    }
}
