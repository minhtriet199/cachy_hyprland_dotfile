import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets

// A tray app's menu (Steam, Discord…) in Island style: paper card, rows light up on hover, separators as thin lines,
// ticks for check / radio entries. A submenu opens in place with a "‹ Back" row.
// Like the bar cards it sits on a see-through layer over the screen: a click anywhere outside, or Esc, closes it.
PanelWindow {
    id: m
    property string monitor
    property real k: 1                       // bar scale (design px → screen px)
    property bool up: false                  // bar at the bottom: opens above
    property Item target: null
    property var menu: null                  // the tray item's menu handle
    property var stack: []                   // submenus opened inside it
    readonly property var cur: stack.length ? stack[stack.length - 1] : menu
    property point at: Qt.point(0, 0)        // under (or over) the icon, screen px
    function toggle(item, handle) {
        if (visible && target === item) { close(); return }
        const p = item.mapToItem(null, item.width / 2, up ? 0 : item.height);
        target = item; menu = handle; stack = []; at = p; visible = true;
    }
    function close() { visible = false; stack = []; target = null }
    screen: Quickshell.screens.find(s => s.name === monitor) || null
    visible: false
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    WlrLayershell.namespace: "island-traymenu"
    QsMenuOpener { id: opener; menu: m.cur }

    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: m.stack.length ? (m.stack = m.stack.slice(0, -1)) : m.close()
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onPressed: m.close() }
        Item {
            width: card.width; height: card.height; scale: m.k; transformOrigin: Item.TopLeft
            x: Math.max(8, Math.min(m.width - card.width * m.k - 8, m.at.x - card.width * m.k / 2))
            y: m.up ? m.at.y - card.height * m.k - 8 : m.at.y + 8
            UiCandy {
                id: card
                width: 270; height: col.implicitHeight + 16
                radius: 18; bw: 3; ink: Theme.ink; drop: 5; hi: 0; fill: Theme.paper
                Column {
                    id: col
                    x: 8; y: 8; width: parent.width - 16; spacing: 2
                    UiCandy {
                        visible: m.stack.length > 0
                        width: col.width; height: 32; radius: 10; bw: hovered ? 2 : 0; drop: 0; hi: 0
                        fill: hovered ? Theme.gLilac : Theme.sand; pressable: true
                        onClicked: m.stack = m.stack.slice(0, -1)
                        UiText { x: 12; anchors.verticalCenter: parent.verticalCenter; text: "‹  Back"; px: 13; w: 700 }
                    }
                    Repeater {
                        model: opener.children
                        delegate: Item {
                            id: en
                            required property var modelData
                            readonly property bool ticked: modelData.buttonType !== QsMenuButtonType.None && modelData.checkState === Qt.Checked
                            width: col.width; height: modelData.isSeparator ? 10 : 34
                            Rectangle { visible: en.modelData.isSeparator; x: 10; width: parent.width - 20; height: 2; radius: 1
                                anchors.verticalCenter: parent.verticalCenter; color: Theme.sand }
                            UiCandy {
                                visible: !en.modelData.isSeparator
                                anchors.fill: parent; radius: 10; bw: hovered && en.modelData.enabled ? 2 : 0; drop: 0; hi: 0
                                fill: hovered && en.modelData.enabled ? Theme.gLilac : Theme.paper
                                pressable: en.modelData.enabled; hoverable: true; opacity: en.modelData.enabled ? 1 : 0.45
                                onClicked: { if (en.modelData.hasChildren) m.stack = m.stack.concat([en.modelData]); else { en.modelData.triggered(); m.close() } }
                                // tick (check / radio) or the entry's icon
                                Glyph { visible: en.ticked; x: 10; anchors.verticalCenter: parent.verticalCenter; name: "check"; size: 13; stroke: 3 }
                                IconImage { visible: !en.ticked && en.modelData.icon !== ""; x: 9; anchors.verticalCenter: parent.verticalCenter
                                    implicitSize: 16; source: en.modelData.icon; asynchronous: true }
                                UiText { x: 34; width: parent.width - 34 - 26; anchors.verticalCenter: parent.verticalCenter
                                    text: en.modelData.text; px: 13; w: 700; color: Theme.textDeep }
                                Glyph { visible: en.modelData.hasChildren; anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter
                                    name: "arrowRight"; size: 12; stroke: 2.6 }
                            }
                        }
                    }
                }
            }
        }
    }
}
