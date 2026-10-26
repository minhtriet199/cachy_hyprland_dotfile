import QtQuick

// Shell page (phone): notifications, bar & dock, game mode, phone on the left; look (colours, light / dark, boxes) and the
// lock / unlock transition on the right. Same rows, labels and spacing as the other settings pages (was its own
// tile layout in ScrSettingsQuick until 2026-10-26).
Item {
    id: sh
    property var svc
    property var prefs
    readonly property bool narrow: width < 560
    readonly property real colW: narrow ? width : (width - 20) / 2
    implicitHeight: narrow ? leftCol.implicitHeight + 20 + rightCol.implicitHeight : Math.max(leftCol.implicitHeight, rightCol.implicitHeight)

    component Label: UiText { fam: "n"; px: 11; w: 900; track: 1.4; color: Theme.textSoft; height: 18 }
    component Toggle: UiRow {
        id: tg
        property bool on: false
        signal flip()
        width: parent.width; active: on; onClicked: flip()
        UiSwitch { on: tg.on; onToggled: tg.flip() }
    }

    Column {
        id: leftCol
        width: sh.colW; spacing: 8
        Label { text: "NOTIFICATIONS" }
        Toggle { glyph: "bell"; title: "Pop-ups"; sub: sh.prefs.notifications ? "On" : "Off"; on: sh.prefs.notifications; onFlip: sh.prefs.flip("notifications") }
        Toggle { glyph: sh.svc.dnd ? "bellOff" : "bell"; title: "Do not disturb"; on: sh.svc.dnd; onFlip: sh.svc.toggle("dnd")
            sub: sh.svc.dnd && sh.svc.dndUntil ? "Until " + Qt.formatTime(new Date(sh.svc.dndUntil), sh.svc.h24 ? "HH:mm" : "h:mm AP") : (sh.svc.dnd ? "On" : "Off") }
        UiRow { width: parent.width; glyph: "moon"; title: "Quiet for 1 hour"; sub: "Then pop-ups come back"; onClicked: sh.svc.dndFor(60)
            Glyph { name: "arrowRight"; size: 15; stroke: 2.6 } }
        Toggle { glyph: "gamepad"; title: "Quiet while gaming"; sub: "No pop-ups while a game is open"; on: sh.prefs.dndGaming; onFlip: sh.prefs.flip("dndGaming") }

        Item { width: 1; height: 6 }
        Label { text: "BAR & DOCK" }
        Toggle { glyph: "barThin"; title: "Bar"; sub: sh.prefs.bar ? "On" : "Off"; on: sh.prefs.bar; onFlip: sh.prefs.flip("bar") }
        Toggle { glyph: "dock"; title: "Dock"; sub: sh.prefs.dock ? "On" : "Off"; on: sh.prefs.dock; onFlip: sh.prefs.flip("dock") }
        SetSeg { width: parent.width; label: "Style"; options: ["Float", "Straight", "Transparent"]; current: sh.prefs.barStyle; onPicked: v => sh.prefs.set("barStyle", v) }
        SetSeg { width: parent.width; label: "Position"; options: ["Top", "Bottom"]; current: sh.prefs.barPos; onPicked: v => sh.prefs.set("barPos", v) }
        UiRow {
            width: parent.width; glyph: "resize"; title: "Shell size"; sub: sh.prefs.size.toFixed(2) + "×"; pressable: false
            Repeater { model: ["−", "+"]
                delegate: UiCandy { required property string modelData; required property int index
                    width: 30; height: 30; radius: 15; bw: 2; drop: 2; hi: 0; fill: Theme.paper; pressable: true
                    onClicked: sh.prefs.setSize(sh.prefs.size + (index ? 0.05 : -0.05))
                    UiText { anchors.centerIn: parent; text: modelData; px: 15; w: 700 } } }
        }

        Item { width: 1; height: 6 }
        Label { text: "GAMING" }
        Toggle { glyph: "gamepad2"; title: "Game mode"; sub: sh.svc.gameMode ? "No animations, calmer shell" : "Off"; on: sh.svc.gameMode; onFlip: sh.svc.toggle("game") }

        Item { width: 1; height: 6 }
        Label { text: "PHONE" }
        SetSeg { width: parent.width; label: "Height"; options: ["Low", "Middle", "High"]; current: sh.prefs.phoneSpot; onPicked: v => sh.prefs.set("phoneSpot", v) }
        SetSeg { width: parent.width; label: "Open as"; options: ["Overlay", "Window"]; current: sh.prefs.phoneWindow ? "Window" : "Overlay"
            onPicked: v => sh.prefs.phoneWindow = v === "Window" }      // this phone only (not saved)
        SetSeg { width: parent.width; label: "Reopen"; options: ["Fresh", "As I left it"]; current: sh.prefs.phoneRemember ? "As I left it" : "Fresh"
            onPicked: v => { sh.prefs.set("phoneRemember", v !== "Fresh"); sh.prefs.set("phoneWinLast", sh.prefs.phoneWindow) } }
    }

    Column {
        id: rightCol
        x: sh.narrow ? 0 : sh.colW + 20; y: sh.narrow ? leftCol.implicitHeight + 20 : 0; width: sh.colW; spacing: 8
        Label { text: "LOOK" }
        // colour themes (Theme.allPalettes)
        Flow {
            width: parent.width; spacing: 8
            Repeater {
                model: Object.keys(Theme.allPalettes)
                delegate: UiCandy {
                    id: sw
                    required property string modelData
                    readonly property var p: Theme.allPalettes[modelData]
                    readonly property bool on: (sh.prefs.theme || "island") === modelData
                    selected: on
                    width: (rightCol.width - 16) / 3; height: 50; radius: 14; bw: on ? 3 : 2.5; drop: on ? 0 : 3; hi: 0
                    ink: p.ink || "#3D5A66"; fill: p.gOn || ["#D8F1F4", "#A9DDE4"]; pressable: true
                    onClicked: sh.prefs.set("theme", modelData)
                    Row { x: 9; y: 8; spacing: 3
                        Repeater { model: [sw.p.ink || "#3D5A66", sw.p.sea || "#55BFC6", (sw.p.gActive || ["#C9B9F7", "#9C86E6"])[1], sw.p.cream || "#FFF9EC"]
                            delegate: Rectangle { required property color modelData; width: 12; height: 12; radius: 6; color: modelData; border.width: 1.5; border.color: Qt.rgba(0, 0, 0, 0.25) } } }
                    UiText { x: 9; y: 26; width: parent.width - 14; elide: Text.ElideRight; text: (sw.on ? "✓ " : "") + sw.p.name; px: 12.5; w: 700; color: sw.p.textDeep || "#213F48" }
                }
            }
        }
        // custom theme: any hue
        Item {
            visible: sh.prefs.theme === "custom"
            width: parent.width; height: 34
            UiText { width: 70; height: 34; verticalAlignment: Text.AlignVCenter; text: "Colour"; px: 13; w: 700 }
            Rectangle {
                x: 80; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 80; height: 12; radius: 6; border.width: 2; border.color: Theme.inkPhone
                gradient: Gradient { orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Qt.hsla(0, .6, .7, 1) } GradientStop { position: .17; color: Qt.hsla(.17, .6, .7, 1) }
                    GradientStop { position: .33; color: Qt.hsla(.33, .6, .7, 1) } GradientStop { position: .5; color: Qt.hsla(.5, .6, .7, 1) }
                    GradientStop { position: .67; color: Qt.hsla(.67, .6, .7, 1) } GradientStop { position: .83; color: Qt.hsla(.83, .6, .7, 1) }
                    GradientStop { position: 1; color: Qt.hsla(1, .6, .7, 1) } }
            }
            Rectangle { x: 80 + (parent.width - 80) * sh.prefs.themeHue - 9; anchors.verticalCenter: parent.verticalCenter; width: 18; height: 18; radius: 9
                color: Qt.hsla(sh.prefs.themeHue, .6, .7, 1); border.width: 2.5; border.color: Theme.inkPhone }
            MouseArea { x: 80; width: parent.width - 80; height: parent.height
                function pick(mx) { sh.prefs.themeHue = Math.round(Math.max(0, Math.min(1, mx / width)) * 200) / 200 }
                onPressed: m => pick(m.x); onPositionChanged: m => pick(m.x); onReleased: sh.prefs.save() }
        }
        SetSeg { width: parent.width; label: "Shell"; options: ["Light", "Dark"]; current: sh.prefs.dark ? "Dark" : "Light"; onPicked: v => sh.prefs.set("dark", v === "Dark") }
        SetSeg { width: parent.width; label: "Apps"; options: ["Light", "Dark"]; current: sh.prefs.appsDark ? "Dark" : "Light"; onPicked: v => sh.prefs.set("appsDark", v === "Dark") }
        SetSeg { width: parent.width; label: "Boxes"; options: ["Candy", "Ring", "Pop", "Soft", "Flat", "Glass"]
            current: (sh.prefs.boxStyle || "candy").charAt(0).toUpperCase() + (sh.prefs.boxStyle || "candy").slice(1)
            onPicked: v => sh.prefs.set("boxStyle", v.toLowerCase()) }

        Item { width: 1; height: 6 }
        Label { text: "LOCK & UNLOCK TRANSITION" }
        Flow {
            width: parent.width; spacing: 8
            UiText { width: 84; height: 30; verticalAlignment: Text.AlignVCenter; text: "Background"; px: 13; w: 700 }
            Repeater {
                model: ["wallpaper"].concat(Object.keys(sh.prefs.wipeBgs))
                delegate: UiCandy {
                    required property string modelData
                    readonly property bool picked: sh.prefs.wipeBg === modelData
                    selected: picked
                    width: 34; height: 30; radius: 10; bw: picked ? 3 : 2; ink: picked ? Theme.purple : Theme.inkPhone; drop: picked ? 2 : 0; hi: 0
                    fill: modelData === "wallpaper" ? sh.prefs.wipeAuto[0] : sh.prefs.wipeBgs[modelData][0]; pressable: true
                    onClicked: sh.prefs.set("wipeBg", modelData)
                    Glyph { visible: modelData === "wallpaper"; anchors.centerIn: parent; name: "image"; size: 15; stroke: 2.4; color: Theme.inkPhone }   // follows your wallpaper
                }
            }
        }
        Flow {
            width: parent.width; spacing: 8
            UiText { width: 84; height: 38; verticalAlignment: Text.AlignVCenter; text: "Icon"; px: 13; w: 700 }
            Repeater {
                model: ["leaf", "star", "bell", "apple", "flower", "heart", "shell", "none"]
                delegate: UiCandy {
                    required property string modelData
                    readonly property bool picked: sh.prefs.wipeIcon === modelData
                    selected: picked
                    width: 38; height: 38; radius: 12; bw: picked ? 3 : 2; ink: picked ? Theme.purple : Theme.inkPhone; drop: picked ? 2 : 0; hi: 0
                    fill: sh.prefs.wipeColors[0]; pressable: true
                    onClicked: sh.prefs.set("wipeIcon", modelData)
                    WipeIcon { visible: modelData !== "none"; anchors.centerIn: parent; width: 26; height: 26; name: modelData }
                    UiText { visible: modelData === "none"; anchors.centerIn: parent; text: "—"; px: 14; w: 700 }
                }
            }
        }
        UiRow { width: parent.width; glyph: "play"; title: "Preview"; sub: "Play the lock / unlock transition"; onClicked: sh.svc.previewWipe()
            Glyph { name: "arrowRight"; size: 15; stroke: 2.6 } }
    }
}
