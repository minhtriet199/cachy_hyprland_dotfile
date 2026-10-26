import QtQuick

// Search (canvas "Phone-Search"): apps, actions, quick math. Type → ↑↓ → Enter.
Item {
    id: s
    property var svc
    property string query: ""
    property int sel: 0
    signal go(string screen)
    signal done()
    readonly property var results: svc.search(query)
    readonly property var flat: results.apps.concat(results.actions)
    // web search: when nothing on the island matches, or when the query starts with "web "
    readonly property var engines: [["Google", "https://www.google.com/search?q=", "#7C83F0"], ["DuckDuckGo", "https://duckduckgo.com/?q=", "#F2A07B"],
                                    ["YouTube", "https://www.youtube.com/results?search_query=", "#EE7D9C"], ["GitHub", "https://github.com/search?q=", "#5E7A84"],
                                    ["Wikipedia", "https://en.wikipedia.org/w/index.php?search=", "#9AA7B0"], ["ArchWiki", "https://wiki.archlinux.org/index.php?search=", "#55BFC6"]]
    property int eng: 0
    readonly property bool webPrefix: /^web\s/i.test(query)
    readonly property string webQ: (webPrefix ? query.replace(/^web\s+/i, "") : query).trim()
    readonly property bool isUrl: /^(https?:\/\/)?[\w-]+(\.[\w-]+)+(\/\S*)?$/.test(webQ) && !webQ.includes(" ")
    readonly property bool webMode: query.trim() !== "" && (webPrefix || (flat.length === 0 && results.math === ""))
    function openWeb() {
        if (!webQ) return;
        const url = isUrl ? (/^https?:/.test(webQ) ? webQ : "https://" + webQ) : engines[eng][1] + encodeURIComponent(webQ);
        svc.openApp(["xdg-open", url]); s.done();
    }
    function activate(i) {
        const it = flat[i]; if (!it) return;
        if (it.kind === "app") svc.launchEntry(it); else svc.runAction(it);
        s.done();
    }
    function focusField() { field.forceActiveFocus() }
    onQueryChanged: { sel = 0; if (field.text !== query) field.text = query }
    onVisibleChanged: if (!visible) { query = ""; eng = 0 }          // start fresh every time the phone opens
    Keys.forwardTo: [field]

    Column {
        x: 18; y: 16; width: parent.width - 36
        spacing: 11
        PhoneStatus { svc: s.svc; timePx: 16 }
        // field
        Item {
            width: parent.width; height: 50 + 10
            Item { y: 10; width: parent.width; height: 50
            Rectangle { x: -4; y: -4; width: parent.width + 8; height: parent.height + 8; radius: 30; color: "#BFE6C2" }
            UiCandy {
                anchors.fill: parent; bw: 3; ink: Theme.ink; drop: 4; dropColor: Theme.leafDeep; hi: 0
                Glyph { x: 16; anchors.verticalCenter: parent.verticalCenter; name: "search"; size: 20; stroke: 2.5 }
                TextInput {
                    id: field
                    x: 46; width: parent.width - 46 - 60; anchors.verticalCenter: parent.verticalCenter
                    font.family: Theme.display; font.weight: 600; font.pixelSize: 18; color: Theme.text
                    selectionColor: Theme.seaSoft; selectedTextColor: Theme.text
                    clip: true
                    onTextChanged: if (s.query !== text) s.query = text
                    Component.onCompleted: text = s.query
                    Keys.onUpPressed: s.sel = Math.max(0, s.sel - 1)
                    Keys.onDownPressed: s.sel = Math.min(s.flat.length - 1, s.sel + 1)
                    Keys.onReturnPressed: s.webMode ? s.openWeb() : s.activate(s.sel)
                    Keys.onEnterPressed: s.webMode ? s.openWeb() : s.activate(s.sel)
                    Keys.onTabPressed: e => { if (s.webMode) { s.eng = (s.eng + 1) % s.engines.length; e.accepted = true } else e.accepted = false }
                    Keys.onEscapePressed: { if (s.query !== "") s.query = ""; else s.svc.phoneEsc() }   // overlay: close · window: back
                    UiText { visible: field.text === ""; text: "Type to search…"; px: 18; w: 600; color: Theme.textSoft; anchors.verticalCenter: parent.verticalCenter }
                }
                PhoneKeycap { anchors.right: parent.right; anchors.rightMargin: 8 + 3; anchors.verticalCenter: parent.verticalCenter
                    text: "Esc"; px: 12; height: 30; radius: 10; ink: Theme.ink; onClicked: s.svc.phoneEsc() }   // = the Esc key: overlay closes, window goes back
            }
            }
        }
        // math answer
        PhoneRow {
            visible: s.results.math !== ""
            glyph: "calc"; tint: "#9AA7B0"; title: s.results.math; sub: "Enter copies the answer"
            onClicked: s.svc.copy(s.results.math)
        }
        UiText { visible: s.results.apps.length > 0; text: "APPS"; fam: "n"; w: 900; px: 11; track: 1.4; color: Theme.textSoft; topPadding: 4 }
        Repeater {
            model: s.results.apps
            delegate: PhoneRow {
                required property var modelData
                required property int index
                selected: index === s.sel
                glyph: modelData.glyph; tint: modelData.tint; iconSource: modelData.glyph ? "" : (modelData.icon || "")
                title: modelData.name; sub: modelData.generic || ""
                onClicked: s.activate(index)
            }
        }
        UiText { visible: s.results.actions.length > 0; text: "ACTIONS"; fam: "n"; w: 900; px: 11; track: 1.4; color: Theme.textSoft; topPadding: 4 }
        Repeater {
            model: s.results.actions
            delegate: PhoneRow {
                required property var modelData
                required property int index
                selected: index + s.results.apps.length === s.sel
                glyph: modelData.glyph; tint: modelData.tint; title: modelData.title; sub: modelData.sub
                onClicked: s.activate(index + s.results.apps.length)
            }
        }
        // web: one big "Search …" row …
        UiCandy {
            visible: s.webMode
            width: parent.width; height: 52; radius: 26; bw: 3; ink: Theme.inkPhone; drop: 4; hi: 3; fill: Theme.gLilacSoft; pressable: true
            onClicked: s.openWeb()
            Rectangle { x: 10; anchors.verticalCenter: parent.verticalCenter; width: 32; height: 32; radius: 16; color: s.engines[s.eng][2]; border.width: 2.5; border.color: Theme.inkPhone
                UiText { anchors.centerIn: parent; text: s.isUrl ? "↗" : s.engines[s.eng][0].charAt(0); px: 15; w: 700; color: "#FFFFFF" } }
            UiText { x: 52; width: parent.width - 52 - 48; anchors.verticalCenter: parent.verticalCenter
                text: s.isUrl ? "Open " + s.webQ : "Search “" + s.webQ + "”"; px: 15; w: 700; color: Theme.textDeep }
            UiCandy { anchors.right: parent.right; anchors.rightMargin: 9; anchors.verticalCenter: parent.verticalCenter; width: 32; height: 32; bw: 2.5; ink: Theme.inkPhone; drop: 0; hi: 0; fill: Theme.paper
                Glyph { anchors.centerIn: parent; name: "arrowRight"; size: 15; stroke: 2.8 } }
        }
        // … and the engine card in the empty space
        Column {
            visible: s.webMode
            width: parent.width; topPadding: 60; spacing: 10
            UiCandy { anchors.horizontalCenter: parent.horizontalCenter; width: 112; height: 112; bw: 3.5; ink: Theme.inkPhone; drop: 7; hi: 6; hiColor: Qt.rgba(1, 1, 1, 0.45); fill: s.engines[s.eng][2]
                Behavior on fill { ColorAnimation { duration: 200 } }
                UiText { anchors.centerIn: parent; text: s.isUrl ? "↗" : s.engines[s.eng][0].charAt(0); px: 54; w: 700; color: "#FFFFFF" } }
            UiText { anchors.horizontalCenter: parent.horizontalCenter; text: s.isUrl ? "Web address" : s.engines[s.eng][0]; px: 28; w: 700; color: Theme.textDeep }
            UiText { anchors.horizontalCenter: parent.horizontalCenter; text: s.flat.length === 0 && !s.webPrefix ? "Nothing on this island — search the web?" : "Type what to search for."; fam: "n"; px: 13; w: 800; color: Theme.textMuted }
            UiText { width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap
                text: "Tab switches the search engine · a web address opens directly."; fam: "n"; px: 12; w: 800; color: Theme.textSoft }
            UiTag { anchors.horizontalCenter: parent.horizontalCenter; text: "Tab ⇆ next engine"; fill: Theme.sun; ink: Theme.inkPhone; textColor: Theme.textDeep; px: 13; tilt: -4 }
        }
    }
    // footer
    Row {
        anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 12 + 6 + 11
        spacing: 14
        Repeater { model: ["↵ open", "↑↓ move", "Esc back"]
            delegate: UiText { required property string modelData; text: modelData; fam: "n"; w: 800; px: 12; color: Theme.textSoft } }
    }
    Rectangle { anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 12; width: 110; height: 6; radius: 3; color: Theme.ink; opacity: 0.35 }
}
