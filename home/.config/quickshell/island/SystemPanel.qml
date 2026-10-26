import QtQuick

// System page (phone): About + Reload Island on the left; storage (+ Disk map) and updates on the right.
// Charge limit moved to Power, firewall / SSH / file sharing to Wi-Fi (NetSecurity), 2026-10-26.
Item {
    id: sp
    property var svc
    signal go(string screen)
    readonly property var v: svc.sys
    readonly property bool narrow: width < 560
    readonly property real colW: narrow ? width : (width - 20) / 2
    readonly property real leftH: left.implicitHeight
    implicitHeight: narrow ? left.implicitHeight + 20 + right.implicitHeight : Math.max(left.implicitHeight, right.implicitHeight)
    Component.onCompleted: svc.loadSys()

    Column {
        id: left
        width: sp.colW; spacing: 6
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
    }

    Column {
        id: right
        x: sp.narrow ? 0 : sp.colW + 20; y: sp.narrow ? sp.leftH + 20 : 0; width: sp.colW; spacing: 6
        SysStorage { width: parent.width; svc: sp.svc; onGo: s => sp.go(s) }
    }
}
