import QtQuick

// Password prompt for system changes (Island is the polkit agent): time zone, auto time, region…
// Shows what is asking, a password box (Enter = OK, Esc = Cancel) and a wrong-password message (+ shake) inside the card.
Item {
    id: d
    property var flow
    width: 370
    height: card.height + 18
    property bool wrong: false   // last try was a wrong password (PAM sends no message for that)
    onFlowChanged: { pw.text = ""; wrong = false }
    Connections {
        target: d.flow
        function onAuthenticationFailed() { pw.text = ""; d.wrong = true; shake.restart() }
    }

    UiCandy {
        id: card
        y: 14; width: d.width; height: col.implicitHeight + 40
        SequentialAnimation on x { id: shake; running: false
            NumberAnimation { to: -9; duration: 50 } NumberAnimation { to: 8; duration: 70 }
            NumberAnimation { to: -5; duration: 60 } NumberAnimation { to: 0; duration: 50 } }
        radius: 26; bw: 3; drop: 6; hi: 0; ink: Theme.ink; fill: Theme.cream
        Column {
            id: col
            x: 22; y: 24; width: parent.width - 44; spacing: 10
            UiText { width: parent.width; wrapMode: Text.Wrap; px: 16; w: 700
                text: d.flow ? d.flow.message : "" }
            UiText { width: parent.width; wrapMode: Text.Wrap; fam: "n"; px: 11.5; w: 800; color: Theme.textSoft
                text: "Type your password to allow this change." }
            UiCandy {
                width: parent.width; height: 38; radius: 12; bw: 2.5; drop: 0; hi: 0
                fill: d.wrong || (d.flow && d.flow.supplementaryIsError) ? Theme.pinkSoft : Theme.paper
                Glyph { x: 11; anchors.verticalCenter: parent.verticalCenter; name: "lock"; size: 15; stroke: 2.6 }
                TextInput {
                    id: pw; x: 34; width: parent.width - 46 - 30; anchors.verticalCenter: parent.verticalCenter; clip: true
                    property bool reveal: false
                    echoMode: reveal || (d.flow && d.flow.responseVisible) ? TextInput.Normal : TextInput.Password
                    font.family: Theme.body; font.weight: 800; font.pixelSize: 14; color: Theme.text
                    focus: true
                    onTextChanged: if (text) d.wrong = false
                    Component.onCompleted: forceActiveFocus()
                    onAccepted: if (d.flow && text) d.flow.submit(text)
                    Keys.onEscapePressed: if (d.flow) d.flow.cancelAuthenticationRequest()
                    UiText { visible: !pw.text; text: d.flow && d.flow.inputPrompt ? d.flow.inputPrompt.replace(/:\s*$/, "") : "Password"
                        fam: "n"; px: 13; w: 800; color: Theme.textSoft; anchors.verticalCenter: parent.verticalCenter }
                }
                // eye: show / hide what you typed
                UiCandy { anchors.right: parent.right; anchors.rightMargin: 6; anchors.verticalCenter: parent.verticalCenter
                    width: 26; height: 26; bw: 0; drop: 0; hi: 0; fill: "transparent"; pressable: true
                    onClicked: pw.reveal = !pw.reveal
                    Glyph { anchors.centerIn: parent; name: pw.reveal ? "eyeOff" : "eye"; size: 16; stroke: 2.4 } }
            }
            UiText { visible: text !== ""; width: parent.width; wrapMode: Text.Wrap; fam: "n"; px: 11; w: 800
                color: d.wrong || (d.flow && d.flow.supplementaryIsError) ? Theme.berry : Theme.textSoft
                text: d.wrong ? "Wrong password, try again." : d.flow ? (d.flow.supplementaryMessage || "") : "" }
            Row {
                anchors.right: parent.right; spacing: 8
                UiCandy {
                    width: noT.implicitWidth + 32; height: 36; radius: 13; bw: 2.5; drop: 3; hi: 0; fill: Theme.paper; pressable: true
                    onClicked: if (d.flow) d.flow.cancelAuthenticationRequest()
                    UiText { id: noT; anchors.centerIn: parent; text: "Cancel"; px: 14; w: 700 }
                }
                UiCandy {
                    width: yesT.implicitWidth + 32; height: 36; radius: 13; bw: 2.5; drop: 3; hi: 0; fill: Theme.gOn; pressable: true
                    onClicked: if (d.flow && pw.text) d.flow.submit(pw.text)
                    UiText { id: yesT; anchors.centerIn: parent; text: "Allow"; px: 14; w: 700 }
                }
            }
        }
    }
    UiTag { x: 20; y: 0; text: "System"; px: 14; padX: 13; height: 28; bw: 2.5; drop: 3; tilt: -4; fill: Theme.sun; ink: Theme.ink }
}
