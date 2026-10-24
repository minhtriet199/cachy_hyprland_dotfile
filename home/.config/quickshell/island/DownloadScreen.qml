import QtQuick

// Download mode's dim screen (like a phone's always-on screen / Steam Deck's screen-off download): black, a dim clock,
// what's downloading with progress, the newest notifications. Moves a little every minute. No animations (saves power).
Item {
    id: ds
    property var svc
    readonly property var d: svc.download
    function size(b) { return b >= 1073741824 ? (b / 1073741824).toFixed(1) + " GB" : b >= 1048576 ? Math.round(b / 1048576) + " MB" : Math.round(b / 1024) + " KB" }
    function rate(b) { return b >= 1048576 ? (b / 1048576).toFixed(1) + " MB/s" : Math.round(b / 1024) + " KB/s" }
    readonly property string status: d.items.length ? "" : d.speed > 150000 ? "Downloading · " + rate(d.speed)
                                   : !d.saw ? "Waiting for a download to start…" : "Finishing up… done in " + Math.max(0, 60 - d.quiet) + " s"
    property date now: new Date()
    property point drift: Qt.point(0, 0)
    Timer { interval: 60000 - new Date().getSeconds() * 1000; running: ds.visible; repeat: true; triggeredOnStart: true
        onTriggered: { interval = 60000; ds.now = new Date(); ds.drift = Qt.point(Math.random() * 80 - 40, Math.random() * 60 - 30) } }
    Timer { interval: 5000; running: ds.visible; repeat: true; onTriggered: ds.now = new Date() }     // battery / clock

    Column {
        x: (ds.width - width) / 2 + ds.drift.x; y: ds.height * 0.16 + ds.drift.y; width: Math.min(560, ds.width - 80); spacing: 6
        UiText { anchors.horizontalCenter: parent.horizontalCenter; text: Qt.formatTime(ds.now, ds.svc.h24 ? "HH:mm" : "h:mm AP"); px: 120; w: 300; color: "#FFFFFF"; opacity: 0.55 }
        UiText { anchors.horizontalCenter: parent.horizontalCenter; fam: "n"; px: 16; w: 700; color: "#FFFFFF"; opacity: 0.4
            text: Qt.formatDate(ds.now, "dddd, d MMMM") + "  ·  " + ds.svc.battery.percent + "%" + (ds.svc.battery.plugged ? " ⚡" : "") }
        Item { width: 1; height: 44 }
        UiText { fam: "n"; px: 12; w: 900; track: 2; color: "#FFFFFF"; opacity: 0.35; text: "DOWNLOAD MODE" }
        Item { width: 1; height: 4 }
        // what's downloading
        Repeater {
            model: ds.d.items.slice(0, 4)
            delegate: Column {
                required property var modelData
                width: parent.width; spacing: 5
                Item { width: parent.width; height: 22
                    UiText { width: parent.width - 150; elide: Text.ElideRight; text: modelData.name; px: 17; w: 700; color: "#FFFFFF"; opacity: 0.6 }
                    UiText { anchors.right: parent.right; fam: "n"; px: 13; w: 800; color: "#FFFFFF"; opacity: 0.45
                        text: modelData.total ? Math.floor(modelData.done / modelData.total * 100) + "%" : ds.size(modelData.done) } }
                Rectangle { width: parent.width; height: 6; radius: 3; color: Qt.rgba(1, 1, 1, 0.12)
                    // no total known (browser files): a dim full bar just says "in progress"
                    Rectangle { width: parent.width * (modelData.total ? modelData.done / modelData.total : 1); height: parent.height; radius: 3
                        color: Theme.sea; opacity: modelData.total ? 0.6 : 0.2 } }
                UiText { fam: "n"; px: 12; w: 800; color: "#FFFFFF"; opacity: 0.35; height: 22
                    text: modelData.installing ? modelData.app + "  ·  Installing…" : modelData.app + (modelData.total ? "  ·  " + ds.size(modelData.done) + " of " + ds.size(modelData.total) : "") + "  ·  " + ds.rate(modelData.rate !== undefined ? modelData.rate : ds.d.speed) }
            }
        }
        UiText { visible: ds.status !== ""; fam: "n"; px: 15; w: 800; color: "#FFFFFF"; opacity: 0.45; text: ds.status }
        Item { width: 1; height: 36 }
        // newest notifications
        Repeater {
            model: ds.svc.notifications.slice(0, 3)
            delegate: UiText {
                required property var modelData
                width: parent.width; elide: Text.ElideRight; fam: "n"; px: 13; w: 700; color: "#FFFFFF"; opacity: 0.35
                text: modelData.app + "  ·  " + modelData.body
            }
        }
    }
    UiText { anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 36 + ds.drift.y / 3
        fam: "n"; px: 12; w: 800; color: "#FFFFFF"; opacity: 0.22
        text: "Press any key or move the mouse to use the PC  ·  turns itself off when the download is done" }
}
