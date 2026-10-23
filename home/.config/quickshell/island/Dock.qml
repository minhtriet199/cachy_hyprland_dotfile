import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets

// Bottom dock: search, pinned apps, then other open apps, phone button.
// Open apps get a dot; the app you are using gets a long green bar.
// Hovering an app reports it (hoverKey/hoverX) so shell.qml can show live window previews above it.
UiCandy {
    id: dock
    property var svc
    signal openPhone(string screen)
    width: row.implicitWidth + 24
    height: 48 + 20 + bw * 2
    bw: 3; radius: 30; drop: 6; hiColor: Qt.rgba(1, 1, 1, 0.8)
    fill: Theme.gDock

    // ── open windows ──
    readonly property var tops: ToplevelManager.toplevels.values.filter(t => t.appId)
    readonly property string activeKey: ToplevelManager.activeToplevel && ToplevelManager.activeToplevel.activated ? (ToplevelManager.activeToplevel.appId || "").toLowerCase() : ""
    function winsFor(key) { return tops.filter(t => t.appId.toLowerCase() === key) }
    readonly property var pinnedKeys: svc.dockApps.map(a => (a.cls || "").toLowerCase())
    readonly property var extraKeys: {
        const out = [];
        for (const t of tops) { const k = t.appId.toLowerCase(); if (!pinnedKeys.includes(k) && !out.includes(k)) out.push(k) }
        return out;
    }
    function entryFor(appId) { return DesktopEntries.byId(appId) || DesktopEntries.heuristicLookup(appId) }
    function nameFor(key) { const e = entryFor(key); return e ? e.name : key }

    // click: not open → start it · open → focus it · already focused → next window of that app
    function focusOrCycle(key, launch) {
        const w = winsFor(key);
        if (!w.length) { launch(); return }
        const i = w.findIndex(t => t.activated);
        w[i >= 0 ? (i + 1) % w.length : 0].activate();
    }

    // ── hover (read by the preview popup in shell.qml) ──
    property string hoverKey: ""
    property string hoverName: ""
    property real hoverX: 0
    property bool popupHovered: false
    readonly property var hoverWins: hoverKey ? winsFor(hoverKey) : []
    function enter(key, name, item) { hideTimer.stop(); hoverName = name; hoverX = item.mapToItem(dock, item.width / 2, 0).x; hoverKey = key }
    function leave() { hideTimer.restart() }
    onPopupHoveredChanged: popupHovered ? hideTimer.stop() : hideTimer.restart()
    Timer { id: hideTimer; interval: 280; onTriggered: if (!dock.popupHovered) dock.hoverKey = "" }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 10
        UiCandy {
            Layout.preferredWidth: 48; Layout.preferredHeight: 48
            radius: 17; hi: 0; pressable: true
            onClicked: dock.openPhone("search")
            Glyph { anchors.centerIn: parent; name: "search"; size: 22; stroke: 2.5 }
        }
        // pinned apps
        Repeater {
            model: dock.svc.dockApps
            delegate: UiCandy {
                id: pin
                required property var modelData
                readonly property string key: (modelData.cls || "").toLowerCase()
                readonly property bool open: dock.winsFor(key).length > 0
                readonly property bool cur: dock.activeKey === key
                Layout.preferredWidth: 48; Layout.preferredHeight: 48
                radius: 17; hi: 4; hiColor: Qt.rgba(1, 1, 1, 0.4); fill: modelData.tint; pressable: true
                onClicked: dock.focusOrCycle(key, () => dock.svc.launch(modelData))
                Glyph { anchors.centerIn: parent; name: pin.modelData.glyph; size: 24; stroke: 2.6; color: "#FFFFFF" }
                RunMark { anchors.horizontalCenter: parent.horizontalCenter; anchors.top: parent.bottom; anchors.topMargin: 4; running: pin.open; active: pin.cur }
                onHoveredChanged: hovered ? dock.enter(pin.key, pin.modelData.label, pin) : dock.leave()
                TapHandler { acceptedButtons: Qt.MiddleButton; onTapped: dock.svc.launch(pin.modelData) }
            }
        }
        // other open apps
        Rectangle { visible: dock.extraKeys.length > 0; Layout.preferredWidth: 3; Layout.preferredHeight: 36; radius: 2; color: Qt.rgba(61 / 255, 90 / 255, 102 / 255, 0.3) }
        Repeater {
            model: dock.extraKeys
            delegate: UiCandy {
                id: ex
                required property string modelData
                readonly property var entry: dock.entryFor(modelData)
                readonly property bool cur: dock.activeKey === modelData
                Layout.preferredWidth: 48; Layout.preferredHeight: 48
                radius: 17; hi: 0; fill: Theme.paper; pressable: true
                onClicked: dock.focusOrCycle(modelData, () => {})
                IconImage { anchors.centerIn: parent; implicitSize: 30; asynchronous: true
                    source: Quickshell.iconPath(ex.entry ? ex.entry.icon : ex.modelData, "application-x-executable") }
                RunMark { anchors.horizontalCenter: parent.horizontalCenter; anchors.top: parent.bottom; anchors.topMargin: 4; running: true; active: ex.cur }
                onHoveredChanged: hovered ? dock.enter(ex.modelData, dock.nameFor(ex.modelData), ex) : dock.leave()
            }
        }
        Rectangle { Layout.preferredWidth: 3; Layout.preferredHeight: 36; radius: 2; color: Qt.rgba(61 / 255, 90 / 255, 102 / 255, 0.3) }
        UiCandy {
            Layout.preferredWidth: 56; Layout.preferredHeight: 48
            radius: 17; hi: 4; hiColor: Qt.rgba(1, 1, 1, 0.4); fill: Theme.sea; pressable: true
            onClicked: dock.openPhone("home")
            Glyph { anchors.centerIn: parent; name: "phone"; size: 24; stroke: 2.6; color: "#FFFFFF" }
        }
    }
}
