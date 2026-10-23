import QtQuick

// Keyboard page (phone): every shortcut from ~/.config/hypr/keybinds.json, grouped, with search.
// Click a shortcut → press the new keys (Esc cancels). While recording, Hyprland is put in the empty
// "keycapture" submap so existing binds don't fire (same trick as the Keyboard Shortcuts app).
// Saving goes through tools/setbind.py → the app's own apply(): reload + roll back on errors.
// Filter chips: All · Same keys (two shortcuts on one key combo) · Mine (added here) · each group.
FocusScope {
    id: kp
    property var svc
    property real listH: 300
    property string filter: ""
    property string chip: "all"             // all · dup · custom · a category name
    property int recIndex: -1               // -2 = recording keys for a NEW shortcut
    property bool adding: false
    property var nameField: null
    property var cmdField: null
    readonly property var newName: nameField || ({ text: "" })
    readonly property var newCmd: cmdField || ({ text: "" })
    property string recKeys: ""
    implicitHeight: col.implicitHeight
    Component.onCompleted: { svc.loadBinds(); svc.bindMsg = "" }
    Component.onDestruction: if (recIndex >= 0) svc.submap("reset")

    // same keys = same modifiers + key in any order; "Super + 1…9" rows count as their ten number keys
    function combos(b) {
        const base = b.keys.split("+").map(p => p.trim().toUpperCase()).filter(p => p);
        const one = extra => base.concat(extra).sort().join("+");
        if (b.action !== "ws_digits") return [one([])];
        const out = []; for (let c = 10; c <= 19; c++) out.push(one(["CODE:" + c])); return out;
    }
    readonly property var dupSet: {
        const seen = {}, dup = {};
        svc.binds.forEach((b, i) => combos(b).forEach(c => { if (seen[c] !== undefined && seen[c] !== i) { dup[i] = true; dup[seen[c]] = true } else seen[c] = i }));
        return dup;
    }
    readonly property int dupCount: Object.keys(dupSet).length
    readonly property var cats: { const o = []; for (const b of svc.binds) if (!o.includes(b.category)) o.push(b.category); return o }
    readonly property var rows: {
        const f = filter.toLowerCase(), out = [];
        svc.binds.forEach((b, i) => {
            if (chip === "dup" ? !dupSet[i] : chip === "custom" ? b.category !== "Custom" : chip !== "all" && b.category !== chip) return;
            if (!f || (b.desc + " " + b.keys + " " + b.category).toLowerCase().includes(f)) out.push(Object.assign({ index: i }, b)) });
        const order = []; for (const b of out) if (!order.includes(b.category)) order.push(b.category);
        return out.sort((a, b) => order.indexOf(a.category) - order.indexOf(b.category) || a.index - b.index);
    }
    function editable(b) { return b.action !== "ws_digits" && !b.keys.includes("mouse") && b.keys.split(" + ").length > 0 }
    function startRec(i) { if (i === -2 && (!newName.text.trim() || !newCmd.text.trim())) { svc.bindMsg = "Not ready — fill in name and command"; return }
        recIndex = i; recKeys = ""; svc.bindMsg = ""; svc.submap("keycapture"); kp.forceActiveFocus() }
    function stopRec() { recIndex = -1; svc.submap("reset") }

    // Qt key → Hyprland key name (same names the Keyboard Shortcuts app writes)
    readonly property var named: ({ [Qt.Key_Space]: "Space", [Qt.Key_Return]: "Return", [Qt.Key_Enter]: "Return", [Qt.Key_Tab]: "Tab", [Qt.Key_Backspace]: "BackSpace",
        [Qt.Key_Delete]: "Delete", [Qt.Key_Left]: "Left", [Qt.Key_Right]: "Right", [Qt.Key_Up]: "Up", [Qt.Key_Down]: "Down", [Qt.Key_Home]: "Home", [Qt.Key_End]: "End",
        [Qt.Key_PageUp]: "Prior", [Qt.Key_PageDown]: "Next", [Qt.Key_Print]: "Print", [Qt.Key_Period]: "period", [Qt.Key_Comma]: "comma", [Qt.Key_Slash]: "slash",
        [Qt.Key_Semicolon]: "semicolon", [Qt.Key_Apostrophe]: "apostrophe", [Qt.Key_BracketLeft]: "bracketleft", [Qt.Key_BracketRight]: "bracketright",
        [Qt.Key_Minus]: "Minus", [Qt.Key_Equal]: "equal", [Qt.Key_Plus]: "Plus", [Qt.Key_QuoteLeft]: "grave", [Qt.Key_Backslash]: "backslash", [Qt.Key_Escape]: "Escape" })
    Keys.onPressed: e => {
        if (recIndex < 0) return;
        e.accepted = true;
        if ([Qt.Key_Shift, Qt.Key_Control, Qt.Key_Alt, Qt.Key_Meta, Qt.Key_Super_L, Qt.Key_Super_R, Qt.Key_AltGr].includes(e.key)) return;
        const mods = [];
        if (e.modifiers & Qt.MetaModifier) mods.push("SUPER");
        if (e.modifiers & Qt.ControlModifier) mods.push("CONTROL");
        if (e.modifiers & Qt.AltModifier) mods.push("ALT");
        if (e.modifiers & Qt.ShiftModifier) mods.push("SHIFT");
        if (e.key === Qt.Key_Escape && !mods.length) { stopRec(); return }
        let key = "";
        if (e.nativeScanCode >= 10 && e.nativeScanCode <= 19) key = "code:" + e.nativeScanCode;     // number row, layout-safe
        else if (e.key >= Qt.Key_A && e.key <= Qt.Key_Z) key = String.fromCharCode(e.key);
        else if (e.key >= Qt.Key_F1 && e.key <= Qt.Key_F24) key = "F" + (e.key - Qt.Key_F1 + 1);
        else if (named[e.key]) key = named[e.key];
        else return;
        recKeys = mods.concat([key]).join(" + ");
        const i = recIndex; stopRec();
        if (i === -2) { svc.addBind(newName.text, newCmd.text, recKeys); adding = false; newName.text = ""; newCmd.text = "" }
        else svc.setBind(i, recKeys);
    }

    Column {
        id: col
        width: kp.width; spacing: 10
        Item {
            width: parent.width; height: 34
            UiCandy {
                width: parent.width - msg.width - 12 - addBtn.width - 8; height: 34; radius: 12; bw: 2.5; drop: 0; hi: 0; fill: Theme.paper
                Glyph { x: 10; anchors.verticalCenter: parent.verticalCenter; name: "search"; size: 15; stroke: 2.6 }
                TextInput {
                    id: q; x: 32; width: parent.width - 42; anchors.verticalCenter: parent.verticalCenter; clip: true
                    font.family: Theme.body; font.weight: 800; font.pixelSize: 13; color: Theme.text
                    onTextChanged: kp.filter = text
                    UiText { visible: !q.text; text: "Search shortcuts…"; fam: "n"; px: 13; w: 800; color: Theme.textSoft; anchors.verticalCenter: parent.verticalCenter }
                }
            }
            UiCandy {
                id: addBtn
                x: parent.width - msg.width - 8 - width; anchors.verticalCenter: parent.verticalCenter
                width: al.implicitWidth + 24; height: 34; radius: 12; bw: 2.5; drop: kp.adding ? 0 : 3; hi: 3
                fill: kp.adding ? Theme.gOn : Theme.gLeaf; pressable: true
                onClicked: { kp.adding = !kp.adding; if (kp.adding) newName.forceActiveFocus() }
                UiText { id: al; anchors.centerIn: parent; text: kp.adding ? "Cancel" : "+ Add"; px: 13; w: 700 }
            }
            UiText { id: msg; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; width: Math.min(implicitWidth, kp.width * 0.3)
                text: kp.recIndex !== -1 ? "Press the keys · Esc cancels" : kp.svc.bindMsg; fam: "n"; px: 11; w: 800
                color: kp.recIndex !== -1 ? Theme.purple : kp.svc.bindMsg.startsWith("Not") ? Theme.berry : Theme.leafDeep }
        }
        // filter chips (scroll sideways on the narrow phone)
        Flickable {
            width: parent.width; height: 30; clip: true
            contentWidth: chipRow.width; flickableDirection: Flickable.HorizontalFlick; boundsBehavior: Flickable.StopAtBounds
            Row {
                id: chipRow; spacing: 6
                Repeater {
                    model: [["all", "All"], ["dup", "Same keys · " + kp.dupCount], ["custom", "Mine"]].concat(kp.cats.filter(c => c !== "Custom").map(c => [c, c]))
                    delegate: UiCandy {
                        required property var modelData
                        readonly property bool on: kp.chip === modelData[0]
                        readonly property bool warn: modelData[0] === "dup" && kp.dupCount > 0
                        width: ct.implicitWidth + 22; height: 28; radius: 10; bw: 2; drop: on ? 0 : 2; hi: 0
                        fill: on ? Theme.gOn : warn ? Theme.pinkSoft : Theme.cream; pressable: true
                        onClicked: kp.chip = on && modelData[0] !== "all" ? "all" : modelData[0]
                        UiText { id: ct; anchors.centerIn: parent; text: modelData[1]; px: 12; w: 700 }
                    }
                }
            }
        }
        UiText { visible: kp.rows.length === 0; width: parent.width; height: 30; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
            text: kp.chip === "dup" ? "No two shortcuts share the same keys ✓" : "Nothing here"; fam: "n"; px: 12; w: 800; color: Theme.textSoft }
        // new shortcut: name + command, then record the keys
        UiCandy {
            visible: kp.adding
            width: parent.width; height: addCol.implicitHeight + 20; radius: 14; bw: 2.5; drop: 3; hi: 0; fill: Theme.gSun
            Column {
                id: addCol; x: 10; y: 10; width: parent.width - 20; spacing: 8
                UiText { text: "New shortcut"; px: 14; w: 700; height: 18 }
                Repeater {
                    model: [["Name, e.g. Open Discord", "n"], ["Command, e.g. discord", "c"]]
                    delegate: UiCandy {
                        required property var modelData
                        width: addCol.width; height: 32; radius: 10; bw: 2; drop: 0; hi: 0; fill: Theme.paper
                        TextInput {
                            id: ti; x: 10; width: parent.width - 20; anchors.verticalCenter: parent.verticalCenter; clip: true
                            font.family: Theme.body; font.weight: 800; font.pixelSize: 12; color: Theme.text
                            Component.onCompleted: if (modelData[1] === "n") kp.nameField = ti; else kp.cmdField = ti
                            UiText { visible: !ti.text; text: modelData[0]; fam: "n"; px: 11; w: 800; color: Theme.textSoft; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                }
                UiCandy {
                    width: rl.implicitWidth + 28; height: 32; radius: 10; bw: 2.5; drop: kp.recIndex === -2 ? 0 : 3; hi: 3
                    fill: kp.recIndex === -2 ? Theme.gLilac : Theme.gGo; pressable: true
                    onClicked: kp.recIndex === -2 ? kp.stopRec() : kp.startRec(-2)
                    UiText { id: rl; anchors.centerIn: parent; text: kp.recIndex === -2 ? "Press the keys now…" : "⌨  Record keys & save"; px: 13; w: 700; color: kp.recIndex === -2 ? Theme.text : "#FFFFFF" }
                }
            }
        }
        ListView {
            id: list
            width: parent.width; height: kp.listH - 40 - (kp.adding ? addCol.implicitHeight + 30 : 0)
            clip: true; spacing: 5; boundsBehavior: Flickable.StopAtBounds
            model: kp.rows
            delegate: Column {
                id: cell
                required property var modelData
                required property int index
                readonly property bool first: index === 0 || kp.rows[index - 1].category !== modelData.category
                width: list.width; spacing: 4
                UiText { visible: cell.first; width: list.width; height: 24; text: cell.modelData.category.toUpperCase(); fam: "n"; px: 11; w: 900; track: 1.4; color: Theme.textSoft; verticalAlignment: Text.AlignBottom }
            UiCandy {
                id: row
                readonly property var modelData: cell.modelData
                readonly property bool rec: kp.recIndex === modelData.index
                readonly property bool can: kp.editable(modelData)
                width: list.width; height: 40; radius: 12; bw: rec ? 2.5 : 2; drop: rec ? 2 : 0; hi: 0
                fill: rec ? Theme.gLilac : Theme.cream; pressable: can
                onClicked: rec ? kp.stopRec() : kp.startRec(modelData.index)
                UiText { x: 12; y: 0; height: row.height; width: row.width - chips.width - 30; text: row.modelData.desc || row.modelData.action; px: 13; w: 700 }
                Row {
                    id: chips
                    x: row.width - width - 10; y: (row.height - 24) / 2; height: 24; spacing: 4
                    Repeater {
                        model: row.rec ? ["…"] : row.modelData.keys.split(" + ").map(k => k.replace("CONTROL", "Ctrl").replace("SUPER", "Super").replace("SHIFT", "Shift").replace("ALT", "Alt")
                            .replace(/^code:1([0-8])$/, (m, d) => String(+d + 1)).replace("code:19", "0").replace("XF86Audio", "").replace("XF86MonBrightness", "Bright ").replace("XF86", ""))
                        delegate: UiCandy {
                            required property string modelData
                            width: kc.implicitWidth + 14; height: 24; radius: 7; bw: 2; drop: 2; hi: 0; fill: Theme.paper
                            UiText { id: kc; anchors.centerIn: parent; text: modelData; px: 11; w: 700 }
                        }
                    }
                    UiText { visible: row.modelData.action === "ws_digits"; text: "+ 1…9"; fam: "n"; px: 11; w: 900; anchors.verticalCenter: parent.verticalCenter }
                    // same keys as another shortcut: only one of them will work
                    UiCandy { visible: !!kp.dupSet[row.modelData.index]; width: 24; height: 24; bw: 2; drop: 0; hi: 0; fill: Theme.berry
                        UiText { anchors.centerIn: parent; text: "!"; px: 13; w: 700; color: "#FFFFFF" } }
                    // shortcuts you added can be removed
                    UiCandy { visible: row.modelData.category === "Custom"; width: 24; height: 24; bw: 2; drop: 0; hi: 0; fill: Theme.pinkSoft; pressable: true
                        onClicked: kp.svc.removeBind(row.modelData.index)
                        Glyph { anchors.centerIn: parent; name: "trash"; size: 12; stroke: 2.4 } }
                }
            }
            }
        }
    }
}
