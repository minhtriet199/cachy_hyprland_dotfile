import QtQuick
import QtQuick.Layouts
import Quickshell

// Phone home = launcher + search in one screen. Type in the box: results replace the app grid right here.
// Tabs pick what to search: All (pages, apps, actions, files) · Apps · Files (by name) · Content (text inside files).
// Nothing found → "Search Google". ↑↓ choose · Enter opens · Esc clears / closes.
Item {
    id: home
    property var svc
    signal go(string screen)
    signal launch(var app)
    signal typed(string t)
    property int mode: 0                                   // 0 All · 1 Apps · 2 Files · 3 Content
    readonly property var modes: ["All", "Apps", "Files", "Content"]
    property string query: ""
    property int sel: 0
    focus: true
    function focusField() { field.forceActiveFocus() }
    // Tab anywhere on Home (also from an app tile): next search type, cursor back in the search box
    function tabKey(fwd) { mode = (mode + (fwd ? 1 : modes.length - 1)) % modes.length; focusField() }
    onVisibleChanged: if (!visible) { query = ""; field.text = ""; mode = 0 } else Qt.callLater(focusField)
    onQueryChanged: { sel = 0; refreshFiles() }
    onModeChanged: { sel = 0; refreshFiles(); focusField() }
    function refreshFiles() { if (mode === 2 || mode === 3 || (mode === 0 && query.length >= 3)) svc.searchFiles(query.trim(), mode === 3 ? "content" : "files"); else svc.searchFiles("", "files") }

    readonly property var r: svc.search(query)
    readonly property string q: query.trim()
    // flat list of rows for the current tab: { kind, … } (headers are rows too, but never selected)
    readonly property var rows: {
        if (!q) return [];
        const out = [], add = (title, items) => { if (items.length) { out.push({ kind: "header", title: title }); for (const it of items) out.push(it) } };
        if (r.math && mode <= 1) out.push({ kind: "math", title: r.math });
        if (mode === 0) { add("ISLA", r.pages); add("APPS", r.apps.slice(0, 5)); add("ACTIONS", r.actions); add("FILES", svc.fileHits.slice(0, 6).map(f => Object.assign({ kind: "file" }, f))) }
        else if (mode === 1) add("APPS", r.apps);
        else if (mode === 2) add("FILES & FOLDERS", svc.fileHits.map(f => Object.assign({ kind: "file" }, f)));
        else add("INSIDE FILES", svc.fileHits.map(f => Object.assign({ kind: "content" }, f)));
        if (!out.some(x => x.kind !== "header") && !(svc.fileBusy && mode >= 2)) out.push({ kind: "web", title: q });
        else if (mode <= 1) out.push({ kind: "web", title: q, small: true });
        return out;
    }
    readonly property var pickable: rows.map((x, i) => x.kind === "header" ? -1 : i).filter(i => i >= 0)
    readonly property int selRow: pickable.length ? pickable[Math.min(sel, pickable.length - 1)] : -1
    function activate(i, reveal) {
        const it = rows[i]; if (!it) return;
        if (it.kind === "page") home.go(it.screen);
        else if (it.kind === "app") home.launch({ entry: it.entry });
        else if (it.kind === "action") { svc.runAction(it); home.launch({ internal: "x" }) }
        else if (it.kind === "file" || it.kind === "content") { svc.openPath(it.path, reveal); home.launch({ internal: "x" }) }
        else if (it.kind === "math") svc.copy(it.title);
        else if (it.kind === "web") {
            const t = it.title, url = /^(https?:\/\/)?[\w-]+(\.[\w-]+)+(\/\S*)?$/.test(t) && !t.includes(" ") ? (/^https?:/.test(t) ? t : "https://" + t) : "https://www.google.com/search?q=" + encodeURIComponent(t);
            svc.openApp(["xdg-open", url]); home.launch({ internal: "x" });
        }
    }

    Column {
        id: top
        x: 18; y: 18; width: parent.width - 36
        spacing: 12
        PhoneStatus { svc: home.svc; right2: home.svc.wifi.on ? home.svc.wifi.ssid : "offline" }
        // what to search
        Item { width: parent.width; height: 49 + 6
            PhoneTabs { y: 6; labels: home.modes; current: home.mode; onPicked: i => home.mode = i } }
        // the search box (typing here searches in place)
        UiCandy {
            width: parent.width; height: 48
            ink: Theme.inkPhone; hiColor: Qt.rgba(1, 1, 1, 0.9)
            Glyph { x: 16; anchors.verticalCenter: parent.verticalCenter; name: "search"; size: 20; stroke: 2.5 }
            TextInput {
                id: field
                x: 46; width: parent.width - 46 - 46; anchors.verticalCenter: parent.verticalCenter; clip: true
                font.family: Theme.display; font.weight: 600; font.pixelSize: 16; color: Theme.text
                onTextChanged: home.query = text
                Keys.onUpPressed: home.sel = Math.max(0, home.sel - 1)
                Keys.onDownPressed: home.sel = Math.min(home.pickable.length - 1, home.sel + 1)
                Keys.onReturnPressed: e => home.activate(home.selRow, e.modifiers & Qt.ShiftModifier)
                Keys.onEnterPressed: home.activate(home.selRow, false)
                Keys.onEscapePressed: e => { if (text) text = ""; else e.accepted = false }
                Keys.onTabPressed: home.tabKey(true)
                Keys.onBacktabPressed: home.tabKey(false)
                UiText { visible: !field.text; anchors.verticalCenter: parent.verticalCenter; fam: "n"; w: 800; px: 14; color: Theme.textSoft
                    text: ["Search apps, settings and files…", "Search apps…", "Search file and folder names…", "Search text inside your files…"][home.mode] }
            }
            UiCandy { visible: field.text !== ""; x: parent.width - 38; anchors.verticalCenter: parent.verticalCenter; width: 26; height: 26; bw: 0; drop: 0; hi: 0; fill: "transparent"; pressable: true
                onClicked: { field.text = ""; home.focusField() }
                Glyph { anchors.centerIn: parent; name: "close"; size: 13; stroke: 2.8 } }
            // working on it (files / content)
            Glyph { visible: home.svc.fileBusy && field.text !== "" && home.mode >= 2; x: parent.width - 64; anchors.verticalCenter: parent.verticalCenter; name: "reload"; size: 15; stroke: 2.6
                RotationAnimation on rotation { running: parent.visible; loops: Animation.Infinite; from: 0; to: 360; duration: 900 } }
        }
    }

    // ── nothing typed: apps A–Z (Apps / All) or a hint (Files / Content) ──
    GridView {
        id: grid
        visible: home.q === "" && home.mode <= 1
        x: 18; y: top.y + top.height + 12; width: parent.width - 36
        height: home.height - y - 18 - ((home.svc.phoneBig && home.height > home.width) ? 52 : 4)
        cellWidth: width / Math.max(4, Math.floor(width / 110)); cellHeight: 98     // more columns on the wide (sideways) phone
        clip: true; boundsBehavior: Flickable.StopAtBounds
        model: home.svc.entries.slice().sort((a, b) => a.name.localeCompare(b.name))
        delegate: Item {
            required property var modelData
            width: grid.cellWidth; height: grid.cellHeight
            readonly property var look: home.svc.lookFor(modelData.startupClass || modelData.id)
            PhoneAppTile {
                anchors.horizontalCenter: parent.horizontalCenter
                label: parent.modelData.name
                glyph: parent.look[0] !== "grid" ? parent.look[0] : "grid"
                iconSource: parent.look[0] !== "grid" ? "" : Quickshell.iconPath(parent.modelData.icon, "application-x-executable")
                tint: parent.look[0] !== "grid" ? parent.look[1] : "#FFFFFF"
                onClicked: home.launch({ entry: parent.modelData })
            }
        }
    }
    Column {
        visible: home.q === "" && home.mode >= 2
        x: 18; y: top.y + top.height + 60; width: parent.width - 36; spacing: 10
        Glyph { anchors.horizontalCenter: parent.horizontalCenter; name: home.mode === 2 ? "folder" : "search"; size: 46; stroke: 2.2; color: Theme.textSoft }
        UiText { width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; fam: "n"; px: 13; w: 800; color: Theme.textSoft
            text: home.mode === 2 ? "Type part of a file or folder name.\nSearches your home folder (not hidden or cache folders)."
                                  : "Type a word to find it inside your files.\nSearches Documents, Desktop, Projects, Downloads and dotfiles." }
    }

    // ── results, right here ──
    ListView {
        id: list
        visible: home.q !== ""
        x: 18; y: top.y + top.height + 12; width: parent.width - 36
        height: home.height - y - 18 - ((home.svc.phoneBig && home.height > home.width) ? 52 : 26)          // room for the hint footer
        clip: true; spacing: 6; boundsBehavior: Flickable.StopAtBounds
        model: home.rows
        onCountChanged: positionViewAtBeginning()
        Connections { target: home; function onSelRowChanged() { if (home.selRow >= 0) list.positionViewAtIndex(home.selRow, ListView.Contain) } }
        delegate: Item {
            id: rowItem
            required property var modelData
            required property int index
            readonly property bool picked: index === home.selRow
            width: list.width
            height: modelData.kind === "header" ? 24 : modelData.kind === "web" && !modelData.small ? 230 : (modelData.kind === "content" ? 62 : 52)
            UiText { visible: rowItem.modelData.kind === "header"; y: 6; text: rowItem.modelData.title || ""; fam: "n"; w: 900; px: 11; track: 1.4; color: Theme.textSoft }
            // normal result row
            UiCandy {
                id: rc
                visible: rowItem.modelData.kind !== "header" && !(rowItem.modelData.kind === "web" && !rowItem.modelData.small)
                width: parent.width; height: parent.height - 4; radius: 16; bw: 2.5; ink: Theme.inkPhone; drop: rowItem.picked ? 3 : 0; hi: 0
                fill: rowItem.picked ? Theme.gGo : Theme.paper; pressable: true
                onClicked: home.activate(rowItem.index, false)
                onRightClicked: if (rowItem.modelData.kind === "file" || rowItem.modelData.kind === "content") home.activate(rowItem.index, true)
                readonly property string kind: rowItem.modelData.kind || ""
                readonly property color txt: rowItem.picked ? "#FFFFFF" : Theme.text
                UiCandy {
                    x: 8; anchors.verticalCenter: parent.verticalCenter; width: 34; height: 34; radius: 11; bw: 2; ink: Theme.inkPhone; drop: 0; hi: 0
                    fill: rc.kind === "page" ? (rowItem.modelData.tint || "#55BFC6") : rc.kind === "app" ? (rowItem.modelData.glyph ? (rowItem.modelData.tint || "#55BFC6") : "#FFFFFF")
                        : rc.kind === "action" ? (rowItem.modelData.tint || "#55BFC6") : rc.kind === "web" ? "#7C83F0" : rc.kind === "math" ? "#9AA7B0" : rowItem.modelData.isDir ? "#FFD45C" : "#D8F1F4"
                    Glyph { visible: !(rc.kind === "app" && !rowItem.modelData.glyph); anchors.centerIn: parent; size: 17; stroke: 2.4
                        color: rc.kind === "file" || rc.kind === "content" ? Theme.inkPhone : "#FFFFFF"
                        name: rc.kind === "web" ? "globe" : rc.kind === "math" ? "calc" : rc.kind === "file" ? (rowItem.modelData.isDir ? "folder" : "clipboard")
                            : rc.kind === "content" ? "search" : (rowItem.modelData.glyph || "grid") }
                    Image { visible: rc.kind === "app" && !rowItem.modelData.glyph; anchors.centerIn: parent; width: 24; height: 24; sourceSize: Qt.size(48, 48); source: rowItem.modelData.icon || "" }
                }
                Column {
                    x: 52; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 52 - 40
                    UiText { width: parent.width; height: 18; px: 14; w: 700; color: rc.txt
                        text: (rc.kind === "page" ? rowItem.modelData.title : rc.kind === "app" ? rowItem.modelData.name : rc.kind === "action" ? rowItem.modelData.title
                            : rc.kind === "web" ? "Search Google for “" + rowItem.modelData.title + "”" : rc.kind === "math" ? "= " + rowItem.modelData.title : rowItem.modelData.name) || "" }
                    UiText { width: parent.width; height: 15; fam: "n"; px: 10.5; w: 800; color: rowItem.picked ? Theme.adapt("#EFFFF0") : Theme.textSoft
                        text: rc.kind === "page" ? (rowItem.modelData.sub || "Isla settings") : rc.kind === "app" ? (rowItem.modelData.generic || "App") : rc.kind === "action" ? (rowItem.modelData.sub || "")
                            : rc.kind === "web" ? "Opens in your browser" : rc.kind === "math" ? "Enter copies the answer" : "~/" + (rowItem.modelData.dir || "") + (rowItem.modelData.lineNo ? " · line " + rowItem.modelData.lineNo : "") }
                    UiText { visible: rc.kind === "content"; width: parent.width; height: 15; text: rowItem.modelData.line || ""; px: 11; w: 600; color: rc.txt; font.family: "monospace" }
                }
                Glyph { visible: rowItem.picked; anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; name: "arrowRight"; size: 15; stroke: 2.8; color: "#FFFFFF" }
            }
            // nothing found: big Google card
            Column {
                visible: rowItem.modelData.kind === "web" && !rowItem.modelData.small
                width: parent.width; spacing: 10
                UiCandy {
                    width: parent.width; height: 52; radius: 26; bw: 3; ink: Theme.inkPhone; drop: rowItem.picked ? 4 : 2; hi: 3; fill: Theme.gLilacSoft; pressable: true
                    onClicked: home.activate(rowItem.index, false)
                    Rectangle { x: 10; anchors.verticalCenter: parent.verticalCenter; width: 32; height: 32; radius: 16; color: "#7C83F0"; border.width: 2.5; border.color: Theme.inkPhone
                        UiText { anchors.centerIn: parent; text: "G"; px: 15; w: 700; color: "#FFFFFF" } }
                    UiText { x: 52; width: parent.width - 100; anchors.verticalCenter: parent.verticalCenter; text: "Search Google for “" + (rowItem.modelData.title || "") + "”"; px: 15; w: 700; color: Theme.textDeep }
                    UiCandy { anchors.right: parent.right; anchors.rightMargin: 9; anchors.verticalCenter: parent.verticalCenter; width: 32; height: 32; bw: 2.5; ink: Theme.inkPhone; drop: 0; hi: 0; fill: Theme.paper
                        Glyph { anchors.centerIn: parent; name: "arrowRight"; size: 15; stroke: 2.8 } }
                }
                UiCandy { anchors.horizontalCenter: parent.horizontalCenter; width: 92; height: 92; bw: 3.5; ink: Theme.inkPhone; drop: 6; hi: 6; hiColor: Qt.rgba(1, 1, 1, 0.45); fill: "#7C83F0"
                    UiText { anchors.centerIn: parent; text: "G"; px: 44; w: 700; color: "#FFFFFF" } }
                UiText { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: home.mode >= 2 ? "No " + (home.mode === 2 ? "files" : "matches") + " found — search the web?" : "Nothing on this island — search the web?"; fam: "n"; px: 13; w: 800; color: Theme.textMuted }
            }
        }
    }

    // footer hints while searching
    Row {
        visible: home.q !== "" && !(home.svc.phoneBig && home.height > home.width)
        anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 10
        spacing: 12
        Repeater { model: home.mode >= 2 ? ["↵ open", "⇧↵ show in folder", "Tab type"] : ["↵ open", "↑↓ move", "Tab type", "Esc clear"]
            delegate: UiText { required property string modelData; text: modelData; fam: "n"; w: 800; px: 11; color: Theme.textSoft } }
    }
}
