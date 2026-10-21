import QtQuick

// Clipboard (canvas "Phone-Clipboard"): search, All / Pinned tabs, history with kind chips, preview card, Delete / Copy (pin + ✕ on each row).
// ↑↓ choose · Enter copies · Delete removes · Esc closes. Backed by cliphist.
Item {
    id: c
    property var svc
    property string query: ""
    property int sel: 0
    property bool pinsOnly: false
    signal go(string screen)
    signal done()
    readonly property var list: { const q = query.toLowerCase(); return svc.clips.filter(x => (!pinsOnly || x.pinned) && (!q || x.text.toLowerCase().includes(q) || x.kind.toLowerCase() === q)) }
    readonly property var cur: list.length ? list[Math.min(sel, list.length - 1)] : null
    readonly property var chip: ({ TXT: "#D8F1F4", CMD: "#D6EED7", DIR: "#FFE7A8", URL: "#FBD5E0", IMG: "#FDDCCB" })
    function focusField() { field.forceActiveFocus() }
    Component.onCompleted: svc.loadClips()
    // the screen stays loaded between openings → refresh every time it shows, and while open
    onVisibleChanged: { if (visible) { svc.loadClips(); sel = 0 } else { field.text = ""; _shown = "" } }   // search starts empty next time
    // the list refreshes every 1.5 s with new objects: only reload the preview when a different item is picked (else it flickers)
    property string _shown: ""
    onCurChanged: { const id = cur ? cur.id : ""; if (id !== _shown) { _shown = id; svc.clipPreview(cur) } }
    onQueryChanged: sel = 0
    onPinsOnlyChanged: sel = 0
    function copy() { if (!cur) return; svc.clipCopy(cur); c.done() }
    // typing while on the list goes to the search box (letters, numbers, Backspace)
    Keys.onPressed: e => {
        if (field.activeFocus || (e.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) return;
        if (e.key === Qt.Key_Delete) { if (c.cur) c.svc.clipDelete(c.cur); e.accepted = true }   // (its text is an invisible char: typed into the search it emptied the list)
        else if (e.key === Qt.Key_Backspace) { field.forceActiveFocus(); field.text = field.text.slice(0, -1); e.accepted = true }
        else if (e.text.length === 1 && e.text > " " && e.text !== "\x7f") { field.forceActiveFocus(); field.text += e.text; field.cursorPosition = field.text.length; e.accepted = true }
    }

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
            Row {
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: 6
                // tabs: chosen one is a dark ink tile
                Repeater {
                    model: ["All", "Pinned"]
                    delegate: UiCandy {
                        id: tab
                        required property string modelData
                        required property int index
                        readonly property bool on: c.pinsOnly === (index === 1)
                        width: tl.implicitWidth + 20; height: 26; radius: 9; bw: 2; ink: Theme.inkPhone; drop: on ? 3 : 0; hi: 0
                        rotation: Theme.tilt(index + 3); fill: on ? Theme.inkPhone : Theme.paper; pressable: true
                        onClicked: c.pinsOnly = index === 1
                        UiText { id: tl; anchors.centerIn: parent; text: modelData; fam: "n"; px: 11; w: 900; color: tab.on ? "#FFFFFF" : Theme.textDeep }
                    }
                }
                UiCandy { width: cnt.implicitWidth + 18; height: 24; bw: 2; ink: Theme.inkPhone; drop: 0; hi: 0; fill: Theme.paper
                    UiText { id: cnt; anchors.centerIn: parent; text: c.list.length + " items"; fam: "n"; px: 11; w: 900 } }
            }
        }
        // list
        ListView {
            id: lv
            width: parent.width; height: 5 * 53 - 7
            clip: true; spacing: 7; boundsBehavior: Flickable.StopAtBounds
            topMargin: 4; bottomMargin: 4; leftMargin: 4        // room for the keyboard focus ring
            model: c.list
            currentIndex: c.sel
            highlightFollowsCurrentItem: false
            onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
            onCountChanged: if (!moving) positionViewAtBeginning()
            delegate: UiCandy {
                id: row
                required property var modelData
                required property int index
                readonly property bool picked: index === c.sel
                width: lv.width - 8; height: 46; radius: 20; bw: 2.5; ink: Theme.inkPhone; drop: picked ? 3 : 0; hi: 0
                fill: picked ? Theme.gLilac : Theme.paper; pressable: true
                // moving with the keys shows it in the preview right away, so one Enter copies it
                onActiveFocusChanged: if (activeFocus) c.sel = index
                onClicked: { if (c.sel === index) c.copy(); else c.sel = index }
                onRightClicked: c.svc.clipDelete(modelData)
                UiCandy { x: 10; anchors.verticalCenter: parent.verticalCenter; width: 38; height: 20; radius: 7; bw: 2; ink: Theme.inkPhone; drop: 0; hi: 0
                    fill: c.chip[modelData.kind] || Theme.paper
                    UiText { anchors.centerIn: parent; text: modelData.kind; fam: "n"; px: 9.5; w: 900 } }
                Column { x: 58; width: parent.width - 58 - 68; anchors.verticalCenter: parent.verticalCenter
                    UiText { width: parent.width; text: modelData.text.replace(/\s+/g, " "); px: 13; w: 600; height: 17 }
                    UiText { visible: text !== ""; width: parent.width; text: c.svc.ago(modelData.time); fam: "n"; px: 10; w: 800; color: Theme.textSoft; height: 13 } }
                UiCandy { x: parent.width - 60; anchors.verticalCenter: parent.verticalCenter; width: 24; height: 24; bw: 2; ink: Theme.inkPhone; drop: 0; hi: 0
                    fill: row.modelData.pinned ? Theme.inkPhone : Theme.paper; pressable: true
                    onClicked: c.svc.clipPin(row.modelData)
                    Glyph { anchors.centerIn: parent; name: "pushpin"; size: 13; stroke: 2.6; rotation: 30; color: row.modelData.pinned ? "#FFFFFF" : Theme.text } }
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
                UiText { visible: !c.cur; anchors.centerIn: parent; text: c.pinsOnly ? "Nothing pinned yet" : "Nothing copied yet"; fam: "n"; px: 13; w: 800; color: Theme.textSoft }
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
