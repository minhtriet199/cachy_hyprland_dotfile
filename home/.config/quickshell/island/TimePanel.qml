import QtQuick

// Screen time page (phone). Left: the picked day (total + hour chart) and the last 7 days (click a day).
// Right: that day's top apps (click one to show only its hours, click again for all). Hover a bar for its time.
// Data: tools/screentime-summary.py (archive + live file, same as the Screen Time app).
Item {
    id: tp
    property var svc
    property int dayIdx: 6                    // 6 = today
    property string appId: ""                 // "" = all apps
    property string tip: ""                   // hover text
    readonly property var days: svc.screenTime && svc.screenTime.days ? svc.screenTime.days : []
    readonly property var day: days.length ? days[dayIdx] : null
    readonly property var app: day && appId ? day.apps.find(a => a.id === appId) || null : null
    readonly property var hours: app ? app.hourly : (day ? day.hourly : [])
    readonly property bool narrow: width < 560
    readonly property real colW: narrow ? width : (width - 20) / 2
    readonly property real leftH: 330
    implicitHeight: narrow ? 330 + 20 + 40 + (day ? day.apps.length * 38 : 0) : 300
    Component.onCompleted: svc.loadScreenTime()
    Timer { interval: 60000; running: tp.visible; repeat: true; onTriggered: tp.svc.loadScreenTime() }
    function hm(sec) { const h = Math.floor(sec / 3600), m = Math.round(sec % 3600 / 60); return h ? h + " h " + m + " m" : m + " min" }
    function hourName(h) { return (h % 12 || 12) + (h < 12 ? " AM" : " PM") }

    UiText { visible: !tp.day; text: "Reading screen time…"; fam: "n"; px: 12; w: 800; color: Theme.textSoft }

    // ── left ──
    Column {
        visible: !!tp.day
        width: tp.colW; spacing: 6
        Item {
            width: parent.width; height: 16
            UiText { text: tp.day ? (tp.dayIdx === 6 ? "TODAY" : tp.day.date.toUpperCase()) + (tp.app ? " · " + tp.app.name.toUpperCase() : "") : ""; fam: "n"; px: 11; w: 900; track: 1.4; color: Theme.textSoft; width: parent.width - tipT.width - 8 }
            UiText { id: tipT; anchors.right: parent.right; text: tp.tip; fam: "n"; px: 11; w: 900; color: Theme.purple }
        }
        UiStrokeText { text: tp.day ? tp.hm(tp.app ? tp.app.sec : tp.day.total) : ""; px: 32; weight: 700; strokeW: 6; strokeColor: Theme.inkPhone }
        Row {
            spacing: 2
            Repeater {
                model: tp.hours
                delegate: Item {
                    required property var modelData
                    required property int index
                    width: (tp.colW - 46) / 24; height: 56
                    Rectangle { anchors.bottom: parent.bottom; width: parent.width; radius: 2
                        height: Math.max(2, 52 * Math.min(1, modelData / 3600))
                        color: hov.hovered ? Theme.berry : tp.app ? Theme.purple : Theme.sea
                        Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } } }
                    HoverHandler { id: hov; onHoveredChanged: tp.tip = hovered ? tp.hourName(index) + " · " + tp.hm(modelData) : "" }
                }
            }
        }
        Row { width: tp.colW
            Repeater { model: ["12 AM", "6 AM", "12 PM", "6 PM"]
                delegate: UiText { required property string modelData; width: tp.colW / 4; text: modelData; fam: "n"; px: 9; w: 800; color: Theme.textSoft } } }
        UiText { text: "LAST 7 DAYS · CLICK A DAY"; fam: "n"; px: 11; w: 900; track: 1.4; color: Theme.textSoft; height: 22; verticalAlignment: Text.AlignBottom }
        Row {
            id: weekRow
            spacing: 8
            readonly property real mx: Math.max(3600, ...tp.days.map(w => w.total))
            Repeater {
                model: tp.days
                delegate: Column {
                    required property var modelData
                    required property int index
                    readonly property bool picked: index === tp.dayIdx
                    spacing: 3
                    Item { width: (tp.colW - 48) / 7; height: 60
                        UiCandy {
                            anchors.bottom: parent.bottom; width: parent.width; height: Math.max(10, 60 * modelData.total / weekRow.mx)
                            radius: 6; bw: picked ? 2.5 : 2; drop: picked ? 3 : 0; hi: 0; fill: picked ? Theme.gLilac : Theme.gOn; pressable: true
                            onClicked: { tp.dayIdx = index; tp.appId = "" }
                            onHoveredChanged: tp.tip = hovered ? modelData.date + " · " + tp.hm(modelData.total) : ""
                            Behavior on height { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                        }
                    }
                    UiText { width: (tp.colW - 48) / 7; horizontalAlignment: Text.AlignHCenter; text: modelData.label === "Today" ? "Today" : modelData.label
                        fam: "n"; px: 10; w: 900; color: picked ? Theme.purple : Theme.textSoft; height: 14 }
                }
            }
        }
    }

    // ── right: apps of the picked day ──
    Column {
        visible: !!tp.day
        x: tp.narrow ? 0 : tp.colW + 20; y: tp.narrow ? tp.leftH + 20 : 0; width: tp.colW; spacing: 4
        UiText { text: "TOP APPS · CLICK ONE"; fam: "n"; px: 11; w: 900; track: 1.4; color: Theme.textSoft; height: 16 }
        Repeater {
            model: tp.day ? tp.day.apps : []
            delegate: UiCandy {
                required property var modelData
                required property int index
                readonly property bool picked: tp.appId === modelData.id
                width: tp.colW; height: 34; radius: 10; bw: picked ? 2 : 0; drop: 0; hi: 0
                fill: picked ? Theme.gLilac : (hovered ? Qt.rgba(1, 1, 1, 0.6) : "transparent"); pressable: true
                onClicked: tp.appId = picked ? "" : modelData.id
                UiText { x: 6; y: 3; width: parent.width - 90; height: 15; text: modelData.name; px: 13; w: 700 }
                UiText { anchors.right: parent.right; anchors.rightMargin: 6; y: 3; height: 15; text: tp.hm(modelData.sec); fam: "n"; px: 11; w: 900; color: Theme.textSoft }
                Rectangle { x: 6; y: 22; width: parent.width - 12; height: 7; radius: 4; color: Theme.sand }
                Rectangle { x: 6; y: 22; width: Math.max(6, (parent.width - 12) * modelData.sec / tp.day.apps[0].sec); height: 7; radius: 4
                    color: [Theme.sea, Theme.purple, Theme.berry, Theme.leaf, Theme.sunDeep, Theme.peach, Theme.indigo, Theme.slate, Theme.seaDeep, Theme.orange][index % 10]
                    Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } } }
            }
        }
        UiText { visible: !!tp.day && tp.day.apps.length === 0; text: "Nothing recorded this day"; fam: "n"; px: 12; w: 800; color: Theme.textSoft }
    }
}
