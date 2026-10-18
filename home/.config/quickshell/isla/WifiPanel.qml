import QtQuick

// Wi-Fi: on/off, networks (click = connect, × = disconnect), password box for new locked networks,
// Used by the bar dropdown and the phone.
Item {
    id: w
    property var svc
    property real listH: 260
    property string askFor: ""            // ssid waiting for a password
    property string detail: ""            // ssid whose settings page is open ("" = the list)
    onVisibleChanged: if (!visible) detail = ""
    implicitHeight: detail ? det.implicitHeight : col.implicitHeight
    WifiDetail { id: det; visible: w.detail !== ""; width: w.width; svc: w.svc; ssid: w.detail; onBack: w.detail = "" }
    Component.onCompleted: svc.wifiScan()
    Timer { interval: 8000; running: w.visible; repeat: true; onTriggered: w.svc.wifiScan() }

    Column {
        id: col
        visible: w.detail === ""
        width: w.width; spacing: 10
        Item {
            width: parent.width; height: 30
            UiText { anchors.verticalCenter: parent.verticalCenter; text: "WI-FI"; fam: "n"; px: 11; w: 900; track: 1.4; color: Theme.textSoft }
            Row {
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: 8
                UiText { visible: w.svc.wifiScanning; anchors.verticalCenter: parent.verticalCenter; text: "Searching…"; fam: "n"; px: 11; w: 800; color: Theme.seaDeep }
                UiCandy { width: 28; height: 28; bw: 2; drop: 2; hi: 0; fill: w.svc.wifiScanning ? Theme.gOn : Theme.paper; pressable: !w.svc.wifiScanning; onClicked: w.svc.wifiRescanNow()
                    Glyph { id: spin; anchors.centerIn: parent; name: "reload"; size: 14; stroke: 2.6
                        RotationAnimation on rotation { running: w.svc.wifiScanning; loops: Animation.Infinite; from: 0; to: 360; duration: 900 }
                        Connections { target: w.svc; function onWifiScanningChanged() { if (!w.svc.wifiScanning) spin.rotation = 0 } } } }
                UiSwitch { on: w.svc.wifi.on; onToggled: w.svc.toggle("wifi") }
            }
        }
        UiText { visible: w.svc.wifiError !== "" && w.svc.wifiErrFor === ""; width: parent.width; text: "⚠ " + w.svc.wifiError; fam: "n"; px: 11; w: 800; color: Theme.berry; wrapMode: Text.Wrap; maximumLineCount: 2 }
        // password box
        UiCandy {
            visible: w.askFor !== ""
            width: parent.width; height: 84; radius: 15; bw: 2.5; drop: 3; hi: 0; fill: Theme.gSun
            UiText { x: 12; y: 8; width: parent.width - 24 - 30; text: "Password for " + w.askFor; px: 13; w: 700 }
            // cancel (Esc in the box does the same)
            UiCandy { x: parent.width - 32; y: 6; width: 24; height: 24; bw: 2; drop: 0; hi: 0; fill: Theme.paper; pressable: true
                onClicked: { pw.text = ""; w.askFor = "" }
                Glyph { anchors.centerIn: parent; name: "close"; size: 11; stroke: 2.8 } }
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
        // loading bar on top of the list while scanning
        Item {
            visible: w.svc.wifiScanning && w.svc.wifi.on
            width: parent.width; height: 6
            Rectangle { anchors.fill: parent; radius: 3; color: Theme.sand }
            Rectangle { id: lb; width: parent.width * 0.3; height: 6; radius: 3; color: Theme.sea
                SequentialAnimation on x { running: w.svc.wifiScanning; loops: Animation.Infinite
                    NumberAnimation { from: 0; to: col.width * 0.7; duration: 700; easing.type: Easing.InOutSine }
                    NumberAnimation { from: col.width * 0.7; to: 0; duration: 700; easing.type: Easing.InOutSine } } }
        }
        ListView {
            id: list
            visible: w.svc.wifi.on
            width: parent.width; height: Math.min(w.listH, Math.max(1, count) * 56 - 6)
            clip: true; spacing: 6; boundsBehavior: Flickable.StopAtBounds
            onCountChanged: if (!moving) positionViewAtBeginning()   // list refreshes → stay at the top
            // the network being connected goes to the top, so you can see it
            model: { const t = w.svc.wifiTarget, a = w.svc.wifiNets; const k = t ? a.findIndex(x => x.ssid === t) : -1
                     return k > 0 ? [a[k]].concat(a.slice(0, k), a.slice(k + 1)) : a }
            Connections { target: w.svc; function onWifiTargetChanged() { if (w.svc.wifiTarget) list.positionViewAtBeginning() } }
            delegate: UiRow {
                id: net
                required property var modelData
                width: list.width
                glyph: modelData.signal > 30 ? "wifi" : "wifiOff"
                title: modelData.ssid
                active: modelData.active
                readonly property bool failed: w.svc.wifiErrFor === modelData.ssid
                busy: w.svc.wifiTarget === modelData.ssid
                busyText: "Connecting…"
                subColor: failed ? Theme.berry : Theme.textSoft
                sub: failed ? "⚠ " + w.svc.wifiError : (modelData.active ? "Connected · " : modelData.known ? "Saved · " : "") + modelData.signal + "%" + (modelData.secure ? " · 🔒" : "")
                onClicked: {
                    if (modelData.active) { w.detail = modelData.ssid; return }
                    if (modelData.secure && !modelData.known) { w.askFor = modelData.ssid; pw.forceActiveFocus() }
                    else w.svc.wifiConnect(modelData, "");
                }
                // cancel while connecting (otherwise it waits until nmcli gives up)
                UiCandy { visible: w.svc.wifiTarget === modelData.ssid; width: 26; height: 26; bw: 2; drop: 0; hi: 0; fill: Theme.paper; pressable: true
                    onClicked: w.svc.wifiCancel()
                    Glyph { anchors.centerIn: parent; name: "close"; size: 12; stroke: 2.6 } }
                // settings page for saved networks
                UiCandy { visible: (modelData.active || modelData.known) && w.svc.wifiTarget !== modelData.ssid; width: 26; height: 26; bw: 2; drop: 0; hi: 0; fill: Theme.paper; pressable: true
                    onClicked: w.detail = modelData.ssid
                    Glyph { anchors.centerIn: parent; name: "gear"; size: 13; stroke: 2.2 } }
                UiCandy { visible: modelData.active; width: 26; height: 26; bw: 2; drop: 0; hi: 0; fill: Theme.paper; pressable: true
                    onClicked: w.svc.wifiDisconnect(modelData)
                    Glyph { anchors.centerIn: parent; name: "close"; size: 12; stroke: 2.6 } }
            }
        }
        UiText { visible: w.svc.wifi.on && w.svc.wifiNets.length === 0; width: parent.width; horizontalAlignment: Text.AlignHCenter; height: 40
            text: "Looking for networks…"; fam: "n"; px: 12; w: 800; color: Theme.textSoft }
    }
}
