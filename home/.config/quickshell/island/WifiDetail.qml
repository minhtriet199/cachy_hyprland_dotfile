import QtQuick
import Quickshell
import Quickshell.Io

// One Wi-Fi network's settings (opened from the Wi-Fi list): status + IP info, DNS presets, IPv4 auto/manual,
// IPv6 on/off, auto-connect, private address (MAC), metered, band (2.4 / 5 GHz), forget, password (👁 / copy) + share QR.
// Changes go through nmcli (svc.wifiModify).
Item {
    id: wd
    property var svc
    property string ssid: ""
    signal back()
    readonly property var i: svc.wifiInfo && svc.wifiInfo.ssid === ssid ? svc.wifiInfo : null
    // password / share QR: read on the first tap, forgotten when you leave the network's page
    property string pw: ""
    property string qr: ""
    property bool pwLoaded: false
    property bool pwErr: false
    property bool pwShown: false
    property bool qrShown: false
    property bool copied: false
    readonly property bool pwBusy: pwP.running
    property var _afterPw: null
    function withPw(f) { if (pwLoaded) { f(); return } if (pwP.running || !i || !i.name) return; _afterPw = f; pwErr = false
        pwP.command = ["sh", Quickshell.shellDir + "/tools/wifi-share.sh", i.name, ssid]; pwP.running = true }
    Process { id: pwP
        stdout: StdioCollector { id: pwOut }
        onExited: code => { const l = pwOut.text.split("\n"); if (code !== 0 || l.length < 2) { wd.pwErr = true; return }
            wd.pw = l[0]; wd.qr = l[1]; wd.pwLoaded = true; if (wd._afterPw) { const f = wd._afterPw; wd._afterPw = null; f() } } }
    Timer { id: copiedT; interval: 1500; onTriggered: wd.copied = false }
    implicitHeight: col.implicitHeight
    Component.onCompleted: if (svc && ssid) svc.loadWifiInfo(ssid)
    onSsidChanged: { pw = ""; qr = ""; pwLoaded = false; pwErr = false; pwShown = false; qrShown = false; if (svc && ssid) svc.loadWifiInfo(ssid) }
    Timer { interval: 5000; running: wd.visible && wd.ssid !== ""; repeat: true; onTriggered: wd.svc.loadWifiInfo(wd.ssid) }

    // DNS presets: [label, ipv4, ipv6]  ("" = automatic, i.e. the system's encrypted DNS / router)
    readonly property var presets: [["Auto", "", ""], ["Cloudflare", "1.1.1.1,1.0.0.1", "2606:4700:4700::1111,2606:4700:4700::1001"],
                                    ["Google", "8.8.8.8,8.8.4.4", "2001:4860:4860::8888,2001:4860:4860::8844"], ["Quad9", "9.9.9.9,149.112.112.112", "2620:fe::fe,2620:fe::9"],
                                    ["AdGuard", "94.140.14.14,94.140.15.15", "2a10:50c0::ad1:ff,2a10:50c0::ad2:ff"]]
    readonly property string dnsNow: i ? (i["ipv4.dns"] || "") : ""
    readonly property string presetNow: { const p = presets.find(x => x[1] === dnsNow); return p ? p[0] : (dnsNow ? "Custom" : "Auto") }
    function setDns(p) {
        if (!p[1]) svc.wifiModify(i, ["ipv4.dns", "", "ipv4.ignore-auto-dns", "no", "ipv6.dns", "", "ipv6.ignore-auto-dns", "no"]);
        else svc.wifiModify(i, ["ipv4.dns", p[1], "ipv4.ignore-auto-dns", "yes", "ipv6.dns", p[2], "ipv6.ignore-auto-dns", "yes"]);
        svc.dnsApply([p[0].toLowerCase()]);   // the system list wins over the network's DNS, so set it too
    }
    // Manual / Custom are choices you're still editing: only re-read them from the system when another network opens or after Save
    property bool manual: false
    property bool customDns: false
    property string syncedFor: ""
    function syncFromSystem() {
        if (!i) return;
        manual = i["ipv4.method"] === "manual";
        customDns = presetNow === "Custom";
        ipIn.text = (i["ipv4.addresses"] || (i.ip || "")).split(",")[0];
        gwIn.text = i["ipv4.gateway"] || i.gw || "";
        dns4In.text = (i["ipv4.dns"] || "").split(",").join(", ");
        syncedFor = ssid;
    }
    onIChanged: if (i && syncedFor !== ssid) syncFromSystem()
    Connections { target: wd.svc; function onWifiSaveMsgChanged() { if (wd.svc.wifiSaveMsg === "Saved ✓") wd.syncedFor = "" } }

    Column {
        id: col
        width: wd.width; spacing: 10
        // header: back + name + status
        Item {
            width: parent.width; height: 44
            UiCandy { width: 36; height: 36; anchors.verticalCenter: parent.verticalCenter; bw: 2.5; drop: 2; hi: 0; fill: Theme.paper; pressable: true; onClicked: wd.back()
                Glyph { anchors.centerIn: parent; name: "back"; size: 15; stroke: 3 } }
            Column { x: 48; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 48 - msg.width - 10
                UiText { width: parent.width; text: wd.ssid; px: 18; w: 700; color: Theme.textDeep; height: 21 }
                UiText { width: parent.width; fam: "n"; px: 11; w: 800; color: wd.i && wd.i.active ? Theme.leafDeep : Theme.textSoft
                    text: !wd.i ? "Loading…" : (wd.i.active ? "Connected" : wd.i.saved ? "Saved" : "Not saved") + (wd.i.signal ? " · " + wd.i.signal + "%" : "") + (wd.i.freq ? " · " + (parseInt(wd.i.freq) > 4000 ? "5 GHz" : "2.4 GHz") : "") + (wd.i.security ? " · " + wd.i.security : "") }
            }
            UiText { id: msg; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: wd.svc.wifiSaveMsg; fam: "n"; px: 11; w: 900
                color: wd.svc.wifiSaveMsg.startsWith("Not") ? Theme.berry : Theme.leafDeep }
        }
        // live info
        UiCandy {
            visible: !!wd.i && wd.i.active
            width: parent.width; height: infoGrid.implicitHeight + 20; radius: 14; bw: 2; drop: 0; hi: 0; fill: Theme.cream
            Grid {
                id: infoGrid; x: 12; y: 10; columns: 2; columnSpacing: 16; rowSpacing: 4
                Repeater {
                    model: wd.i ? [["IP address", wd.i.ip || "—"], ["Router", wd.i.gw || "—"], ["DNS in use", wd.i.dnsNow || "system (encrypted)"], ["IPv6", wd.i.ip6 || "—"]] : []
                    delegate: Row { required property var modelData; spacing: 8
                        UiText { width: 84; text: modelData[0]; fam: "n"; px: 11; w: 900; color: Theme.textSoft; height: 16 }
                        UiText { width: (col.width - 24 - 16) / 2 - 92; text: modelData[1]; px: 12; w: 700; height: 16 } }
                }
            }
        }
        UiText { visible: !!wd.i && !wd.i.saved; width: parent.width; wrapMode: Text.Wrap; text: "Connect to this network once to change its settings."; fam: "n"; px: 12; w: 800; color: Theme.textSoft }

        // password + share: read only when you tap 👁 / copy / Share (tools/wifi-share.sh); Share = a QR other phones scan to join
        Column {
            visible: !!wd.i && wd.i.saved
            width: parent.width; spacing: 6
            UiText { fam: "n"; px: 11; w: 900; track: 1.4; color: Theme.textSoft; height: 18; text: "PASSWORD & SHARING" }
            UiCandy {
                width: parent.width; height: 44; radius: 14; bw: 2; drop: 0; hi: 0; fill: Theme.cream
                UiText { x: 14; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 14 - pwBtns.width - 22; elide: Text.ElideRight
                    text: wd.pwBusy ? "Reading…" : wd.pwErr ? "Couldn't read it" : wd.pwLoaded && wd.pw === "" ? "No password (open network)"
                        : wd.pwShown ? wd.pw : "••••••••••"
                    px: 14; w: 700; color: wd.pwErr ? Theme.berry : Theme.text }
                Row {
                    id: pwBtns; anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter; spacing: 6
                    UiCandy { width: 32; height: 30; radius: 10; bw: 2; drop: 2; hi: 0; fill: wd.pwShown ? Theme.gOn : Theme.paper; pressable: true
                        onClicked: wd.withPw(() => wd.pwShown = !wd.pwShown)
                        Glyph { anchors.centerIn: parent; name: wd.pwShown ? "eyeOff" : "eye"; size: 15; stroke: 2.6 } }
                    UiCandy { width: 32; height: 30; radius: 10; bw: 2; drop: 2; hi: 0; fill: wd.copied ? Theme.gOn : Theme.paper; pressable: true
                        onClicked: wd.withPw(() => { if (!wd.pw) return; Quickshell.execDetached(["sh", "-c", 'printf %s "$0" | wl-copy --sensitive', wd.pw]); wd.copied = true; copiedT.restart() })
                        Glyph { anchors.centerIn: parent; name: wd.copied ? "check" : "clipboard"; size: 15; stroke: 2.6 } }
                    UiCandy { width: shT.implicitWidth + 40; height: 30; radius: 10; bw: 2.5; drop: wd.qrShown ? 0 : 3; hi: 3; fill: wd.qrShown ? Theme.gOn : Theme.gLeaf; pressable: true
                        onClicked: wd.withPw(() => wd.qrShown = !wd.qrShown)
                        Glyph { x: 9; anchors.verticalCenter: parent.verticalCenter; name: "scan"; size: 14; stroke: 2.6 }
                        UiText { id: shT; x: 28; anchors.verticalCenter: parent.verticalCenter; text: "Share"; px: 12.5; w: 700 } }
                }
            }
            UiCandy {
                visible: wd.qrShown && wd.qr !== ""
                width: parent.width; height: qrCol.implicitHeight + 24; radius: 16; bw: 2.5; drop: 3; hi: 0; fill: "#FFFFFF"
                Column {
                    id: qrCol; y: 12; width: parent.width; spacing: 8
                    Image { anchors.horizontalCenter: parent.horizontalCenter; width: Math.min(220, parent.width - 40); height: width
                        source: wd.qr; smooth: false; fillMode: Image.PreserveAspectFit }
                    UiText { width: parent.width - 24; anchors.horizontalCenter: parent.horizontalCenter; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap
                        text: "Scan with a phone camera to join “" + wd.ssid + "”"; fam: "n"; px: 11.5; w: 800; color: "#3A4A50" }
                }
            }
        }

        // DNS
        Column {
            visible: !!wd.i && wd.i.saved
            width: parent.width; spacing: 6
            UiText { fam: "n"; px: 11; w: 900; track: 1.4; color: Theme.textSoft; height: 18; text: "DNS · " + wd.presetNow.toUpperCase() }
            Flow {
                width: parent.width; spacing: 6
                Repeater {
                    model: wd.presets
                    delegate: UiCandy {
                        required property var modelData
                        readonly property bool picked: !wd.customDns && wd.presetNow === modelData[0]
                        width: dl.implicitWidth + 22; height: 30; radius: 10; bw: 2; drop: picked ? 2 : 0; hi: 0
                        fill: picked ? Theme.gOn : Theme.cream; pressable: true
                        onClicked: { wd.customDns = false; wd.setDns(modelData) }
                        UiText { id: dl; anchors.centerIn: parent; text: modelData[0]; px: 12; w: 700 }
                    }
                }
                UiCandy {
                    width: cl.implicitWidth + 22; height: 30; radius: 10; bw: 2; drop: wd.customDns ? 2 : 0; hi: 0
                    fill: wd.customDns ? Theme.gOn : Theme.cream; pressable: true
                    onClicked: { wd.customDns = true; dns4In.forceActiveFocus() }
                    UiText { id: cl; anchors.centerIn: parent; text: "Custom…"; px: 12; w: 700 }
                }
                // restart the DNS service + clear its cache (when sites still resolve the old way)
                UiCandy {
                    width: rl.implicitWidth + 40; height: 30; radius: 10; bw: 2; drop: 2; hi: 0; fill: Theme.paper; pressable: true
                    onClicked: wd.svc.dnsApply(["restart"])
                    Glyph { x: 9; anchors.verticalCenter: parent.verticalCenter; name: "reload"; size: 13; stroke: 2.6 }
                    UiText { id: rl; x: 28; anchors.verticalCenter: parent.verticalCenter; text: "Restart DNS"; px: 12; w: 700 }
                }
            }
            // your own DNS servers (IPv4; IPv6 optional)
            Row {
                visible: wd.customDns
                spacing: 6
                UiCandy {
                    width: Math.min(300, wd.width - 90); height: 32; radius: 10; bw: 2; drop: 0; hi: 0; fill: Theme.paper
                    TextInput { id: dns4In; x: 10; width: parent.width - 20; anchors.verticalCenter: parent.verticalCenter; clip: true
                        font.family: Theme.body; font.weight: 800; font.pixelSize: 12; color: Theme.text
                        onAccepted: dnsSave.clicked()
                        UiText { visible: !dns4In.text; text: "DNS servers, e.g. 1.1.1.1, 8.8.8.8"; fam: "n"; px: 11; w: 800; color: Theme.textSoft; anchors.verticalCenter: parent.verticalCenter } }
                }
                UiCandy { id: dnsSave; width: 70; height: 32; radius: 10; bw: 2.5; drop: 2; hi: 3; fill: Theme.gGo; pressable: true
                    onClicked: {
                        const v4 = dns4In.text.split(/[\s,;]+/).filter(x => /^\d{1,3}(\.\d{1,3}){3}$/.test(x));
                        const v6 = dns4In.text.split(/[\s,;]+/).filter(x => x.includes(":"));
                        if (!v4.length && !v6.length) return;
                        wd.svc.wifiModify(wd.i, ["ipv4.dns", v4.join(","), "ipv4.ignore-auto-dns", "yes", "ipv6.dns", v6.join(","), "ipv6.ignore-auto-dns", v6.length ? "yes" : "no"]);
                        wd.svc.dnsApply(["custom"].concat(v4, v6));
                    }
                    UiText { anchors.centerIn: parent; text: "Save"; px: 13; w: 700; color: "#FFFFFF" } }
            }
            UiText { visible: text !== ""; width: parent.width; fam: "n"; px: 11; w: 900; text: wd.svc.dnsMsg
                color: wd.svc.dnsMsg.startsWith("Not") ? Theme.berry : Theme.leafDeep }
            UiText { width: parent.width; wrapMode: Text.Wrap; fam: "n"; px: 10.5; w: 800; color: Theme.textSoft
                text: wd.customDns ? "Separate servers with commas. IPv6 addresses (with “:”) can go in the same box."
                                   : "Your pick becomes the system DNS for every network, encrypted (asks your password). Auto = Google first, Cloudflare backup: keeps Steam on the Vietnam server the ISP doesn't block." }
        }

        // IPv4
        Column {
            visible: !!wd.i && wd.i.saved
            width: parent.width; spacing: 6
            UiText { fam: "n"; px: 11; w: 900; track: 1.4; color: Theme.textSoft; height: 18; text: "IPV4 ADDRESS" }
            Row {
                spacing: 6
                Repeater {
                    model: [["auto", "Automatic (DHCP)"], ["manual", "Manual"]]
                    delegate: UiCandy {
                        required property var modelData
                        readonly property bool picked: (modelData[0] === "manual") === wd.manual
                        width: ml.implicitWidth + 22; height: 30; radius: 10; bw: 2; drop: picked ? 2 : 0; hi: 0
                        fill: picked ? Theme.gOn : Theme.cream; pressable: true
                        onClicked: { if (modelData[0] === "auto") { wd.manual = false; wd.svc.wifiModify(wd.i, ["ipv4.method", "auto", "ipv4.addresses", "", "ipv4.gateway", ""]) } else wd.manual = true }
                        UiText { id: ml; anchors.centerIn: parent; text: modelData[1]; px: 12; w: 700 }
                    }
                }
            }
            Row {
                id: ipRow
                visible: wd.manual
                width: parent.width; spacing: 6
                readonly property real room: width - 70 - 2 * spacing          // the two boxes share what Save leaves
                UiCandy {
                    width: ipRow.room * 0.56; height: 32; radius: 10; bw: 2; drop: 0; hi: 0; fill: Theme.paper
                    TextInput { id: ipIn; x: 10; width: parent.width - 20; anchors.verticalCenter: parent.verticalCenter; clip: true
                        font.family: Theme.body; font.weight: 800; font.pixelSize: 12; color: Theme.text
                        UiText { visible: !ipIn.text; text: "Address, e.g. 192.168.1.50/24"; width: parent.width; elide: Text.ElideRight; fam: "n"; px: 11; w: 800; color: Theme.textSoft; anchors.verticalCenter: parent.verticalCenter } }
                }
                UiCandy {
                    width: ipRow.room * 0.44; height: 32; radius: 10; bw: 2; drop: 0; hi: 0; fill: Theme.paper
                    TextInput { id: gwIn; x: 10; width: parent.width - 20; anchors.verticalCenter: parent.verticalCenter; clip: true
                        font.family: Theme.body; font.weight: 800; font.pixelSize: 12; color: Theme.text
                        UiText { visible: !gwIn.text; text: "Router, e.g. 192.168.1.1"; width: parent.width; elide: Text.ElideRight; fam: "n"; px: 11; w: 800; color: Theme.textSoft; anchors.verticalCenter: parent.verticalCenter } }
                }
                UiCandy { width: 70; height: 32; radius: 10; bw: 2.5; drop: 2; hi: 3; fill: Theme.gGo; pressable: true
                    onClicked: { const a = ipIn.text.trim(); if (!a) return; wd.svc.wifiModify(wd.i, ["ipv4.method", "manual", "ipv4.addresses", a.includes("/") ? a : a + "/24", "ipv4.gateway", gwIn.text.trim()]) }
                    UiText { anchors.centerIn: parent; text: "Save"; px: 13; w: 700; color: "#FFFFFF" } }
            }
        }

        // switches
        Column {
            visible: !!wd.i && wd.i.saved
            width: parent.width; spacing: 6
            UiText { fam: "n"; px: 11; w: 900; track: 1.4; color: Theme.textSoft; height: 18; text: "OPTIONS" }
            // routers that send one name on 2.4 + 5 GHz: pin the band (5 GHz faster · 2.4 GHz reaches further)
            SetSeg { width: parent.width; label: "Band"; options: ["Auto", "2.4 GHz", "5 GHz"]
                current: ({ bg: "2.4 GHz", a: "5 GHz" })[wd.i ? wd.i["802-11-wireless.band"] : ""] || "Auto"
                onPicked: v => wd.svc.wifiModify(wd.i, ["802-11-wireless.band", ({ "2.4 GHz": "bg", "5 GHz": "a" })[v] || ""]) }
            Repeater {
                model: wd.i ? [
                    ["IPv6", "Turn off if some sites are slow or don't load", wd.i["ipv6.method"] !== "disabled", ["ipv6.method", wd.i["ipv6.method"] === "disabled" ? "auto" : "disabled"]],
                    ["Connect automatically", "Join this network when it's in range", wd.i["connection.autoconnect"] === "yes", ["connection.autoconnect", wd.i["connection.autoconnect"] === "yes" ? "no" : "yes"]],
                    ["Private address", "Use a random MAC address on this network", wd.i["802-11-wireless.cloned-mac-address"] === "random" || wd.i["802-11-wireless.cloned-mac-address"] === "stable",
                        ["802-11-wireless.cloned-mac-address", (wd.i["802-11-wireless.cloned-mac-address"] === "random" || wd.i["802-11-wireless.cloned-mac-address"] === "stable") ? "permanent" : "stable"]],
                    ["Metered", "Tell apps to save data (phone hotspots)", wd.i["connection.metered"] === "yes", ["connection.metered", wd.i["connection.metered"] === "yes" ? "no" : "yes"]]
                ] : []
                delegate: UiRow {
                    required property var modelData
                    width: col.width; height: 48; glyph: ["globe", "reload", "shield", "chart"][index]; title: modelData[0]; sub: modelData[1]; active: modelData[2]
                    required property int index
                    onClicked: wd.svc.wifiModify(wd.i, modelData[3])
                    UiSwitch { on: modelData[2]; onToggled: wd.svc.wifiModify(wd.i, modelData[3]) }
                }
            }
        }

        // forget / disconnect
        Row {
            visible: !!wd.i && wd.i.saved
            spacing: 8
            UiCandy { visible: !!wd.i && wd.i.active; width: 120; height: 34; radius: 11; bw: 2.5; drop: 3; hi: 0; fill: Theme.paper; pressable: true
                onClicked: wd.svc.wifiDisconnect({ ssid: wd.i.name })
                UiText { anchors.centerIn: parent; text: "Disconnect"; px: 13; w: 700 } }
            UiCandy { width: 140; height: 34; radius: 11; bw: 2.5; drop: 3; hi: 3; fill: Theme.gBerry; pressable: true
                onClicked: { wd.svc.wifiForget({ ssid: wd.i.name }); wd.back() }
                UiText { anchors.centerIn: parent; text: "Forget network"; px: 13; w: 700 } }
        }
    }
}
