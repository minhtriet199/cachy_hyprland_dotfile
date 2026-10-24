import QtQuick

// Quick panel chips, like a phone's quick tiles: the ones you picked (Prefs.quickChips), 2 × 3 per page; more → next page
// (wheel / touchpad sideways, or the dots). Click: open its settings page (or switch it when it has none) · right-click: switch it.
// editing (pencil button): one extra row = the tray of chips you don't use (scrolls sideways). Drag a chip to move it
// (hold it at the left / right edge to change page), drag it down into the tray to remove it, drag one up to add it;
// tapping a chip moves it across too. Saved on every drop.
Item {
    id: qc
    property var svc
    property bool editing: false
    signal go(string screen)
    readonly property int columns: 2
    readonly property int perPage: 6
    readonly property real gap: 10
    readonly property real tw: (width - gap) / 2
    readonly property real th: 50
    readonly property var all: ["wifi", "bt", "sound", "warp", "airplane", "night", "dnd", "mic", "awake", "game", "power", "ime", "theme", "location", "hotspot"]
    // order while editing (live as you drag), else the saved one
    property var work: []
    readonly property var picked: editing ? work : (Prefs.quickChips || []).filter(c => all.includes(c))
    readonly property var spare: all.filter(c => !picked.includes(c))
    onEditingChanged: { if (editing) work = (Prefs.quickChips || []).filter(c => all.includes(c)); dragId = ""; page = Math.min(page, pages - 1) }

    function info(id) {
        const s = svc;
        switch (id) {
        case "wifi": return { glyph: "wifi", title: "Wi-Fi", on: s.wifi.on, sub: s.wifi.on ? (s.wifi.ssid || "On") : "Off", page: "settingsWifi", flip: "wifi" };
        case "bt": return { glyph: "bluetooth", title: "Bluetooth", on: s.bluetooth.on, sub: s.bluetooth.on ? (s.bluetooth.name || "On") : "Off", page: "settingsBt", flip: "bt" };
        case "sound": return { glyph: s.muted ? "mute" : "volume", title: "Sound", on: !s.muted, page: "settingsSound", flip: "mute",
                               sub: Math.round(s.volume * 100) + "% · mic " + (s.micOn ? Math.round(s.micVolume * 100) + "%" : "off") };
        case "warp": return { glyph: "cloud", title: "Cloudflare WARP", on: s.warp.connected, sub: s.warp.connected ? "Connected" : "Disconnected", page: "", flip: "warp" };
        case "airplane": return { glyph: "plane", title: "Airplane mode", on: s.airplane, sub: "", page: "", flip: "airplane" };
        case "night": return { glyph: "moon", title: "Night light", on: s.nightLight, sub: "", page: "", flip: "night" };
        case "dnd": return { glyph: s.dnd ? "bellOff" : "bell", title: "Do not disturb", on: s.dnd, sub: "", page: "", flip: "dnd" };
        case "mic": return { glyph: "mic", title: "Microphone", on: s.micOn, sub: s.micOn ? Math.round(s.micVolume * 100) + "%" : "Muted", page: "", flip: "mic" };
        case "awake": return { glyph: "eye", title: "Keep awake", on: s.keepAwake, sub: "", page: "", flip: "awake" };
        case "game": return { glyph: "gamepad", title: "Game mode", on: s.gameMode, sub: "", page: "", flip: "game" };
        case "power": return { glyph: "bolt", title: "Power mode", on: s.powerProfile !== "Quiet", page: "settingsPower", flip: "power",
                               sub: ({ Quiet: "Silent", Balanced: "Performance", Performance: "Turbo" })[s.powerProfile] || "…" };
        case "ime": return { glyph: "keyboard", title: "Typing", on: s.imeVi, sub: s.imeVi ? "Vietnamese" : "English", page: "", flip: "ime" };
        case "theme": return { glyph: Prefs.dark ? "moon" : "sun", title: "Dark mode", on: Prefs.dark, sub: "", page: "", flip: "theme" };
        case "hotspot": { const n = parseInt((s.hotspotInfo || {}).clients) || 0
            return { glyph: "wifiArcs", title: "Hotspot", on: s.hotspot, sub: s.busyIds.includes("hotspot") ? "Starting…" : s.hotspot ? n + " device" + (n === 1 ? "" : "s") : "Off", page: "settingsWifi", flip: "hotspot" } }
        case "location": return { glyph: "crosshair", title: "Location", on: Prefs.location, sub: "", page: "settingsPrivacy", flip: "location" };
        }
        return { glyph: "box", title: id, on: false, sub: "", page: "", flip: "" };
    }
    function flip(d) {
        if (d.flip === "power") { const o = ["Quiet", "Balanced", "Performance"]; svc.setProfile(o[(o.indexOf(svc.powerProfile) + 1) % 3]) }   // Silent → Performance → Turbo
        else if (d.flip === "theme") { const v = !Prefs.dark; Prefs.set("dark", v); Prefs.set("appsDark", v) }                                  // Island + apps together
        else if (d.flip === "location") Prefs.set("location", !Prefs.location);
        else if (d.flip) svc.toggle(d.flip)
    }

    // ── layout: pages of 2 × 3 · dots · (editing) the tray row ──
    property int page: 0
    readonly property int pages: Math.max(1, Math.ceil(picked.length / perPage))
    onPagesChanged: if (page > pages - 1 && dragId === "") page = pages - 1
    // as many rows as the chips need (1 – 3; none = no grid); editing keeps room for one more chip to drop in
    readonly property int rows: Math.min(3, Math.ceil((picked.length + (editing && !work.includes(dragId) ? 1 : 0)) / columns))
    readonly property real gridH: rows ? rows * (th + gap) - gap : 0
    readonly property bool dots: pages > 1 || editing
    readonly property real trayTop: gridH + (dots ? 22 : 0)
    height: trayTop + (editing ? th + 4 : 0) - (dots && !editing ? 4 : 0)
    function slot(id) {
        const i = picked.indexOf(id), k = i % perPage, p = Math.floor(i / perPage);
        return Qt.point((p - page) * (width + 24) + (k % columns) * (tw + gap), Math.floor(k / columns) * (th + gap))
    }
    WheelHandler {
        enabled: qc.pages > 1; acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        property real acc: 0
        onWheel: e => { acc += Math.abs(e.angleDelta.x) > Math.abs(e.angleDelta.y) ? -e.angleDelta.x : -e.angleDelta.y
            if (Math.abs(acc) >= 120) { qc.page = Math.max(0, Math.min(qc.pages - 1, qc.page + (acc > 0 ? 1 : -1))); acc = 0 } }
    }

    // ── dragging (one drag at a time; the pointer is followed by the chip's grid delegate) ──
    property string dragId: ""
    // the tray keeps its chips while one is dragged (else the dragged chip's tray spot — and its drag — would vanish)
    property var trayModel: []
    onSpareChanged: if (dragId === "") trayModel = spare
    onDragIdChanged: if (dragId === "") trayModel = spare
    Component.onCompleted: trayModel = spare
    property point dragAt: Qt.point(0, 0)          // pointer, in qc coordinates
    function hover(id, p) {
        dragAt = p;
        const w = work.filter(c => c !== id);
        edgeFlip.dir = p.y < gridH + gap && qc.pages + (work.includes(id) ? 0 : 1) > 1 ? (p.x < 14 ? -1 : p.x > width - 14 ? 1 : 0) : 0;
        if (p.y < gridH + gap) {      // over the grid: put it at that spot on this page (the others slide)
            const col = Math.max(0, Math.min(columns - 1, Math.floor(p.x / (tw + gap)))), row = Math.max(0, Math.min(rows - 1, Math.floor(p.y / (th + gap))));
            w.splice(Math.min(w.length, page * perPage + row * columns + col), 0, id);
        }                              // below: back to the tray
        if (w.join() !== work.join()) work = w;
    }
    function drop() { dragId = ""; edgeFlip.dir = 0; save() }
    function moveAcross(id) { work = work.includes(id) ? work.filter(c => c !== id) : work.concat([id]); save() }
    function save() { Prefs.set("quickChips", work.slice()) }
    Timer {      // holding a chip at the edge turns the page
        id: edgeFlip; property int dir: 0; interval: 550; repeat: true; running: dir !== 0
        onTriggered: { const n = Math.max(0, Math.min(qc.pages, qc.page + dir)); if (n !== qc.page && n * qc.perPage <= qc.work.length) { qc.page = n; qc.hover(qc.dragId, qc.dragAt) } }
    }

    // grid chips: one delegate per chip, never rebuilt while you drag
    Repeater {
        model: qc.all
        delegate: Item {
            id: cell
            required property string modelData
            required property int index
            readonly property var d: qc.info(modelData)
            readonly property bool held: qc.dragId === modelData
            readonly property bool inGrid: qc.picked.includes(modelData)
            readonly property point at: inGrid ? qc.slot(modelData) : Qt.point(0, 0)
            readonly property bool here: inGrid && Math.floor(qc.picked.indexOf(modelData) / qc.perPage) === qc.page   // on the page you're looking at
            visible: held || (inGrid && opacity > 0)
            opacity: held || here ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 160 } }
            width: qc.tw; height: qc.th; z: held ? 10 : 0
            x: held ? qc.dragAt.x - width / 2 : at.x
            y: held ? qc.dragAt.y - height / 2 : at.y
            Behavior on x { enabled: !cell.held && cell.inGrid; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            Behavior on y { enabled: !cell.held && cell.inGrid; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            scale: held ? 1.06 : 1
            Behavior on scale { NumberAnimation { duration: 120 } }
            rotation: qc.editing && !held ? (index % 2 ? 1.2 : -1.2) : 0      // editing: a slight tilt, like a phone's edit mode
            PhoneToggleTile {
                width: parent.width; glyph: cell.d.glyph; title: cell.d.title; sub: cell.d.sub; on: cell.d.on
                onClicked: cell.d.page ? qc.go(cell.d.page) : qc.flip(cell.d)
                onRightClicked: qc.flip(cell.d)
            }
            UiCandy {      // − badge
                visible: qc.editing && !cell.held
                x: parent.width - 18; y: -6; width: 22; height: 22; radius: 11; bw: 2; drop: 0; hi: 0; ink: Theme.inkPhone; fill: Theme.paper
                Glyph { anchors.centerIn: parent; name: "minus"; size: 12; stroke: 3 }
            }
            MouseArea {      // editing: drag / tap (covers the chip, so it doesn't switch anything)
                anchors.fill: parent; anchors.margins: -4
                enabled: qc.editing
                cursorShape: cell.held ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                property point down
                property bool dragged: false          // a drag's release is not a tap
                onPressed: m => { down = Qt.point(m.x, m.y); dragged = false }
                onPositionChanged: m => { if (!cell.held && !dragged && Math.hypot(m.x - down.x, m.y - down.y) > 5) { dragged = true; qc.dragId = cell.modelData }
                    if (cell.held) qc.hover(cell.modelData, mapToItem(qc, m.x, m.y)) }
                onReleased: if (cell.held) qc.drop()
                onCanceled: if (cell.held) qc.drop()
                onClicked: if (!dragged) qc.moveAcross(cell.modelData)
            }
        }
    }

    // page dots
    Row {
        visible: qc.dots
        anchors.horizontalCenter: parent.horizontalCenter; y: qc.gridH + 8; spacing: 6
        Repeater {
            model: qc.pages + (qc.editing && qc.picked.length % qc.perPage === 0 && qc.picked.length ? 1 : 0)   // editing: a free page to drop onto
            delegate: Rectangle {
                required property int index
                width: index === qc.page ? 16 : 7; height: 7; radius: 4
                color: index === qc.page ? Theme.inkPhone : Theme.textSoft; opacity: index === qc.page ? 1 : 0.5
                Behavior on width { NumberAnimation { duration: 160 } }
                MouseArea { anchors.fill: parent; anchors.margins: -5; onClicked: qc.page = parent.index }
            }
        }
    }

    // editing: the tray — chips you don't use, one row, scrolls sideways
    ListView {
        id: tray
        visible: qc.editing
        y: qc.trayTop; width: qc.width; height: qc.th + 4
        orientation: ListView.Horizontal; spacing: qc.gap; clip: true; boundsBehavior: Flickable.StopAtBounds
        interactive: false
        model: qc.trayModel
        WheelHandler { onWheel: e => tray.contentX = Math.max(0, Math.min(Math.max(0, tray.contentWidth - tray.width), tray.contentX - (e.angleDelta.x || e.angleDelta.y) / 2)) }
        header: Item { width: 0; height: 1 }
        delegate: Item {
            id: tc
            required property string modelData
            readonly property var d: qc.info(modelData)
            width: qc.tw * 0.8; height: qc.th + 4
            opacity: qc.dragId === modelData ? 0 : 0.85
            PhoneToggleTile { y: 4; width: parent.width; glyph: tc.d.glyph; title: tc.d.title; sub: "Add"; on: false }
            UiCandy {      // + badge
                x: parent.width - 18; y: -2; width: 22; height: 22; radius: 11; bw: 2; drop: 0; hi: 0; ink: Theme.inkPhone; fill: Theme.gOn
                Glyph { anchors.centerIn: parent; name: "plus"; size: 12; stroke: 3 }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: qc.dragId === tc.modelData ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                property point down
                property bool dragged: false
                onPressed: m => { down = Qt.point(m.x, m.y); dragged = false }
                onPositionChanged: m => { if (!dragged && Math.hypot(m.x - down.x, m.y - down.y) > 5) { dragged = true; qc.dragId = tc.modelData }
                    if (qc.dragId === tc.modelData) qc.hover(tc.modelData, mapToItem(qc, m.x, m.y)) }
                onReleased: if (qc.dragId === tc.modelData) qc.drop()
                onCanceled: if (qc.dragId === tc.modelData) qc.drop()
                onClicked: if (!dragged) qc.moveAcross(tc.modelData)
            }
        }
    }
    // the tray is empty: say so
    UiText { visible: qc.editing && !qc.spare.length; anchors.horizontalCenter: parent.horizontalCenter; y: qc.trayTop + qc.th / 2 - 8
        text: "All chips are in use"; fam: "n"; px: 11; w: 800; color: Theme.textSoft }
}
