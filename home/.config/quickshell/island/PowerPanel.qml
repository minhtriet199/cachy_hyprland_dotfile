import QtQuick

// Power page: battery card + charge limit on the left; brightness link, timers, lid, keep awake and the power menu on the right.
Item {
    id: pp
    property var svc
    signal go(string screen)
    readonly property bool narrow: width < 560
    implicitHeight: narrow ? leftCol.height + 16 + right.implicitHeight : Math.max(leftCol.height + 6, right.implicitHeight)
    Column {
        id: leftCol
        width: pp.narrow ? pp.width : Math.min(360, (pp.width - 20) / 2); spacing: 16
        DropBattery { id: bat; svc: pp.svc; showBrightness: false; showSettings: false; width: parent.width }
        ChargeLimit { width: parent.width; svc: pp.svc }
    }
    Column {
        id: right
        x: pp.narrow ? 0 : leftCol.width + 20; y: pp.narrow ? leftCol.height + 16 : 0; width: pp.narrow ? pp.width : pp.width - leftCol.width - 20; spacing: 12
        UiRow {
            width: parent.width; glyph: "sun"; title: "Brightness · " + Math.round(pp.svc.brightness * 100) + "%"; sub: "Every screen, night light, gamma — in Displays"
            onClicked: pp.go("settingsDisplays")
            Glyph { name: "arrowRight"; size: 16; stroke: 2.6 }
        }
        Item { width: 1; height: 4 }
        // Windows-style timers
        UiText { text: "SCREEN & HIBERNATE"; fam: "n"; px: 11; w: 900; track: 1.4; color: Theme.textSoft; height: 18 }
        PowerTimer { width: parent.width; key: "idleLock"; glyph: "lock"; title: "Lock after" }
        PowerTimer { width: parent.width; key: "idleScreen"; glyph: "monitor"; title: "Screen off after" }
        PowerTimer { width: parent.width; key: "idleSleep"; glyph: "moon"; title: "Hibernate after" }
        UiText { width: parent.width; wrapMode: Text.Wrap; fam: "n"; px: 10.5; w: 800; color: Theme.textSoft
            text: "Counts from your last mouse or key press. Videos and games that keep the screen awake pause it, and so does Keep awake." }
        Item { width: 1; height: 4 }
        UiText { text: "WHEN I CLOSE THE LID"; fam: "n"; px: 11; w: 900; track: 1.4; color: Theme.textSoft; height: 18 }
        PowerTimer { width: parent.width; key: "lidClose"; glyph: "desktop"; title: "Close the lid"
            choices: [["sleep", "Hibernate"], ["screen", "Screen off"], ["lock", "Lock"], ["nothing", "Nothing"]] }
        UiText { width: parent.width; wrapMode: Text.Wrap; fam: "n"; px: 10.5; w: 800; color: Theme.textSoft
            text: "Hibernate saves everything and powers off (no battery used); press the power button to come back. Screen off / Lock with another screen plugged in: the laptop's windows move to that screen and the laptop screen switches off until you open the lid. Unplugging while it's closed changes nothing." }
        Item { width: 1; height: 2 }
        UiRow {
            width: parent.width; glyph: "moon"; title: "Keep awake"; sub: pp.svc.keepAwake ? "Screens stay on, no lock or hibernate" : "Timers above apply"
            active: pp.svc.keepAwake; onClicked: pp.svc.toggle("awake")
            UiSwitch { on: pp.svc.keepAwake; onToggled: pp.svc.toggle("awake") }
        }
        UiRow {
            width: parent.width; glyph: "power"; title: "Power menu"; sub: "Lock, log out, reboot, shut down"
            onClicked: pp.svc.powerMenu()
            Glyph { name: "arrowRight"; size: 16; stroke: 2.6 }
        }
    }
}
