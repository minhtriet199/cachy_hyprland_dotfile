import QtQuick

// Keyring password pop-up (tools/keyring-prompter.py via Services.keyAsk), drawn like Isla's notification bubbles:
// tilted name tag, message, password box with the eye button, Cancel / Unlock. "confirm" prompts just get the buttons.
Item {
    id: d
    property var svc
    readonly property var ask: svc.keyAsk
    readonly property bool isPassword: !!ask && ask.kind === "password"
    width: 400
    height: card.height + 18
    onAskChanged: { pw.text = ""; pw.reveal = false; if (ask) Qt.callLater(() => pw.forceActiveFocus()) }
    function submit() { if (d.isPassword && !pw.text) return; d.svc.keyAnswer(true, pw.text); pw.text = "" }

    UiCandy {
        id: card
        y: 15; width: d.width; height: col.implicitHeight + 46
        radius: 28; bw: 3; drop: 6; hi: 0; ink: Theme.ink; fill: Theme.cream
        Column {
            id: col
            x: 22; y: 26; width: parent.width - 44; spacing: 10
            UiText { width: parent.width; wrapMode: Text.Wrap; px: 16; w: 700
                text: d.ask ? (d.ask.message || d.ask.title || "Unlock your keyring") : "" }
            UiText { visible: text !== ""; width: parent.width; wrapMode: Text.Wrap; fam: "n"; px: 12; w: 800; color: Theme.textSoft
                text: d.ask ? (d.ask.description || "") : "" }
            UiText { visible: text !== ""; width: parent.width; wrapMode: Text.Wrap; fam: "n"; px: 11.5; w: 800; color: Theme.berry
                text: d.ask ? (d.ask.warning || "") : "" }
            UiCandy {
                visible: d.isPassword
                width: parent.width; height: 40; radius: 13; bw: pw.activeFocus ? 3 : 2.5; drop: 0; hi: 0
                ink: pw.activeFocus ? Theme.seaDeep : Theme.ink; fill: Theme.paper
                Glyph { x: 11; anchors.verticalCenter: parent.verticalCenter; name: "lock"; size: 15; stroke: 2.6 }
                TextInput {
                    id: pw; x: 34; width: parent.width - 34 - 40; anchors.verticalCenter: parent.verticalCenter; clip: true
                    property bool reveal: false
                    echoMode: reveal ? TextInput.Normal : TextInput.Password
                    font.family: Theme.body; font.weight: 800; font.pixelSize: 14; color: Theme.text
                    onAccepted: d.submit()
                    Keys.onEscapePressed: d.svc.keyAnswer(false, "")
                    UiText { visible: !pw.text; text: d.ask && d.ask.new ? "New password" : "Password"; fam: "n"; px: 13; w: 800; color: Theme.textSoft
                        anchors.verticalCenter: parent.verticalCenter }
                }
                UiCandy { anchors.right: parent.right; anchors.rightMargin: 6; anchors.verticalCenter: parent.verticalCenter
                    width: 26; height: 26; bw: 0; drop: 0; hi: 0; fill: "transparent"; pressable: true
                    onClicked: pw.reveal = !pw.reveal
                    Glyph { anchors.centerIn: parent; name: pw.reveal ? "eyeOff" : "eye"; size: 16; stroke: 2.4 } }
            }
            Row {
                anchors.right: parent.right; spacing: 8
                UiCandy {
                    width: noT.implicitWidth + 32; height: 36; radius: 13; bw: 2.5; drop: 3; hi: 0; fill: Theme.paper; pressable: true
                    onClicked: d.svc.keyAnswer(false, "")
                    UiText { id: noT; anchors.centerIn: parent; text: "Cancel"; px: 14; w: 700 }
                }
                UiCandy {
                    width: yesT.implicitWidth + 32; height: 36; radius: 13; bw: 2.5; drop: 3; hi: 3; fill: Theme.gGo; pressable: true
                    onClicked: d.submit()
                    UiText { id: yesT; anchors.centerIn: parent; text: d.isPassword ? "Unlock" : "Continue"; px: 14; w: 700; color: "#FFFFFF" }
                }
            }
        }
    }
    UiTag { x: 20; y: 0; text: "Keyring"; px: 14; padX: 13; height: 30; bw: 2.5; drop: 3; tilt: -4; fill: Theme.sea; ink: Theme.ink }
}
