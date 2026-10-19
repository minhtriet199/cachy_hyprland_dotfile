import QtQuick

// Calendar card (bar dropdown), SekaiPop-style: "2026 · Week 42" over a big month name, ‹ ›, month grid
// (today lilac, Sundays berry, a dot under days with notes).
// Scroll or ‹ › to change month. Click the title to zoom out: month → the year's 12 months → 12 years; click a tile to go back in.
// Click a day → its hours: click an hour to write a note (text + a picture from the clipboard or a file),
// click a note to change it.
// At that time you get a bubble that stays until clicked (Services.schedule / SvcSchedule.qml).
DropCard {
    id: d
    property var svc
    readonly property var sch: svc.schedule
    property int offset: 0                       // months from now
    property string day: ""                      // "2026-10-20" = day view
    property string zoom: "month"                // month · year (12 months) · years (12 years)
    readonly property int year: first.getFullYear()
    readonly property int yearsFrom: Math.floor(year / 12) * 12
    function goMonth(y, m) { offset = (y - today.getFullYear()) * 12 + m - today.getMonth(); zoom = "month" }
    function step(n) { if (day) shiftDay(n); else offset += n * (zoom === "years" ? 144 : zoom === "year" ? 12 : 1) }
    readonly property date today: svc.now
    readonly property date first: new Date(today.getFullYear(), today.getMonth() + offset, 1)
    readonly property var months: ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    readonly property var wdays: ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    readonly property int weeks: Math.ceil((first.getDay() + new Date(first.getFullYear(), first.getMonth() + 1, 0).getDate()) / 7)
    readonly property date dayDate: { const p = day.split("-").map(Number); return day ? new Date(p[0], p[1] - 1, p[2]) : today }
    width: 340; height: day ? 136 + 312 + (compose.visible ? compose.height + 10 : 0) : zoom !== "month" ? 110 + 4 * 54 + 10 : 136 + 30 + weeks * 34 + 14
    headerH: 96

    function isoWeek(dt) {
        const t = new Date(Date.UTC(dt.getFullYear(), dt.getMonth(), dt.getDate()));
        const day = t.getUTCDay() || 7; t.setUTCDate(t.getUTCDate() + 4 - day);
        return Math.ceil(((t - new Date(Date.UTC(t.getUTCFullYear(), 0, 1))) / 86400000 + 1) / 7);
    }
    function cell(i) { return new Date(first.getFullYear(), first.getMonth(), 1 - first.getDay() + i) }
    function shiftDay(n) { const x = new Date(dayDate); x.setDate(x.getDate() + n); day = sch.key(x); compose.hour = -1 }
    function two(n) { return String(n).padStart(2, "0") }

    WheelHandler { enabled: !d.day; onWheel: e => d.step(e.angleDelta.y > 0 ? -1 : 1) }

    // ── header: month (or the day you opened) + ‹ › ──
    Item {
        x: 24; y: 18; width: 210; height: 66
        UiText { color: Theme.textDeep; fam: "n"; px: 12; w: 900; track: 1
            text: d.day ? d.wdays[d.dayDate.getDay()] + " · Week " + d.isoWeek(d.dayDate)
                : d.zoom === "years" ? "Pick a year" : d.zoom === "year" ? "Pick a month · click for years"
                : d.year + (d.offset === 0 ? " · Week " + d.isoWeek(d.today) : "") + " · click for the year" }
        UiStrokeText { y: 18; text: d.day ? d.months[d.dayDate.getMonth()].slice(0, 3) + " " + d.dayDate.getDate()
                : d.zoom === "years" ? d.yearsFrom + "–" + (d.yearsFrom + 11) : d.zoom === "year" ? d.year : d.months[d.first.getMonth()]
            px: 34; weight: 700; strokeW: 6; strokeColor: Theme.ink }
        // zoom out: day → month → year → years
        MouseArea { anchors.fill: parent; cursorShape: d.zoom !== "years" || d.day ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: { if (d.day) d.day = ""; else if (d.zoom === "month") d.zoom = "year"; else d.zoom = "years" } }
    }
    // back to this month (small chip in the corner, so the title keeps its room)
    UiCandy { visible: !d.day && (d.offset !== 0 || d.zoom !== "month"); x: d.width - width - 24; y: 15; width: tl.implicitWidth + 16; height: 20; radius: 10
        bw: 2; drop: 0; hi: 0; fill: Theme.paper; pressable: true; onClicked: { d.offset = 0; d.zoom = "month" }
        UiText { id: tl; anchors.centerIn: parent; text: "Today"; px: 11; w: 700 } }
    Row {
        x: d.width - width - 24; y: 42; spacing: 6
        Repeater {
            model: ["prev", "next"]
            delegate: UiCandy {
                required property string modelData
                width: 32; height: 32; radius: 16; bw: 2.5; drop: 2; hi: 0; fill: Theme.paper; pressable: true
                onClicked: d.step(modelData === "prev" ? -1 : 1)
                Glyph { anchors.centerIn: parent; name: "arrowRight"; rotation: modelData === "prev" ? 180 : 0; size: 14; stroke: 2.6 }
            }
        }
    }

    // ── year (12 months) or years (12 years): big tiles, now highlighted, a dot where there are notes ──
    Grid {
        visible: !d.day && d.zoom !== "month"
        x: 16; y: 112; columns: 3; rowSpacing: 6; columnSpacing: 6
        Repeater {
            model: 12
            delegate: UiCandy {
                id: tile
                required property int index
                readonly property bool yrs: d.zoom === "years"
                readonly property string pre: yrs ? String(d.yearsFrom + index) : d.year + "-" + d.two(index + 1)
                readonly property bool isNow: yrs ? d.yearsFrom + index === d.today.getFullYear()
                                                  : d.year === d.today.getFullYear() && index === d.today.getMonth()
                readonly property bool noted: d.sch.notes.some(n => n.date.startsWith(pre))
                width: (d.width - 32 - 12) / 3; height: 48; radius: 12
                bw: isNow ? 2.5 : 0; drop: isNow ? 3 : 0; hi: 0; fill: isNow ? Theme.gActive : Theme.sand
                rotation: isNow ? -2 : 0; pressable: true
                onClicked: yrs ? (d.offset += (d.yearsFrom + index - d.year) * 12, d.zoom = "year") : d.goMonth(d.year, index)
                UiText { anchors.centerIn: parent; anchors.verticalCenterOffset: tile.noted ? -3 : 0
                    text: tile.yrs ? d.yearsFrom + tile.index : d.months[tile.index].slice(0, 3); px: 17; w: 700
                    color: tile.isNow ? Theme.textDeep : Theme.text }
                Rectangle { visible: tile.noted; anchors.horizontalCenter: parent.horizontalCenter; y: 36; width: 5; height: 5; radius: 2.5; color: Theme.berry }
            }
        }
    }

    // ── month grid ──
    Grid {
        visible: !d.day && d.zoom === "month"
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
                readonly property bool noted: !!d.sch.days[d.sch.key(dt)]
                width: (d.width - 32) / 7; height: 34
                // every day of the month on a small tile; today pink with an outline (SekaiPop)
                UiCandy { visible: parent.inMonth; anchors.centerIn: parent; width: parent.width - 5; height: 29; radius: 9
                    bw: parent.isToday ? 2.5 : 0; drop: parent.isToday ? 3 : 0; hi: 0; fill: parent.isToday ? Theme.gActive : Theme.sand
                    rotation: parent.isToday ? -3 : 0; pressable: true; onClicked: { d.day = d.sch.key(parent.dt); compose.hour = -1 } }
                UiText { anchors.centerIn: parent; anchors.verticalCenterOffset: parent.noted ? -2 : 0; text: parent.dt.getDate(); px: 15; w: 700
                    color: !parent.inMonth ? Theme.textSoft : parent.isToday ? Theme.textDeep : parent.weekend ? Theme.berry : Theme.text
                    opacity: parent.inMonth ? 1 : 0.45 }
                Rectangle { visible: parent.noted; anchors.horizontalCenter: parent.horizontalCenter; y: 25; width: 5; height: 5; radius: 2.5; color: Theme.berry }
            }
        }
    }

    // ── day: 24 hours, notes in their hour; click an hour to write one ──
    Flickable {
        id: hours
        visible: !!d.day
        x: 14; y: 108; width: d.width - 28; height: 300
        contentHeight: hourCol.height; clip: true; boundsBehavior: Flickable.StopAtBounds
        // open on the hour it is now (today) or 8:00
        function home() { contentY = Math.min(Math.max(0, contentHeight - height), Math.max(0, (d.day === d.sch.key(d.today) ? d.today.getHours() : 8) * 44 - 8)) }
        Connections { target: d; function onDayChanged() { if (d.day) Qt.callLater(hours.home) } }
        Component.onCompleted: if (d.day) Qt.callLater(home)
        Column {
            id: hourCol
            width: parent.width; spacing: 4
            Repeater {
                model: 24
                delegate: UiCandy {
                    id: hr
                    required property int index
                    readonly property var list: d.sch.onDay(d.day).filter(n => n.hour === index)
                    readonly property bool now: d.day === d.sch.key(d.today) && d.today.getHours() === index
                    width: hourCol.width; height: Math.max(40, noteCol.implicitHeight + 12); radius: 12
                    bw: compose.hour === index || now ? 2.5 : 0; drop: 0; hi: 0
                    fill: compose.hour === index ? Theme.gSun : now ? Theme.gActive : list.length ? Theme.cream : Theme.sand
                    pressable: true; onClicked: compose.open(index, null)
                    UiText { x: 10; y: 11; text: d.two(hr.index) + ":00"; px: 14; w: 700; color: hr.list.length || hr.now ? Theme.textDeep : Theme.textSoft }
                    Column {
                        id: noteCol
                        x: 66; y: 6; width: parent.width - 74; spacing: 4
                        Repeater {
                            model: hr.list
                            delegate: UiCandy {
                                required property var modelData
                                width: noteCol.width; height: Math.max(28, nt.implicitHeight + 10); radius: 9; bw: 2; drop: 2; hi: 0
                                fill: compose.editId === modelData.id ? Theme.gSun : Theme.paper; pressable: true; onClicked: compose.open(hr.index, modelData)
                                Image { id: th; visible: !!modelData.image; x: 4; anchors.verticalCenter: parent.verticalCenter; width: visible ? 34 : 0; height: 22
                                    source: modelData.image ? "file://" + modelData.image : ""; fillMode: Image.PreserveAspectCrop; sourceSize.width: 80; asynchronous: true }
                                UiText { id: nt; x: th.width + 8; anchors.verticalCenter: parent.verticalCenter; width: parent.width - x - 30
                                    text: (modelData.min ? ":" + d.two(modelData.min) + "  " : "") + (modelData.text || "Picture"); fam: "n"; px: 12; w: 800
                                    wrapMode: Text.Wrap; maximumLineCount: 3; elide: Text.ElideRight; color: Theme.text }
                                UiCandy { anchors.right: parent.right; anchors.rightMargin: 4; anchors.verticalCenter: parent.verticalCenter
                                    width: 20; height: 20; bw: 1.5; drop: 0; hi: 0; fill: Theme.cream; pressable: true; onClicked: d.sch.remove(modelData.id)
                                    Glyph { anchors.centerIn: parent; name: "close"; size: 9; stroke: 2.8 } }
                            }
                        }
                    }
                }
            }
        }
    }

    // ── writing a note for the picked hour: minutes, text, picture, Add ──
    UiCandy {
        id: compose
        property int hour: -1
        property int min: 0
        property string image: ""
        property string editId: ""                   // changing this note instead of adding one
        function open(h, note) { hour = h; editId = note ? note.id : ""; min = note ? note.min : 0; image = note ? note.image : ""
            noteIn.text = note ? note.text : ""; minIn.text = d.two(min); noteIn.forceActiveFocus(); noteIn.cursorPosition = noteIn.length }
        function add() { if (hour < 0) return
            if (editId) d.sch.update(editId, hour, min, noteIn.text, image); else d.sch.add(d.day, hour, min, noteIn.text, image)
            hour = -1; editId = "" }
        visible: !!d.day && hour >= 0
        x: 14; y: 108 + 300 + 10; width: d.width - 28; height: compCol.implicitHeight + 20
        radius: 14; bw: 2.5; drop: 3; hi: 0; fill: Theme.cream
        Connections { target: d.sch; function onPicked(p) { compose.image = p } }
        Column {
            id: compCol
            x: 10; y: 10; width: parent.width - 20; spacing: 8
            Row {
                spacing: 4
                UiText { text: d.two(compose.hour) + " :"; px: 16; w: 700; color: Theme.textDeep; anchors.verticalCenter: parent.verticalCenter }
                // minutes: type 0–59
                UiCandy {
                    width: 46; height: 28; radius: 8; bw: 2; drop: 0; hi: 0; fill: minIn.activeFocus ? Theme.cream : Theme.paper
                    TextInput { id: minIn; anchors.centerIn: parent; width: parent.width - 10; horizontalAlignment: TextInput.AlignHCenter
                        font.family: Theme.display; font.weight: 700; font.pixelSize: 15; color: Theme.textDeep; selectByMouse: true
                        validator: IntValidator { bottom: 0; top: 59 }
                        maximumLength: 2
                        onTextEdited: compose.min = Math.min(59, parseInt(text) || 0)
                        onEditingFinished: text = d.two(compose.min)
                        onActiveFocusChanged: if (activeFocus) selectAll()
                        Keys.onReturnPressed: compose.add()
                        Keys.onEscapePressed: compose.hour = -1 } }
                UiText { text: compose.editId ? "editing" : "min"; fam: "n"; px: 11; w: 800; color: Theme.textSoft; anchors.verticalCenter: parent.verticalCenter; leftPadding: 4 }
            }
            UiCandy {
                width: parent.width; height: Math.max(34, noteIn.contentHeight + 14); radius: 10; bw: 2; drop: 0; hi: 0; fill: Theme.paper
                TextEdit { id: noteIn; x: 9; y: 7; width: parent.width - 18; wrapMode: TextEdit.Wrap
                    font.family: Theme.body; font.weight: 800; font.pixelSize: 13; color: Theme.text
                    Keys.onReturnPressed: e => { if (e.modifiers & Qt.ShiftModifier) e.accepted = false; else compose.add() }
                    Keys.onEscapePressed: compose.hour = -1
                    UiText { visible: !noteIn.text; text: "What's happening? (Shift+Enter = new line)"; fam: "n"; px: 12; w: 800; color: Theme.textSoft } }
            }
            Row {
                spacing: 6
                Image { visible: !!compose.image; width: visible ? 46 : 0; height: 30; source: compose.image ? "file://" + compose.image : ""
                    fillMode: Image.PreserveAspectCrop; sourceSize.width: 120 }
                Repeater { model: [["clipboard", "Paste", () => d.sch.pasteImage()], ["image", "File", () => d.sch.chooseImage()]]
                    delegate: UiCandy { required property var modelData
                        width: bl.implicitWidth + 36; height: 30; radius: 10; bw: 2; drop: 2; hi: 0; fill: Theme.paper; pressable: true; onClicked: modelData[2]()
                        Glyph { x: 8; anchors.verticalCenter: parent.verticalCenter; name: modelData[0]; size: 14; stroke: 2.4 }
                        UiText { id: bl; x: 26; anchors.verticalCenter: parent.verticalCenter; text: modelData[1]; px: 12; w: 700 } } }
                UiCandy { width: 64; height: 30; radius: 10; bw: 2.5; drop: 2; hi: 3; fill: Theme.gGo; pressable: true; onClicked: compose.add()
                    UiText { anchors.centerIn: parent; text: compose.editId ? "Save" : "Add"; px: 13; w: 700; color: "#FFFFFF" } }
            }
        }
    }
}
