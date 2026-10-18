import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets

// The top bar: three groups of candy pills (left · centre · right), like the canvas "Main" board.
Item {
    id: bar
    property var svc
    property string monitor: ""
    signal openPhone(string screen)
    signal openDropdown(string which, real x)
    signal openPower()
    function drop(which, pill) { openDropdown(which, pill.mapToItem(bar, pill.width / 2, 0).x) }
    height: 50

    // ── left: places & weather & music ──
    Row {
        id: leftGroup
        spacing: 10
        anchors.verticalCenter: parent.verticalCenter
        BarPill {
            fill: Theme.gSea; pressable: true
            onClicked: bar.openPhone("islands")
            Glyph { name: "island"; size: 22; stroke: 2.3 }
        }
        Row {
            spacing: 8
            anchors.verticalCenter: parent.verticalCenter
            Repeater {
                model: bar.svc.barWorkspaces(bar.monitor)
                delegate: UiCandy {
                    required property var modelData
                    readonly property bool cur: modelData.kind === "current"
                    readonly property bool empty: modelData.kind === "empty"
                    anchors.verticalCenter: parent.verticalCenter
                    width: cur ? 46 : 42; height: width
                    bw: empty ? 2 : 2.5; drop: empty ? 0 : 4          // empty: thin smooth outline, flat (no shadow)
                    ink: Theme.ink                                              // solid outline (dashed when empty)
                    fill: empty ? Theme.cream : (cur ? Theme.gActive : Theme.gChip)   // solid, so the wallpaper can't make it muddy
                    hi: empty ? 0 : (cur ? 4 : 3)
                    hiColor: Qt.rgba(1, 1, 1, cur ? 0.5 : 0.75)
                    pressable: true
                    onClicked: bar.svc.goWorkspace(modelData.id)
                    UiText { anchors.centerIn: parent; text: modelData.number; px: cur ? 19 : 17; w: 700
                        color: cur ? "#FFFFFF" : (empty ? Theme.textSoft : Theme.text) }
                }
            }
        }
        BarPill {
            id: wxPill
            fill: Theme.gSun; pressable: true
            onClicked: bar.drop("weather", wxPill)
            Glyph { name: bar.svc.weather.glyph; size: 20; stroke: 2.3 }
            UiText { text: bar.svc.weather.temp; px: 16; w: 600 }
        }
        // music: spinning cover with a progress ring · title / artist · mirrored visualizer · ⏮ ⏯ ⏭
        BarPill {
            id: musicPill
            readonly property var med: bar.svc.media
            readonly property bool playing: !!med && med.playing
            visible: !!med
            fill: bar.svc.artFill; padL: 4; padR: 6; gap: 9              // tinted with the cover's colours
            HoverHandler { id: musicHover }
            // cover: a little record that turns while playing, ring = song progress
            Item {
                Layout.preferredWidth: 36; Layout.preferredHeight: 36
                Shape {
                    anchors.fill: parent; preferredRendererType: Shape.CurveRenderer
                    ShapePath { strokeColor: Qt.rgba(61 / 255, 90 / 255, 102 / 255, 0.2); strokeWidth: 3; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                        PathAngleArc { centerX: 18; centerY: 18; radiusX: 16.5; radiusY: 16.5; startAngle: 0; sweepAngle: 360 } }
                    ShapePath { strokeColor: bar.svc.artAccent; strokeWidth: 3; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                        PathAngleArc { centerX: 18; centerY: 18; radiusX: 16.5; radiusY: 16.5; startAngle: -90
                            sweepAngle: 360 * Math.max(0.001, Math.min(1, musicPill.med ? musicPill.med.progress : 0)) } }
                }
                Item {
                    id: disc
                    anchors.centerIn: parent; width: 28; height: 28
                    // slow spin in small steps (20 fps, not 120) so the bar doesn't redraw every frame; stops while gaming
                    Timer { interval: 50; repeat: true; running: musicPill.playing && !bar.svc.gaming; onTriggered: disc.rotation = (disc.rotation + 2) % 360 }
                    Rectangle { anchors.fill: parent; radius: width / 2; color: Theme.inkPhone }
                    ClippingRectangle {
                        anchors.fill: parent; anchors.margins: 1.5; radius: width / 2; color: Theme.lilacSoft
                        Glyph { anchors.centerIn: parent; visible: art.status !== Image.Ready; name: "music"; size: 13; stroke: 2.6; color: "#FFFFFF" }
                        Image { id: art; anchors.fill: parent; visible: status === Image.Ready; fillMode: Image.PreserveAspectCrop
                            source: musicPill.med ? musicPill.med.art : ""; sourceSize: Qt.size(64, 64) }
                    }
                    Rectangle { anchors.centerIn: parent; width: 6; height: 6; radius: 3; color: Theme.cream; border.width: 1.5; border.color: Theme.inkPhone }   // record hole
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: bar.svc.mediaToggle() }
            }
            // title / artist (time while hovered) — click for the music card
            Column {
                id: musicText
                spacing: 1
                UiMarquee { text: musicPill.med ? musicPill.med.title : ""; px: 14; w: 700; width: 128; height: 16 }
                UiMarquee { visible: !musicHover.hovered; text: musicPill.med ? musicPill.med.artist : ""; fam: "n"; px: 11; w: 800; color: Theme.textSoft; width: 128; height: 13 }
                UiText { visible: musicHover.hovered; height: 13; fam: "n"; px: 11; w: 900; color: bar.svc.artAccent
                    text: musicPill.med ? bar.svc.mmss(musicPill.med.position) + " / " + bar.svc.mmss(musicPill.med.length) : "" }
                TapHandler { onTapped: bar.drop("music", musicText) }
            }
            // visualizer: mirrored bars from the middle line
            Row {
                Layout.preferredHeight: 28
                spacing: 2
                Repeater {
                    model: bar.svc.viz.length
                    delegate: Item {
                        required property int index
                        readonly property real v: musicPill.playing ? Math.min(1, (bar.svc.viz[index] || 0) / 100) : 0
                        width: 3; height: 28
                        Rectangle {
                            anchors.centerIn: parent; width: 3; radius: 1.5
                            height: Math.max(3, 26 * v)
                            color: Qt.rgba(0, 0, 0, 0)
                            gradient: Gradient {
                                GradientStop { position: 0; color: bar.svc.artPalette[index < 5 ? 0 : index < 10 ? 1 : 2] }
                                GradientStop { position: 1; color: Qt.darker(bar.svc.artPalette[index < 5 ? 0 : index < 10 ? 1 : 2], 1.25) }
                            }
                        }
                    }
                }
            }
            // controls
            Row {
                spacing: 5
                UiCandy { width: 26; height: 26; bw: 2; drop: 2; hi: 0; fill: Theme.paper; pressable: true; onClicked: bar.svc.mediaPrev(); anchors.verticalCenter: parent.verticalCenter
                    Glyph { anchors.centerIn: parent; name: "prev"; size: 12; stroke: 2.6 } }
                UiCandy { width: 32; height: 32; bw: 2.5; drop: 2; hi: 3; fill: Theme.gGo; pressable: true; onClicked: bar.svc.mediaToggle(); anchors.verticalCenter: parent.verticalCenter
                    Glyph { anchors.centerIn: parent; name: musicPill.playing ? "pause" : "play"; size: 13; stroke: 3.2; color: "#FFFFFF" } }
                UiCandy { width: 26; height: 26; bw: 2; drop: 2; hi: 0; fill: Theme.paper; pressable: true; onClicked: bar.svc.mediaNext(); anchors.verticalCenter: parent.verticalCenter
                    Glyph { anchors.centerIn: parent; name: "next"; size: 12; stroke: 2.6 } }
            }
        }
    }

    // ── centre: time & date, kept in the middle (slides aside on a narrow screen instead of overlapping) ──
    Row {
        id: centerGroup
        spacing: 10
        anchors.verticalCenter: parent.verticalCenter
        x: Math.max(leftGroup.width + 12, Math.min(bar.width - rightGroup.width - width - 12, (bar.width - width) / 2))
        BarPill {
            id: datePill
            fill: Theme.gBerry; pressable: true; gap: 8
            onClicked: bar.drop("calendar", datePill)
            Glyph { name: "calendar"; size: 19; stroke: 2.3 }
            UiText { text: bar.svc.timeText; px: 16; w: 700 }
            Rectangle { Layout.preferredWidth: 6; Layout.preferredHeight: 6; radius: 3; color: Theme.ink; opacity: 0.45 }
            UiText { text: bar.svc.dateText; px: 16; w: 600 }
        }
    }

    // ── right: the computer (monitor, connections, tray, quiet/EN, battery, power) ──
    Row {
        id: rightGroup
        spacing: 10
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        // PC monitor: CPU · RAM · GPU (click for graphs, temperatures, fans)
        BarPill {
            id: sysPill
            fill: Theme.gChip; gap: 12; padL: 12; padR: 12; pressable: true
            onClicked: bar.drop("sys", sysPill)
            Repeater {
                // [icon, % (bar fill), colour, temperature (°C, 0 = none), text]
                model: [["cpu", bar.svc.sysmon.cpu, Theme.seaDeep, bar.svc.sysmon.cpuTemp, bar.svc.sysmon.cpu + "%"],
                        ["ram", bar.svc.sysmon.ram, Theme.purple, 0, bar.svc.sysmon.ramUsed.toFixed(1) + " GB"],
                        ["gpu", bar.svc.sysmon.gpu, Theme.berry, bar.svc.sysmon.gpuTemp, bar.svc.sysmon.gpu + "%"]]
                delegate: Row {
                    required property var modelData
                    spacing: 5
                    Glyph { anchors.verticalCenter: parent.verticalCenter; name: modelData[0]; size: 18; stroke: 2.2 }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter; spacing: 2
                        Row {
                            spacing: 4
                            UiText { text: modelData[4]; px: 13; w: 700; height: 14 }
                            UiText { visible: modelData[3] > 0; text: modelData[3] + "°"; fam: "n"; px: 10.5; w: 900; height: 14
                                color: modelData[3] >= 85 ? Theme.berry : modelData[3] >= 75 ? Theme.orange : Theme.textSoft }
                        }
                        Item { width: 46; height: 5
                            Rectangle { anchors.fill: parent; radius: 3; color: Qt.rgba(61 / 255, 90 / 255, 102 / 255, 0.18) }
                            Rectangle { width: parent.width * Math.min(1, modelData[1] / 100); height: 5; radius: 3; color: modelData[2]
                                Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } } } }
                    }
                }
            }
        }
        // apps running in the background (system tray: Steam, Discord, WARP…)
        // fcitx5 is left out: the EN/VI button already shows it
        BarPill {
            readonly property var hidden: ["Fcitx"]
            id: trayPill
            visible: SystemTray.items.values.some(i => !hidden.includes(i.id))
            fill: Theme.gSea; padL: 12; padR: 12; gap: 12
            Repeater {
                model: SystemTray.items
                delegate: Item {
                    id: ti
                    required property SystemTrayItem modelData
                    visible: !trayPill.hidden.includes(modelData.id)
                    Layout.preferredWidth: 22 * popT; Layout.preferredHeight: 22
                    // pops in with a little bounce when the app starts
                    property real popT: 0
                    Component.onCompleted: popIn.start()
                    NumberAnimation { id: popIn; target: ti; property: "popT"; from: 0; to: 1; duration: 420; easing.type: Easing.OutBack; easing.overshoot: 2 }
                    scale: popT; opacity: Math.min(1, popT * 1.5)
                    function menu() {
                        if (!modelData.hasMenu) return;
                        const p = ti.mapToItem(null, 0, ti.height + 10);
                        modelData.display(QsWindow.window, p.x, p.y);
                    }
                    IconImage { anchors.fill: parent; asynchronous: true
                        // Steam's tray icon is a pale mono glyph; its normal app icon reads better on the light pill
                        source: ti.modelData.id === "steam" ? (Quickshell.iconPath("steam", true) || ti.modelData.icon) : ti.modelData.icon
                        scale: tma.pressed ? 0.85 : (tma.containsMouse ? 1.12 : 1)
                        Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutBack } } }
                    MouseArea {
                        id: tma
                        anchors.fill: parent; anchors.margins: -5; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                        onClicked: m => {
                            if (m.button === Qt.RightButton || (m.button === Qt.LeftButton && ti.modelData.onlyMenu)) ti.menu();
                            else if (m.button === Qt.MiddleButton) ti.modelData.secondaryActivate();
                            else ti.modelData.activate();
                        }
                        onWheel: w => ti.modelData.scroll(w.angleDelta.y, false)
                    }
                }
            }
        }
        BarPill {
            fill: Theme.gLilac; padL: 6; padR: 6; gap: 6
            BarToggle { name: "dropper"; on: false; onClicked: bar.svc.tool("picker") }   // colour picker
            BarToggle {
                id: bellT
                name: bar.svc.dnd ? "bellOff" : "bell"; on: bar.svc.dnd
                onClicked: bar.drop("notifs", bellT)
                Rectangle { visible: bar.svc.notifications.length > 0 && !bar.svc.dnd; x: parent.width - 11; y: 1; width: 9; height: 9; radius: 5
                    color: Theme.berry; border.width: 1.5; border.color: Theme.ink }
            }
            UiCandy {
                Layout.preferredHeight: 28; Layout.preferredWidth: lang.implicitWidth + 18
                bw: 2; drop: 0; hi: 0; fill: Theme.sun; pressable: true
                onClicked: bar.svc.toggle("ime")
                UiText { id: lang; anchors.centerIn: parent; text: bar.svc.imeVi ? "VI" : "EN"; px: 13; w: 700 }
            }
        }
        // each icon opens its own dropdown; scroll anywhere on the pill = volume
        BarPill {
            fill: Theme.gSea; gap: 14
            // Wi-Fi: off · no connection (faint) · 1 / 2 / 3 bars
            BarIcon { id: wifiI; onClicked: bar.drop("wifi", wifiI)
                property int frame: 0           // connecting: bars fill 1 → 2 → 3 on repeat
                Timer { interval: 380; repeat: true; running: bar.svc.wifiIcon === "connecting"; onTriggered: wifiI.frame = (wifiI.frame + 1) % 3 }
                readonly property string shown: bar.svc.wifiIcon === "connecting" ? ["wifi1", "wifi2", "wifi"][frame] : bar.svc.wifiIcon
                name: shown === "none" ? "wifiArcs" : shown
                under: shown === "wifi1" || shown === "wifi2" ? "wifiArcs" : ""
                opacity: shown === "none" ? 0.4 : 1
                badge: bar.svc.wifiBadge }
            // Bluetooth: off · on · connected (dots) · searching (blinks)
            BarIcon { id: btI; onClicked: bar.drop("bt", btI)
                name: bar.svc.btState === "off" ? "btOff" : bar.svc.btState === "connected" ? "btConnected" : "bluetooth"
                pulse: bar.svc.btState === "searching" }
            // sound: muted · low · medium · loud (live)
            // hover + scroll = volume (smooth, follows how far you scroll)
            BarIcon { id: sndI; name: bar.svc.volIcon; onClicked: bar.drop("sound", sndI); onWheel: dy => bar.svc.nudgeVolume(dy / 120 * 0.05) }
        }
        BarPill {
            id: batPill
            fill: Theme.gLeaf; pressable: true
            onClicked: bar.drop("battery", batPill)
            BarBattery { level: bar.svc.battery.percent / 100; charging: bar.svc.battery.charging }
            UiText { text: bar.svc.battery.percent + "%"; px: 16; w: 600 }
        }
        UiCandy {
            width: 42; height: 42
            fill: Theme.gBerry; hiColor: Qt.rgba(1, 1, 1, 0.5); pressable: true
            onClicked: bar.openPower()
            Glyph { anchors.centerIn: parent; name: "power"; size: 20; stroke: 2.6 }
        }
    }
}
