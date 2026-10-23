import QtQuick

// Chunky slider (volume): click, drag or scroll. value 0..max.
// The wheel only moves it after a click on it ("armed", yellow ring on the knob) until the pointer leaves,
// so scrolling a page over a slider scrolls the page.
// While you use it the knob follows your hand at once (its own copy of the value); the real value
// (e.g. PipeWire) catches up in the background and is shown again a moment after you stop.
Item {
    id: l
    property real value: 0.5
    property real max: 1
    property real step: 0.05                 // per wheel notch
    property color color: Theme.leaf
    signal picked(real v)
    height: 14
    property real local: value
    property bool busy: false
    property bool armed: false
    readonly property real shown: busy ? local : value
    Timer { id: settle; interval: 500; onTriggered: l.busy = false }
    function set(v) { local = Math.max(0, Math.min(l.max, v)); busy = true; settle.restart(); l.picked(local) }

    Rectangle { anchors.fill: parent; radius: 7; color: Theme.ink }
    Rectangle { anchors.fill: parent; anchors.margins: 2.5; radius: 5; color: Theme.sand }
    Item { anchors.fill: parent; anchors.margins: 2.5; clip: true
        Rectangle { width: parent.width * Math.max(0, Math.min(1, l.shown / l.max)); height: parent.height; radius: 5; color: l.color } }
    Rectangle { x: Math.max(0, Math.min(l.width - width, l.width * l.shown / l.max - width / 2)); anchors.verticalCenter: parent.verticalCenter
        width: 20; height: 20; radius: 10; color: Theme.paper; border.width: l.armed ? 3.5 : 2.5; border.color: l.armed ? Theme.sunDeep : Theme.ink }
    MouseArea {
        anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onExited: l.armed = false
        function pick(m) { l.set(Math.max(0, Math.min(1, m.x / l.width)) * l.max) }
        onPressed: m => { l.armed = true; pick(m) }
        onPositionChanged: m => { if (pressed) pick(m) }
        // smooth scroll: touchpads send small steps, mouse wheels send 120 per notch
        onWheel: w => { if (!l.armed) { w.accepted = false; return }      // not clicked yet: let the page scroll
            l.set((l.busy ? l.local : l.value) + w.angleDelta.y / 120 * l.step) }
    }
}
