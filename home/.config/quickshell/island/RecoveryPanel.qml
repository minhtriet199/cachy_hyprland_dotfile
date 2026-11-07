import QtQuick
import Quickshell
import Quickshell.Io

// Recovery page: all snapshots in one place, tools/snapshot.py behind every tab.
// Desktop = Island's own setup backups: Restore asks once more, saves the current setup first, restarts Island.
// CachyOS / Home = Snapper (root helper, one-time setup): list, add, delete, and Home's schedule. Restoring those stays in Btrfs Assistant.
Item {
    id: rc
    property var svc
    implicitHeight: col.implicitHeight
    property var list: []
    property var sys: ({})              // Snapper data, loaded the first time its tab opens
    property bool sysLoaded: false
    property string tab: "Desktop"
    readonly property bool snap: tab !== "Desktop"
    readonly property string cfg: tab === "Home" ? "home" : "root"
    readonly property var rows: snap ? sys[cfg] || [] : list
    readonly property bool needSetup: snap && sysLoaded && !sys.ready
    readonly property var everyOf: ({ "Off": "off", "1 hour": "1", "6 hours": "6", "Day": "24" })
    onSnapChanged: if (snap && !sysLoaded) sysP.running = true
    property bool adding: false
    property string sure: ""            // id waiting for the second tap on Restore
    property string restoring: ""
    readonly property string tool: Quickshell.shellDir + "/tools/snapshot.py"
    function load() { getP.running = true; if (sysLoaded) sysP.running = true }
    Component.onCompleted: load()
    Process { id: getP; command: ["python3", rc.tool, "list"]
        stdout: StdioCollector { onStreamFinished: { try { rc.list = JSON.parse(this.text) } catch (e) {} } } }
    Process { id: sysP; command: ["python3", rc.tool, "btrfs"]
        stdout: StdioCollector { onStreamFinished: { try { rc.sys = JSON.parse(this.text) } catch (e) { rc.sys = {} } rc.sysLoaded = true } } }
    Process { id: act; onExited: rc.load() }
    function run(args) { if (act.running) return; act.command = ["python3", tool].concat(args); act.running = true }
    function save(name) { run(snap ? ["root", "create", cfg, name] : ["create", name]) }
    function remove(s) {
        if (!snap) { run(["delete", s.id]); return }
        if (sure !== "d" + s.id) { sure = "d" + s.id; sureT.restart(); return }
        sure = ""; run(["root", "delete", cfg].concat(s.nums.map(String)))
    }
    function restore(s) {
        if (sure !== s.id) { sure = s.id; sureT.restart(); return }
        sure = ""; restoring = s.id
        Quickshell.execDetached(["python3", tool, "restore", s.id])     // detached: it restarts Island
    }
    Timer { id: sureT; interval: 3000; onTriggered: rc.sure = "" }
    function size(b) { return b < 1048576 ? Math.round(b / 1024) + " KB" : (b / 1048576).toFixed(1) + " MB" }

    component Label: UiText { fam: "n"; px: 11; w: 900; track: 1.4; color: Theme.textSoft; height: 18 }

    Column {
        id: col
        width: rc.width; spacing: 8

        SetSeg { width: parent.width; label: "Show"; options: ["Desktop", "CachyOS", "Home"]; current: rc.tab
            onPicked: v => { rc.tab = v; rc.adding = false; rc.sure = "" } }
        UiText {
            width: parent.width; wrapMode: Text.WordWrap; fam: "n"; px: 10.5; w: 800; color: Theme.textSoft
            text: rc.tab === "Desktop" ? "Island, the login screen, Hyprland (keys, windows, displays), themes and your Island settings. Not your clipboard or wallpapers. Made when you press + Snapshot. Restoring saves the current setup first, so you can always go back. The newest 10 automatic snapshots are kept."
                : rc.tab === "CachyOS" ? "The whole system except your home folder. Made automatically before and after every app install, removal or update. To roll back, use Btrfs Assistant."
                : "Your whole home folder, games included, so old game files stay on disk until every snapshot holding them is deleted. Each one takes under a second. To get files back, use Btrfs Assistant."
        }
        // no helper yet: one-time setup
        UiCandy {
            visible: rc.needSetup
            width: parent.width; height: setupCol.implicitHeight + 18; radius: 13; bw: 2; drop: 0; hi: 0; fill: Theme.sand
            Column {
                id: setupCol
                x: 10; y: 9; width: parent.width - 20; spacing: 6
                UiText { width: parent.width; wrapMode: Text.Wrap; fam: "n"; px: 11; w: 800; color: Theme.textMuted
                    text: "These snapshots need root. Run the one-time setup in a terminal (copies 2 commands), then reopen this page:" }
                UiCandy { width: cpT.implicitWidth + 24; height: 28; radius: 9; bw: 2; drop: 2; hi: 0; fill: Theme.paper; pressable: true
                    onClicked: { rc.svc.run(["wl-copy", "sudo install -m 755 -o root ~/.config/quickshell/island/tools/snapper-if.src /usr/local/bin/island-snapper && sudo install -m 440 -o root ~/.config/quickshell/island/tools/snapper-if.sudoers.src /etc/sudoers.d/island-snapper"]); cpT.text = "Copied" }
                    UiText { id: cpT; anchors.centerIn: parent; text: "Copy setup command"; px: 12; w: 700 } }
            }
        }
        // Home's schedule (changing Keep lets snapper-cleanup remove older automatic ones within the hour)
        SetSeg { visible: rc.tab === "Home" && !!rc.sys.ready; width: parent.width; label: "Every"; options: ["Off", "1 hour", "6 hours", "Day"]
            current: Object.keys(rc.everyOf).find(k => rc.everyOf[k] === rc.sys.every) || ""
            onPicked: v => rc.run(["root", "every", rc.everyOf[v]]) }
        SetSeg { visible: rc.tab === "Home" && !!rc.sys.ready; width: parent.width; label: "Keep"; options: ["5", "10", "20"]; current: rc.sys.keep || ""
            onPicked: v => rc.run(["root", "keep", v]) }
        UiText {
            visible: rc.tab === "Home" && !!rc.sys.ready
            width: parent.width; wrapMode: Text.WordWrap; fam: "n"; px: 10.5; w: 800; color: Theme.textSoft
            text: "Now keeping: " + (rc.sys.limits || "nothing automatic") + ". Keep sets hourly and daily to that number with no monthly or yearly ones, and older automatic snapshots go within the hour."
        }

        Item {
            visible: !rc.needSetup
            width: parent.width; height: 30
            Label { anchors.verticalCenter: parent.verticalCenter; text: rc.snap && !rc.sysLoaded ? "LOADING…" : "SNAPSHOTS · " + rc.rows.length }
            UiCandy {
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                width: addT.implicitWidth + 22; height: 30; radius: 10; bw: 2.5; drop: rc.adding ? 0 : 3; hi: 3
                fill: rc.adding ? Theme.gOn : Theme.gLeaf; pressable: !act.running
                onClicked: { rc.adding = !rc.adding; if (rc.adding) nameIn.forceActiveFocus() }
                UiText { id: addT; anchors.centerIn: parent; text: act.running ? "Saving…" : rc.adding ? "Cancel" : "+ Snapshot"; px: 12.5; w: 700 }
            }
        }
        // new snapshot: optional name
        UiCandy {
            visible: rc.adding
            width: parent.width; height: 52; radius: 14; bw: 2.5; drop: 3; hi: 0; fill: Theme.gSun
            UiCandy {
                x: 10; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 20 - saveBtn.width - 8; height: 32; radius: 10; bw: 2; drop: 0; hi: 0; fill: Theme.paper
                TextInput {
                    id: nameIn; x: 10; width: parent.width - 20; anchors.verticalCenter: parent.verticalCenter; clip: true
                    font.family: Theme.body; font.weight: 800; font.pixelSize: 12; color: Theme.text
                    onAccepted: saveBtn.save()
                    Keys.onEscapePressed: rc.adding = false
                    UiText { visible: !nameIn.text; text: "Name (optional), e.g. Before new theme"; fam: "n"; px: 11; w: 800; color: Theme.textSoft; anchors.verticalCenter: parent.verticalCenter }
                }
            }
            UiCandy {
                id: saveBtn
                function save() { rc.save(nameIn.text.trim()); nameIn.text = ""; rc.adding = false }
                x: parent.width - width - 10; anchors.verticalCenter: parent.verticalCenter
                width: svT.implicitWidth + 28; height: 32; radius: 10; bw: 2.5; drop: 3; hi: 3; fill: Theme.gGo; pressable: true
                onClicked: save()
                UiText { id: svT; anchors.centerIn: parent; text: "Save"; px: 13; w: 700; color: "#FFFFFF" }
            }
        }

        Repeater {
            model: rc.rows
            delegate: UiRow {
                id: row
                required property var modelData
                readonly property string when: Qt.formatDateTime(new Date(modelData.time * 1000), rc.svc.h24 ? "d MMM yyyy · HH:mm" : "d MMM yyyy · h:mm AP")
                width: col.width; glyph: modelData.auto ? "reload" : "undo"; pressable: false
                title: modelData.name || row.when
                sub: (modelData.name ? row.when + " · " : "") + (rc.snap ? (modelData.auto ? "automatic" : "kept until deleted")
                     : rc.size(modelData.size) + (modelData.auto ? " · automatic" : ""))
                busy: rc.restoring === modelData.id; busyText: "Restoring… Island restarts"
                UiCandy {
                    id: resB
                    visible: !rc.snap
                    readonly property bool ask: rc.sure === row.modelData.id
                    width: rt.implicitWidth + 20; height: 28; radius: 10; bw: 2; drop: ask ? 0 : 2; hi: 0
                    fill: ask ? Theme.pinkSoft : Theme.paper; pressable: rc.restoring === ""
                    onClicked: rc.restore(row.modelData)
                    UiText { id: rt; anchors.centerIn: parent; text: resB.ask ? "Sure? Tap again" : "Restore"; px: 12; w: 700 }
                }
                UiCandy {
                    id: delB
                    readonly property bool ask: rc.sure === "d" + row.modelData.id
                    width: ask ? st.implicitWidth + 20 : 28; height: 28; bw: 2; drop: 0; hi: 0; fill: ask ? Theme.pinkSoft : Theme.paper; pressable: rc.restoring === ""
                    onClicked: rc.remove(row.modelData)
                    Glyph { visible: !delB.ask; anchors.centerIn: parent; name: "trash"; size: 12; stroke: 2.6 }
                    UiText { id: st; visible: delB.ask; anchors.centerIn: parent; text: "Sure?"; px: 12; w: 700 } }
            }
        }
        UiText { visible: rc.rows.length === 0 && !rc.adding && !rc.needSetup && (!rc.snap || rc.sysLoaded); width: parent.width; text: "No snapshots yet · press + Snapshot"; fam: "n"; px: 11.5; w: 800; color: Theme.textSoft }
    }
}
