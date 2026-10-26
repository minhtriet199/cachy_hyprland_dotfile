import QtQuick

// Network & security: firewall state, SSH server switch, file-sharing ports. Wi-Fi page.
Column {
    id: sp
    property var svc
    readonly property var v: svc.sys
    spacing: 8
    Component.onCompleted: svc.loadSys()
    UiText { text: "NETWORK & SECURITY"; fam: "n"; px: 11; w: 900; track: 1.4; color: Theme.textSoft; height: 16 }
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
