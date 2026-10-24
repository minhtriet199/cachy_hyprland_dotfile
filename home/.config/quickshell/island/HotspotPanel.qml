import QtQuick
import Quickshell

// Hotspot (Settings → Wi-Fi, under the networks): share this laptop's internet over Wi-Fi (tools/hotspot.sh).
// On/off, devices connected, name + password, band. On Wi-Fi the band/channel follows your Wi-Fi (the card has one channel).
// Details load only while this is shown.
Column {
    id: hp
    property var svc
    readonly property var i: svc.hotspotInfo || ({})
    readonly property int freq: parseInt(i.wifiFreq) || 0
    readonly property bool busy: svc.busyIds.includes("hotspot")
    width: parent ? parent.width : 300; spacing: 8
    onVisibleChanged: if (visible) svc.hotspotRun(["status"])
    Component.onCompleted: svc.hotspotRun(["status"])
    Timer { interval: 5000; running: hp.visible && hp.svc.hotspot; repeat: true; onTriggered: hp.svc.hotspotRun(["status"]) }   // device count
    property string syncedFor: ""
    onIChanged: if (i.name !== undefined && syncedFor !== i.name + i.pass) { nameIn.text = i.name || ""; passIn.text = i.pass || ""; syncedFor = i.name + i.pass }

    UiText { fam: "n"; px: 11; w: 900; track: 1.4; color: Theme.textSoft; height: 18; text: "HOTSPOT" }
    UiRow {
        width: parent.width; height: 52; glyph: "wifiArcs"; title: "Share my internet"; active: hp.svc.hotspot; busy: hp.busy; busyText: "Starting…"
        sub: hp.svc.hotspot ? (parseInt(hp.i.clients) || 0) + " device" + ((parseInt(hp.i.clients) || 0) === 1 ? "" : "s") + " connected · " + (hp.i.name || "")
                            : "Phones and laptops can join this laptop's Wi-Fi"
        onClicked: hp.svc.toggle("hotspot")
        UiSwitch { on: hp.svc.hotspot; onToggled: hp.svc.toggle("hotspot") }
    }
    UiText { visible: hp.svc.hotspotMsg !== "" && hp.svc.hotspotMsg !== "Starting…"; width: parent.width; wrapMode: Text.Wrap; maximumLineCount: 3
        text: (hp.svc.hotspotMsg.startsWith("Saved") ? "" : "⚠ ") + hp.svc.hotspotMsg; fam: "n"; px: 11; w: 800
        color: hp.svc.hotspotMsg.startsWith("Saved") ? Theme.seaDeep : Theme.berry }

    // name + password
    Row {
        id: np
        width: parent.width; spacing: 6
        readonly property real room: width - 70 - 12
        UiCandy {
            width: np.room * 0.5; height: 32; radius: 10; bw: 2; drop: 0; hi: 0; fill: Theme.paper
            TextInput { id: nameIn; x: 10; width: parent.width - 20; anchors.verticalCenter: parent.verticalCenter; clip: true
                font.family: Theme.body; font.weight: 800; font.pixelSize: 12; color: Theme.text
                UiText { visible: !nameIn.text; text: "Name"; fam: "n"; px: 11; w: 800; color: Theme.textSoft; anchors.verticalCenter: parent.verticalCenter } }
        }
        UiCandy {
            width: np.room * 0.5; height: 32; radius: 10; bw: 2; drop: 0; hi: 0; fill: Theme.paper
            TextInput { id: passIn; x: 10; width: parent.width - 20 - 22; anchors.verticalCenter: parent.verticalCenter; clip: true
                property bool reveal: false
                echoMode: reveal ? TextInput.Normal : TextInput.Password; font.family: Theme.body; font.weight: 800; font.pixelSize: 12; color: Theme.text
                UiText { visible: !passIn.text; text: "Password (8+)"; fam: "n"; px: 11; w: 800; color: Theme.textSoft; anchors.verticalCenter: parent.verticalCenter } }
            Glyph { x: parent.width - 24; anchors.verticalCenter: parent.verticalCenter; name: passIn.reveal ? "eyeOff" : "eye"; size: 14; stroke: 2.4
                MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: passIn.reveal = !passIn.reveal } }
        }
        UiCandy { width: 70; height: 32; radius: 10; bw: 2.5; drop: 2; hi: 3; fill: Theme.gGo; pressable: true
            onClicked: hp.svc.hotspotRun(["set", nameIn.text.trim(), passIn.text])
            UiText { anchors.centerIn: parent; text: "Save"; px: 13; w: 700; color: "#FFFFFF" } }
    }

    // band: on Wi-Fi it can't be picked (one channel), on a cable it can
    UiText { visible: hp.freq > 0; width: parent.width; wrapMode: Text.Wrap; fam: "n"; px: 11; w: 800; color: Theme.textMuted
        text: "Band · " + (hp.freq > 5000 ? "5 GHz" : "2.4 GHz") + " channel " + (hp.freq > 5000 ? (hp.freq - 5000) / 5 : (hp.freq - 2407) / 5)
              + " · follows your Wi-Fi (the card has one channel)" }
    SetSeg { visible: hp.freq === 0; width: parent.width; label: "Band"; options: ["2.4 GHz", "5 GHz"]
        current: Prefs.hotspotBand === "2.4" ? "2.4 GHz" : "5 GHz"; onPicked: v => Prefs.set("hotspotBand", v === "2.4 GHz" ? "2.4" : "5") }

    // no helper yet: each start asks for your password — one-time setup removes that
    UiCandy {
        visible: hp.i.helper === "0"
        width: parent.width; height: hintCol.implicitHeight + 18; radius: 13; bw: 2; drop: 0; hi: 0; fill: Theme.sand
        Column {
            id: hintCol
            x: 10; y: 9; width: parent.width - 20; spacing: 6
            UiText { width: parent.width; wrapMode: Text.Wrap; fam: "n"; px: 11; w: 800; color: Theme.textMuted
                text: "Starting asks for your password. To skip it, run the one-time setup in a terminal (copies 2 commands):" }
            UiCandy { width: cpT.implicitWidth + 24; height: 28; radius: 9; bw: 2; drop: 2; hi: 0; fill: Theme.paper; pressable: true
                onClicked: { hp.svc.run(["wl-copy", "sudo install -m 755 -o root ~/.config/quickshell/island/tools/hotspot-if.src /usr/local/bin/island-hotspot-if && sudo install -m 440 -o root ~/.config/quickshell/island/tools/hotspot-if.sudoers.src /etc/sudoers.d/island-hotspot"]); cpT.text = "Copied ✓" }
                UiText { id: cpT; anchors.centerIn: parent; text: "Copy setup command"; px: 12; w: 700 } }
        }
    }
}
