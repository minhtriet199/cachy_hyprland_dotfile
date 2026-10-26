import QtQuick
import Quickshell
import Quickshell.Io

// Apps page: installed apps (InstalledApps.qml), default apps (tap a kind → pick from the apps that can open it) and startup apps
// (Island's own list with on/off, add = pick an installed app or type a command, remove; the ones Hyprland always starts are shown below).
// Data + changes: tools/apps.py. Startup list is started by hypr/config/startup_island.lua.
Item {
    id: ap
    property var svc
    implicitHeight: col.implicitHeight
    property var d: ({ defaults: [], startup: [], system: [] })
    property string open: ""            // which default kind is showing its choices
    property bool adding: false
    property bool ownCmd: false
    property string query: ""
    // startup apps picked from the list are saved as "uwsm app -- <id>.desktop" (same way Island search opens apps)
    function entryOf(cmd) { const m = /^uwsm app -- (.+)\.desktop$/.exec(cmd); return m ? m[1] : "" }
    readonly property var addedIds: d.startup.map(r => entryOf(r.cmd)).filter(x => x)
    readonly property var picks: {
        if (!adding) return [];
        const q = query.trim().toLowerCase();
        return DesktopEntries.applications.values.filter(e => !e.noDisplay && e.id && (!q || e.name.toLowerCase().includes(q) || e.id.toLowerCase().includes(q)))
            .sort((a, b) => q ? (b.name.toLowerCase().startsWith(q) - a.name.toLowerCase().startsWith(q)) || a.name.localeCompare(b.name) : a.name.localeCompare(b.name))
            .slice(0, q ? 8 : 6).map(e => ({ id: e.id.replace(/\.desktop$/, ""), name: e.name, icon: e.icon }));
    }
    function addApp(e) { if (addedIds.includes(e.id)) return; run(["add", e.name, "uwsm app -- " + e.id + ".desktop"]) }
    readonly property string tool: Quickshell.shellDir + "/tools/apps.py"
    function load() { getP.running = true }
    Component.onCompleted: load()
    Process { id: getP; command: ["python3", ap.tool, "get"]
        stdout: StdioCollector { onStreamFinished: { try { ap.d = JSON.parse(this.text) } catch (e) {} } } }
    Process { id: act; onExited: ap.load() }
    function run(args) { if (act.running) return; act.command = ["python3", tool].concat(args); act.running = true }
    readonly property var glyphs: ({ browser: "globe", files: "folder", video: "play", music: "music", images: "image", pdf: "box", text: "pencil" })

    component Label: UiText { fam: "n"; px: 11; w: 900; track: 1.4; color: Theme.textSoft; height: 18 }

    Column {
        id: col
        width: ap.width; spacing: 8

        InstalledApps { width: parent.width; svc: ap.svc }
        Item { width: 1; height: 4 }
        Label { text: "DEFAULT APPS · WHAT OPENS YOUR FILES" }
        Repeater {
            model: ap.d.defaults
            delegate: Column {
                id: dc
                required property var modelData
                width: col.width; spacing: 6
                UiRow {
                    width: parent.width; glyph: ap.glyphs[dc.modelData.cat] || "box"; title: dc.modelData.label
                    sub: dc.modelData.curName; active: ap.open === dc.modelData.cat; busy: act.running && ap.open === dc.modelData.cat
                    onClicked: ap.open = ap.open === dc.modelData.cat ? "" : dc.modelData.cat
                    Glyph { name: "arrowRight"; size: 15; stroke: 2.6; rotation: ap.open === dc.modelData.cat ? 90 : 0 }
                }
                Flow {
                    visible: ap.open === dc.modelData.cat
                    width: parent.width; spacing: 6; leftPadding: 10
                    Repeater {
                        model: dc.modelData.options
                        delegate: UiCandy {
                            required property var modelData
                            readonly property bool cur: modelData.id === dc.modelData.cur
                            width: ot.implicitWidth + 24; height: 30; radius: 10; bw: 2; drop: cur ? 0 : 2; hi: 0
                            fill: cur ? Theme.gOn : Theme.cream; pressable: !cur
                            onClicked: ap.run(["default", dc.modelData.cat, modelData.id])
                            UiText { id: ot; anchors.centerIn: parent; text: (parent.cur ? "✓ " : "") + modelData.name; px: 12.5; w: 700 }
                        }
                    }
                    UiText { visible: dc.modelData.options.length === 0; text: "No installed app opens these"; fam: "n"; px: 11.5; w: 800; color: Theme.textSoft; height: 30; verticalAlignment: Text.AlignVCenter }
                }
            }
        }

        Item { width: 1; height: 4 }
        Item {
            width: parent.width; height: 30
            Label { anchors.verticalCenter: parent.verticalCenter; width: parent.width - addB.width - 8; elide: Text.ElideRight; text: "STARTUP APPS" }
            UiCandy {
                id: addB
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                width: addT.implicitWidth + 22; height: 30; radius: 10; bw: 2.5; drop: ap.adding ? 0 : 3; hi: 3
                fill: ap.adding ? Theme.gOn : Theme.gLeaf; pressable: true
                onClicked: { ap.adding = !ap.adding; ap.query = ""; ap.ownCmd = false; if (ap.adding) Qt.callLater(() => findIn.forceActiveFocus()) }
                UiText { id: addT; anchors.centerIn: parent; text: ap.adding ? "Done" : "+ Add"; px: 12.5; w: 700 }
            }
        }
        UiText { width: parent.width; wrapMode: Text.Wrap; fam: "n"; px: 11; w: 800; color: Theme.textSoft
            text: ap.adding ? "Tap an app to open it every time you log in" : "These open by themselves every time you log in" }
        // add: pick an installed app (search) · or type your own command
        UiCandy {
            visible: ap.adding
            width: parent.width; height: addCol.implicitHeight + 20; radius: 14; bw: 2.5; drop: 3; hi: 0; fill: Theme.gSun
            Column {
                id: addCol; x: 10; y: 10; width: parent.width - 20; spacing: 6
                UiCandy {
                    width: addCol.width; height: 34; radius: 11; bw: 2; drop: 0; hi: 0; fill: Theme.paper
                    Glyph { x: 10; anchors.verticalCenter: parent.verticalCenter; name: "search"; size: 14; stroke: 2.6 }
                    TextInput {
                        id: findIn; x: 32; width: parent.width - 42; anchors.verticalCenter: parent.verticalCenter; clip: true
                        font.family: Theme.body; font.weight: 800; font.pixelSize: 13; color: Theme.text
                        onTextChanged: ap.query = text
                        onAccepted: if (ap.picks.length) ap.addApp(ap.picks[0])
                        UiText { visible: !findIn.text; text: "Search apps, e.g. Discord"; fam: "n"; px: 11.5; w: 800; color: Theme.textSoft; anchors.verticalCenter: parent.verticalCenter }
                    }
                }
                Repeater {
                    model: ap.picks
                    delegate: UiCandy {
                        required property var modelData
                        readonly property bool added: ap.addedIds.includes(modelData.id)
                        width: addCol.width; height: 40; radius: 12; bw: 2; drop: added ? 0 : 2; hi: 0
                        fill: added ? Theme.gOn : Theme.cream; pressable: !added
                        onClicked: ap.addApp(modelData)
                        Image { x: 9; anchors.verticalCenter: parent.verticalCenter; width: 24; height: 24; sourceSize: Qt.size(48, 48); asynchronous: true
                            source: Quickshell.iconPath(modelData.icon, "application-x-executable") }
                        UiText { x: 42; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 42 - tag.width - 16; elide: Text.ElideRight; text: modelData.name; px: 13; w: 700 }
                        UiText { id: tag; anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter
                            text: parent.added ? "✓ added" : "+ add"; fam: "n"; px: 11; w: 900; color: Theme.textSoft }
                    }
                }
                UiText { visible: !ap.picks.length; width: addCol.width; wrapMode: Text.Wrap; text: "No app called “" + ap.query + "”"; fam: "n"; px: 11.5; w: 800; color: Theme.textSoft }
                // own command (scripts, flags like --start-minimized)
                UiText { text: ap.ownCmd ? "▾ Own command" : "▸ Own command (advanced)"; fam: "n"; px: 11; w: 900; color: Theme.textSoft; height: 22; verticalAlignment: Text.AlignVCenter
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: ap.ownCmd = !ap.ownCmd } }
                Repeater {
                    model: ap.ownCmd ? [["Name, e.g. Discord", "n"], ["Command, e.g. discord --start-minimized", "c"]] : []
                    delegate: UiCandy {
                        required property var modelData
                        width: addCol.width; height: 32; radius: 10; bw: 2; drop: 0; hi: 0; fill: Theme.paper
                        TextInput {
                            id: ti; x: 10; width: parent.width - 20; anchors.verticalCenter: parent.verticalCenter; clip: true
                            font.family: Theme.body; font.weight: 800; font.pixelSize: 12; color: Theme.text
                            Component.onCompleted: if (modelData[1] === "n") nameIn.field = ti; else cmdIn.field = ti
                            onAccepted: saveBtn.save()
                            UiText { visible: !ti.text; width: parent.width; elide: Text.ElideRight; text: modelData[0]; fam: "n"; px: 11; w: 800; color: Theme.textSoft; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                }
                UiCandy {
                    id: saveBtn
                    visible: ap.ownCmd
                    function save() { if (!cmdIn.field || !cmdIn.field.text.trim()) return; ap.run(["add", nameIn.field.text, cmdIn.field.text]); nameIn.field.text = ""; cmdIn.field.text = "" }
                    width: svT.implicitWidth + 28; height: 32; radius: 10; bw: 2.5; drop: 3; hi: 3; fill: Theme.gGo; pressable: true
                    onClicked: save()
                    UiText { id: svT; anchors.centerIn: parent; text: "Add command"; px: 13; w: 700; color: "#FFFFFF" }
                }
            }
        }
        QtObject { id: nameIn; property var field: null }
        QtObject { id: cmdIn; property var field: null }

        Repeater {
            model: ap.d.startup
            delegate: UiRow {
                required property var modelData
                required property int index
                readonly property var entry: ap.entryOf(modelData.cmd)
                width: col.width; glyph: "external"; title: modelData.name
                sub: entry ? (modelData.on ? "Opens when you log in" : "Off") : modelData.cmd; active: modelData.on
                onClicked: ap.run(["toggle", String(index)])
                UiSwitch { on: modelData.on; onToggled: ap.run(["toggle", String(index)]) }
                UiCandy { width: 26; height: 26; bw: 2; drop: 0; hi: 0; fill: Theme.paper; pressable: true
                    onClicked: ap.run(["remove", String(index)])
                    Glyph { anchors.centerIn: parent; name: "trash"; size: 12; stroke: 2.6 } }
            }
        }
        UiText { visible: ap.d.startup.length === 0 && !ap.adding; width: parent.width; wrapMode: Text.Wrap; text: "Nothing yet · press + Add and tap an app"; fam: "n"; px: 11.5; w: 800; color: Theme.textSoft }
        Item { width: 1; height: 4 }

        Label { text: "ALWAYS STARTED BY THE SYSTEM" }
        Repeater {
            model: ap.d.system
            delegate: UiText {
                required property var modelData
                width: col.width; elide: Text.ElideRight; fam: "n"; px: 11; w: 800; color: Theme.textSoft
                text: "• " + (modelData.note ? modelData.note.split(";")[0] : modelData.cmd)
            }
        }
    }
}
