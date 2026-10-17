import QtQuick

// Calendar dropdown: date badge, month title + week, month grid (today lilac, Sundays berry).
// Scroll or ‹ › to change month, click the title to jump back to today.
DropCard {
    id: d
    property var svc
    property int offset: 0                       // months from now
    readonly property date today: svc.now
    readonly property date first: new Date(today.getFullYear(), today.getMonth() + offset, 1)
    readonly property var months: ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    readonly property int weeks: Math.ceil((first.getDay() + new Date(first.getFullYear(), first.getMonth() + 1, 0).getDate()) / 7)
    width: 340; height: 132 + 30 + weeks * 36 + 14
    headerColor: Theme.gBerry[1]; headerH: 92

    function isoWeek(dt) {
        const t = new Date(Date.UTC(dt.getFullYear(), dt.getMonth(), dt.getDate()));
        const day = t.getUTCDay() || 7; t.setUTCDate(t.getUTCDate() + 4 - day);
        return Math.ceil(((t - new Date(Date.UTC(t.getUTCFullYear(), 0, 1))) / 86400000 + 1) / 7);
    }
    function cell(i) { return new Date(first.getFullYear(), first.getMonth(), 1 - first.getDay() + i) }

    WheelHandler { onWheel: e => d.offset += e.angleDelta.y > 0 ? -1 : 1 }

    // date badge
    UiCandy {
        x: 18; y: 16; width: 54; height: 60; radius: 12; bw: 2.5; drop: 3; hi: 0; fill: Theme.paper
        Rectangle { x: 2.5; y: 2.5; width: parent.width - 5; height: 17; radius: 9.5; color: Theme.berry }
        Rectangle { x: 2.5; y: 12; width: parent.width - 5; height: 8; color: Theme.berry }
        Rectangle { x: 2.5; y: 19.5; width: parent.width - 5; height: 2.5; color: Theme.ink }
        UiText { y: 3; width: parent.width; horizontalAlignment: Text.AlignHCenter; text: ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"][d.today.getDay()]
                 fam: "n"; px: 10; w: 900; color: "#FFFFFF"; height: 16 }
        UiText { y: 22; width: parent.width; height: 34; horizontalAlignment: Text.AlignHCenter; text: d.today.getDate(); px: 24; w: 700 }
    }
    Item {
        x: 86; y: 22; width: 170; height: 50
        UiText { text: d.months[d.first.getMonth()]; px: 25; w: 700; width: parent.width }
        UiText { y: 30; text: d.first.getFullYear() + (d.offset === 0 ? " · Week " + d.isoWeek(d.today) : ""); fam: "n"; px: 11; w: 800; color: Theme.textMuted }
        MouseArea { anchors.fill: parent; cursorShape: d.offset ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: d.offset = 0 }
    }
    Row {
        x: d.width - width - 16; y: 30; spacing: 6
        Repeater {
            model: ["prev", "next"]
            delegate: UiCandy {
                required property string modelData
                width: 30; height: 30; bw: 2; drop: 2; hi: 0; fill: Theme.paper; pressable: true
                onClicked: d.offset += modelData === "prev" ? -1 : 1
                Glyph { anchors.centerIn: parent; name: modelData; size: 14; stroke: 2.6 }
            }
        }
    }

    // grid
    Grid {
        x: 16; y: 106; columns: 7; columnSpacing: 0; rowSpacing: 0
        Repeater {
            model: ["S", "M", "T", "W", "T", "F", "S"]
            delegate: UiText { required property string modelData; width: (d.width - 32) / 7; height: 30
                horizontalAlignment: Text.AlignHCenter; text: modelData; fam: "n"; px: 12; w: 900; color: Theme.textMuted }
        }
        Repeater {
            model: d.weeks * 7
            delegate: Item {
                required property int index
                readonly property date dt: d.cell(index)
                readonly property bool inMonth: dt.getMonth() === d.first.getMonth()
                readonly property bool isToday: dt.toDateString() === d.today.toDateString()
                width: (d.width - 32) / 7; height: 36
                UiCandy { visible: parent.isToday; anchors.centerIn: parent; width: 36; height: 30; radius: 9; bw: 2.5; drop: 2; hi: 2
                    fill: Theme.gActive; hiColor: Qt.rgba(1, 1, 1, 0.45) }
                UiText { anchors.centerIn: parent; text: parent.dt.getDate(); px: 15; w: 700
                    color: parent.isToday ? "#FFFFFF" : !parent.inMonth ? "#C4AE86" : parent.dt.getDay() === 0 ? Theme.berry : Theme.text }
            }
        }
    }
}
