import QtQuick
import Quickshell
import Quickshell.Io

// Apps page: default apps (tap a kind → pick from the apps that can open it) and startup apps
// (Island's own list with on/off, add by name + command, remove; the ones Hyprland always starts are shown below).
// Data + changes: tools/apps.py. Startup list is started by hypr/config/startup_island.lua.
Item {
    id: ap
    property var svc
    implicitHeight: col.implicitHeight
    property var d: ({ defaults: [], startup: [], system: [] })
    property string open: ""            // which default kind is showing its choices
    property bool adding: false
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
            Label { anchors.verticalCenter: parent.verticalCenter; text: "STARTUP APPS · OPEN WHEN YOU LOG IN" }
            UiCandy {
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                width: addT.implicitWidth + 22; height: 30; radius: 10; bw: 2.5; drop: ap.adding ? 0 : 3; hi: 3
                fill: ap.adding ? Theme.gOn : Theme.gLeaf; pressable: true
                onClicked: { ap.adding = !ap.adding; if (ap.adding) nameIn.forceActiveFocus() }
                UiText { id: addT; anchors.centerIn: parent; text: ap.adding ? "Cancel" : "+ Add"; px: 12.5; w: 700 }
            }
        }
        // add: name + command
        UiCandy {
            visible: ap.adding
            width: parent.width; height: addCol.implicitHeight + 20; radius: 14; bw: 2.5; drop: 3; hi: 0; fill: Theme.gSun
            Column {
                id: addCol; x: 10; y: 10; width: parent.width - 20; spacing: 8
                Repeater {
                    model: [["Name, e.g. Discord", "n"], ["Command, e.g. discord --start-minimized", "c"]]
                    delegate: UiCandy {
                        required property var modelData
                        width: addCol.width; height: 32; radius: 10; bw: 2; drop: 0; hi: 0; fill: Theme.paper
                        TextInput {
                            id: ti; x: 10; width: parent.width - 20; anchors.verticalCenter: parent.verticalCenter; clip: true
                            font.family: Theme.body; font.weight: 800; font.pixelSize: 12; color: Theme.text
                            Component.onCompleted: if (modelData[1] === "n") nameIn.field = ti; else cmdIn.field = ti
                            onAccepted: saveBtn.save()
                            UiText { visible: !ti.text; text: modelData[0]; fam: "n"; px: 11; w: 800; color: Theme.textSoft; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                }
                UiCandy {
                    id: saveBtn
                    function save() { if (!cmdIn.field || !cmdIn.field.text.trim()) return; ap.run(["add", nameIn.field.text, cmdIn.field.text]); nameIn.field.text = ""; cmdIn.field.text = ""; ap.adding = false }
                    width: svT.implicitWidth + 28; height: 32; radius: 10; bw: 2.5; drop: 3; hi: 3; fill: Theme.gGo; pressable: true
                    onClicked: save()
                    UiText { id: svT; anchors.centerIn: parent; text: "Save"; px: 13; w: 700; color: "#FFFFFF" }
                }
            }
        }
        QtObject { id: nameIn; property var field: null; function forceActiveFocus() { if (field) field.forceActiveFocus() } }
        QtObject { id: cmdIn; property var field: null }

        Repeater {
            model: ap.d.startup
            delegate: UiRow {
                required property var modelData
                required property int index
                width: col.width; glyph: "external"; title: modelData.name; sub: modelData.cmd; active: modelData.on
                onClicked: ap.run(["toggle", String(index)])
                UiSwitch { on: modelData.on; onToggled: ap.run(["toggle", String(index)]) }
                UiCandy { width: 26; height: 26; bw: 2; drop: 0; hi: 0; fill: Theme.paper; pressable: true
                    onClicked: ap.run(["remove", String(index)])
                    Glyph { anchors.centerIn: parent; name: "trash"; size: 12; stroke: 2.6 } }
            }
        }
        UiText { visible: ap.d.startup.length === 0 && !ap.adding; width: parent.width; text: "Nothing added yet · press + Add"; fam: "n"; px: 11.5; w: 800; color: Theme.textSoft }

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
