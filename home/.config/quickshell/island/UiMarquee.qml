import QtQuick

// One line of text. If it doesn't fit: shows "…" normally, and while hovered scrolls left in an endless loop
// (two copies back to back, ticker style). Short text never moves.
Item {
    id: m
    property string text: ""
    property string fam: "f"
    property int w: 600
    property real px: 14
    property color color: Theme.text
    property real speed: 40                 // px per second
    property real gap: 36                   // space between the end and the next start
    readonly property bool overflow: probe.implicitWidth > width + 1
    readonly property bool scrolling: overflow && hov.hovered && visible
    implicitHeight: probe.implicitHeight
    clip: true
    HoverHandler { id: hov }
    UiText { id: probe; visible: false; text: m.text; fam: m.fam; w: m.w; px: m.px; elide: Text.ElideNone }

    // resting: elided
    UiText { visible: !m.scrolling; width: m.width; height: m.height; text: m.text; fam: m.fam; w: m.w; px: m.px; color: m.color; elide: Text.ElideRight }
    // hovered: endless ticker
    Row {
        id: ticker
        visible: m.scrolling
        height: m.height; spacing: m.gap
        UiText { text: m.text; fam: m.fam; w: m.w; px: m.px; color: m.color; elide: Text.ElideNone; height: m.height }
        UiText { text: m.text; fam: m.fam; w: m.w; px: m.px; color: m.color; elide: Text.ElideNone; height: m.height }
        NumberAnimation on x {
            running: m.scrolling; loops: Animation.Infinite
            from: 0; to: -(probe.implicitWidth + m.gap)
            duration: (probe.implicitWidth + m.gap) / m.speed * 1000
        }
    }
    onScrollingChanged: ticker.x = 0
}
