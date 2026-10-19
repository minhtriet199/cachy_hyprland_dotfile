import QtQuick

// Power menu (bar power button / Super+Esc): Lock · Log out · Suspend · Reboot · Shut down.
// ← → or 1–5 to choose, Enter to run. Everything but Lock counts down 4 s first: Cancel / Esc stops it,
// Enter or the same tile again does it now, and after 4 s it happens by itself.
FocusScope {
    id: pm
    property var svc
    property int sel: 2
    property string armed: ""               // action counting down
    property int secsLeft: 0                // seconds left (not "left": that name is taken by QML)
    signal closed()
    function cancel() { armed = ""; countdown.stop() }
    function now() { const o = opts.find(x => x.id === armed); cancel(); if (o) { closed(); svc.power(o.id) } }
    Timer { id: countdown; interval: 1000; repeat: true; onTriggered: { pm.secsLeft--; if (pm.secsLeft <= 0) pm.now() } }
    onVisibleChanged: if (!visible) cancel()
    width: 600; height: 272
    readonly property var opts: [
        { id: "lock",     label: "Lock",      glyph: "lock",       tint: Theme.gSea,   ok: svc.hasLocker, confirm: false, doing: "Locking" },
        { id: "logout",   label: "Log out",   glyph: "arrowRight", tint: Theme.gSun,   ok: true, confirm: true, doing: "Logging out" },
        { id: "suspend",  label: "Suspend",   glyph: "moon",       tint: Theme.gLilac, ok: true, confirm: true, doing: "Suspending" },
        { id: "reboot",   label: "Reboot",    glyph: "reload",     tint: Theme.gLeaf,  ok: true, confirm: true, doing: "Rebooting" },
        { id: "shutdown", label: "Shut down", glyph: "power",      tint: Theme.gBerry, ok: true, confirm: true, doing: "Shutting down" }
    ]
    function pick(i) {
        const o = opts[i]; sel = i;
        if (!o.ok) { cancel(); return }
        if (o.confirm && armed !== o.id) { armed = o.id; secsLeft = 4; countdown.restart(); return }   // start the 4 s countdown
        cancel(); closed(); svc.power(o.id);
    }
    Keys.onEscapePressed: armed ? cancel() : closed()
    Keys.onLeftPressed: { sel = (sel + 4) % 5; cancel() }
    Keys.onRightPressed: { sel = (sel + 1) % 5; cancel() }
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
                        onEntered: if (!pm.armed) pm.sel = tile.index }      // hovering doesn't stop a countdown
                    UiCandy {
                        anchors.horizontalCenter: parent.horizontalCenter; y: 16; width: 52; height: 52; bw: 2.5; drop: 0; hi: 0
                        fill: tile.cur ? Theme.paper : tile.modelData.tint[1]
                        Glyph { anchors.centerIn: parent; name: tile.modelData.glyph; size: 24; stroke: 2.5 }
                    }
                    // counting down: the big number replaces the name, so it fits the narrow tile
                    UiText { y: tile.arm ? 74 : 78; width: parent.width - 8; x: 4; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
                        text: tile.arm ? pm.secsLeft : tile.modelData.label; px: tile.arm ? 22 : 15; w: 700 }
                    UiText { y: 98; width: parent.width; horizontalAlignment: Text.AlignHCenter
                        text: !tile.modelData.ok ? "needs hyprlock" : tile.arm ? "tap = now" : (tile.index + 1); fam: "n"; px: 10; w: 800; color: Theme.textSoft }
                    // countdown ring: shrinks over the 4 seconds
                    Rectangle { visible: tile.arm; anchors.horizontalCenter: parent.horizontalCenter; y: 12; width: 60; height: 60; radius: 30
                        color: "transparent"; border.width: 4; border.color: Theme.berry; opacity: 0.35 + 0.65 * pm.secsLeft / 4
                        scale: 0.85 + 0.15 * pm.secsLeft / 4; Behavior on scale { NumberAnimation { duration: 900 } } }
                }
            }
        }
        UiText { visible: !pm.armed; x: 0; y: parent.height - 34; width: parent.width; horizontalAlignment: Text.AlignHCenter
            text: "← → choose · Enter · 1–5 · Esc to stay"; fam: "n"; px: 11; w: 800; color: Theme.textSoft }
        // countdown bar: what happens, in how long, Cancel / Do it now
        Row {
            visible: !!pm.armed
            anchors.horizontalCenter: parent.horizontalCenter; y: parent.height - 44; spacing: 10
            UiText { anchors.verticalCenter: parent.verticalCenter; px: 14; w: 700; color: Theme.textDeep
                text: (pm.opts.find(o => o.id === pm.armed) || { doing: "" }).doing + " in " + pm.secsLeft + "…" }
            UiCandy { width: cT.implicitWidth + 26; height: 32; radius: 11; bw: 2.5; drop: 2; hi: 0; fill: Theme.paper; pressable: true
                onClicked: pm.cancel()
                UiText { id: cT; anchors.centerIn: parent; text: "Cancel"; px: 13; w: 700 } }
            UiCandy { width: nT.implicitWidth + 26; height: 32; radius: 11; bw: 2.5; drop: 2; hi: 0; fill: Theme.gBerry; pressable: true
                onClicked: pm.now()
                UiText { id: nT; anchors.centerIn: parent; text: "Do it now"; px: 13; w: 700 } }
        }
    }
}
