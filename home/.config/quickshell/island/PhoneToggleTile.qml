import QtQuick

// Quick-panel toggle: wide pill (icon dot + title + state) or small square; optional level bar (or two side by side: level2).
Item {
    id: t
    property string glyph: "wifi"
    property string title: ""
    property string sub: ""
    property bool on: false
    property bool small: false
    property real level: -1          // 0..1 shows a level bar under the pill
    property color levelColor: Theme.sea
    property real level2: -1         // 0..1 second bar (right half), e.g. Sound: speaker | mic
    property color level2Color: Theme.berry
    signal clicked()
    signal rightClicked()
    signal levelPicked(real v)
    signal level2Picked(real v)
    width: small ? 48 : 100
    height: small ? 48 : (level >= 0 ? 50 + 6 + 10 : 50)
    UiCandy {
        width: parent.width; height: t.small ? 48 : 50
        radius: t.small ? 16 : 999
        ink: Theme.inkPhone; hiColor: Qt.rgba(1, 1, 1, 0.7)
        fill: t.on ? Theme.gOn : Theme.paper
        pressable: true
        onClicked: t.clicked()
        onRightClicked: t.rightClicked()
        Glyph { visible: t.small; anchors.centerIn: parent; name: t.glyph; size: 20; stroke: 2.4 }
        Rectangle {
            visible: !t.small
            x: 6 + 2.5 - 2.5 + 3.5; anchors.verticalCenter: parent.verticalCenter
            width: 32; height: 32; radius: 16; color: Theme.inkPhone
            Rectangle { x: 2; y: 2; width: 28; height: 28; radius: 14; color: t.on ? "#FFFFFF" : Theme.sand }
            Glyph { anchors.centerIn: parent; name: t.glyph; size: 17; stroke: 2.4 }
        }
        Column {
            visible: !t.small
            x: 6 + 32 + 8 + 3.5 - 2.5; anchors.verticalCenter: parent.verticalCenter
            UiText { text: t.title; px: 14; w: 700; color: Theme.textDeep; width: Math.min(implicitWidth, t.width - 56)
                wrapMode: Text.WordWrap; maximumLineCount: 2; lineHeightMode: Text.FixedHeight; lineHeight: 15.4 }
            UiText { text: t.sub !== "" ? t.sub : (t.on ? "On" : "Off"); fam: "n"; w: 800; px: 10.5; color: Theme.textMuted; width: Math.min(implicitWidth, 86) }
        }
    }
    PhoneLevel {
        visible: t.level >= 0
        y: 56; width: t.level2 >= 0 ? (parent.width - 8) / 2 : parent.width; height: 10
        value: Math.max(0, t.level); color: t.levelColor
        onPicked: v => t.levelPicked(v)
    }
    PhoneLevel {
        visible: t.level2 >= 0
        x: (parent.width + 8) / 2; y: 56; width: (parent.width - 8) / 2; height: 10
        value: Math.max(0, t.level2); color: t.level2Color
        onPicked: v => t.level2Picked(v)
    }
}
