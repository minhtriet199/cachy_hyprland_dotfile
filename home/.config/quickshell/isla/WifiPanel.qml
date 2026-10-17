import QtQuick

// Wi-Fi: on/off, networks (click = connect, × = disconnect), password box for new locked networks,
// Used by the bar dropdown and the phone.
Item {
    id: w
    property var svc
    property real listH: 260
    property string askFor: ""            // ssid waiting for a password
    implicitHeight: col.implicitHeight
    Component.onCompleted: svc.wifiScan()
    Timer { interval: 8000; running: w.visible; repeat: true; onTriggered: w.svc.wifiScan() }

    Column {
        id: col
        width: w.width; spacing: 10
        Item {
            width: parent.width; height: 30
            UiText { anchors.verticalCenter: parent.verticalCenter; text: "WI-FI"; fam: "n"; px: 11; w: 900; track: 1.4; color: Theme.textSoft }
            Row {
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: 8
                UiCandy { width: 28; height: 28; bw: 2; drop: 2; hi: 0; fill: Theme.paper; pressable: true; onClicked: w.svc.wifiScan()
                    Glyph { anchors.centerIn: parent; name: "reload"; size: 14; stroke: 2.6 } }
                UiSwitch { on: w.svc.wifi.on; onToggled: w.svc.toggle("wifi") }
            }
        }
        UiText { visible: w.svc.wifiError !== ""; width: parent.width; text: "⚠ " + w.svc.wifiError; fam: "n"; px: 11; w: 800; color: Theme.berry; wrapMode: Text.Wrap; maximumLineCount: 2 }
        // password box
        UiCandy {
            visible: w.askFor !== ""
            width: parent.width; height: 84; radius: 15; bw: 2.5; drop: 3; hi: 0; fill: Theme.gSun
            UiText { x: 12; y: 8; width: parent.width - 24; text: "Password for " + w.askFor; px: 13; w: 700 }
            UiCandy {
                x: 10; y: 34; width: parent.width - 20 - 82; height: 38; radius: 11; bw: 2; drop: 0; hi: 0; fill: Theme.paper
                TextInput {
                    id: pw
                    x: 10; width: parent.width - 20; anchors.verticalCenter: parent.verticalCenter
                    echoMode: TextInput.Password; font.family: Theme.body; font.pixelSize: 14; font.weight: 800; color: Theme.text; clip: true
                    onAccepted: go.clicked()
                    Keys.onEscapePressed: { w.askFor = ""; text = "" }
                }
            }
            UiCandy {
                id: go
                x: parent.width - 10 - 74; y: 34; width: 74; height: 38; radius: 11; bw: 2.5; drop: 2; hi: 3; fill: Theme.gGo; pressable: true
                onClicked: { const n = w.svc.wifiNets.find(x => x.ssid === w.askFor); if (n) w.svc.wifiConnect(n, pw.text); pw.text = ""; w.askFor = "" }
                UiText { anchors.centerIn: parent; text: "Join"; px: 14; w: 700; color: "#FFFFFF" }
            }
        }
        ListView {
            id: list
            visible: w.svc.wifi.on
            width: parent.width; height: Math.min(w.listH, Math.max(1, count) * 56 - 6)
            clip: true; spacing: 6; boundsBehavior: Flickable.StopAtBounds
            onCountChanged: if (!moving) positionViewAtBeginning()   // list refreshes → stay at the top
            model: w.svc.wifiNets
            delegate: UiRow {
                required property var modelData
                width: list.width
                glyph: modelData.signal > 30 ? "wifi" : "wifiOff"
                title: modelData.ssid
                active: modelData.active
                sub: (modelData.active ? "Connected · " : modelData.known ? "Saved · " : "") + modelData.signal + "%" + (modelData.secure ? " · 🔒" : "")
                onClicked: {
                    if (modelData.active) return;
                    if (modelData.secure && !modelData.known) { w.askFor = modelData.ssid; pw.forceActiveFocus() }
                    else w.svc.wifiConnect(modelData, "");
                }
                UiCandy { visible: modelData.active || modelData.known; width: 26; height: 26; bw: 2; drop: 0; hi: 0; fill: Theme.paper; pressable: true
                    onClicked: modelData.active ? w.svc.wifiDisconnect(modelData) : w.svc.wifiForget(modelData)
                    Glyph { anchors.centerIn: parent; name: modelData.active ? "close" : "trash"; size: 12; stroke: 2.6 } }
            }
        }
        UiText { visible: w.svc.wifi.on && w.svc.wifiNets.length === 0; width: parent.width; horizontalAlignment: Text.AlignHCenter; height: 40
            text: "Looking for networks…"; fam: "n"; px: 12; w: 800; color: Theme.textSoft }
        UiText { visible: w.svc.wifiBusy; width: parent.width; text: "Connecting…"; fam: "n"; px: 11; w: 800; color: Theme.seaDeep }
    }
}
