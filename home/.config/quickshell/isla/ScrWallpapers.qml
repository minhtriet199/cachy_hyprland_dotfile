import QtQuick
import Qt.labs.folderlistmodel

// Wallpaper picker on a string (landscape, canvas "Wallpapers"). ←/→ spin · Enter sets it.
Item {
    id: wp
    property var svc
    property var prefs
    // the string slides smoothly: `view` is the live position (any real number, follows your drag),
    // `viewTarget` is where it settles; i = the picked picture (wrapped into 0…n-1)
    property real view: 0
    property real viewTarget: 0
    property bool dragging: false
    property bool snap: false
    Behavior on view { enabled: !wp.dragging && !wp.snap; SpringAnimation { spring: 3.2; damping: 0.3; epsilon: 0.002 } }
    readonly property int i: n ? ((Math.round(viewTarget) % n) + n) % n : 0
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
    readonly property real topPad: narrow ? 26 : 0                     // below the punch hole
    FolderListModel {
        id: files
        folder: "file://" + wp.prefs.wallDir
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.JPG", "*.PNG"]
        showDirs: false
        sortField: wp.sortMode === "name" || wp.sortMode === "nameDesc" ? FolderListModel.Name : FolderListModel.Time
        sortReversed: wp.sortMode === "oldest" || wp.sortMode === "nameDesc"
    }
    property string sortMode: "newest"
    property var askDelete: null                 // { name, path } waiting for "Delete?" confirmation
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
    function settle(t) { viewTarget = t; view = t }
    function step(d) { if (n) settle(Math.round(viewTarget) + d) }
    function jump(k) { snap = true; settle(k); snap = false }
    // swing: photos lag behind when the string moves and wobble back, like clothes on a line
    property real vel: 0                          // pictures / second
    property real _last: 0
    property real swing: 0
    Behavior on swing { SpringAnimation { spring: 2.4; damping: 0.1; epsilon: 0.05 } }
    FrameAnimation { running: wp.visible && (wp.dragging || Math.abs(wp.view - wp.viewTarget) > 0.001 || Math.abs(wp.vel) > 0.01)
        onTriggered: { const v = frameTime > 0 ? (wp.view - wp._last) / frameTime : 0; wp._last = wp.view
            wp.vel = wp.vel * 0.6 + v * 0.4; wp.swing = Math.max(-16, Math.min(16, -wp.vel * 7)) } }
    function apply() { if (cur) prefs.set(targetKey, cur.path) }

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
                onTextChanged: { wp.filter = text; wp.jump(0) }
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
                            onClicked: { wp.sortMode = modelData[0]; wp.sortOpen = false; wp.jump(0) }
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
        // drag the string left/right: the photos follow your hand, then spring onto the nearest one.
        // A short click picks the photo under the pointer (middle one = set it).
        MouseArea {
            anchors.fill: parent; z: 50
            property real sx: 0
            property real sv: 0
            property bool moved: false
            cursorShape: wp.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            onPressed: m => { sx = m.x; sv = wp.view; moved = false }
            onPositionChanged: m => { if (!pressed) return; const d = m.x - sx
                if (!moved && Math.abs(d) > 6) { moved = true; wp.dragging = true }
                if (moved) wp.view = sv - d / 170 }
            function finish() { if (!moved) return; moved = false; wp.dragging = false
                wp.settle(Math.round(wp.view + Math.max(-3, Math.min(3, wp.vel * 0.18)))) }
            onReleased: m => { if (moved) { finish(); return }
                let hit = null
                for (let k = 0; k < cards.count; k++) { const c = cards.itemAt(k); if (!c || !c.visible || c.opacity < 0.3) continue
                    const pt = c.mapFromItem(stage, m.x, m.y); if (c.contains(pt) && (!hit || c.z > hit.z)) hit = c }
                if (hit) { const o = Math.round(hit.o); if (o === 0) wp.apply(); else wp.step(o) } }
            onCanceled: finish()
        }
        WheelHandler { onWheel: e => wp.step(e.angleDelta.y > 0 ? -1 : 1) }
        // the string: quadratic curve (10,70) → ctrl (390,-30) → (770,70) in the Canvas (which sits at 10,4)
        function stringY(xs) { const t = Math.max(0, Math.min(1, (xs - 20) / 760)); return (1 - t) * (1 - t) * 70 + 2 * (1 - t) * t * -30 + t * t * 70 + 4 }
        function stringAngle(xs) { const t = Math.max(0, Math.min(1, (xs - 20) / 760)); return Math.atan2(-200 * (1 - t) + 200 * t, 760) * 180 / Math.PI }
        property real sway: 0
        SequentialAnimation on sway { running: wp.visible; loops: Animation.Infinite
            NumberAnimation { from: -1; to: 1; duration: 2200; easing.type: Easing.InOutSine } NumberAnimation { from: 1; to: -1; duration: 2200; easing.type: Easing.InOutSine } }
        // spots along the string by distance from the middle: [x, width, photo height, opacity]; in-between = blended
        readonly property var slots: [[-110, 100, 72, 0], [18, 120, 86, 1], [136, 150, 106, 1], [302, 190, 132, 1], [512, 150, 106, 1], [650, 120, 86, 1], [800, 100, 72, 0]]
        function slot(o) {
            const c = Math.max(-3, Math.min(3, o)), a = Math.min(2, Math.floor(c)), f = c - a
            const A = slots[a + 3], B = slots[a + 4]
            return [A[0] + (B[0] - A[0]) * f, A[1] + (B[1] - A[1]) * f, A[2] + (B[2] - A[2]) * f, A[3] + (B[3] - A[3]) * f]
        }
        // 7 pegs; peg k always holds a picture whose number ≡ k (mod 7), so it only swaps its picture off-screen
        Repeater {
            id: cards
            model: 7
            delegate: Item {
                id: card
                required property int index
                readonly property int a: index + 7 * Math.round((wp.view - index) / 7)     // picture number on this peg
                readonly property real o: a - wp.view                                      // distance from the middle (-3.5 … 3.5)
                readonly property var sl: stage.slot(o)
                readonly property bool mid: Math.abs(o) < 0.5
                readonly property var pic: wp.n ? wp.list[((a % wp.n) + wp.n) % wp.n] : null
                readonly property real pinX: sl[0] + sl[1] / 2
                // clip sits on the string; the photo hangs below it, tilted with the string, swaying and swinging
                x: sl[0]; y: stage.stringY(pinX) - 9
                width: sl[1]; height: 16 + sl[2]
                rotation: stage.stringAngle(pinX) * 0.8 + stage.sway * (1.6 - Math.abs(o) * 0.3) * (((a % 2) + 2) % 2 ? -1 : 1)
                          + wp.swing * (1 - Math.min(3, Math.abs(o)) * 0.15)
                transformOrigin: Item.Top
                z: 10 - Math.abs(o)
                opacity: sl[3]
                visible: wp.n > 0 && opacity > 0.01 && Math.abs(o) <= wp.n / 2
                UiCandy {
                    id: photo
                    y: 16; width: card.width; height: card.sl[2]
                    radius: 12; ink: wp.ink; bw: card.mid ? 4 : 3; drop: card.mid ? 7 : 4; hi: 0
                    fill: "#DDF4FA"
                    Image {
                        x: photo.bw; y: photo.bw; width: photo.width - 2 * photo.bw; height: photo.height - 2 * photo.bw
                        source: card.pic ? "file://" + card.pic.path : ""
                        sourceSize: Qt.size(380, 264); fillMode: Image.PreserveAspectCrop; asynchronous: true; smooth: true
                    }
                    Rectangle { x: photo.bw; y: photo.bw; width: photo.width - 2 * photo.bw; height: photo.height - 2 * photo.bw
                        opacity: Math.max(0, 1 - Math.abs(card.o) * 2)
                        radius: 8; color: "transparent"; border.width: 6; border.color: Theme.paper }
                }
                Rectangle { anchors.horizontalCenter: parent.horizontalCenter; width: 14; height: 22; radius: 4; color: card.mid ? Theme.sun : Theme.paper; border.width: 2; border.color: wp.ink }
            }
        }
        UiText { visible: wp.n === 0; anchors.centerIn: parent; horizontalAlignment: Text.AlignHCenter; fam: "n"; w: 800; px: 13; color: Theme.textSoft
            text: "No pictures in " + wp.prefs.wallDir + "\nPut some wallpapers there and come back ✿" }
    }

    // caption + actions
    Column {
        anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: (wp.narrow ? 70 : 14) + (wp.svc && wp.svc.phoneBig && wp.narrow ? 64 : 0)
        spacing: 6
        UiStrokeText { anchors.horizontalCenter: parent.horizontalCenter; text: wp.cur ? wp.cur.name : "—"; px: 18; strokeW: 5; strokeColor: wp.ink }
        UiCandy { anchors.horizontalCenter: parent.horizontalCenter; width: il.implicitWidth + 24; height: 19; bw: 2; ink: wp.ink; drop: 0; hi: 0
            UiText { id: il; anchors.centerIn: parent; text: (wp.n ? wp.i + 1 : 0) + " / " + wp.n; px: 11; w: 700 } }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter; spacing: 10; height: 40
            WpButton { text: "‹ Previous"; h: 30; onClicked: wp.step(-1) }
            WpButton { text: wp.applied ? "✓ Applied" : "Set as " + wp.target; h: 36; bold: true; drop: 3; fill: wp.applied ? wp.accent : Theme.paper; onClicked: wp.apply() }
            WpButton { text: "Next ›"; h: 30; onClicked: wp.step(1) }
            WpButton { text: "🗑"; h: 30; onClicked: if (wp.cur) wp.askDelete = { name: wp.cur.name, path: wp.cur.path } }
            WpButton { visible: !wp.narrow; text: wp.svc.pasteMsg || "📋 Paste image"; h: 30; onClicked: wp.svc.pasteWallpaper() }
        }
        Row {   // upright phone: paste goes on its own line
            visible: wp.narrow; anchors.horizontalCenter: parent.horizontalCenter; height: 34
            WpButton { text: wp.svc.pasteMsg || "📋 Paste image"; h: 30; onClicked: wp.svc.pasteWallpaper() }
        }
    }
    // delete confirmation (moves the picture to the Trash, so it can be restored)
    Rectangle {
        visible: !!wp.askDelete; z: 80; anchors.fill: parent; radius: 40; color: Qt.rgba(33 / 255, 63 / 255, 72 / 255, 0.35)
        MouseArea { anchors.fill: parent; onClicked: wp.askDelete = null }
        UiCandy {
            anchors.centerIn: parent; width: Math.min(420, parent.width - 40); height: dcol.implicitHeight + 32; radius: 22; bw: 3; ink: wp.ink; drop: 6; hi: 0; fill: Theme.cream
            MouseArea { anchors.fill: parent; z: -1 }
            Column {
                id: dcol; x: 18; y: 16; width: parent.width - 36; spacing: 10
                UiText { width: parent.width; text: "Delete this picture?"; px: 19; w: 700; color: Theme.textDeep }
                UiText { width: parent.width; text: wp.askDelete ? wp.askDelete.name : ""; fam: "n"; px: 12; w: 800; color: Theme.textMuted; wrapMode: Text.WrapAnywhere }
                UiText { width: parent.width; text: "It goes to the Trash — you can restore it from Dolphin."; fam: "n"; px: 11; w: 800; color: Theme.textSoft; wrapMode: Text.Wrap }
                Row {
                    anchors.right: parent.right; spacing: 10
                    UiCandy { width: 90; height: 36; radius: 12; bw: 2.5; ink: wp.ink; drop: 3; hi: 0; fill: Theme.paper; pressable: true; onClicked: wp.askDelete = null
                        UiText { anchors.centerIn: parent; text: "Cancel"; px: 13; w: 700 } }
                    UiCandy { width: 100; height: 36; radius: 12; bw: 2.5; ink: wp.ink; drop: 3; hi: 3; fill: Theme.gBerry; pressable: true
                        onClicked: { wp.svc.trashFile(wp.askDelete.path); wp.askDelete = null }
                        UiText { anchors.centerIn: parent; text: "Delete"; px: 13; w: 700 } }
                }
            }
        }
    }
    focus: true
    // Ctrl+V: paste a picture (or image link) from the clipboard; jump to it once it's saved
    Keys.onPressed: e => { if ((e.modifiers & Qt.ControlModifier) && e.key === Qt.Key_V) { wp.svc.pasteWallpaper(); e.accepted = true } }
    Connections { target: wp.svc; function onPastedWallpaper(path) { wp.sortMode = "newest"; wp.filter = ""; jumpTo.path = path; jumpTo.restart() } }
    Timer { id: jumpTo; property string path: ""; interval: 600; onTriggered: { const k = wp.list.findIndex(x => x.path === path); if (k >= 0) wp.jump(k) } }
    Keys.onLeftPressed: step(-1)
    Keys.onRightPressed: step(1)
    Keys.onReturnPressed: apply()
    Keys.onEscapePressed: close()
}
