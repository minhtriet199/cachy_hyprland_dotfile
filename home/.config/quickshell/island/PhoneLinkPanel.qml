import QtQuick

// Phone Link page: the paired phone, its pairing QR, and whether it may open a Terminal here. The link itself is
// island-link-pc (SvcLink.qml talks to it).
Column {
    id: pl
    property var svc
    readonly property var lk: svc.link
    width: parent ? parent.width : 300; spacing: 8
    property string sure: ""                  // id waiting for the second tap on Forget
    Timer { id: sureT; interval: 3000; onTriggered: pl.sure = "" }
    property real now: Date.now()
    Timer { interval: 1000; repeat: true; running: pl.lk.qr !== ""; onTriggered: pl.now = Date.now() }
    function timeLeft() { const s = Math.max(0, Math.round((lk.qrUntil - now) / 1000)); return Math.floor(s / 60) + ":" + (s % 60 < 10 ? "0" : "") + s % 60 }

    component Label: UiText { fam: "n"; px: 11; w: 900; track: 1.4; color: Theme.textSoft; height: 18 }

    UiRow {
        visible: !pl.lk.up
        width: parent.width; height: 52; glyph: "phone"; title: "The link isn't running"
        sub: "Start it: systemctl --user start island-link"; pressable: false
    }

    Label { visible: pl.lk.up; text: "YOUR PHONE" }
    Repeater {
        model: pl.lk.state.phones
        delegate: UiRow {
            required property var modelData
            width: pl.width; height: 52; glyph: "phone"; title: modelData.name; active: modelData.connected; pressable: false
            sub: !modelData.connected ? "Not connected" : "Connected" + (modelData.battery >= 0 ? " · " + modelData.battery + "%" + (modelData.charging ? " charging" : "") : "")
            UiCandy { width: fT.implicitWidth + 20; height: 28; radius: 9; bw: 2; drop: 2; hi: 0; fill: pl.sure === modelData.id ? Theme.gBerry : Theme.paper; pressable: true
                onClicked: { if (pl.sure !== modelData.id) { pl.sure = modelData.id; sureT.restart() } else { pl.sure = ""; pl.lk.forget(modelData.id) } }
                UiText { id: fT; anchors.centerIn: parent; text: pl.sure === modelData.id ? "Sure?" : "Forget"; px: 12; w: 700; color: pl.sure === modelData.id ? "#FFFFFF" : Theme.text } }
        }
    }

    // pairing
    Label { visible: pl.lk.up; text: "PAIR A PHONE" }
    UiCandy {
        visible: pl.lk.up
        width: parent.width; height: pl.lk.qr ? 232 : 52; radius: 15; bw: 2.5; drop: 3; hi: 0; fill: Theme.cream
        pressable: !pl.lk.qr; onClicked: pl.lk.pair()
        Row {
            visible: !pl.lk.qr; x: 14; anchors.verticalCenter: parent.verticalCenter; spacing: 10
            Glyph { anchors.verticalCenter: parent.verticalCenter; name: "scan"; size: 18; stroke: 2.4 }
            Column { anchors.verticalCenter: parent.verticalCenter
                UiText { text: "Show pairing code"; px: 14; w: 700; height: 17 }
                UiText { text: pl.lk.qrError !== "" ? "⚠ " + pl.lk.qrError : "Scan it in Island Link on your phone"; fam: "n"; px: 10.5; w: 800; height: 14
                    color: pl.lk.qrError !== "" ? Theme.berry : Theme.textSoft } }
        }
        Image {
            visible: !!pl.lk.qr; x: 14; y: 14; width: 204; height: 204; smooth: false; cache: false; fillMode: Image.PreserveAspectFit
            source: pl.lk.qr ? pl.lk.qr + "?" + pl.lk.qrStamp : ""
        }
        Column {
            visible: !!pl.lk.qr; x: 232; y: 14; width: parent.width - 246; spacing: 6
            UiText { width: parent.width; wrapMode: Text.Wrap; text: "Scan this in Island Link"; px: 15; w: 700 }
            UiText { width: parent.width; wrapMode: Text.Wrap; fam: "n"; px: 11; w: 800; color: Theme.textSoft
                text: "Same Wi-Fi as this PC. It works once, for " + pl.timeLeft() + "." }
        }
    }

    // terminal: off until you say so
    Label { visible: pl.lk.up; text: "TERMINAL" }
    UiRow {
        visible: pl.lk.up
        width: parent.width; height: 52; glyph: "terminal"; title: "Let the phone open a terminal"; pressable: true
        sub: "One visible kitty, fingerprint each time"
        onClicked: pl.lk.setTerminal(!pl.lk.state.terminal)
        UiSwitch { on: pl.lk.state.terminal; onToggled: pl.lk.setTerminal(!pl.lk.state.terminal) }
    }
}
