import QtQuick

// Settings section card with a pill tag on its top edge.
Item {
    id: sec
    property string title: ""
    property color tagColor: Theme.pinkSoft
    property real padTop: 22
    property bool stripes: false
    default property alias content: holder.data
    width: parent ? parent.width : 400
    height: holder.childrenRect.height + padTop + 14 + 5
    UiCandy {
        anchors.fill: parent; radius: 22; ink: Theme.inkPhone; drop: 4; hi: 0; fill: Theme.adapt("#FFFCF5")
        Item { id: holder; x: 14 + 2.5; y: sec.padTop + 2.5; width: parent.width - 33 }
        SetStripes { visible: sec.stripes; anchors.right: parent.right; anchors.rightMargin: 16 + 2.5; y: 10 + 2.5; w: 7; h: 12; colors: [Theme.sunDeep, "#A08AEA", Theme.leaf] }
    }
    UiCandy {
        x: 14; y: -14; width: tl.implicitWidth + 6 + 18 + 6 + 12 + 5; height: 26
        ink: Theme.inkPhone; drop: 3; hi: 0; fill: sec.tagColor
        Rectangle { x: 6 + 2.5; anchors.verticalCenter: parent.verticalCenter; width: 18; height: 18; radius: 9; color: Theme.inkPhone
            Rectangle { anchors.fill: parent; anchors.margins: 2; radius: 7; color: Theme.paper } }
        UiText { id: tl; x: 6 + 2.5 + 18 + 6; anchors.verticalCenter: parent.verticalCenter; text: sec.title; px: 13; w: 700; color: Theme.textDeep }
    }
}
