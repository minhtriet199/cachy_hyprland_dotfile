import QtQuick

// Calendar card (bar dropdown + desktop widget), SekaiPop-style: "2026 · Week 42" over a big month name, ‹ ›, month grid
// (today lilac, Sundays berry).
// Scroll or ‹ › to change month, click the title to jump back to today.
DropCard {
    id: d
    property var svc
    property int offset: 0                       // months from now
    readonly property date today: svc.now
    readonly property date first: new Date(today.getFullYear(), today.getMonth() + offset, 1)
    readonly property var months: ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    readonly property int weeks: Math.ceil((first.getDay() + new Date(first.getFullYear(), first.getMonth() + 1, 0).getDate()) / 7)
    width: 340; height: 136 + 30 + weeks * 34 + 14
    headerH: 96

    function isoWeek(dt) {
        const t = new Date(Date.UTC(dt.getFullYear(), dt.getMonth(), dt.getDate()));
        const day = t.getUTCDay() || 7; t.setUTCDate(t.getUTCDate() + 4 - day);
        return Math.ceil(((t - new Date(Date.UTC(t.getUTCFullYear(), 0, 1))) / 86400000 + 1) / 7);
    }
    function cell(i) { return new Date(first.getFullYear(), first.getMonth(), 1 - first.getDay() + i) }

    WheelHandler { onWheel: e => d.offset += e.angleDelta.y > 0 ? -1 : 1 }

    Item {
        x: 24; y: 18; width: 210; height: 66
        UiText { color: Theme.textDeep; text: d.first.getFullYear() + (d.offset === 0 ? " · Week " + d.isoWeek(d.today) : ""); fam: "n"; px: 12; w: 900; track: 1 }
        UiStrokeText { y: 18; text: d.months[d.first.getMonth()]; px: 34; weight: 700; strokeW: 6; strokeColor: Theme.ink }
        MouseArea { anchors.fill: parent; cursorShape: d.offset ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: d.offset = 0 }
    }
    Row {
        x: d.width - width - 24; y: 34; spacing: 6
        Repeater {
            model: ["prev", "next"]
            delegate: UiCandy {
                required property string modelData
                width: 32; height: 32; radius: 16; bw: 2.5; drop: 2; hi: 0; fill: Theme.paper; pressable: true
                onClicked: d.offset += modelData === "prev" ? -1 : 1
                Glyph { anchors.centerIn: parent; name: "arrowRight"; rotation: modelData === "prev" ? 180 : 0; size: 14; stroke: 2.6 }
            }
        }
    }

    // grid
    Grid {
        x: 16; y: 110; columns: 7; columnSpacing: 0; rowSpacing: 0
        Repeater {
            model: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
            delegate: UiText { required property string modelData; required property int index; width: (d.width - 32) / 7; height: 30
                horizontalAlignment: Text.AlignHCenter; text: modelData; fam: "n"; px: 12; w: 900; color: index % 6 === 0 ? Theme.berry : Theme.textMuted }
        }
        Repeater {
            model: d.weeks * 7
            delegate: Item {
                required property int index
                readonly property date dt: d.cell(index)
                readonly property bool inMonth: dt.getMonth() === d.first.getMonth()
                readonly property bool isToday: dt.toDateString() === d.today.toDateString()
                readonly property bool weekend: dt.getDay() === 0 || dt.getDay() === 6
                width: (d.width - 32) / 7; height: 34
                // every day of the month on a small tile; today pink with an outline (SekaiPop)
                UiCandy { visible: parent.inMonth; anchors.centerIn: parent; width: parent.width - 5; height: 29; radius: 9
                    bw: parent.isToday ? 2.5 : 0; drop: parent.isToday ? 3 : 0; hi: 0; fill: parent.isToday ? Theme.gActive : Theme.sand
                    rotation: parent.isToday ? -3 : 0 }
                UiText { anchors.centerIn: parent; text: parent.dt.getDate(); px: 15; w: 700
                    color: !parent.inMonth ? Theme.textSoft : parent.isToday ? Theme.textDeep : parent.weekend ? Theme.berry : Theme.text
                    opacity: parent.inMonth ? 1 : 0.45 }
            }
        }
    }
}
