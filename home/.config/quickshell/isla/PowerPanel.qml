import QtQuick

// Power page: battery card on the left; brightness, keep awake and the power menu on the right.
Item {
    id: pp
    property var svc
    readonly property bool narrow: width < 560
    implicitHeight: narrow ? bat.height + 16 + right.implicitHeight : Math.max(bat.height + 6, right.implicitHeight)
    DropBattery { id: bat; svc: pp.svc; width: pp.narrow ? pp.width : Math.min(360, (pp.width - 20) / 2) }
    Column {
        id: right
        x: pp.narrow ? 0 : bat.width + 20; y: pp.narrow ? bat.height + 16 : 0; width: pp.narrow ? pp.width : pp.width - bat.width - 20; spacing: 12
        UiText { text: "SCREEN BRIGHTNESS · " + Math.round(pp.svc.brightness * 100) + "%"; fam: "n"; px: 11; w: 900; track: 1.4; color: Theme.textSoft; height: 18 }
        UiSlider { width: parent.width; value: pp.svc.brightness; color: Theme.sunDeep; onPicked: v => pp.svc.setBrightness(Math.max(0.05, v)) }
        Item { width: 1; height: 4 }
        UiRow {
            width: parent.width; glyph: "moon"; title: "Keep awake"; sub: pp.svc.keepAwake ? "Screen will not sleep" : "Normal sleep"
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
