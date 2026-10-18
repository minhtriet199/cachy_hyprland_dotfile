import QtQuick
import Quickshell.Bluetooth
import Quickshell.Io

// Bluetooth: on/off, scan, devices (connected first, then paired, then new ones found by scanning).
// Click = connect / disconnect, new device = pair + connect, shield = trust (auto-reconnect), trash = forget.
Item {
    id: b
    property var svc
    property real listH: 260
    readonly property var ad: Bluetooth.defaultAdapter
    readonly property var devs: ad ? ad.devices.values.slice().sort((x, y) => (y.connected - x.connected) || (y.paired - x.paired) || (x.name || "").localeCompare(y.name || "")) : []
    implicitHeight: col.implicitHeight
    // Quickshell has no pairing agent, so pair() alone waits forever. bluetoothctl brings its own
    // (no PIN prompt), then connects. Trust is left to the shield button. Fails → the row says so.
    property string pairAddr: ""
    property string failAddr: ""
    function pairNew(d) {
        if (pairP.running) return
        failAddr = ""; pairAddr = d.address
        pairP.command = ["sh", "-c", "a=$1; timeout 30 bluetoothctl --agent NoInputNoOutput pair $a; timeout 20 bluetoothctl connect $a | grep -q 'Connection successful'", "sh", d.address]
        pairP.running = true
    }
    Process { id: pairP; onExited: code => { if (code !== 0) b.failAddr = b.pairAddr; b.pairAddr = "" } }
    onVisibleChanged: if (!visible && ad && ad.discovering) ad.discovering = false

    function iconFor(d) {
        const i = d.icon || "";
        return i.includes("headset") || i.includes("headphone") ? "headphones" : i.includes("audio") ? "speakerOn" : i.includes("phone") ? "phone"
             : i.includes("keyboard") ? "keyboard" : i.includes("mouse") || i.includes("input") ? "gamepad" : "bluetooth";
    }

    Column {
        id: col
        width: b.width; spacing: 10
        Item {
            width: parent.width; height: 30
            UiText { anchors.verticalCenter: parent.verticalCenter; text: "BLUETOOTH"; fam: "n"; px: 11; w: 900; track: 1.4; color: Theme.textSoft }
            Row {
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: 8
                UiCandy {
                    visible: !!b.ad && b.ad.enabled
                    width: scanT.implicitWidth + 20; height: 28; radius: 10; bw: 2; drop: 2; hi: 0
                    fill: b.ad && b.ad.discovering ? Theme.gSun : Theme.paper; pressable: true
                    onClicked: b.ad.discovering = !b.ad.discovering
                    UiText { id: scanT; anchors.centerIn: parent; text: b.ad && b.ad.discovering ? "Scanning…" : "Scan"; px: 12; w: 700 }
                }
                UiSwitch { on: !!b.ad && b.ad.enabled; onColor: Theme.sea; onToggled: if (b.ad) b.ad.enabled = !b.ad.enabled }
            }
        }
        UiText { visible: !b.ad; width: parent.width; text: "No Bluetooth adapter found"; fam: "n"; px: 12; w: 800; color: Theme.textSoft }
        ListView {
            id: list
            visible: !!b.ad && b.ad.enabled
            width: parent.width; height: Math.min(b.listH, Math.max(1, count) * 56 - 6)
            clip: true; spacing: 6; boundsBehavior: Flickable.StopAtBounds
            onCountChanged: if (!moving) positionViewAtBeginning()   // list refreshes → stay at the top
            model: b.devs
            delegate: UiRow {
                required property var modelData
                width: list.width
                glyph: b.iconFor(modelData)
                title: modelData.name || modelData.address
                active: modelData.connected
                busy: b.pairAddr === modelData.address || modelData.pairing || modelData.state === BluetoothDeviceState.Connecting || modelData.state === BluetoothDeviceState.Disconnecting
                busyText: b.pairAddr === modelData.address ? "Pairing…" : "Working…"
                subColor: b.failAddr === modelData.address ? Theme.berry : Theme.textSoft
                sub: b.failAddr === modelData.address && !modelData.connected ? "Couldn't connect · hold its pairing button, then tap again"
                     : (modelData.connected ? "Connected" : modelData.paired ? "Paired" : "New device")
                       + (modelData.paired ? (modelData.trusted ? " · Trusted" : " · Not trusted") : "")
                     + (modelData.batteryAvailable ? " · 🔋 " + Math.round(modelData.battery * 100) + "%" : "")
                onClicked: {
                    if (modelData.connected) modelData.disconnect();
                    else if (modelData.paired && modelData.bonded) modelData.connect();
                    else b.pairNew(modelData)
                }
                UiCandy { visible: modelData.paired; width: 26; height: 26; bw: 2; drop: 0; hi: 0
                    fill: modelData.trusted ? Theme.gSea : Theme.paper; pressable: true
                    onClicked: modelData.trusted = !modelData.trusted
                    Glyph { anchors.centerIn: parent; name: modelData.trusted ? "shieldCheck" : "shield"; size: 13; stroke: 2.4 } }
                UiCandy { visible: modelData.paired; width: 26; height: 26; bw: 2; drop: 0; hi: 0; fill: Theme.paper; pressable: true
                    onClicked: modelData.forget()
                    Glyph { anchors.centerIn: parent; name: "trash"; size: 12; stroke: 2.6 } }
            }
        }
        UiText { visible: !!b.ad && b.ad.enabled && b.devs.length === 0; width: parent.width; horizontalAlignment: Text.AlignHCenter; height: 40
            text: "No devices yet · press Scan"; fam: "n"; px: 12; w: 800; color: Theme.textSoft }
    }
}
