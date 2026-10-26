import QtQuick

// The Island "candy sticker" box: ink outline, solid drop shadow, white inset
// highlight at the top, vertical gradient fill. Children go on top.
Item {
    id: r
    property real radius: 999
    property real bw: 2.5                 // outline width
    property color ink: Theme.ink
    property real drop: 4                 // solid shadow offset (0 = none)
    property color dropColor: ink
    property real hi: 3                   // inset highlight height (0 = none)
    property color hiColor: Theme.hi
    property var fill: [Theme.paper, Theme.paper]   // [top, bottom] or a single colour
    property bool dashed: false
    property bool pressable: false
    // picked swatch / choice: a ring just outside the box, drawn the same in every box style (Soft has no outline,
    // so a thicker outline alone showed nothing there)
    property bool selected: false
    property bool hoverable: pressable
    property bool down: pressable && ma.pressed
    readonly property bool hovered: ma.containsMouse
    readonly property bool fillIsList: fill !== null && typeof fill === "object" && fill.length !== undefined   // JS array or QVariantList
    readonly property color fillTop: fillIsList ? fill[0] : fill
    readonly property color fillBottom: fillIsList ? fill[fill.length - 1] : fill
    // box style (Theme.boxStyle) — what is actually drawn; sizes and layout stay the same in every style:
    //   candy = outline + solid shadow + shine · ring = outline, light gap, then the fill · pop = thicker outline, big solid shadow
    //   soft = no outline, faint see-through shadow · flat = outline only · glass = see-through fill, thin white edge
    readonly property string bs: dashed ? "candy" : Theme.boxStyle
    readonly property real eb: bs === "soft" ? 0 : bs === "glass" ? Math.min(bw, 1.5) : bs === "pop" && bw > 0 ? bw + 0.5 : bw
    readonly property real ed: bs === "flat" || bs === "glass" ? 0 : bs === "pop" && drop > 0 ? drop + 3 : bs === "soft" && drop > 0 ? drop + 1 : drop
    readonly property real eh: bs === "candy" ? hi : 0
    readonly property color edgeColor: bs === "glass" ? Qt.rgba(1, 1, 1, 0.85) : ink
    readonly property real fillAlpha: bs === "glass" ? 0.55 : 1
    readonly property color edropColor: bs === "ring" ? Qt.rgba(fillBottom.r, fillBottom.g, fillBottom.b, 0.85)
                                      : bs === "soft" ? Qt.rgba(ink.r, ink.g, ink.b, 0.16) : dropColor
    readonly property real ir: Math.max(0, Math.min(radius, Math.min(width, height) / 2) - eb)
    readonly property real gap: bs === "ring" ? (Math.min(width, height) < 30 ? 2 : Math.min(width, height) < 44 ? 3.5 : 5) : 0
    default property alias content: holder.data
    signal clicked()
    signal rightClicked()

    // keyboard: Tab / arrows move between buttons, Enter / Space press (only in windows that have keyboard focus, like the phone)
    activeFocusOnTab: pressable && visible && enabled
    Keys.onReturnPressed: clicked()
    Keys.onEnterPressed: clicked()
    Keys.onSpacePressed: clicked()
    function zoneOf(it) { let p = it ? it.parent : null; while (p) { if (p.isNavZone === true) return p; p = p.parent } return null }
    // a small button inside another button (the ✕ on a list row): ↑/↓ skip it, Tab and →/← reach it
    function nestedIn(it) { let p = it ? it.parent : null; while (p) { if (p.activeFocusOnTab === true && typeof p.moveFocus === "function") return p; p = p.parent } return null }
    function moveFocus(fwd, rowsOnly) {
        const z = zoneOf(r); let n = r;
        for (let k = 0; k < 400; k++) {
            n = n.nextItemInFocusChain(fwd);
            if (!n || n === r) return;
            if (rowsOnly && nestedIn(n)) continue;
            if (rowsOnly && !fwd && nestedIn(r) === n) continue;       // from a row's ✕, ↑ goes to the row above, not its own row
            if (zoneOf(n) === z) { n.forceActiveFocus(fwd ? Qt.TabFocusReason : Qt.BacktabFocusReason); return }
        }
    }
    // a screen can take over Tab (e.g. Home: Tab = next search type) by defining tabKey(forward)
    function tabOwner() { let p = r.parent; while (p) { if (typeof p.tabKey === "function") return p; p = p.parent } return null }
    Keys.onTabPressed: { const o = tabOwner(); if (o) o.tabKey(true); else moveFocus(true) }
    Keys.onBacktabPressed: { const o = tabOwner(); if (o) o.tabKey(false); else moveFocus(false) }
    // plain arrows move the ring; with Ctrl / Alt they pass up to the phone (Ctrl+←/→ switch area, Alt+← back)
    function arrow(e, fwd, rows) { if (e.modifiers & (Qt.ControlModifier | Qt.AltModifier)) { e.accepted = false; return } moveFocus(fwd, rows) }
    Keys.onDownPressed: e => arrow(e, true, true)
    Keys.onRightPressed: e => arrow(e, true, false)
    Keys.onUpPressed: e => arrow(e, false, true)
    Keys.onLeftPressed: e => arrow(e, false, false)

    Rectangle {
        visible: r.selected
        x: -4; y: -4 + body.y; width: r.width + 8; height: r.height + 8 + Math.max(0, r.ed - 1); z: -1
        radius: r.radius >= 999 ? height / 2 : r.radius + 4; color: "transparent"; border.width: 2.5; border.color: Theme.purple
    }
    Item {
        id: body
        width: r.width; height: r.height
        y: r.down ? Math.min(2, r.ed) : 0
        Behavior on y { NumberAnimation { duration: 70 } }

        Rectangle { visible: r.ed > 0 && !r.dashed; y: r.ed - body.y; width: parent.width; height: parent.height; radius: r.radius; color: r.edropColor }
        Rectangle { visible: r.gap > 0; x: r.eb; y: r.eb; width: parent.width - 2 * r.eb; height: parent.height - 2 * r.eb; radius: r.ir; color: Theme.paper }
        Rectangle { visible: !r.dashed && r.eh > 0; x: r.eb; y: r.eb; width: parent.width - 2 * r.eb; height: parent.height - 2 * r.eb; radius: r.ir; color: r.fillTop }
        Rectangle { visible: !r.dashed && r.eh > 0; x: r.eb; y: r.eb; width: parent.width - 2 * r.eb; height: parent.height - 2 * r.eb; radius: r.ir; color: r.hiColor }
        Rectangle {
            visible: !r.dashed
            readonly property real inset: r.eb + r.gap
            x: inset; y: inset + r.eh; width: parent.width - 2 * inset; height: parent.height - 2 * inset - r.eh; radius: Math.max(0, r.ir - r.gap)
            opacity: r.fillAlpha
            gradient: Gradient { GradientStop { position: 0; color: r.fillTop } GradientStop { position: 1; color: r.fillBottom } }
        }
        // outline ring on top (so see-through fills stay clean)
        Rectangle { visible: !r.dashed && r.eb > 0; anchors.fill: parent; radius: r.radius; color: "transparent"; border.width: r.eb; border.color: r.edgeColor }
        UiDashed { visible: r.dashed; anchors.fill: parent; radius: r.radius; bw: r.bw; color: r.ink; fillColor: r.fillTop }
        Rectangle { anchors.fill: parent; radius: r.radius; color: "white"; opacity: r.hoverable && r.hovered && !r.down ? 0.18 : 0
            Behavior on opacity { NumberAnimation { duration: 120 } } }
        Item { id: holder; anchors.fill: parent }
        // keyboard focus ring
        Rectangle { visible: r.activeFocus; anchors.fill: parent; anchors.margins: -4; radius: r.radius + 5; color: "transparent"; border.width: 3; border.color: Theme.sunDeep }
    }
    MouseArea {
        id: ma
        z: -1                    // under the children, so buttons inside a clickable box get their own clicks
        anchors.fill: parent
        enabled: r.pressable || r.hoverable
        hoverEnabled: r.hoverable
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: r.pressable ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: m => m.button === Qt.RightButton ? r.rightClicked() : r.clicked()
    }
}
