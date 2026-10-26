import QtQuick
import Quickshell
import Quickshell.Io

// Installed apps (top of the Apps page), like Windows "Installed apps" / Android "App info":
// search, All / Apps / Games / Tools, sort by size · name · newest; tap one → its folders + sizes,
// Open, Clear cache, Uninstall (pacman: your password via Island's prompt · Steam: Steam asks).
// Data: tools/installed.py (list ~0.6 s when the page opens; a row's folders only when you open it).
Item {
    id: ia
    property var svc
    property bool wide: width >= 600
    implicitHeight: col.implicitHeight
    readonly property string tool: Quickshell.shellDir + "/tools/installed.py"
    property var all: []
    property string filter: "all"
    property string sort: "size"
    property string query: ""
    property bool showAll: false
    property string openId: ""
    property var info: null                 // folders of the open one
    property string confirm: ""            // "cache" / "remove" waiting for the second tap
    property string msg: ""
    function load() { listP.running = true }
    Component.onCompleted: load()
    Process { id: listP; command: ["python3", ia.tool, "list"]
        stdout: StdioCollector { onStreamFinished: { try { ia.all = JSON.parse(this.text) } catch (e) {} } } }
    Process { id: infoP; stdout: StdioCollector { onStreamFinished: { try { ia.info = JSON.parse(this.text) } catch (e) {} } } }
    Process { id: actP
        property string what: ""
        stderr: StdioCollector { id: actErr }
        onExited: code => { ia.confirm = "";
            ia.msg = code === 0 ? (what === "cache" ? "Cache cleared ✓" : "Uninstalled ✓") : code === 126 || code === 127 ? "Cancelled" : "Not done — " + actErr.text.trim().split("\n").pop().slice(0, 90)
            if (code === 0 && what === "remove") ia.openId = ""; ia.load(); if (ia.openId) ia.pick(ia.openId, true) } }

    function gb(b) { return b >= 1e9 ? (b / 1e9).toFixed(1) + " GB" : b >= 1e6 ? Math.round(b / 1e6) + " MB" : b > 0 ? Math.round(b / 1e3) + " KB" : "—" }
    function day(t) { return t ? new Date(t * 1000).toLocaleDateString(Qt.locale("en_GB"), "d MMM yyyy") : "" }
    readonly property var shown: {
        const q = query.toLowerCase();
        const l = all.filter(a => (filter === "all" ? a.kind !== "tool" : filter === "apps" ? (a.kind === "app" || a.kind === "shortcut") : filter === "games" ? a.kind === "game" : a.kind === "tool")
                              && (!q || (a.name + " " + a.pkg).toLowerCase().includes(q)));
        return l.sort(sort === "name" ? (a, b) => a.name.localeCompare(b.name) : sort === "new" ? (a, b) => b.date - a.date : (a, b) => b.size - a.size);
    }
    readonly property real total: shown.reduce((s, a) => s + a.size, 0)
    function pick(id, keep) {
        if (!keep && openId === id) { openId = ""; return }
        openId = id; confirm = ""; if (!keep) { msg = ""; info = null }
        infoP.running = false; infoP.command = ["python3", tool, "info", id]; infoP.running = true
    }
    function uninstall(a) {
        if (a.source === "Steam") { Quickshell.execDetached(["steam", "steam://uninstall/" + a.appid]); msg = "Steam will ask to confirm"; confirm = ""; return }
        actP.what = "remove"; actP.command = ["pkexec", "pacman", "-Rns", "--noconfirm", a.pkg]; msg = "Uninstalling…"; actP.running = true
    }
    function clearCache(a) { actP.what = "cache"; actP.command = ["python3", tool, "clearcache", a.id]; actP.running = true }

    component Label: UiText { fam: "n"; px: 11; w: 900; track: 1.4; color: Theme.textSoft; height: 18 }
    component Chip: UiCandy {
        id: chip
        property string t
        property bool on
        width: ct.implicitWidth + 22; height: 30; radius: 10; bw: 2; drop: on ? 2 : 0; hi: 0; fill: on ? Theme.gOn : Theme.cream; pressable: true
        UiText { id: ct; anchors.centerIn: parent; text: chip.t; px: 12; w: 700 }
    }

    Column {
        id: col
        width: ia.width; spacing: 8

        Label { text: "INSTALLED APPS · " + ia.shown.length + " · " + ia.gb(ia.total) }
        // search + filters + sort
        Flow {
            width: parent.width; spacing: 6
            UiCandy {
                width: ia.wide ? 200 : parent.width; height: 30; radius: 10; bw: 2; drop: 0; hi: 0; fill: Theme.paper
                Glyph { x: 9; anchors.verticalCenter: parent.verticalCenter; name: "search"; size: 13; stroke: 2.6 }
                TextInput { id: qIn; x: 28; width: parent.width - 36; anchors.verticalCenter: parent.verticalCenter; clip: true
                    font.family: Theme.body; font.weight: 800; font.pixelSize: 12; color: Theme.text
                    onTextChanged: { ia.query = text; ia.showAll = false }
                    UiText { visible: !qIn.text; text: "Search apps"; fam: "n"; px: 11; w: 800; color: Theme.textSoft; anchors.verticalCenter: parent.verticalCenter } }
            }
            Repeater { model: [["all", "All"], ["apps", "Apps"], ["games", "Games"], ["tools", "Steam tools"]]
                delegate: Chip { required property var modelData; t: modelData[1]; on: ia.filter === modelData[0]; onClicked: { ia.filter = modelData[0]; ia.showAll = false } } }
            Chip { t: "↓ " + ({ size: "Size", name: "Name", new: "Newest" })[ia.sort]; on: false
                onClicked: ia.sort = ({ size: "name", name: "new", new: "size" })[ia.sort] }
        }
        UiText { visible: listP.running && !ia.all.length; text: "Looking…"; fam: "n"; px: 12; w: 800; color: Theme.textSoft }

        Repeater {
            model: ia.showAll ? ia.shown : ia.shown.slice(0, 8)
            delegate: Column {
                id: rc
                required property var modelData
                readonly property bool isOpen: ia.openId === modelData.id
                width: col.width; spacing: 6
                UiCandy {
                    width: parent.width; height: 50; radius: 15; bw: 2.5; drop: rc.isOpen ? 0 : 3; hi: 0
                    fill: rc.isOpen ? Theme.inkPhone : Theme.cream; pressable: true
                    onClicked: ia.pick(rc.modelData.id)
                    UiCandy { x: 9; anchors.verticalCenter: parent.verticalCenter; width: 32; height: 32; bw: 2; drop: 0; hi: 0; fill: Theme.paper
                        Image { anchors.centerIn: parent; width: 22; height: 22; sourceSize: Qt.size(44, 44); asynchronous: true
                            source: Quickshell.iconPath(rc.modelData.icon, rc.modelData.kind === "game" ? "applications-games" : "application-x-executable") } }
                    Column { x: 50; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 50 - sz.width - 24
                        UiText { width: parent.width; elide: Text.ElideRight; text: rc.modelData.name; px: 14; w: 700; height: 17; color: rc.isOpen ? "#FFFFFF" : Theme.text }
                        UiText { width: parent.width; elide: Text.ElideRight; fam: "n"; px: 10.5; w: 800; height: 14; color: rc.isOpen ? Qt.rgba(1, 1, 1, 0.75) : Theme.textSoft
                            text: [rc.modelData.source, rc.modelData.version, ia.day(rc.modelData.date)].filter(x => x).join(" · ") } }
                    UiText { id: sz; anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
                        text: ia.gb(rc.modelData.size); px: 13; w: 700; color: rc.isOpen ? "#FFFFFF" : Theme.text }
                }
                // details
                UiCandy {
                    visible: rc.isOpen
                    width: parent.width; height: det.implicitHeight + 20; radius: 14; bw: 2.5; drop: 3; hi: 0; fill: Theme.paper
                    Column {
                        id: det; x: 12; y: 10; width: parent.width - 24; spacing: 6
                        UiText { visible: text !== ""; width: parent.width; wrapMode: Text.Wrap; text: rc.modelData.desc; fam: "n"; px: 11; w: 800; color: Theme.textSoft }
                        UiText { visible: !ia.info; text: "Measuring…"; fam: "n"; px: 11; w: 800; color: Theme.textSoft }
                        Repeater {
                            model: rc.isOpen && ia.info ? ia.info.dirs : []
                            // a folder: tap = open it in your Files app (folder mark + ↗, highlight on hover)
                            delegate: Item {
                                required property var modelData
                                width: det.width; height: 26
                                Rectangle { anchors.fill: parent; radius: 8; color: Theme.cream; border.width: 2; border.color: Theme.inkPhone; visible: pathMa.containsMouse }
                                Glyph { x: 6; anchors.verticalCenter: parent.verticalCenter; name: "folder"; size: 13; stroke: 2.4; color: pathMa.containsMouse ? Theme.seaDeep : Theme.textSoft }
                                UiText { x: 26; width: parent.width - 26 - 84; elide: Text.ElideMiddle; anchors.verticalCenter: parent.verticalCenter; px: 12; w: 700
                                    color: pathMa.containsMouse ? Theme.seaDeep : Theme.text
                                    text: modelData.label + "  ·  " + modelData.path.replace(Quickshell.env("HOME"), "~") }
                                UiText { anchors.right: parent.right; anchors.rightMargin: 26; anchors.verticalCenter: parent.verticalCenter; text: ia.gb(modelData.size); px: 12; w: 700 }
                                Glyph { anchors.right: parent.right; anchors.rightMargin: 7; anchors.verticalCenter: parent.verticalCenter; name: "external"; size: 12; stroke: 2.4; color: pathMa.containsMouse ? Theme.seaDeep : Theme.textSoft }
                                MouseArea { id: pathMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ia.svc.openPath(modelData.path) }
                            }
                        }
                        UiText { visible: !!ia.info && ia.info.dirs.length === 0 && rc.modelData.source !== "Steam"; text: "No folders of its own in your home"; fam: "n"; px: 11; w: 800; color: Theme.textSoft }
                        UiText { visible: !rc.modelData.removable && rc.modelData.source !== "Shortcut" && rc.modelData.source !== "Steam"; width: parent.width; wrapMode: Text.Wrap
                            text: "Installed as part of another package or the desktop, so it can't be removed here."; fam: "n"; px: 10.5; w: 800; color: Theme.textSoft }
                        UiText { visible: ia.msg !== ""; text: ia.msg; fam: "n"; px: 11; w: 900; color: ia.msg.startsWith("Not") ? Theme.berry : Theme.leafDeep }
                        Flow {
                            width: parent.width; spacing: 6
                            readonly property real cache: ia.info ? ia.info.dirs.filter(d => d.cache).reduce((s, d) => s + d.size, 0) : 0
                            Chip { t: ia.info && ia.info.running ? "Running · Open" : "Open"; on: false; visible: !!rc.modelData.exec; onClicked: ia.svc.openApp(["sh", "-c", rc.modelData.exec]) }   // exec has arguments (steam steam://…)
                            // a running app keeps writing its cache: close it first
                            Chip { readonly property bool busy: !!ia.info && ia.info.running
                                t: busy ? "Close it to clear cache" : ia.confirm === "cache" ? "Tap again · clear " + ia.gb(parent.cache) : "Clear cache " + ia.gb(parent.cache)
                                on: ia.confirm === "cache"; opacity: busy ? 0.55 : 1; pressable: !busy
                                visible: parent.cache > 0; onClicked: { if (ia.confirm !== "cache") { ia.confirm = "cache"; return } ia.clearCache(rc.modelData) } }
                            UiCandy {
                                visible: rc.modelData.removable
                                width: ut.implicitWidth + 24; height: 30; radius: 10; bw: 2.5; drop: 2; hi: 0; pressable: !actP.running
                                fill: ia.confirm === "remove" ? [Theme.berry, Theme.berry] : Theme.gPeach
                                onClicked: { if (ia.confirm !== "remove") { ia.confirm = "remove"; return } ia.uninstall(rc.modelData) }
                                UiText { id: ut; anchors.centerIn: parent; px: 12; w: 700; color: ia.confirm === "remove" ? "#FFFFFF" : Theme.text
                                    text: ia.confirm === "remove" ? "Tap again to uninstall" : "Uninstall" }
                            }
                        }
                    }
                }
            }
        }
        Chip { visible: !ia.showAll && ia.shown.length > 8; t: "Show all " + ia.shown.length; on: false; onClicked: ia.showAll = true }
        UiText { visible: !listP.running && ia.shown.length === 0; text: "Nothing found"; fam: "n"; px: 12; w: 800; color: Theme.textSoft }
    }
}
