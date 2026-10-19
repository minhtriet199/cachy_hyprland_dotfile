import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io

// "What to record / share?" — Isla's screen-share picker (tools/share-pick.sh, called by the screen-share portal
// for OBS, Discord, the browser…). Live previews of every screen and window; click one, or Esc to cancel.
// Loaded only while asked (shell.qml LazyLoader).
PanelWindow {
    id: sp
    property string listFile                        // XDPH's window list: id[HC>]class[HT>]title[HE>]address[HA>]…
    signal done()
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "isla-share"
    readonly property real sc: screen ? screen.height / 1080 * Prefs.size : 1

    FileView { id: lf; path: sp.listFile; blockLoading: true }
    readonly property var wins: {
        const out = [];
        for (const e of lf.text().split("[HA>]")) {
            const m = e.match(/^([\s\S]*?)\[HC>\]([\s\S]*?)\[HT>\]([\s\S]*?)\[HE>\]([\s\S]*)$/); if (!m) continue
            const h = Hyprland.toplevels.values.find(t => String(t.address).replace(/^0x/, "") === m[4].replace(/^0x/, ""))
            if (m[2] === "org.quickshell") continue                       // Isla's own windows
            out.push({ id: m[1], cls: m[2], title: m[3], top: h ? h.wayland : null })
        }
        return out;
    }
    property bool answered: false
    function answer(a) { if (answered) return; answered = true; out.command = ["sh", "-c", 'printf "%s" "$1" > "$2"', "_", a, sp.listFile.replace(/windows$/, "answer")]; out.running = true }
    Process { id: out; onExited: sp.done() }

    Rectangle { anchors.fill: parent; color: Theme.scrim }
    MouseArea { anchors.fill: parent; onClicked: sp.answer("cancel") }

    Item {
        width: sp.width / sp.sc; height: sp.height / sp.sc
        scale: sp.sc; transformOrigin: Item.TopLeft
        UiCandy {
            id: card
            anchors.centerIn: parent
            width: Math.min(parent.width - 80, 1060); height: Math.min(parent.height - 80, col.implicitHeight + 44)
            radius: 28; bw: 3; drop: 7; hi: 3; ink: Theme.inkPhone; fill: Theme.cream
            rotation: -0.6
            MouseArea { anchors.fill: parent }              // clicks on the card don't cancel
            Flickable {
                x: 26; y: 22; width: parent.width - 52; height: parent.height - 44
                contentHeight: col.implicitHeight; clip: true; boundsBehavior: Flickable.StopAtBounds
                Column {
                    id: col
                    width: parent.width; spacing: 14
                    Row {
                        spacing: 12
                        UiCandy { width: 46; height: 46; radius: 15; bw: 2.5; drop: 3; hi: 3; ink: Theme.inkPhone; fill: Theme.gBerry
                            Glyph { anchors.centerIn: parent; name: "record"; size: 22; stroke: 2.6; color: "#FFFFFF" } }
                        Column { anchors.verticalCenter: parent.verticalCenter
                            UiText { text: "What should I record?"; px: 22; w: 700; color: Theme.textDeep }
                            UiText { text: "Pick a screen or a window · Esc cancels"; fam: "n"; px: 12; w: 800; color: Theme.textSoft } }
                    }
                    UiText { text: "SCREENS"; fam: "n"; px: 11; w: 900; track: 1.4; color: Theme.textSoft }
                    Flow {
                        width: parent.width; spacing: 14
                        Repeater { model: Quickshell.screens
                            delegate: Pick { required property var modelData
                                src: modelData; w: 300
                                label: (Services.monitorNames[modelData.name] ? Services.monitorNames[modelData.name].label.split(" · ")[0] : modelData.model || modelData.name)
                                sub: modelData.name + " · " + modelData.width + "×" + modelData.height; glyph: "monitor"
                                onPicked: sp.answer("screen:" + modelData.name) } }
                    }
                    UiText { visible: sp.wins.length > 0; text: "WINDOWS"; fam: "n"; px: 11; w: 900; track: 1.4; color: Theme.textSoft }
                    Flow {
                        width: parent.width; spacing: 14
                        Repeater { model: sp.wins
                            delegate: Pick { required property var modelData
                                src: modelData.top; w: 236
                                label: modelData.title || modelData.cls; sub: modelData.cls
                                glyph: (Services.classLook[modelData.cls] || ["box"])[0]
                                onPicked: sp.answer("window:" + modelData.id) } }
                    }
                }
            }
        }
    }

    // one choice: live preview + name; leans a little when hovered
    component Pick: UiCandy {
        id: pk
        property var src
        property real w: 240
        property string label
        property string sub
        property string glyph
        signal picked()
        width: w; height: w * 9 / 16 + 54; radius: 16; bw: 2.5; drop: hovered ? 5 : 3; hi: 0; ink: Theme.inkPhone
        fill: hovered ? Theme.gSun : Theme.paper; pressable: true
        rotation: hovered ? 1.2 : 0
        Behavior on rotation { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }
        onClicked: picked()
        Rectangle {
            x: 8; y: 8; width: parent.width - 16; height: pk.w * 9 / 16 - 4; radius: 10; color: Theme.inkPhone; clip: true
            ScreencopyView { anchors.fill: parent; anchors.margins: 2; captureSource: pk.src; live: true; constraintSize: Qt.size(width, height) }
        }
        Row {
            x: 12; y: pk.w * 9 / 16 + 10; spacing: 8; width: parent.width - 24
            Glyph { name: pk.glyph; size: 18; stroke: 2.4; color: Theme.textDeep; anchors.verticalCenter: parent.verticalCenter }
            Column { width: parent.width - 26
                UiText { width: parent.width; elide: Text.ElideRight; text: pk.label; px: 14; w: 700; color: Theme.textDeep }
                UiText { width: parent.width; elide: Text.ElideRight; text: pk.sub; fam: "n"; px: 10.5; w: 800; color: Theme.textSoft } }
        }
    }

    Item { focus: true; Component.onCompleted: forceActiveFocus(); Keys.onEscapePressed: sp.answer("cancel") }
}
