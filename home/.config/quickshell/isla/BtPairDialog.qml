import QtQuick

// Bluetooth pair request (from tools/bt-agent.py via Services.btAsk): shows the code a phone/PC
// also shows, with Pair / Cancel. "display" = type this code on the other device (just OK).
// "authorize" = a paired but not trusted device wants to connect: Deny / Allow once / Trust.
// "newdev" = you tapped a new device in the panel: Cancel / Pair only / Pair & trust.
Item {
    id: d
    property var svc
    readonly property var ask: svc.btAsk
    readonly property string kind: ask ? ask.kind : ""
    width: 370
    height: card.height + 18

    UiCandy {
        id: card
        y: 14; width: d.width; height: col.implicitHeight + 40
        radius: 26; bw: 3; drop: 6; hi: 0; ink: Theme.ink; fill: Theme.cream
        Column {
            id: col
            x: 22; y: 24; width: parent.width - 44; spacing: 10
            UiText { width: parent.width; wrapMode: Text.Wrap; px: 17; w: 700
                text: !d.ask ? "" : d.kind === "authorize" ? d.ask.name + " wants to connect"
                    : d.kind === "display" ? "Type this code on " + d.ask.name : "Pair with " + d.ask.name + "?" }
            // the code, one sticker per digit
            Row {
                visible: !!d.ask && !!d.ask.key
                anchors.horizontalCenter: parent.horizontalCenter; spacing: 5
                Repeater {
                    model: d.ask && d.ask.key ? d.ask.key.split("") : []
                    delegate: UiCandy {
                        required property string modelData
                        width: 36; height: 46; radius: 11; bw: 2.5; drop: 3; hi: 0; ink: Theme.ink; fill: Theme.gSea
                        UiText { anchors.centerIn: parent; text: modelData; fam: "t"; px: 24; color: Theme.text }
                    }
                }
            }
            UiText { width: parent.width; wrapMode: Text.Wrap; fam: "n"; px: 11.5; w: 800; color: Theme.textSoft
                text: d.kind === "confirm" ? "Make sure the same code shows on the other device."
                    : d.kind === "display" ? "Then press Pair / OK there."
                    : d.kind === "newdev" ? "Trust = it may connect by itself later. Pair only = it asks first."
                    : "It's paired but not trusted. Trust = it may always connect by itself." }
            Row {
                anchors.right: parent.right; spacing: 8
                UiCandy {
                    visible: d.kind !== "display"
                    width: noT.implicitWidth + 32; height: 36; radius: 13; bw: 2.5; drop: 3; hi: 0; fill: Theme.paper; pressable: true
                    onClicked: d.svc.btAnswer("no")
                    UiText { id: noT; anchors.centerIn: parent; text: d.kind === "authorize" ? "Deny" : "Cancel"; px: 14; w: 700 }
                }
                UiCandy {
                    visible: d.kind === "authorize" || d.kind === "newdev"
                    width: onceT.implicitWidth + 28; height: 36; radius: 13; bw: 2.5; drop: 3; hi: 0; fill: Theme.paper; pressable: true
                    onClicked: d.svc.btAnswer("yes")
                    UiText { id: onceT; anchors.centerIn: parent; text: d.kind === "newdev" ? "Pair only" : "Allow once"; px: 14; w: 700 }
                }
                UiCandy {
                    width: yesT.implicitWidth + 32; height: 36; radius: 13; bw: 2.5; drop: 3; hi: 0; fill: Theme.gOn; pressable: true
                    onClicked: d.svc.btAnswer(d.kind === "authorize" || d.kind === "newdev" ? "trust" : "yes")
                    UiText { id: yesT; anchors.centerIn: parent; text: d.kind === "display" ? "OK" : d.kind === "authorize" ? "Trust" : d.kind === "newdev" ? "Pair & trust" : "Pair"; px: 14; w: 700 }
                }
            }
        }
    }
    UiTag { x: 20; y: 0; text: "Bluetooth"; px: 14; padX: 13; height: 28; bw: 2.5; drop: 3; tilt: -4; fill: Theme.sea; ink: Theme.ink }
}
