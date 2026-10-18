import QtQuick

// Displays page (phone): screen picker drawn as the real layout, brightness, HDR,
// resolution / refresh / scale with Apply + "Keep?" (goes back by itself after 15 s).
// Backend: ~/.config/hypr/scripts/screenctl.py (same as the Screen Settings app).
// No rotate / mirror / disable here — those crashed Hyprland before.
Item {
    id: dp
    property var svc
    property string sel: ""
    readonly property var scr: svc.screens.find(m => m.output === sel) || svc.screens[0] || null
    // staged choice
    property string res: ""
    property real hz: 0
    property real scale: 1
    property var undo: null
    property int keepLeft: 0
    implicitHeight: col.implicitHeight
    Component.onCompleted: svc.loadScreens()
    onScrChanged: if (scr && (!res || scr.output !== sel)) Qt.callLater(reset)
    function reset() { if (!scr) return; sel = scr.output; res = scr.width + "x" + scr.height; hz = scr.refresh; scale = scr.scale }
    readonly property var modeList: scr ? scr.modes : []
    readonly property var rates: { const m = modeList.find(x => x.w + "x" + x.h === res); return m ? m.rates : [] }
    readonly property bool changed: !!scr && (res !== scr.width + "x" + scr.height || Math.abs(hz - scr.refresh) > 0.05 || scale !== scr.scale)
    function apply() {
        undo = { out: scr.output, mode: scr.width + "x" + scr.height + "@" + scr.refresh, scale: scr.scale };
        svc.screenCmd(["mode", scr.output, res + "@" + hz, String(scale)]);
        keepLeft = 15; keepTimer.restart();
    }
    function revert() {
        keepTimer.stop(); keepLeft = 0;
        if (undo && undo.pos) svc.screenCmd(["pos"].concat(undo.pos));
        else if (undo && undo.order) svc.screenCmd(["order"].concat(undo.order));
        else if (undo) svc.screenCmd(["mode", undo.out, undo.mode, String(undo.scale)]);
        undo = null;
    }
    // where the picked screen is now, compared with the other one
    function sideOf(m) {
        const o = svc.screens.find(x => x.output !== m.output); if (!o) return "";
        if (m.y + 1 < o.y && m.x < o.x + o.width / o.scale && o.x < m.x + m.width / m.scale) return "above";
        if (o.y + 1 < m.y && m.x < o.x + o.width / o.scale && o.x < m.x + m.width / m.scale) return "below";
        return m.x < o.x ? "left" : "right";
    }
    // left → right order of the screens, move the picked one by one place
    readonly property var order: svc.screens.slice().sort((a, b) => a.x - b.x).map(m => m.output)
    function place(side) {
        const other = svc.screens.find(m => m.output !== scr.output); if (!other) return;
        const lw = m => Math.round((m.transform % 2 ? m.height : m.width) / m.scale), lh = m => Math.round((m.transform % 2 ? m.width : m.height) / m.scale);
        let ax = 0, ay = 0, bx = 0, by = 0;                 // a = picked, b = other
        if (side === "left")  { ax = 0; bx = lw(scr) }
        if (side === "right") { bx = 0; ax = lw(other) }
        if (side === "above") { ay = 0; by = lh(scr); ax = Math.max(0, Math.round((lw(other) - lw(scr)) / 2)); bx = Math.max(0, Math.round((lw(scr) - lw(other)) / 2)) }
        if (side === "below") { by = 0; ay = lh(other); ax = Math.max(0, Math.round((lw(other) - lw(scr)) / 2)); bx = Math.max(0, Math.round((lw(scr) - lw(other)) / 2)) }
        undo = { pos: [scr.output, scr.x + "x" + scr.y, other.output, other.x + "x" + other.y] };
        svc.screenCmd(["pos", scr.output, ax + "x" + ay, other.output, bx + "x" + by]);
        keepLeft = 15; keepTimer.restart();
    }
    function move(d) {
        const o = order.slice(), i = o.indexOf(scr.output), j = i + d;
        if (i < 0 || j < 0 || j >= o.length) return;
        undo = { order: order.slice() };
        [o[i], o[j]] = [o[j], o[i]];
        svc.screenCmd(["order"].concat(o));
        keepLeft = 15; keepTimer.restart();
    }
    Timer { id: keepTimer; interval: 1000; repeat: true; onTriggered: { dp.keepLeft--; if (dp.keepLeft <= 0) dp.revert() } }

    Column {
        id: col
        width: dp.width; spacing: 12
        // layout picker
        Item {
            id: lay
            width: parent.width; height: 96
            readonly property var bounds: {
                let x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9;
                for (const m of dp.svc.screens) { const w = m.width / m.scale, h = m.height / m.scale; x0 = Math.min(x0, m.x); y0 = Math.min(y0, m.y); x1 = Math.max(x1, m.x + w); y1 = Math.max(y1, m.y + h) }
                return { x0: x0, y0: y0, w: x1 - x0, h: y1 - y0 };
            }
            readonly property real k: bounds.w > 0 ? Math.min((width - 20) / bounds.w, (height - 8) / bounds.h) : 0
            Repeater {
                model: dp.svc.screens
                delegate: UiCandy {
                    required property var modelData
                    readonly property bool cur: dp.scr && modelData.output === dp.scr.output
                    x: (lay.width - lay.bounds.w * lay.k) / 2 + (modelData.x - lay.bounds.x0) * lay.k + 3
                    y: (modelData.y - lay.bounds.y0) * lay.k + 2
                    width: modelData.width / modelData.scale * lay.k - 6; height: modelData.height / modelData.scale * lay.k - 6
                    radius: 10; bw: cur ? 3 : 2.5; drop: cur ? 3 : 0; hi: 0; fill: cur ? Theme.gOn : Theme.paper; pressable: true
                    onClicked: { dp.sel = modelData.output; dp.reset() }
                    Column { anchors.centerIn: parent
                        UiText { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.internal ? "Laptop" : modelData.model; px: 13; w: 700 }
                        UiText { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.output + (modelData.focused ? " · here" : ""); fam: "n"; px: 9.5; w: 800; color: Theme.textSoft } }
                }
            }
        }
        // move the picked screen
        Row {
            visible: !!dp.scr && dp.svc.screens.length > 1 && dp.keepLeft === 0
            anchors.horizontalCenter: parent.horizontalCenter; spacing: dp.width < 460 ? 6 : 10
            Repeater {
                // [side, label, arrow] — buttons shrink so all four fit the narrow phone
                model: [["left", "Left", "←"], ["above", "Top", "↑"], ["below", "Bottom", "↓"], ["right", "Right", "→"]]
                delegate: UiCandy {
                    required property var modelData
                    readonly property bool here: !!dp.scr && dp.sideOf(dp.scr) === modelData[0]
                    width: Math.min(104, (dp.width - 3 * parent.spacing) / 4); height: 32; radius: 11; bw: 2.5; drop: here ? 0 : 3; hi: 0
                    fill: here ? Theme.gOn : Theme.paper; pressable: !here
                    onClicked: dp.place(modelData[0])
                    UiText { anchors.centerIn: parent; width: parent.width - 8; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
                        text: modelData[2] + (parent.width < 90 ? " " : "  ") + modelData[1]; px: parent.width < 90 ? 12 : 13; w: 700 }
                }
            }
        }
        Row {
            visible: dp.keepLeft > 0 && !!dp.undo && (!!dp.undo.order || !!dp.undo.pos)
            anchors.horizontalCenter: parent.horizontalCenter; spacing: 10
            UiCandy { width: 150; height: 32; radius: 11; bw: 2.5; drop: 3; hi: 3; fill: Theme.gGo; pressable: true
                onClicked: { keepTimer.stop(); dp.keepLeft = 0; dp.undo = null }
                UiText { anchors.centerIn: parent; text: "Keep (" + dp.keepLeft + ")"; px: 13; w: 700; color: "#FFFFFF" } }
            UiCandy { width: 110; height: 32; radius: 11; bw: 2.5; drop: 3; hi: 0; fill: Theme.paper; pressable: true
                onClicked: dp.revert()
                UiText { anchors.centerIn: parent; text: "Go back"; px: 13; w: 700 } }
        }
        UiText { visible: !dp.scr; text: "Reading screens…"; fam: "n"; px: 12; w: 800; color: Theme.textSoft }
        // brightness + HDR
        Item {
            visible: !!dp.scr
            width: parent.width; height: 40
            UiText { y: 0; text: "BRIGHTNESS · " + (dp.scr ? dp.scr.pct : 0) + "%" + (dp.scr && dp.scr.hdr ? " · " + dp.scr.nits + " nits" : ""); fam: "n"; px: 11; w: 900; track: 1.4; color: Theme.textSoft; height: 16 }
            UiSlider { y: 22; width: parent.width - (hdrBox.visible ? hdrBox.width + 16 : 0); value: dp.scr ? dp.scr.pct / 100 : 0; color: Theme.sunDeep
                onPicked: v => dp.svc.screenCmd(["set", dp.scr.output, String(Math.max(5, Math.round(v * 100)))]) }
            Row { id: hdrBox; visible: !!dp.scr && dp.scr.hdr_supported; anchors.right: parent.right; y: 8; spacing: 8
                UiText { text: "HDR"; px: 14; w: 700; anchors.verticalCenter: parent.verticalCenter }
                UiSwitch { on: !!dp.scr && dp.scr.hdr; onColor: Theme.purple; onToggled: dp.svc.screenCmd(["hdr", dp.scr.output, dp.scr.hdr ? "off" : "on"]) } }
        }
        // resolution / refresh / scale chips
        Repeater {
            model: dp.scr ? [
                ["RESOLUTION", dp.modeList.map(m => m.w + "x" + m.h), dp.res],
                ["REFRESH RATE", dp.rates.map(r => String(r)), String(dp.hz)],
                ["SCALE", ["1", "1.25", "1.5", "1.6", "2"], String(dp.scale)]
            ] : []
            delegate: Column {
                id: sec
                required property var modelData
                required property int index
                width: col.width; spacing: 6
                UiText { text: modelData[0]; fam: "n"; px: 11; w: 900; track: 1.4; color: Theme.textSoft; height: 16 }
                Flow {
                    width: parent.width; spacing: 6
                    Repeater {
                        model: modelData[1]
                        delegate: UiCandy {
                            required property string modelData
                            readonly property bool picked: modelData === sec.modelData[2]
                            width: chip.implicitWidth + 20; height: 28; radius: 9; bw: 2; drop: picked ? 2 : 0; hi: 0
                            fill: picked ? Theme.gOn : Theme.cream; pressable: true
                            onClicked: {
                                const i = sec.index;
                                if (i === 0) { dp.res = modelData; if (!dp.rates.includes(dp.hz)) dp.hz = dp.rates.length ? Math.max(...dp.rates.filter(r => r <= 120)) || dp.rates[0] : 60 }
                                else if (i === 1) dp.hz = parseFloat(modelData);
                                else dp.scale = parseFloat(modelData);
                            }
                            UiText { id: chip; anchors.centerIn: parent; text: sec.index === 1 ? modelData + " Hz" : sec.index === 2 ? modelData + "×" : modelData.replace("x", " × "); px: 12; w: 700 }
                        }
                    }
                }
            }
        }
        // apply / keep
        Row {
            visible: !!dp.scr; spacing: 10
            UiCandy {
                visible: dp.keepLeft === 0
                width: 120; height: 36; radius: 12; bw: 2.5; drop: 3; hi: dp.changed ? 3 : 0
                fill: dp.changed ? Theme.gGo : Theme.paper; opacity: dp.changed ? 1 : 0.5; pressable: dp.changed
                onClicked: dp.apply()
                UiText { anchors.centerIn: parent; text: "Apply"; px: 14; w: 700; color: dp.changed ? "#FFFFFF" : Theme.text }
            }
            UiCandy {
                visible: dp.keepLeft > 0
                width: 150; height: 36; radius: 12; bw: 2.5; drop: 3; hi: 3; fill: Theme.gGo; pressable: true
                onClicked: { keepTimer.stop(); dp.keepLeft = 0; dp.undo = null }
                UiText { anchors.centerIn: parent; text: "Keep (" + dp.keepLeft + ")"; px: 14; w: 700; color: "#FFFFFF" }
            }
            UiCandy {
                visible: dp.keepLeft > 0 || dp.changed
                width: 100; height: 36; radius: 12; bw: 2.5; drop: 3; hi: 0; fill: Theme.paper; pressable: true
                onClicked: dp.keepLeft > 0 ? dp.revert() : dp.reset()
                UiText { anchors.centerIn: parent; text: dp.keepLeft > 0 ? "Go back" : "Cancel"; px: 14; w: 700 }
            }
        }
    }
}
