import QtQuick
import Qt.labs.folderlistmodel

// Wallpaper picker on a string (landscape, canvas "Wallpapers"). ←/→ spin · Enter sets it.
Item {
    id: wp
    property var svc
    property var prefs
    property int i: 0
    property string filter: ""
    property bool lockTab: false               // (old name, kept) true when target is Lockscreen
    property string target: "Desktop"          // Desktop · Phone · Lockscreen — what "Set" changes
    readonly property string targetKey: target === "Phone" ? "phoneBg" : target === "Lockscreen" ? "lockWallpaper" : "wallpaper"
    onTargetChanged: lockTab = target === "Lockscreen"
    signal go(string screen)
    signal close()
    signal back()
    signal soon(string what)
    readonly property color ink: Theme.inkPhone
    readonly property color accent: Theme.seaSoft
    readonly property bool narrow: width < 600                     // shown on the upright phone
    readonly property real cx: narrow ? 18 : 54
    readonly property real cw: width - cx - (narrow ? 18 : 24)
    readonly property real topPad: narrow ? 40 : 0                     // below the punch hole
    FolderListModel {
        id: files
        folder: "file://" + wp.prefs.wallDir
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.JPG", "*.PNG"]
        showDirs: false
        sortField: wp.sortMode === "name" || wp.sortMode === "nameDesc" ? FolderListModel.Name : FolderListModel.Time
        sortReversed: wp.sortMode === "oldest" || wp.sortMode === "nameDesc"
    }
    property string sortMode: "newest"
    property bool sortOpen: false
    readonly property var sorts: [["newest", "Newest"], ["oldest", "Oldest"], ["name", "Name A–Z"], ["nameDesc", "Name Z–A"]]
    readonly property var list: {
        const out = []; const f = filter.toLowerCase();
        for (let k = 0; k < files.count; k++) { const n = files.get(k, "fileName"); if (!f || n.toLowerCase().includes(f)) out.push({ name: n, path: files.get(k, "filePath") }) }
        return out;
    }
    readonly property int n: list.length
    readonly property var cur: n ? list[((i % n) + n) % n] : null
    readonly property bool applied: !!cur && cur.path === prefs[targetKey]
    function step(d) { if (n) i = ((i + d) % n + n) % n }
    function apply() { if (cur) prefs.set(targetKey, cur.path) }
    onNChanged: if (i >= n) i = 0

    // header
    Flow {
        x: wp.cx; y: 16 + wp.topPad; width: wp.cw
        spacing: 10
        // back button + title (same as the other Settings pages)
        UiCandy {
            
            width: wtc.implicitWidth + 48 + 14; height: 40; radius: 14; ink: wp.ink; drop: 3; hi: 0; fill: wp.accent; pressable: true
            onClicked: wp.back()
            Rectangle { x: 8; anchors.verticalCenter: parent.verticalCenter; width: 28; height: 28; radius: 10; color: wp.ink
                Rectangle { anchors.fill: parent; anchors.margins: 2; radius: 8; color: Theme.paper }
                Glyph { anchors.centerIn: parent; name: "back"; size: 15; stroke: 3 } }
            Column { id: wtc; x: 44; anchors.verticalCenter: parent.verticalCenter
                UiText { text: "Wallpapers"; px: 18; w: 700; color: wp.ink; height: 19 }
                UiText { text: "Spin the string"; fam: "n"; w: 800; px: 10.5; color: wp.ink; opacity: 0.8 } }
        }
        UiCandy {
            
            width: tabsRow.implicitWidth + 13; height: 34; radius: 12; ink: wp.ink; drop: 0; hi: 0
            Row { id: tabsRow; anchors.centerIn: parent; spacing: 4
                Repeater { model: ["Desktop", "Phone", "Lockscreen"]
                    delegate: Item { required property string modelData; required property int index
                        readonly property bool on: wp.target === modelData
                        width: tl.implicitWidth + 24; height: 24
                        UiCandy { anchors.fill: parent; visible: parent.on; radius: 8; bw: 2; ink: wp.ink; drop: 0; hi: 0; fill: wp.accent }
                        UiText { id: tl; anchors.centerIn: parent; text: modelData; px: 12; w: parent.on ? 700 : 600 }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: wp.target = modelData } } } }
        }
        UiText { visible: !wp.narrow; text: "Setting the " + wp.target.toLowerCase() + " · " + wp.n + " wallpapers"; fam: "n"; w: 800; px: 11; color: Theme.textSoft }
    }
    Row {
        anchors.right: parent.right; anchors.rightMargin: wp.narrow ? 18 : 24; y: wp.narrow ? 16 + wp.topPad + 92 : 16; height: 36
        spacing: 10
        UiCandy {
            anchors.verticalCenter: parent.verticalCenter
            width: 10 + 14 + 6 + 90 + 10 + 5; height: 32; ink: wp.ink; drop: 0; hi: 0
            Glyph { x: 12.5; anchors.verticalCenter: parent.verticalCenter; name: "search"; size: 14; stroke: 3 }
            TextInput { id: q; x: 12.5 + 14 + 6; width: 90; anchors.verticalCenter: parent.verticalCenter; clip: true
                font.family: Theme.body; font.weight: 800; font.pixelSize: 12; color: Theme.text
                onTextChanged: { wp.filter = text; wp.i = 0 }
                Keys.onEscapePressed: { if (text) text = ""; else wp.forceActiveFocus() }
                UiText { visible: !q.text; text: "Search…"; fam: "n"; w: 800; px: 12; color: Theme.textSoft; anchors.verticalCenter: parent.verticalCenter } }
        }
        UiCandy {
            id: sortBtn
            anchors.verticalCenter: parent.verticalCenter; width: Math.max(nl.implicitWidth + 25, 96); height: 32; radius: 10; ink: wp.ink; drop: 0; hi: 0
            fill: wp.sortOpen ? Theme.gSun : Theme.paper; pressable: true
            onClicked: wp.sortOpen = !wp.sortOpen
            UiText { id: nl; anchors.centerIn: parent; text: wp.sorts.find(s => s[0] === wp.sortMode)[1] + (wp.sortOpen ? " ▴" : " ▾"); px: 12; w: 600 }
            UiCandy {
                // drawn on the screen's top layer (not inside the header row) so nothing shows through it
                parent: wp; z: 100
                visible: wp.sortOpen
                readonly property point at: (wp.sortOpen, sortBtn.mapToItem(wp, 0, sortBtn.height + 6))
                x: at.x; y: at.y; width: sortBtn.width + 20; height: sortCol.implicitHeight + 12; radius: 12; ink: wp.ink; drop: 3; hi: 0; fill: Theme.paper
                Column {
                    id: sortCol; x: 6; y: 6; width: parent.width - 12; spacing: 2
                    Repeater {
                        model: wp.sorts
                        delegate: UiCandy {
                            required property var modelData
                            width: sortCol.width; height: 28; radius: 8; bw: 0; drop: 0; hi: 0
                            fill: modelData[0] === wp.sortMode ? Theme.seaSoft : "transparent"; pressable: true
                            onClicked: { wp.sortMode = modelData[0]; wp.sortOpen = false; wp.i = 0 }
                            UiText { x: 10; anchors.verticalCenter: parent.verticalCenter; text: modelData[1]; px: 12; w: 600 }
                        }
                    }
                }
            }
        }
        UiCandy { width: cl.implicitWidth + 25; height: 34; radius: 11; ink: wp.ink; drop: 0; hi: 0
            UiText { id: cl; anchors.centerIn: parent; text: wp.svc.timeText; px: 13; w: 700 } }

    }

    // string + photos
    Item {
        id: stage
        // drawn for an 800-wide sideways screen; on the upright phone it's scaled down to fit
        scale: Math.min(1, wp.cw / 800); transformOrigin: Item.TopLeft
        x: wp.cx; y: 16 + wp.topPad + (wp.narrow ? 170 : 36 + 4); width: wp.cw / scale; height: (wp.height - y - 14 - 87 - 4) / scale
        Canvas {
            x: 10; y: 4; width: 780; height: 80
            onPaint: { const g = getContext("2d"); g.reset(); g.strokeStyle = wp.ink; g.lineWidth = 4; g.lineCap = "round"
                g.beginPath(); g.moveTo(10, 70); g.quadraticCurveTo(390, -30, 770, 70); g.stroke() }
        }
        // the string: quadratic curve (10,70) → ctrl (390,-30) → (770,70) in the Canvas (which sits at 10,4)
        function stringY(xs) { const t = Math.max(0, Math.min(1, (xs - 20) / 760)); return (1 - t) * (1 - t) * 70 + 2 * (1 - t) * t * -30 + t * t * 70 + 4 }
        function stringAngle(xs) { const t = Math.max(0, Math.min(1, (xs - 20) / 760)); return Math.atan2(-200 * (1 - t) + 200 * t, 760) * 180 / Math.PI }
        property real sway: 0
        SequentialAnimation on sway { loops: Animation.Infinite
            NumberAnimation { from: -1; to: 1; duration: 2200; easing.type: Easing.InOutSine } NumberAnimation { from: 1; to: -1; duration: 2200; easing.type: Easing.InOutSine } }
        Repeater {
            model: [[-2, 18, 230, 120, 86, -9], [-1, 136, 140, 150, 106, -5], [0, 302, 70, 190, 132, 0], [1, 512, 140, 150, 106, 5], [2, 650, 230, 120, 86, 9]]
            delegate: Item {
                id: card
                required property var modelData
                readonly property int off: modelData[0]
                readonly property var pic: wp.n ? wp.list[(((wp.i + off) % wp.n) + wp.n) % wp.n] : null
                readonly property real pinX: modelData[1] + modelData[3] / 2
                // clip sits on the string; the photo hangs below it, tilted with the string and swaying a little
                x: modelData[1]; y: stage.stringY(pinX) - 9
                width: modelData[3]; height: 16 + modelData[4]
                rotation: stage.stringAngle(pinX) * 0.8 + stage.sway * (1.6 - Math.abs(off) * 0.3) * (off % 2 ? -1 : 1)
                transformOrigin: Item.Top
                z: 10 - Math.abs(off)
                visible: wp.n > 0 && (wp.n >= 5 || Math.abs(off) <= Math.floor(wp.n / 2))
                UiCandy {
                    id: photo
                    y: 16; width: card.width; height: card.modelData[4]
                    radius: 12; ink: wp.ink; bw: card.off === 0 ? 4 : 3; drop: card.off === 0 ? 7 : 4; hi: 0
                    fill: "#DDF4FA"; pressable: true
                    onClicked: card.off === 0 ? wp.apply() : wp.step(card.off)
                    Image {
                        x: photo.bw; y: photo.bw; width: photo.width - 2 * photo.bw; height: photo.height - 2 * photo.bw
                        source: card.pic ? "file://" + card.pic.path : ""
                        sourceSize: Qt.size(width * 2, height * 2); fillMode: Image.PreserveAspectCrop; asynchronous: true; smooth: true
                        layer.enabled: false
                    }
                    Rectangle { visible: card.off === 0; x: photo.bw; y: photo.bw; width: photo.width - 2 * photo.bw; height: photo.height - 2 * photo.bw
                        radius: 8; color: "transparent"; border.width: 6; border.color: Theme.paper }
                }
                Rectangle { anchors.horizontalCenter: parent.horizontalCenter; width: 14; height: 22; radius: 4; color: card.off === 0 ? Theme.sun : Theme.paper; border.width: 2; border.color: wp.ink }
            }
        }
        UiText { visible: wp.n === 0; anchors.centerIn: parent; horizontalAlignment: Text.AlignHCenter; fam: "n"; w: 800; px: 13; color: Theme.textSoft
            text: "No pictures in " + wp.prefs.wallDir + "\nPut some wallpapers there and come back ✿" }
    }

    // caption + actions
    Column {
        anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: wp.narrow ? 70 : 14
        spacing: 6
        UiStrokeText { anchors.horizontalCenter: parent.horizontalCenter; text: wp.cur ? wp.cur.name : "—"; px: 18; strokeW: 5; strokeColor: wp.ink }
        UiCandy { anchors.horizontalCenter: parent.horizontalCenter; width: il.implicitWidth + 24; height: 19; bw: 2; ink: wp.ink; drop: 0; hi: 0
            UiText { id: il; anchors.centerIn: parent; text: (wp.n ? wp.i + 1 : 0) + " / " + wp.n; px: 11; w: 700 } }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter; spacing: 10; height: 40
            WpButton { text: "‹ Previous"; h: 30; onClicked: wp.step(-1) }
            WpButton { text: wp.applied ? "✓ Applied" : "Set as " + wp.target; h: 36; bold: true; drop: 3; fill: wp.applied ? wp.accent : Theme.paper; onClicked: wp.apply() }
            WpButton { text: "Next ›"; h: 30; onClicked: wp.step(1) }
            WpButton { visible: !wp.narrow; text: wp.svc.pasteMsg || "📋 Paste image"; h: 30; onClicked: wp.svc.pasteWallpaper() }
        }
        Row {   // upright phone: paste goes on its own line
            visible: wp.narrow; anchors.horizontalCenter: parent.horizontalCenter; height: 34
            WpButton { text: wp.svc.pasteMsg || "📋 Paste image"; h: 30; onClicked: wp.svc.pasteWallpaper() }
        }
    }
    focus: true
    // Ctrl+V: paste a picture (or image link) from the clipboard; jump to it once it's saved
    Keys.onPressed: e => { if ((e.modifiers & Qt.ControlModifier) && e.key === Qt.Key_V) { wp.svc.pasteWallpaper(); e.accepted = true } }
    Connections { target: wp.svc; function onPastedWallpaper(path) { wp.sortMode = "newest"; wp.filter = ""; jumpTo.path = path; jumpTo.restart() } }
    Timer { id: jumpTo; property string path: ""; interval: 600; onTriggered: { const k = wp.list.findIndex(x => x.path === path); if (k >= 0) wp.i = k } }
    Keys.onLeftPressed: step(-1)
    Keys.onRightPressed: step(1)
    Keys.onReturnPressed: apply()
    Keys.onEscapePressed: close()
}
