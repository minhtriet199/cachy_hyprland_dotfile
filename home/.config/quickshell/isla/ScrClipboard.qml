import QtQuick

// Clipboard (canvas "Phone-Clipboard"): search, history with kind chips, preview card, Delete / Copy.
// ↑↓ choose · Enter copies · Delete removes · Esc closes. Backed by cliphist.
Item {
    id: c
    property var svc
    property string query: ""
    property int sel: 0
    signal go(string screen)
    signal done()
    readonly property var list: { const q = query.toLowerCase(); return svc.clips.filter(x => !q || x.text.toLowerCase().includes(q) || x.kind.toLowerCase() === q) }
    readonly property var cur: list.length ? list[Math.min(sel, list.length - 1)] : null
    readonly property var chip: ({ TXT: "#D8F1F4", CMD: "#D6EED7", DIR: "#FFE7A8", URL: "#FBD5E0", IMG: "#FDDCCB" })
    function focusField() { field.forceActiveFocus() }
    Component.onCompleted: svc.loadClips()
    // the screen stays loaded between openings → refresh every time it shows, and while open
    onVisibleChanged: { if (visible) { svc.loadClips(); sel = 0 } else field.text = "" }   // search starts empty next time
    Timer { interval: 1500; running: c.visible; repeat: true; onTriggered: c.svc.loadClips() }
    onCurChanged: svc.clipPreview(cur)
    onQueryChanged: sel = 0
    function copy() { if (!cur) return; svc.clipCopy(cur); c.done() }

    Column {
        x: 18; y: 16; width: parent.width - 36
        spacing: 10
        PhoneStatus { svc: c.svc; timePx: 16 }
        // search
        UiCandy {
            width: parent.width; height: 50; bw: 3; ink: Theme.inkPhone; drop: 4; hi: 0
            Glyph { x: 16; anchors.verticalCenter: parent.verticalCenter; name: "search"; size: 20; stroke: 2.5 }
            TextInput {
                id: field
                x: 46; width: parent.width - 46 - 44; anchors.verticalCenter: parent.verticalCenter; clip: true
                font.family: Theme.display; font.weight: 600; font.pixelSize: 18; color: Theme.text
                onTextChanged: c.query = text
                Keys.onUpPressed: c.sel = Math.max(0, c.sel - 1)
                Keys.onDownPressed: c.sel = Math.min(c.list.length - 1, c.sel + 1)
                Keys.onReturnPressed: c.copy()
                Keys.onEnterPressed: c.copy()
                Keys.onDeletePressed: if (c.cur) c.svc.clipDelete(c.cur)
                Keys.onEscapePressed: { if (text) text = ""; else c.done() }
                UiText { visible: !field.text; text: "Search clipboard…"; px: 18; w: 600; color: Theme.textSoft; anchors.verticalCenter: parent.verticalCenter }
            }
            UiCandy { visible: field.text !== ""; x: parent.width - 38; anchors.verticalCenter: parent.verticalCenter; width: 26; height: 26; bw: 0; drop: 0; hi: 0; fill: "transparent"; pressable: true
                onClicked: field.text = ""
                Glyph { anchors.centerIn: parent; name: "close"; size: 13; stroke: 2.8 } }
        }
        // title
        Item {
            width: parent.width; height: 34
            UiCandy { width: 30; height: 30; radius: 9; bw: 2.5; ink: Theme.inkPhone; drop: 0; hi: 0; fill: Theme.sun; anchors.verticalCenter: parent.verticalCenter
                Glyph { anchors.centerIn: parent; name: "clipboard"; size: 15; stroke: 2.6 } }
            UiText { x: 40; anchors.verticalCenter: parent.verticalCenter; text: "Clipboard"; px: 22; w: 700; color: Theme.textDeep }
            UiCandy { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; width: cnt.implicitWidth + 18; height: 24; bw: 2; ink: Theme.inkPhone; drop: 0; hi: 0; fill: Theme.paper
                UiText { id: cnt; anchors.centerIn: parent; text: c.list.length + " items"; fam: "n"; px: 11; w: 900 } }
        }
        // list
        ListView {
            id: lv
            width: parent.width; height: 6 * 46 - 7
            clip: true; spacing: 7; boundsBehavior: Flickable.StopAtBounds
            model: c.list
            currentIndex: c.sel
            highlightFollowsCurrentItem: false
            onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
            onCountChanged: if (!moving) positionViewAtBeginning()
            delegate: UiCandy {
                required property var modelData
                required property int index
                readonly property bool picked: index === c.sel
                width: lv.width; height: 39; radius: 20; bw: 2.5; ink: Theme.inkPhone; drop: picked ? 3 : 0; hi: 0
                fill: picked ? Theme.gLilac : Theme.paper; pressable: true
                onClicked: { if (c.sel === index) c.copy(); else c.sel = index }
                onRightClicked: c.svc.clipDelete(modelData)
                UiCandy { x: 10; anchors.verticalCenter: parent.verticalCenter; width: 38; height: 20; radius: 7; bw: 2; ink: Theme.inkPhone; drop: 0; hi: 0
                    fill: c.chip[modelData.kind] || Theme.paper
                    UiText { anchors.centerIn: parent; text: modelData.kind; fam: "n"; px: 9.5; w: 900 } }
                UiText { x: 58; width: parent.width - 58 - 40; anchors.verticalCenter: parent.verticalCenter; text: modelData.text.replace(/\s+/g, " "); px: 13; w: 600 }
                UiCandy { x: parent.width - 32; anchors.verticalCenter: parent.verticalCenter; width: 24; height: 24; bw: 2; ink: Theme.inkPhone; drop: 0; hi: 0
                    fill: Theme.paper; pressable: true
                    onClicked: c.svc.clipDelete(modelData)
                    Glyph { anchors.centerIn: parent; name: "close"; size: 11; stroke: 2.8 } }
            }
        }
        // preview
        Item {
            width: parent.width; height: 214 - ((c.svc.phoneBig && c.height > c.width) ? 44 : 0)     // big mode: stop above the nav bar
            Behavior on height { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
            UiCandy {
                y: 10; width: parent.width; height: parent.height - 10; radius: 20; bw: 3; ink: Theme.inkPhone; drop: 4; hi: 0; fill: Theme.paper
                Text {
                    visible: !!c.cur && c.cur.kind !== "IMG"
                    x: 16; y: 22; width: parent.width - 32; height: parent.height - 22 - 52
                    text: c.svc.clipFull || (c.cur ? c.cur.text : ""); wrapMode: Text.WrapAnywhere; elide: Text.ElideRight
                    font.family: "monospace"; font.pixelSize: 13; color: Theme.text; clip: true
                }
                Image {
                    visible: !!c.cur && c.cur.kind === "IMG"
                    x: 14; y: 22; width: parent.width - 28; height: parent.height - 22 - 52
                    source: c.svc.clipImage; fillMode: Image.PreserveAspectFit; asynchronous: true; cache: false
                }
                UiText { visible: !c.cur; anchors.centerIn: parent; text: "Nothing copied yet"; fam: "n"; px: 13; w: 800; color: Theme.textSoft }
                UiText { x: 16; anchors.bottom: parent.bottom; anchors.bottomMargin: 16; height: 22
                    text: !c.cur ? "" : c.cur.kind === "IMG" ? c.cur.info : (c.svc.clipFull.length + " characters · " + (c.svc.clipFull.split("\n").length) + " line" + (c.svc.clipFull.split("\n").length > 1 ? "s" : ""))
                    fam: "n"; px: 11; w: 800; color: Theme.textSoft }
                Row {
                    anchors.right: parent.right; anchors.rightMargin: 14; anchors.bottom: parent.bottom; anchors.bottomMargin: 12; spacing: 8
                    UiCandy { width: 36; height: 34; radius: 11; bw: 2.5; ink: Theme.inkPhone; drop: 3; hi: 0; fill: Theme.pinkSoft; pressable: !!c.cur
                        onClicked: c.svc.clipDelete(c.cur)
                        Glyph { anchors.centerIn: parent; name: "trash"; size: 15; stroke: 2.6 } }
                    UiCandy { width: 74; height: 34; radius: 11; bw: 2.5; ink: Theme.inkPhone; drop: 3; hi: 3; fill: Theme.gTab; pressable: !!c.cur
                        onClicked: c.copy()
                        UiText { anchors.centerIn: parent; text: "Copy"; px: 14; w: 700; color: "#FFFFFF" } }
                }
            }
            UiTag { x: 18; y: 0; text: "Preview"; fill: Theme.lilacSoft; ink: Theme.inkPhone; textColor: Theme.textDeep; px: 12; tilt: -4 }
        }
    }
}
