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
        if (undo && undo.live) svc.screenCmd(["poslive"].concat(undo.live));
        else if (undo && undo.pos) svc.screenCmd(["pos"].concat(undo.pos));
        else if (undo && undo.order) svc.screenCmd(["order"].concat(undo.order));
        else if (undo) svc.screenCmd(["mode", undo.out, undo.mode, String(undo.scale)]);
        undo = null;
    }
    // ── layout, any number of screens: drag a screen in the map, or use the side buttons. A moved screen snaps
    //    against another (any side, lined up start / middle / end), never overlaps, and loose screens slide back
    //    so there are no gaps. Tried LIVE (screenctl poslive, nothing saved) → Keep saves it, Go back / 15 s undoes. ──
    function lw(m) { return Math.round((m.transform % 2 ? m.height : m.width) / m.scale) }
    function lh(m) { return Math.round((m.transform % 2 ? m.width : m.height) / m.scale) }
    function rects() { return svc.screens.map(m => ({ out: m.output, x: m.x, y: m.y, w: lw(m), h: lh(m) })) }
    function hits(a, b) { return a.x < b.x + b.w && b.x < a.x + a.w && a.y < b.y + b.h && b.y < a.y + a.h }
    function touching(a, b) {
        const v = a.y < b.y + b.h && b.y < a.y + a.h, h = a.x < b.x + b.w && b.x < a.x + a.w;
        return (v && (a.x + a.w === b.x || b.x + b.w === a.x)) || (h && (a.y + a.h === b.y || b.y + b.h === a.y));
    }
    // which side of all the other screens the picked one is on ("" = in between)
    function sideOf(m) {
        const rs = rects(), me = rs.find(r => r.out === m.output), o = rs.filter(r => r.out !== m.output);
        if (!me || !o.length) return "";
        if (me.y + me.h <= Math.min(...o.map(r => r.y))) return "above";
        if (me.y >= Math.max(...o.map(r => r.y + r.h))) return "below";
        if (me.x + me.w <= Math.min(...o.map(r => r.x))) return "left";
        if (me.x >= Math.max(...o.map(r => r.x + r.w))) return "right";
        return "";
    }
    // nearest free spot touching another screen, close to (px, py)
    function snap(out, px, py) {
        const rs = rects(), me = rs.find(r => r.out === out), others = rs.filter(r => r.out !== out);
        let best = null, bd = 1e18;
        for (const o of others) {
            const c = [];
            for (const y of [o.y, o.y + (o.h - me.h) / 2, o.y + o.h - me.h]) { c.push([o.x - me.w, y]); c.push([o.x + o.w, y]) }
            for (const x of [o.x, o.x + (o.w - me.w) / 2, o.x + o.w - me.w]) { c.push([x, o.y - me.h]); c.push([x, o.y + o.h]) }
            for (const p of c) {
                const r = { out: out, x: Math.round(p[0]), y: Math.round(p[1]), w: me.w, h: me.h };
                if (others.some(q => hits(r, q))) continue;
                const d = (r.x - px) ** 2 + (r.y - py) ** 2;
                if (d < bd) { bd = d; best = r }
            }
        }
        return best;
    }
    // screens no longer touching the moved one's group slide toward it until they touch (no gaps)
    function compact(rs, out) {
        for (let pass = 0; pass < rs.length; pass++) {
            const main = [rs.find(r => r.out === out)], rest = rs.filter(r => r.out !== out);
            for (let grew = true; grew;) { grew = false
                for (let i = rest.length - 1; i >= 0; i--) if (main.some(m => touching(m, rest[i]))) { main.push(rest.splice(i, 1)[0]); grew = true } }
            if (!rest.length) break;
            const grp = [rest.shift()];
            for (let grew = true; grew;) { grew = false
                for (let i = rest.length - 1; i >= 0; i--) if (grp.some(g => touching(g, rest[i]))) { grp.push(rest.splice(i, 1)[0]); grew = true } }
            const cand = [];
            for (const c of grp) for (const m of main) {
                if (c.y < m.y + m.h && m.y < c.y + c.h) cand.push([c.x >= m.x + m.w ? m.x + m.w - c.x : c.x + c.w <= m.x ? m.x - c.x - c.w : NaN, 0]);
                if (c.x < m.x + m.w && m.x < c.x + c.w) cand.push([0, c.y >= m.y + m.h ? m.y + m.h - c.y : c.y + c.h <= m.y ? m.y - c.y - c.h : NaN]);
            }
            // only touching at a corner (no straight slide): line it up against the nearest screen instead
            const cand2 = [];
            for (const g of grp) for (const m of main) {
                for (const y of [m.y, m.y + m.h - g.h]) { cand2.push([m.x - g.w - g.x, y - g.y]); cand2.push([m.x + m.w - g.x, y - g.y]) }
                for (const x of [m.x, m.x + m.w - g.w]) { cand2.push([x - g.x, m.y - g.h - g.y]); cand2.push([x - g.x, m.y + m.h - g.y]) }
            }
            const free = d => !grp.some(g => rs.some(q => !grp.includes(q) && hits({ x: g.x + d[0], y: g.y + d[1], w: g.w, h: g.h }, q)));
            const near = (a, b) => Math.abs(a[0]) + Math.abs(a[1]) - Math.abs(b[0]) - Math.abs(b[1]);
            const ok = cand.filter(d => !isNaN(d[0]) && !isNaN(d[1])).sort(near).find(free) || cand2.sort(near).find(free);
            if (!ok) break;                                            // can't line up: leave it where it is
            for (const g of grp) { g.x += ok[0]; g.y += ok[1] }
        }
        const x0 = Math.min(...rs.map(r => r.x)), y0 = Math.min(...rs.map(r => r.y));
        for (const r of rs) { r.x -= x0; r.y -= y0 }
        return rs;
    }
    function pairs(rs) { const o = []; for (const r of rs) o.push(r.out, r.x + "x" + r.y); return o }
    function tryLayout(rs) {
        const now = pairs(rects()), next = pairs(rs);
        if (now.join() === next.join()) return;
        undo = { live: now, next: next };
        svc.screenCmd(["poslive"].concat(next));
        keepLeft = 15; keepTimer.restart();
    }
    function dropAt(out, px, py) {
        const r = snap(out, px, py); if (!r) return;
        tryLayout(compact(rects().map(q => q.out === out ? r : q), out));
    }
    // side buttons: put the picked screen on that side of ALL the others
    function place(side) {
        if (!scr) return;
        const rs = rects(), me = rs.find(r => r.out === scr.output), o = rs.filter(r => r.out !== scr.output);
        if (!o.length) return;
        const pick = (f, cmp) => o.reduce((a, b) => cmp(f(b), f(a)) ? b : a);
        if (side === "left")  { const t = pick(r => r.x, (p, q) => p < q); me.x = t.x - me.w; me.y = t.y }
        if (side === "right") { const t = pick(r => r.x + r.w, (p, q) => p > q); me.x = t.x + t.w; me.y = t.y }
        if (side === "above") { const t = pick(r => r.y, (p, q) => p < q); me.y = t.y - me.h; me.x = Math.round(t.x + (t.w - me.w) / 2) }
        if (side === "below") { const t = pick(r => r.y + r.h, (p, q) => p > q); me.y = t.y + t.h; me.x = Math.round(t.x + (t.w - me.w) / 2) }
        tryLayout(compact(rs, scr.output));
    }
    function keep() { keepTimer.stop(); keepLeft = 0; if (undo && undo.next) svc.screenCmd(["pos"].concat(undo.next)); undo = null }
    // left → right order of the screens
    readonly property var order: svc.screens.slice().sort((a, b) => a.x - b.x).map(m => m.output)
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
            width: parent.width; height: dp.svc.screens.length > 2 ? 140 : 96
            readonly property var bounds: {
                let x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9;
                for (const m of dp.svc.screens) { const w = dp.lw(m), h = dp.lh(m); x0 = Math.min(x0, m.x); y0 = Math.min(y0, m.y); x1 = Math.max(x1, m.x + w); y1 = Math.max(y1, m.y + h) }
                return { x0: x0, y0: y0, w: x1 - x0, h: y1 - y0 };
            }
            readonly property real k: bounds.w > 0 ? Math.min((width - 20) / bounds.w, (height - 8) / bounds.h) : 0
            Repeater {
                model: dp.svc.screens
                delegate: UiCandy {
                    id: box
                    required property var modelData
                    readonly property bool cur: dp.scr && modelData.output === dp.scr.output
                    property real dx: 0
                    property real dy: 0
                    x: (lay.width - lay.bounds.w * lay.k) / 2 + (modelData.x - lay.bounds.x0) * lay.k + 3 + dx
                    y: (lay.height - lay.bounds.h * lay.k) / 2 + (modelData.y - lay.bounds.y0) * lay.k + 2 + dy
                    z: dragMa.moved ? 5 : 0; opacity: dragMa.moved ? 0.85 : 1
                    width: dp.lw(modelData) * lay.k - 6; height: dp.lh(modelData) * lay.k - 6
                    radius: 10; bw: cur ? 3 : 2.5; drop: cur ? 3 : 0; hi: 0; fill: cur ? Theme.gOn : Theme.paper; pressable: false
                    // tap = pick this screen, drag = move it (snaps when let go)
                    MouseArea {
                        id: dragMa
                        anchors.fill: parent
                        property point p0
                        property bool moved: false
                        readonly property bool canDrag: dp.svc.screens.length > 1 && dp.keepLeft === 0
                        cursorShape: canDrag ? (moved ? Qt.ClosedHandCursor : Qt.OpenHandCursor) : Qt.PointingHandCursor
                        onPressed: e => { p0 = mapToItem(lay, e.x, e.y); moved = false }
                        onPositionChanged: e => {
                            if (!canDrag) return;
                            const p = mapToItem(lay, e.x, e.y);
                            if (!moved && Math.hypot(p.x - p0.x, p.y - p0.y) < 6) return;
                            moved = true; box.dx = p.x - p0.x; box.dy = p.y - p0.y;
                        }
                        onReleased: {
                            dp.sel = box.modelData.output; dp.reset();
                            if (moved) dp.dropAt(box.modelData.output, box.modelData.x + box.dx / lay.k, box.modelData.y + box.dy / lay.k);
                            box.dx = 0; box.dy = 0; moved = false;
                        }
                        onCanceled: { box.dx = 0; box.dy = 0; moved = false }
                    }
                    Column { anchors.centerIn: parent
                        UiText { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.internal ? "Laptop" : modelData.model; px: 13; w: 700 }
                        UiText { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.output + (modelData.focused ? " · here" : ""); fam: "n"; px: 9.5; w: 800; color: Theme.textSoft } }
                }
            }
        }
        UiText { visible: dp.svc.screens.length > 1 && dp.keepLeft === 0; width: parent.width; horizontalAlignment: Text.AlignHCenter
            text: "Drag a screen to move it · or put the picked one on a side:"; fam: "n"; px: 10.5; w: 800; color: Theme.textSoft }
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
                onClicked: dp.keep()
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
        // gamma (all screens, through hyprsunset; shared with night light)
        Item {
            visible: !!dp.scr
            width: parent.width; height: 40
            UiText { y: 0; text: "GAMMA · " + Math.round(dp.svc.gamma * 100) + "%"; fam: "n"; px: 11; w: 900; track: 1.4; color: Theme.textSoft; height: 16 }
            UiSlider { y: 22; width: parent.width; value: (dp.svc.gamma - 0.5) / 0.5; color: "#A08AEA"
                onPicked: v => dp.svc.setGamma(0.5 + v * 0.5) }
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
                onClicked: dp.keep()
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
