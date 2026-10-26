import QtQuick
import Quickshell
import Quickshell.Io

// System page, part 2: storage (disk bars, package cache + clean) and updates — a Check button lists every
// package with old → new version; Update opens a terminal with "sudo pacman -Syu" for you to run.
// Nothing runs in the background: the check only happens when you press it (tools/storage.py).
Column {
    id: ss
    property var svc
    signal go(string screen)
    spacing: 8
    property var st: ({ disks: [], pkgCache: 0, userCache: 0, lastUpdate: "" })
    property var up: null               // null = not checked yet
    property bool showAll: false
    readonly property string tool: Quickshell.shellDir + "/tools/storage.py"
    function gb(b) { return b >= 1e12 ? (b / 1e12).toFixed(1) + " TB" : b >= 1e9 ? (b / 1e9).toFixed(1) + " GB" : Math.round(b / 1e6) + " MB" }
    function term(title, cmd) { Quickshell.execDetached(["kitty", "--title", title, "sh", "-c", cmd + "; echo; echo 'Done — press Enter to close'; read x"]) }
    Component.onCompleted: diskP.running = true
    Process { id: diskP; command: ["python3", ss.tool, "disks"]
        stdout: StdioCollector { onStreamFinished: { try { ss.st = JSON.parse(this.text) } catch (e) {} } } }
    Process { id: upP; command: ["python3", ss.tool, "updates"]
        stdout: StdioCollector { onStreamFinished: { try { ss.up = JSON.parse(this.text) } catch (e) { ss.up = { repo: [], aur: [], error: "Couldn't check" } } } } }

    component Label: UiText { fam: "n"; px: 11; w: 900; track: 1.4; color: Theme.textSoft; height: 16 }

    // ── storage ──
    Label { text: "STORAGE" }
    Repeater {
        model: ss.st.disks
        delegate: UiCandy {
            required property var modelData
            width: ss.width; height: 62; radius: 15; bw: 2.5; drop: 0; hi: 0; fill: Theme.cream
            UiText { x: 14; y: 9; text: modelData.mount === "/" ? "Laptop drive" : modelData.mount; px: 14; w: 700 }
            UiText { anchors.right: parent.right; anchors.rightMargin: 14; y: 11; text: ss.gb(modelData.free) + " free of " + ss.gb(modelData.size); fam: "n"; px: 11; w: 800; color: Theme.textSoft }
            Rectangle {
                x: 14; y: 36; width: parent.width - 28; height: 14; radius: 7; color: Theme.sand; border.width: 2; border.color: Theme.inkPhone
                Rectangle { x: 2; y: 2; height: parent.height - 4; radius: 5; width: Math.max(10, (parent.width - 4) * modelData.pct / 100)
                    color: modelData.pct > 90 ? Theme.berry : modelData.pct > 75 ? Theme.orange : Theme.sea }
            }
        }
    }
    UiRow {
        width: ss.width; glyph: "chart"; title: "Disk map"; sub: "What fills your drive"
        onClicked: ss.go("settingsDiskMap")
        Glyph { name: "arrowRight"; size: 15; stroke: 2.6 }
    }
    UiRow {
        width: ss.width; glyph: "box"; title: "Old app downloads · " + ss.gb(ss.st.pkgCache)
        sub: "Clean keeps the newest copy of each (asks your password in a terminal)"
        onClicked: ss.term("Clean package cache", "sudo paccache -rk1 && sudo paccache -ruk0")
        Glyph { name: "trash"; size: 14; stroke: 2.6 }
    }

    // ── updates ──
    Item { width: 1; height: 4 }
    Label { text: "UPDATES" + (ss.st.lastUpdate ? " · LAST " + ss.st.lastUpdate.slice(0, 10) : "") }
    UiCandy {
        width: ss.width; height: 40; radius: 13; bw: 2.5; drop: upP.running ? 0 : 3; hi: 3; fill: upP.running ? Theme.gOn : Theme.gSea; pressable: !upP.running
        onClicked: { ss.up = null; ss.showAll = false; upP.running = true }
        Row { anchors.centerIn: parent; spacing: 8
            Glyph { id: spin; name: "reload"; size: 15; stroke: 2.6; anchors.verticalCenter: parent.verticalCenter
                RotationAnimation on rotation { running: upP.running; loops: Animation.Infinite; from: 0; to: 360; duration: 900 } }
            UiText { text: upP.running ? "Checking…" : "Check for updates"; px: 14; w: 700; anchors.verticalCenter: parent.verticalCenter } }
    }
    UiText { visible: !!ss.up && !!ss.up.error; width: ss.width; text: ss.up ? ss.up.error : ""; fam: "n"; px: 11.5; w: 800; color: Theme.berry }
    UiText { visible: !!ss.up && !ss.up.error && ss.up.repo.length + ss.up.aur.length === 0; width: ss.width; text: "Everything is up to date ✓"; fam: "n"; px: 12; w: 800; color: Theme.leafDeep }
    // the list
    UiCandy {
        visible: !!ss.up && ss.up.repo.length > 0
        width: ss.width; height: upCol.implicitHeight + 20; radius: 14; bw: 2; drop: 0; hi: 0; fill: Theme.paper
        Column {
            id: upCol; x: 10; y: 10; width: parent.width - 20; spacing: 3
            UiText { text: (ss.up ? ss.up.repo.length : 0) + " packages to update"; px: 13.5; w: 700; height: 20 }
            Repeater {
                model: ss.up ? (ss.showAll ? ss.up.repo : ss.up.repo.slice(0, 12)) : []
                delegate: Item {
                    required property var modelData
                    width: upCol.width; height: 17
                    UiText { width: parent.width * 0.45; elide: Text.ElideRight; text: modelData.name; px: 11.5; w: 700; height: 17 }
                    UiText { x: parent.width * 0.47; width: parent.width * 0.53; elide: Text.ElideMiddle; text: modelData.old + "  →  " + modelData.new; fam: "n"; px: 10.5; w: 800; color: Theme.textSoft; height: 17 }
                }
            }
            UiText { visible: !!ss.up && ss.up.repo.length > 12; text: ss.showAll ? "Show less ▴" : "Show all " + (ss.up ? ss.up.repo.length : 0) + " ▾"; fam: "n"; px: 11.5; w: 900; color: Theme.seaDeep; height: 22
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: ss.showAll = !ss.showAll } }
        }
    }
    UiCandy {
        visible: !!ss.up && ss.up.repo.length > 0
        width: ss.width; height: 40; radius: 13; bw: 2.5; drop: 3; hi: 3; fill: Theme.gGo; pressable: true
        onClicked: ss.term("System update", "sudo pacman -Syu; echo; ~/.config/hypr/scripts/hypr-check.sh")
        UiText { anchors.centerIn: parent; text: "Update in terminal · sudo pacman -Syu"; px: 13.5; w: 700; color: "#FFFFFF" }
    }
    // AUR (paru) is separate: pacman doesn't update those
    UiRow {
        visible: !!ss.up && ss.up.aur.length > 0
        width: ss.width; glyph: "box"; title: (ss.up ? ss.up.aur.length : 0) + " AUR packages"
        sub: ss.up ? ss.up.aur.map(a => a.name).join(", ") : ""
        onClicked: ss.term("AUR update", "paru -Sua")
        Glyph { name: "external"; size: 14; stroke: 2.6 }
    }
}
