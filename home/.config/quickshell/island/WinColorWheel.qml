import QtQuick

// Settings → Windows: colour wheel (hue around, strength outwards) + brightness slider + hex box.
// Edits page.v[target] through page.put(); target = "active1" · "active2" · "inactive".
Item {
    id: cw
    property var page                    // the Windows page (values + put())
    property string target: "active1"
    readonly property color cur: page ? "#" + page.v[target] : "#000000"
    // the wheel keeps its own hue/sat/value so dragging stays smooth (hex → hsv loses hue at grey)
    property real hh: 0
    property real ss: 0
    property real vv: 1
    function load() { if (!page) return; const c = cur; hh = Math.max(0, c.hsvHue); ss = c.hsvSaturation; vv = c.hsvValue; hexIn.text = page.v[target].toUpperCase() }
    onTargetChanged: load()
    Connections { target: cw.page; function onLoadedChanged() { cw.load() } }
    Component.onCompleted: load()
    function push() { const h = page.hex(Qt.hsva(hh, ss, vv, 1)); page.put(target, h); if (!hexIn.activeFocus) hexIn.text = h.toUpperCase() }
    readonly property real d: 150
    implicitHeight: d
    height: d
    // wheel
    Item {
        id: wh
        width: cw.d; height: cw.d
        Canvas {
            anchors.fill: parent; anchors.margins: 4
            onPaint: { const g = getContext("2d"), r = width / 2; g.reset()
                const cg = g.createConicalGradient(r, r, 0)
                for (let i = 0; i <= 6; i++) cg.addColorStop(i / 6, Qt.hsva(i / 6, 1, 1, 1))
                g.fillStyle = cg; g.beginPath(); g.arc(r, r, r, 0, Math.PI * 2); g.fill()
                const rg = g.createRadialGradient(r, r, 0, r, r, r); rg.addColorStop(0, "white"); rg.addColorStop(1, Qt.rgba(1, 1, 1, 0))
                g.fillStyle = rg; g.beginPath(); g.arc(r, r, r, 0, Math.PI * 2); g.fill() }
        }
        // darker as brightness goes down
        Rectangle { anchors.fill: parent; anchors.margins: 4; radius: width / 2; color: "black"; opacity: 1 - cw.vv }
        Rectangle { anchors.fill: parent; radius: width / 2; color: "transparent"; border.width: 3; border.color: Theme.inkPhone }
        // knob (conical gradient runs counter-clockwise from 3 o'clock)
        Rectangle {
            readonly property real rr: (cw.d / 2 - 4) * cw.ss
            x: cw.d / 2 + Math.cos(-cw.hh * 2 * Math.PI) * rr - width / 2
            y: cw.d / 2 + Math.sin(-cw.hh * 2 * Math.PI) * rr - height / 2
            width: 20; height: 20; radius: 10; color: cw.cur; border.width: 3; border.color: Theme.paper
            Rectangle { anchors.fill: parent; anchors.margins: -2; radius: 12; color: "transparent"; border.width: 2; border.color: Theme.inkPhone }
        }
        MouseArea {
            anchors.fill: parent; cursorShape: Qt.CrossCursor
            function pick(m) { const dx = m.x - cw.d / 2, dy = m.y - cw.d / 2
                let a = Math.atan2(-dy, dx) / (2 * Math.PI); if (a < 0) a += 1
                cw.hh = a; cw.ss = Math.min(1, Math.sqrt(dx * dx + dy * dy) / (cw.d / 2 - 4)); cw.push() }
            onPressed: m => pick(m)
            onPositionChanged: m => { if (pressed) pick(m) }
        }
    }
    // brightness + hex
    Column {
        x: cw.d + 14; width: cw.width - x; anchors.verticalCenter: parent.verticalCenter; spacing: 8
        UiText { fam: "n"; px: 11; w: 900; track: 1.4; color: Theme.textSoft; height: 18; text: "BRIGHTNESS · " + Math.round(cw.vv * 100) + "%" }
        UiSlider { width: parent.width; value: cw.vv; color: Theme.sunDeep; onPicked: x => { cw.vv = x; cw.push() } }
        Item { width: 1; height: 2 }
        UiText { fam: "n"; px: 11; w: 900; track: 1.4; color: Theme.textSoft; height: 18; text: "HEX CODE" }
        Row {
            spacing: 8
            Rectangle { width: 30; height: 30; radius: 10; color: cw.cur; border.width: 2; border.color: Theme.inkPhone }
            UiCandy {
                width: 104; height: 30; radius: 10; bw: 2; drop: 0; hi: 0; ink: Theme.inkPhone; fill: hexIn.activeFocus ? Theme.cream : Theme.paper
                UiText { id: hash; x: 9; anchors.verticalCenter: parent.verticalCenter; text: "#"; px: 14; w: 700; color: Theme.textSoft }
                TextInput {
                    id: hexIn
                    x: hash.x + hash.implicitWidth + 2; width: parent.width - x - 8; anchors.verticalCenter: parent.verticalCenter
                    font.family: Theme.display; font.pixelSize: 14; font.weight: 700; color: Theme.text; selectByMouse: true
                    font.capitalization: Font.AllUppercase; maximumLength: 7
                    validator: RegularExpressionValidator { regularExpression: /#?[0-9A-Fa-f]{0,6}/ }
                    // applies as soon as 6 digits are there (pasting "#A893EC" works too)
                    onTextEdited: { const t = text.replace("#", ""); if (t.length === 6) { page.put(cw.target, t.toLowerCase()); const c = cw.cur; cw.hh = Math.max(0, c.hsvHue); cw.ss = c.hsvSaturation; cw.vv = c.hsvValue } }
                    onEditingFinished: text = page.v[cw.target].toUpperCase()
                    Keys.onEscapePressed: { text = page.v[cw.target].toUpperCase(); focus = false }
                }
            }
        }
    }
}
