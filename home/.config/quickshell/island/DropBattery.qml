import QtQuick
import Quickshell.Io

// Battery dropdown: big %, charge state, life gauge (10 cells), power mode (asusctl profiles), graphics (MUX: Hybrid = the
// built-in GPU drives the screen and the RX 6700S sleeps · Ultimate = the RX 6700S drives it, faster games, ~10 W more; restart to switch), screen brightness
// (laptop + one slider per plugged-in external screen, from screenctl.py — any brand, DDC/CI or HDR nits).
// The Power settings page shows its own brightness slider, so it turns ours off (showBrightness).
DropCard {
    id: d
    property var svc
    readonly property var bat: svc.battery
    readonly property int pct: bat.percent
    property bool showBrightness: true
    readonly property var externals: (svc.screens || []).filter(m => !m.internal && !m.off && !m.mirror && (m.ddc || m.hdr))
    width: 340; height: showBrightness ? 384 + externals.length * 58 : 316
    Component.onCompleted: if (showBrightness) svc.loadScreens()
    headerH: 92

    function timeText(m) { return m < 60 ? m + " min" : Math.floor(m / 60) + " h " + (m % 60) + " min" }
    readonly property string line1: bat.status === "Charging" ? "Charging" : (bat.plugged ? "Plugged in" : "On battery")
    readonly property string line2: bat.minutes > 0
        ? (bat.status === "Charging" ? "full in " + timeText(bat.minutes) : timeText(bat.minutes) + " left")
        : (bat.plugged ? (pct >= 95 ? "Fully charged" : "Not charging · charge limit") : "")
    readonly property var tag: pct >= 80 ? ["GREAT", Theme.berry] : pct >= 50 ? ["GOOD", Theme.sea] : pct >= 20 ? ["LOW", Theme.orange] : ["CHARGE", Theme.berry]

    UiStrokeText { id: big; x: 22; y: 20; text: d.pct + "%"; px: 46; weight: 700; strokeW: 7; strokeColor: Theme.ink }
    Column {
        x: big.x + big.width + 14; y: 32; spacing: 2
        UiText { text: d.line1; px: 15; w: 700 }
        UiText { text: d.line2; fam: "n"; px: 11; w: 800; color: Theme.textSoft }
    }
    UiTag { x: d.width - width - 24; y: 22; text: d.tag[0]; fill: d.tag[1]; ink: Theme.ink; tilt: 6; px: 13 }

    // life gauge
    UiText { x: 20; y: 108; text: "LIFE GAUGE"; fam: "n"; px: 11; w: 900; track: 1.4; color: Theme.textSoft }
    UiText { x: d.width - width - 20; y: 108; text: "health " + d.bat.health + "%"; fam: "n"; px: 11; w: 800; color: Theme.textSoft }
    Row {
        x: 20; y: 128 + (25 - height) / 2; spacing: 6
        Repeater {
            model: 10
            delegate: Rectangle {
                required property int index
                readonly property bool lit: index < Math.round(d.pct / 10)
                readonly property bool last: index === Math.max(0, Math.round(d.pct / 10) - 1)
                width: Math.min(25, (d.width - 40 - 54) / 10); height: width; radius: 6; rotation: Theme.tilt(index) * 2
                color: lit ? Theme.leaf : Theme.sand
                border.width: last ? 3 : 2; border.color: last ? Theme.sunDeep : Theme.ink
            }
        }
    }

    // power mode
    UiText { x: 20; y: 168; text: "POWER MODE"; fam: "n"; px: 11; w: 900; track: 1.4; color: Theme.textSoft }
    // power settings (in the label row's empty right side, so nothing grows)
    signal settings()
    property bool showSettings: true                // off inside Settings → Power (it would open the page you're on)
    UiCandy { visible: d.showSettings; x: d.width - width - 20; y: 165; width: gt.implicitWidth + 30; height: 20; radius: 10; bw: 2; drop: 0; hi: 0; fill: Theme.paper; pressable: true
        onClicked: d.settings()
        Glyph { x: 6; anchors.verticalCenter: parent.verticalCenter; name: "gear"; size: 11; stroke: 2.4 }
        UiText { id: gt; x: 21; anchors.verticalCenter: parent.verticalCenter; text: "Settings"; fam: "n"; px: 10.5; w: 900 } }
    Row {
        x: 20; y: 190; spacing: 8
        Repeater {
            // Download mode lives in the power menu (Super+Esc); while it's on none of these is lit, a tap here ends it
            model: [["Silent", "Quiet"], ["Performance", "Balanced"], ["Turbo", "Performance"]]
            delegate: UiCandy {
                required property var modelData
                required property int index
                readonly property bool sel: !d.svc.download.on && d.svc.powerProfile === modelData[1]
                width: (d.width - 40 - 16) / 3; height: 38; radius: 12; bw: 2.5; drop: 3; hi: 0; rotation: Theme.tilt(index)
                fill: sel ? Theme.inkPhone : Theme.paper; pressable: true
                onClicked: { if (d.svc.download.on) d.svc.download.stop(); d.svc.setProfile(modelData[1]) }
                UiText { anchors.centerIn: parent; width: parent.width - 8; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
                    text: modelData[0]; px: 13; w: 700; color: sel ? "#FFFFFF" : Theme.text }
            }
        }
    }

    // graphics mode (MUX). set = what the next boot uses (0 Ultimate, 1 Hybrid); now = what this boot uses
    // (the laptop screen hangs off the RX 6700S = card1 in Ultimate). asusd only queues a change and writes it to the
    // firmware at shutdown (asus-shutdown), so our pick is remembered in ~/.cache/island/mux-queued for this boot.
    // Read only while the dropdown exists.
    property string muxSet: ""
    property string muxNow: ""
    property string muxMsg: ""
    Process { running: true; command: ["sh", "-c", "q=$HOME/.cache/island/mux-queued; if [ -n \"$(find \"$q\" -newer /proc/1 2>/dev/null)\" ]; then cat \"$q\"; else cat /sys/class/firmware-attributes/asus-armoury/attributes/gpu_mux_mode/current_value; fi; grep -qx connected /sys/class/drm/card1-eDP-1/status && echo 0 || echo 1"]
        stdout: StdioCollector { onStreamFinished: { const v = this.text.trim().split("\n"); d.muxSet = v[0] || ""; d.muxNow = v[1] || "" } } }
    Process { id: muxP; property string want
        stderr: StdioCollector { id: muxErr }
        onExited: code => { if (code === 0) { d.muxSet = want; d.muxMsg = "" } else d.muxMsg = "Not changed: " + muxErr.text.trim().split("\n").pop().slice(0, 60) } }
    readonly property bool muxPending: muxSet !== "" && muxNow !== "" && muxSet !== muxNow
    UiText { x: 20; y: 244; fam: "n"; px: 11; w: 900; track: 1.4; color: d.muxMsg ? Theme.berry : Theme.textSoft
        text: d.muxMsg || ("GRAPHICS · " + (d.muxPending ? "RESTART TO SWITCH" : d.muxNow === "1" ? "LONGER BATTERY" : d.muxNow === "0" ? "FASTER GAMES" : "…")) }
    Row {
        x: 20; y: 266; spacing: 8
        Repeater {
            model: [["Hybrid", "1"], ["Ultimate", "0"]]
            delegate: UiCandy {
                id: mb
                required property var modelData
                required property int index
                readonly property bool sel: d.muxSet === modelData[1]
                width: (d.width - 40 - (d.muxPending ? 24 : 8)) / (d.muxPending ? 4 : 2); height: 38; radius: 12; bw: 2.5; drop: 3; hi: 0; rotation: Theme.tilt(index + 1)
                fill: sel ? Theme.inkPhone : Theme.paper; pressable: !sel && !muxP.running
                onClicked: { muxP.want = modelData[1]; muxP.command = ["sh", "-c", "asusctl armoury set gpu_mux_mode \"$0\" && mkdir -p ~/.cache/island && echo \"$0\" > ~/.cache/island/mux-queued", modelData[1]]; muxP.running = true }
                UiText { anchors.centerIn: parent; text: mb.modelData[0]; px: 13; w: 700; color: mb.sel ? "#FFFFFF" : Theme.text }
            }
        }
        // the switch happens at the next boot: restart now, or shut down (it switches when you turn it on)
        Repeater {
            model: d.muxPending ? [["Restart", "reboot", Theme.gGo], ["Shut down", "shutdown", [Theme.berry, Theme.berry]]] : []
            delegate: UiCandy {
                id: pb
                required property var modelData
                required property int index
                width: (d.width - 40 - 24) / 4; height: 38; radius: 12; bw: 2.5; drop: 3; hi: 3; rotation: Theme.tilt(index + 3); fill: pb.modelData[2]; pressable: true
                onClicked: d.svc.power(pb.modelData[1])
                UiText { anchors.centerIn: parent; width: parent.width - 6; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
                    text: pb.modelData[0]; px: 13; w: 700; color: "#FFFFFF" }
            }
        }
    }

    // screen brightness (laptop screen)
    UiText { visible: d.showBrightness; x: 20; y: 316; text: (d.externals.length ? "LAPTOP SCREEN · " : "SCREEN BRIGHTNESS · ") + Math.round(d.svc.brightness * 100) + "%"; fam: "n"; px: 11; w: 900; track: 1.4; color: Theme.textSoft }
    UiSlider { visible: d.showBrightness; x: 20; y: 338; width: d.width - 40; value: d.svc.brightness; color: Theme.sunDeep
        onPicked: v => d.svc.setBrightness(Math.max(0.05, v)) }
    Repeater {
        model: d.showBrightness ? d.externals : []
        delegate: Item {
            required property var modelData
            required property int index
            x: 20; y: 374 + index * 58; width: d.width - 40; height: 50
            UiText { width: parent.width; elide: Text.ElideRight; fam: "n"; px: 11; w: 900; track: 1.4; color: Theme.textSoft
                text: modelData.model.toUpperCase() + " · " + modelData.pct + "%" + (modelData.hdr ? " · " + modelData.nits + " NITS" : "") }
            UiSlider { y: 22; width: parent.width; value: modelData.pct / 100; color: Theme.sunDeep
                onPicked: v => d.svc.screenCmd(["set", modelData.output, String(Math.max(5, Math.round(v * 100)))]) }
        }
    }
}
