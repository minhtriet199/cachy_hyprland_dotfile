import QtQuick

// Power menu (bar power button / Super+Esc): Lock · Log out · Suspend · Reboot · Shut down.
// ← → or 1–5 to choose, Enter to run. Log out / Reboot / Shut down ask once more ("Sure?").
FocusScope {
    id: pm
    property var svc
    property int sel: 2
    property string armed: ""
    signal closed()
    width: 600; height: 272
    readonly property var opts: [
        { id: "lock",     label: "Lock",      glyph: "lock",       tint: Theme.gSea,   ok: svc.hasLocker, confirm: false },
        { id: "logout",   label: "Log out",   glyph: "arrowRight", tint: Theme.gSun,   ok: true, confirm: true },
        { id: "suspend",  label: "Suspend",   glyph: "moon",       tint: Theme.gLilac, ok: true, confirm: false },
        { id: "reboot",   label: "Reboot",    glyph: "reload",     tint: Theme.gLeaf,  ok: true, confirm: true },
        { id: "shutdown", label: "Shut down", glyph: "power",      tint: Theme.gBerry, ok: true, confirm: true }
    ]
    function pick(i) {
        const o = opts[i]; sel = i;
        if (!o.ok) { armed = ""; return }
        if (o.confirm && armed !== o.id) { armed = o.id; return }
        closed(); svc.power(o.id);
    }
    Keys.onEscapePressed: closed()
    Keys.onLeftPressed: { sel = (sel + 4) % 5; armed = "" }
    Keys.onRightPressed: { sel = (sel + 1) % 5; armed = "" }
    Keys.onReturnPressed: pick(sel)
    Keys.onEnterPressed: pick(sel)
    Keys.onPressed: e => { if (e.key >= Qt.Key_1 && e.key <= Qt.Key_5) { pick(e.key - Qt.Key_1); e.accepted = true } }

    DropCard {
        anchors.fill: parent
        headerColor: Theme.gPeach[1]; headerH: 70
        UiText { x: 24; y: 14; text: "Leaving the island?"; px: 24; w: 700 }
        UiText { x: 24; y: 44; text: pm.svc.userHost || ""; fam: "n"; px: 11; w: 800; color: Theme.textMuted }
        UiCandy {
            x: parent.width - 54; y: 17; width: 36; height: 36; bw: 2.5; drop: 2; hi: 0; fill: Theme.paper; pressable: true
            onClicked: pm.closed()
            Glyph { anchors.centerIn: parent; name: "close"; size: 15; stroke: 2.8 }
        }
        Row {
            x: 24; y: 70 + 22; spacing: 14
            Repeater {
                model: pm.opts
                delegate: UiCandy {
                    id: tile
                    required property var modelData
                    required property int index
                    readonly property bool cur: pm.sel === index
                    readonly property bool arm: pm.armed === modelData.id
                    width: (pm.width - 48 - 4 * 14) / 5; height: 124; radius: 20; bw: cur ? 3 : 2.5; drop: cur ? 5 : 3
                    hi: 3; fill: arm ? Theme.gBerry : (cur ? modelData.tint : Theme.paper)
                    opacity: modelData.ok ? 1 : 0.45
                    pressable: true
                    y: cur ? -4 : 0
                    Behavior on y { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
                    onClicked: pm.pick(index)
                    MouseArea { anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton
                        onEntered: { if (pm.sel !== tile.index) pm.armed = ""; pm.sel = tile.index } }
                    UiCandy {
                        anchors.horizontalCenter: parent.horizontalCenter; y: 16; width: 52; height: 52; bw: 2.5; drop: 0; hi: 0
                        fill: tile.cur ? Theme.paper : tile.modelData.tint[1]
                        Glyph { anchors.centerIn: parent; name: tile.modelData.glyph; size: 24; stroke: 2.5 }
                    }
                    UiText { y: 78; width: parent.width; horizontalAlignment: Text.AlignHCenter
                        text: tile.arm ? "Sure?" : tile.modelData.label; px: 15; w: 700 }
                    UiText { y: 98; width: parent.width; horizontalAlignment: Text.AlignHCenter
                        text: !tile.modelData.ok ? "needs hyprlock" : tile.arm ? "click again" : (tile.index + 1); fam: "n"; px: 10; w: 800; color: Theme.textSoft }
                }
            }
        }
        UiText { x: 0; y: parent.height - 34; width: parent.width; horizontalAlignment: Text.AlignHCenter
            text: "← → choose · Enter · 1–5 · Esc to stay"; fam: "n"; px: 11; w: 800; color: Theme.textSoft }
    }
}
