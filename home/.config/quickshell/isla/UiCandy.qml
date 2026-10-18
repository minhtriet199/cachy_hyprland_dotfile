import QtQuick

// The Isla "candy sticker" box: ink outline, solid drop shadow, white inset
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
    property bool hoverable: pressable
    property bool down: pressable && ma.pressed
    readonly property bool hovered: ma.containsMouse
    readonly property bool fillIsList: fill !== null && typeof fill === "object" && fill.length !== undefined   // JS array or QVariantList
    readonly property color fillTop: fillIsList ? fill[0] : fill
    readonly property color fillBottom: fillIsList ? fill[fill.length - 1] : fill
    readonly property real ir: Math.max(0, Math.min(radius, Math.min(width, height) / 2) - bw)
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

    Item {
        id: body
        width: r.width; height: r.height
        y: r.down ? Math.min(2, r.drop) : 0
        Behavior on y { NumberAnimation { duration: 70 } }

        Rectangle { visible: r.drop > 0 && !r.dashed; y: r.drop - body.y; width: parent.width; height: parent.height; radius: r.radius; color: r.dropColor }
        Rectangle { visible: !r.dashed && r.hi > 0; x: r.bw; y: r.bw; width: parent.width - 2 * r.bw; height: parent.height - 2 * r.bw; radius: r.ir; color: r.fillTop }
        Rectangle { visible: !r.dashed && r.hi > 0; x: r.bw; y: r.bw; width: parent.width - 2 * r.bw; height: parent.height - 2 * r.bw; radius: r.ir; color: r.hiColor }
        Rectangle {
            visible: !r.dashed
            x: r.bw; y: r.bw + r.hi; width: parent.width - 2 * r.bw; height: parent.height - 2 * r.bw - r.hi; radius: r.ir
            gradient: Gradient { GradientStop { position: 0; color: r.fillTop } GradientStop { position: 1; color: r.fillBottom } }
        }
        // outline ring on top (so see-through fills stay clean)
        Rectangle { visible: !r.dashed; anchors.fill: parent; radius: r.radius; color: "transparent"; border.width: r.bw; border.color: r.ink }
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
