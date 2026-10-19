import QtQuick
import Qt.labs.folderlistmodel

// Wallpaper picker on a string (landscape, canvas "Wallpapers"). ←/→ spin · R random · Enter sets it.
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
    // Surprise me: roll to a random other picture — snap to 6 before it, then spin the last stretch so it lands centred
    function surprise() { if (n < 2) return
        const d = 1 + Math.floor(Math.random() * (n - 1)), b = Math.round(viewTarget)
        if (d > 6) jump(b + d - 6); settle(b + d) }
    // swing: photos lag behind when the string moves and wobble back, like clothes on a line
    property real vel: 0                          // pictures / second
    property real _last: 0
    property real swing: 0
    Behavior on swing { SpringAnimation { spring: 2.4; damping: 0.1; epsilon: 0.05 } }
    FrameAnimation { running: wp.visible && (wp.dragging || Math.abs(wp.view - wp.viewTarget) > 0.001 || Math.abs(wp.vel) > 0.01)
        onTriggered: { const v = frameTime > 0 ? (wp.view - wp._last) / frameTime : 0; wp._last = wp.view
            wp.vel = wp.vel * 0.6 + v * 0.4; wp.swing = Math.max(-16, Math.min(16, -wp.vel * 7)) } }
    function apply() { if (cur) prefs.set(targetKey, cur.path) }
    function applyTo(key) { if (cur) prefs.set(key, cur.path) }
    // Preview: show the picture on the desktop (the phone fades away); ← → keep browsing, Esc / Back ends it
    readonly property bool previewing: !!svc && svc.wallPreview !== ""
    function preview() { if (cur) svc.wallPreview = cur.path }
    onCurChanged: if (previewing && cur) svc.wallPreview = cur.path
    // washi tape colours for the strips that hold each photo
    readonly property var tapes: [Theme.pinkSoft, Theme.seaSoft, Theme.sun, Theme.lilacSoft, Theme.peach]

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

    // string + photos, cut at the screen's edges (the rope is longer than the screen)
    Item {
        id: stageClip
        x: 12; width: wp.width - 24; height: wp.height; clip: true      // 12 = phone frame around the screen
    Item {
        id: stage
        // drawn for an 800-wide sideways screen; on the upright phone it's scaled down to fit
        // and shrunk to fit above the name + buttons (≈ 270 design px tall), centred
        readonly property real room: wp.height - (16 + wp.topPad + (wp.narrow ? 170 : 40)) - caption.height - caption.anchors.bottomMargin - 10
        scale: Math.max(0.3, Math.min(1, wp.cw / 800, room / 270)); transformOrigin: Item.TopLeft
        x: wp.cx - stageClip.x + (wp.cw - 800 * scale) / 2; y: 16 + wp.topPad + (wp.narrow ? 170 : 36 + 4); width: 800; height: room / scale
        // the rope runs past both sides (x -220 … 1020) so the outer photos hang from it too.
        // Quadratic curve (-220,110) → ctrl (400,-50) → (1020,110) in stage coords; the canvas sits at x -230
        Canvas {
            id: rope
            x: -230; y: 0; width: 1260; height: 150
            property color inkC: wp.ink
            property color dotC: Theme.paper
            onInkCChanged: requestPaint()
            onPaint: {
                const g = getContext("2d"); g.reset(); g.strokeStyle = inkC; g.lineCap = "round"
                const ox = 230, Y = t => (1 - t) * (1 - t) * 110 + 2 * (1 - t) * t * -50 + t * t * 110
                g.lineWidth = 4; g.beginPath(); g.moveTo(ox - 220, 110); g.quadraticCurveTo(ox + 400, -50, ox + 1020, 110); g.stroke()       // main rope
                g.lineWidth = 2.5; g.beginPath(); g.moveTo(ox - 200, 126); g.quadraticCurveTo(ox + 400, -32, ox + 1000, 126); g.stroke()     // thin rope under it
                for (const x of [70, 220, 400, 580, 730]) {
                    const t = (x + 220) / 1240, y = Y(t), y2 = Y((x + 200) / 1200) + 16
                    g.lineWidth = 2; g.beginPath(); g.moveTo(ox + x, y); g.lineTo(ox + x, y2); g.stroke()                       // little strut
                    g.fillStyle = dotC; g.beginPath()
                    if (x === 400) { g.moveTo(ox + x, y - 7); g.lineTo(ox + x + 7, y); g.lineTo(ox + x, y + 7); g.lineTo(ox + x - 7, y); g.closePath() }
                    else g.arc(ox + x, y, 6, 0, 2 * Math.PI)
                    g.fill(); g.lineWidth = 2.5; g.stroke()
                    if (x !== 400) { g.fillStyle = inkC; g.beginPath(); g.arc(ox + x, y, 2, 0, 2 * Math.PI); g.fill() }
                }
            }
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
        // height / slope of the main rope at stage x (same curve as the Canvas above; x is linear in t there)
        function stringY(xs) { const t = Math.max(0, Math.min(1, (xs + 220) / 1240)); return (1 - t) * (1 - t) * 110 + 2 * (1 - t) * t * -50 + t * t * 110 }
        function stringAngle(xs) { const t = Math.max(0, Math.min(1, (xs + 220) / 1240)); return Math.atan2(-320 * (1 - t) + 320 * t, 1240) * 180 / Math.PI }
        property real sway: 0
        SequentialAnimation on sway { running: wp.visible; loops: Animation.Infinite
            NumberAnimation { from: -1; to: 1; duration: 2200; easing.type: Easing.InOutSine } NumberAnimation { from: 1; to: -1; duration: 2200; easing.type: Easing.InOutSine } }
        // spots along the string by distance from the middle: [x, width, photo height, opacity]; in-between = blended
        readonly property var slots: [[-320, 140, 92, 0], [-140, 150, 98, 1], [32, 200, 130, 1], [257, 286, 186, 1], [568, 200, 130, 1], [790, 150, 98, 1], [960, 140, 92, 0]]
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
                x: sl[0]; y: stage.stringY(pinX) + 4
                width: sl[1]; height: 22 + sl[2]
                rotation: stage.stringAngle(pinX) * 0.8 + stage.sway * (1.6 - Math.abs(o) * 0.3) * (((a % 2) + 2) % 2 ? -1 : 1)
                          + wp.swing * (1 - Math.min(3, Math.abs(o)) * 0.15)
                transformOrigin: Item.Top
                z: 10 - Math.abs(o)
                opacity: sl[3]
                visible: wp.n > 0 && opacity > 0.01 && Math.abs(o) <= wp.n / 2
                // two strings from the rope down to the photo's top corners
                // two strings from the rope (wherever it is above that corner) down to the photo's top corners
                Repeater { model: [0.18, 0.82]
                    delegate: Rectangle {
                        required property real modelData
                        readonly property real ropeAt: stage.stringY(card.x + card.width * modelData) - card.y
                        x: card.width * modelData - 1; y: Math.min(ropeAt, 20); width: 2; height: 24 - y; color: wp.ink } }
                UiCandy {
                    id: photo
                    y: 22; width: card.width; height: card.sl[2]
                    radius: 14; ink: wp.ink; bw: card.mid ? 4 : 3; drop: card.mid ? 7 : 4; hi: 0
                    fill: Theme.paper
                    // the picture sits on a white mat inside the frame
                    readonly property real mat: photo.bw + (card.mid ? 7 : 5)
                    Image {
                        x: photo.mat; y: photo.mat; width: photo.width - 2 * photo.mat; height: photo.height - 2 * photo.mat
                        source: card.pic ? "file://" + card.pic.path : ""
                        sourceSize: Qt.size(380, 264); fillMode: Image.PreserveAspectCrop; asynchronous: true; smooth: true
                    }
                }
                // washi tape strips over the top corners
                Repeater { model: [0, 1]
                    delegate: Rectangle {
                        required property int modelData
                        width: card.width * 0.2; height: 13; radius: 2
                        x: modelData ? card.width * 0.82 - width / 2 : card.width * 0.18 - width / 2; y: 22 - 6
                        rotation: modelData ? 7 : -6
                        color: wp.tapes[(((card.a * 2 + modelData) % wp.tapes.length) + wp.tapes.length) % wp.tapes.length]; opacity: 0.85
                    }
                }
            }
        }
        UiText { visible: wp.n === 0; anchors.centerIn: parent; horizontalAlignment: Text.AlignHCenter; fam: "n"; w: 800; px: 13; color: Theme.textSoft
            text: "No pictures in " + wp.prefs.wallDir + "\nPut some wallpapers there and come back ✿" }
    }

    }

    // caption + actions
    Column {
        id: caption
        anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: (wp.narrow ? 70 : 14) + (wp.svc && wp.svc.phoneBig && wp.narrow ? 64 : 0)
        spacing: 6
        UiStrokeText { anchors.horizontalCenter: parent.horizontalCenter; text: wp.cur ? wp.cur.name : "—"; px: 18; strokeW: 5; strokeColor: wp.ink }
        UiCandy { anchors.horizontalCenter: parent.horizontalCenter; width: il.implicitWidth + 24; height: 19; bw: 2; ink: wp.ink; drop: 0; hi: 0
            UiText { id: il; anchors.centerIn: parent; text: (wp.n ? wp.i + 1 : 0) + " / " + wp.n; px: 11; w: 700 } }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter; spacing: 10; height: 40
            WpButton { text: wp.narrow ? "‹" : "‹ Previous"; h: 30; onClicked: wp.step(-1) }
            Repeater {
                model: [["wallpaper", "🖥", "Desktop"], ["lockWallpaper", "🔒", "Lockscreen"]]
                delegate: WpButton {
                    required property var modelData
                    readonly property bool done: !!wp.cur && wp.prefs[modelData[0]] === wp.cur.path
                    text: (done ? "✓ " : modelData[1] + "  ") + (wp.narrow ? modelData[2] : "Set as " + modelData[2])
                    h: 36; bold: true; drop: 3; fill: done ? wp.accent : Theme.paper; onClicked: wp.applyTo(modelData[0])
                }
            }
            WpButton { text: wp.narrow ? "›" : "Next ›"; h: 30; onClicked: wp.step(1) }
        }
        Row {   // the rest: phone screen, delete, paste
            anchors.horizontalCenter: parent.horizontalCenter; spacing: 8; height: 34
            WpButton { readonly property bool done: !!wp.cur && wp.prefs.phoneBg === wp.cur.path
                text: (done ? "✓ " : "📱 ") + "Phone"; h: 28; fill: done ? wp.accent : Theme.paper; onClicked: wp.applyTo("phoneBg") }
            WpButton { text: "👁 Preview"; h: 28; onClicked: wp.preview() }
            WpButton { text: wp.narrow ? "🎲" : "🎲 Surprise me"; h: 28; onClicked: wp.surprise() }
            WpButton { text: "🗑"; h: 28; onClicked: if (wp.cur) wp.askDelete = { name: wp.cur.name, path: wp.cur.path } }
            WpButton { text: wp.svc.pasteMsg || "📋 Paste image"; h: 28; onClicked: wp.svc.pasteWallpaper() }
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
    Keys.onPressed: e => { if ((e.modifiers & Qt.ControlModifier) && e.key === Qt.Key_V) { wp.svc.pasteWallpaper(); e.accepted = true }
        else if (e.key === Qt.Key_R && !e.modifiers) { wp.surprise(); e.accepted = true } }      // R = surprise me
    Connections { target: wp.svc; function onPastedWallpaper(path) { wp.sortMode = "newest"; wp.filter = ""; jumpTo.path = path; jumpTo.restart() } }
    Timer { id: jumpTo; property string path: ""; interval: 600; onTriggered: { const k = wp.list.findIndex(x => x.path === path); if (k >= 0) wp.jump(k) } }
    Keys.onLeftPressed: step(-1)
    Keys.onRightPressed: step(1)
    Keys.onReturnPressed: apply()
    Keys.onEscapePressed: previewing ? (svc.wallPreview = "") : close()
    Keys.onSpacePressed: previewing ? (svc.wallPreview = "") : preview()      // Space = preview on / off
}
