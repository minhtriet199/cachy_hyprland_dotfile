import QtQuick

// System page (phone): charge limit, firewall, SSH, file sharing on the left; About, storage and updates on the right.
Item {
    id: sp
    property var svc
    readonly property var v: svc.sys
    readonly property bool narrow: width < 560
    readonly property real colW: narrow ? width : (width - 20) / 2
    readonly property real leftH: left.implicitHeight
    implicitHeight: narrow ? left.implicitHeight + 20 + right.implicitHeight : Math.max(left.implicitHeight, right.implicitHeight)
    Component.onCompleted: svc.loadSys()

    Column {
        id: left
        width: sp.colW; spacing: 8
        UiText { text: "BATTERY CHARGE LIMIT · " + (sp.v.limit || "?") + "%"; fam: "n"; px: 11; w: 900; track: 1.4; color: Theme.textSoft; height: 16 }
        Row {
            spacing: 6
            Repeater {
                model: [60, 80, 100]
                delegate: UiCandy {
                    required property int modelData
                    readonly property bool picked: String(modelData) === sp.v.limit
                    width: (sp.colW - 12) / 3; height: 32; radius: 10; bw: 2.5; drop: picked ? 2 : 0; hi: 0
                    fill: picked ? Theme.gGo : Theme.cream; pressable: true
                    onClicked: sp.svc.sysCmd(["asusctl", "battery", "limit", String(modelData)])
                    UiText { anchors.centerIn: parent; text: modelData + "%"; px: 13; w: 700; color: parent.picked ? "#FFFFFF" : Theme.text }
                }
            }
        }
        UiText { text: "60–80% keeps the battery healthy when you stay plugged in"; fam: "n"; px: 10; w: 800; color: Theme.textSoft; width: parent.width; wrapMode: Text.Wrap }
        Item { width: 1; height: 2 }
        UiRow {
            width: parent.width; glyph: "shieldCheck"; title: "Firewall"
            sub: sp.v.fw === "active" ? "On · public zone" : (sp.v.fw || "…")
            active: sp.v.fw === "active"; pressable: false
        }
        UiRow {
            id: sshRow
            width: parent.width; glyph: "terminal"; title: "SSH server"
            sub: sp.v.sshok !== "1" ? "Needs one-time setup (ssh-toggle helper)" : sp.v.ssh === "active" ? "On · until reboot" : "Off"
            active: sp.v.ssh === "active"
            onClicked: if (sp.v.sshok === "1") sp.svc.sysCmd(["sudo", "-n", "/usr/local/bin/ssh-toggle", sp.v.ssh === "active" ? "off" : "on"])
            UiSwitch { visible: sp.v.sshok === "1"; on: sp.v.ssh === "active"; onToggled: sshRow.clicked() }
        }
        UiRow {
            width: parent.width; glyph: "folder"; title: "File sharing"
            sub: "Open LocalSend / KDE Connect ports for 15 min"
            onClicked: sp.svc.run([sp.svc.scripts + "/share-firewall.sh"])
            Glyph { name: "arrowRight"; size: 15; stroke: 2.6 }
        }
    }

    Column {
        id: right
        x: sp.narrow ? 0 : sp.colW + 20; y: sp.narrow ? sp.leftH + 20 : 0; width: sp.colW; spacing: 6
        UiText { text: "ABOUT"; fam: "n"; px: 11; w: 900; track: 1.4; color: Theme.textSoft; height: 16 }
        UiCandy {
            width: parent.width; height: about.implicitHeight + 24; radius: 16; bw: 2.5; drop: 3; hi: 0; fill: Theme.cream
            Column {
                id: about; x: 14; y: 12; width: parent.width - 28; spacing: 5
                Repeater {
                    model: [["Device", "ROG Zephyrus G14 · " + (sp.v.host || "")], ["System", sp.v.os || ""], ["Kernel", sp.v.kernel || ""], ["CPU", sp.v.cpu || ""],
                            ["Memory", sp.v.ram ? sp.v.ram + " GB" : ""], ["Hyprland", sp.v.hypr || ""], ["Shell", "Island · Quickshell " + (sp.v.qs || "")], ["Up for", sp.v.up || ""]]
                    delegate: Item {
                        required property var modelData
                        width: about.width; height: 18
                        UiText { width: 78; text: modelData[0]; fam: "n"; px: 11; w: 900; color: Theme.textSoft; height: 18 }
                        UiText { x: 80; width: parent.width - 80; text: modelData[1]; px: 12; w: 700; height: 18 }
                    }
                }
            }
        }
        UiCandy {
            width: parent.width; height: 34; radius: 12; bw: 2.5; drop: 3; hi: 0; fill: Theme.paper; pressable: true
            onClicked: sp.svc.reloadShell()
            Row { anchors.centerIn: parent; spacing: 8
                Glyph { name: "reload"; size: 14; stroke: 2.6; anchors.verticalCenter: parent.verticalCenter }
                UiText { text: "Reload Island"; px: 13; w: 700; anchors.verticalCenter: parent.verticalCenter } }
        }
        Item { width: 1; height: 8 }
        SysStorage { width: parent.width; svc: sp.svc }
    }
}
