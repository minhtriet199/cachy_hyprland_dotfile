import QtQuick
import QtQuick.Window
import "Mat.js" as M

// The phone overlay: 3D tilted Pixel rising from the bottom (portrait), turning sideways
// into a landscape phone for Settings — one phone, one motion (like the demo video).
// Lives in a full-screen layer; everything here is in design px (1920×1080 scaled).
Item {
    id: stage
    property var svc
    property var prefs
    property string monitor: ""
    property string screen: "home"           // portrait: home search quick islands · landscape: settings settingsQuick wallpapers
    property string prevScreen: ""
    property bool shown: false
    readonly property bool big: !!svc && svc.phoneBig
    property real flat: big && (wantLand || hand > 0.001) ? 1 : 0     // 1 = no tilt (big landscape); held while it fades out
    Behavior on flat { NumberAnimation { duration: 380 * stage.dur; easing.type: Easing.OutCubic } }
    property real flatP: big && (!wantLand || hand < 0.999) ? 1 : 0   // big portrait: centred, larger, upright; held while it fades out
    Behavior on flatP { NumberAnimation { duration: 420 * stage.dur; easing.type: Easing.OutCubic } }
    // light mode (side button ⚡, or on by itself while a game has focus): the phone face is drawn at a lower
    // sharpness, animations are about half as long and the wobble is skipped — less GPU work next to the game
    // wallpaper preview (Wallpapers → Preview): the phone fades away, the desktop shows the picture, a small bar floats
    readonly property bool previewing: !!svc && svc.wallPreview !== ""
    property real pv: previewing ? 1 : 0
    Behavior on pv { NumberAnimation { duration: 260 * stage.dur; easing.type: Easing.OutCubic } }
    readonly property bool lite: (!!prefs && prefs.phoneLite) || (!!svc && svc.gaming)
    readonly property real dur: lite ? 0.45 : 1
    property real texScale: lite ? (big ? 2 : 1.4) : (big ? 4 : 2.2)          // phone face is drawn flat at this sharpness, then tilted
    readonly property var landScreens: ["settings", "settingsQuick", "wallpapers", "settingsWifi", "settingsBt", "settingsSound", "settingsPower", "settingsDisplays", "settingsKeys", "settingsTime", "settingsSystem", "settingsWindows", "settingsTimeLang", "settingsMouse", "settingsApps", "settingsPrivacy", "settingsDiskMap"]
    // orientation never changes by itself: every screen opens the way the phone is held; only ↻ turns it.
    // A fresh phone opens upright.
    property string orient: "portrait"
    function landFor(scr) { return orient === "landscape" }
    readonly property bool wantLand: landFor(screen)
    readonly property var allScreens: ["home", "quick", "islands", "clipboard", "profile", "settings", "settingsQuick", "wallpapers",
                                       "settingsWifi", "settingsBt", "settingsSound", "settingsPower", "settingsDisplays", "settingsKeys", "settingsTime", "settingsSystem", "settingsWindows", "settingsTimeLang", "settingsMouse", "settingsApps", "settingsPrivacy", "settingsDiskMap"]
    readonly property var tallScreens: ["quick", "clipboard", "profile"]       // upright layouts that scroll on the short sideways phone
    function rotate() {
        if (!shown) return;
        const was = wantLand;
        orient = was ? "portrait" : "landscape";
        transition(screen, !was, was);
    }
    Connections { target: stage.svc; function onPhoneRotate() { stage.rotate() } }
    signal closed()
    signal soon(string what)

    // ── animation state ──
    property real rise: 0        // portrait phone up (0..1, overshoots)
    property real wobT: 1        // wobble timeline after rising
    property real turn: 0        // portrait → landscape pose (0..1)
    property real hand: 0        // 1 = landscape phone is the one you see
    property real slideIn: 0     // landscape phone straight in (when portrait was not up)
    property bool viaTurn: false
    readonly property real wob: Math.sin(wobT * Math.PI * 3) * (1 - wobT) * 2.4
    readonly property real visibleAmount: Math.max(Math.min(1, rise), hand, slideIn)

    function open(scr) {
        if (scr === "search") scr = "home";           // search lives on the home screen now
        transition(scr, landFor(scr), shown && wantLand);
    }
    // was = the sideways phone is the one showing now; land = it should be after this
    function transition(scr, land, was) {
        if (land) {
            if (rise > 0.5 && !was && big) { viaTurn = false; setScreen(scr); fadeAnim.to = 1; fadeAnim.restart() }
            else if (rise > 0.5 && !was) { viaTurn = true; setScreen(scr); toLand.restart() }
            else if (was && (hand > 0.5 || slideIn > 0.5)) setScreen(scr)
            else { viaTurn = false; setScreen(scr); slideAnim.from = slideIn; slideAnim.to = 1; slideAnim.restart() }
        } else {
            if (was && !viaTurn && hand > 0.5 && turn < 0.01 && rise > 0.5) { setScreen(scr); fadeAnim.to = 0; fadeAnim.restart() }   // big cross-fade back
            else if (was && viaTurn && hand > 0.5) { setScreen(scr); toPort.restart() }
            else if (was && slideIn > 0.5) { slideAnim.from = slideIn; slideAnim.to = 0; slideAnim.restart(); setScreen(scr); riseUp() }
            else { setScreen(scr); if (rise < 0.99 || !shown) riseUp() }
        }
        shown = true;
        focusSoon.restart();
    }
    // ── navigation history (Back buttons, mouse back button, Alt+←) ──
    property var history: []
    property int navDir: 1                       // 1 = forward (slide from right), -1 = back
    function go(scr) {
        if (shown && scr !== screen) history = history.concat([screen]);
        navDir = 1; open(scr);
    }
    function back() {
        navDir = -1;
        if (history.length) { const h = history.slice(); const p = h.pop(); history = h; open(p) }
        else if (screen.startsWith("settings") && screen !== "settings" || screen === "wallpapers") open("settings")
        else if (screen !== "home") open("home")
        else close();
    }
    function riseUp() { riseAnim.from = rise; riseAnim.to = 1; riseAnim.easing.type = Easing.OutBack; riseAnim.restart(); if (lite) wobT = 1; else { wobT = 0; wobAnim.restart() } }
    function close() {
        if (!shown) return;
        history = [];
        if (svc) svc.phoneBig = false;           // next open (Ctrl+B / Super+Space) always starts small
        shown = false;
        dropAnim.restart();
    }
    function setScreen(s) { if (s === screen) return; prevScreen = screen; screen = s; swapT = 0; swapAnim.restart() }
    property real swapT: 1
    NumberAnimation { id: swapAnim; target: stage; property: "swapT"; from: 0; to: 1; duration: 340 * stage.dur; easing.type: Easing.OutCubic }

    NumberAnimation { id: riseAnim; target: stage; property: "rise"; duration: 650 * stage.dur; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
    NumberAnimation { id: wobAnim; target: stage; property: "wobT"; from: 0; to: 1; duration: 1100 * stage.dur }
    NumberAnimation { id: slideAnim; target: stage; property: "slideIn"; duration: 700 * stage.dur; easing.type: Easing.OutBack; easing.overshoot: 1.3 }
    // one continuous phone: the screen goes blank while it turns, the two phone shapes swap on a blank screen
    // (same place, same size → invisible), then the new screen fades in
    property real landContent: 1                 // sideways screen content (0 = blank paper)
    readonly property real blankP: Math.max(0, Math.min(1, (turn - 0.08) / 0.38))   // upright screen fades out early in the turn
    SequentialAnimation {
        id: toLand
        ScriptAction { script: stage.landContent = 0 }
        NumberAnimation { target: stage; property: "turn"; to: 1; duration: 720 * stage.dur; easing.type: Easing.InOutCubic }
        NumberAnimation { target: stage; property: "hand"; to: 1; duration: 40 * stage.dur }
        NumberAnimation { target: stage; property: "landContent"; to: 1; duration: 280 * stage.dur; easing.type: Easing.OutCubic }
    }
    SequentialAnimation {
        id: toPort
        NumberAnimation { target: stage; property: "landContent"; to: 0; duration: 170 * stage.dur; easing.type: Easing.InCubic }
        NumberAnimation { target: stage; property: "hand"; to: 0; duration: 40 * stage.dur }
        NumberAnimation { target: stage; property: "turn"; to: 0; duration: 720 * stage.dur; easing.type: Easing.InOutCubic }
        ScriptAction { script: stage.landContent = 1 }
    }
    // big mode: the big upright and big sideways phones cross-fade (no turn, so no jump in size)
    NumberAnimation { id: fadeAnim; target: stage; property: "hand"; duration: 380 * stage.dur; easing.type: Easing.InOutCubic }
    SequentialAnimation {
        id: dropAnim
        ParallelAnimation {
            NumberAnimation { target: stage; property: "rise"; to: 0; duration: 400 * stage.dur; easing.type: Easing.InBack }
            NumberAnimation { target: stage; property: "slideIn"; to: 0; duration: 380 * stage.dur; easing.type: Easing.InBack }
            NumberAnimation { target: stage; property: "hand"; to: 0; duration: 260 * stage.dur }
        }
        ScriptAction { script: { stage.turn = 0; stage.viaTurn = false; stage.orient = "portrait"; stage.screen = "home"; stage.closed() } }
    }

    // ── scrim (click outside = close) ──
    Rectangle {
        anchors.fill: parent; color: Theme.scrim; opacity: Math.min(1, stage.visibleAmount) * (1 - stage.pv)
        MouseArea { anchors.fill: parent; enabled: stage.shown; onClicked: stage.close() }
    }

    // ── portrait phone ──
    readonly property real lk: M.easeInOut(turn)
    readonly property real r: rise
    Item {
        id: pHolder
        x: stage.width / 2 - 240 + 45 * stage.flatP
        readonly property real baseY: stage.height + 250 - 844        // as designed: bottom of the phone below the screen edge
        y: baseY + stage.flatP * ((stage.height / 2 - 422) - baseY)
        width: 390; height: 844
        // small upright phone is drawn 10% bigger; it eases back to 1 while turning so it still lands on the sideways phone
        readonly property real smallScale: 1.1
        scale: (1 - stage.flatP) * (1 + (smallScale - 1) * (1 - stage.lk)) + stage.flatP * Math.min(1.25, stage.height * 0.9 / 844)
        visible: stage.r > 0.001 && stage.hand < 1
        opacity: (1 - stage.hand) * (1 - stage.pv)
        readonly property real piv: 422 * (1 - stage.lk)
        readonly property var inner: M.about(195, 422, M.chain(
            M.T(0, (1 - stage.r) * 1150), M.T(51 * stage.lk, (-343.5 - (stage.height - 1080) / 2) * stage.lk + piv)   /* lands exactly on the sideways phone at any shell size */, M.S(1 + 0.213 * stage.lk),
            M.Ry(-32 * (1 - stage.flatP) + 46 * stage.lk), M.Rx(5 * (1 - stage.flatP) - 29 * stage.lk),
            M.Rz(5 * (1 - stage.flatP) - (1 - stage.r) * 14 + stage.wob * (1 - stage.lk) - 98 * stage.lk),
            M.T(0, -piv)))
        readonly property var view: M.chain(M.F(), M.persp(1500 + 700 * stage.lk, 195 + 51 * stage.lk, 422 - 343.5 * stage.lk), inner)
        // back plate
        Rectangle { width: 390; height: 834; radius: 54; color: Theme.phoneBack
            transform: Matrix4x4 { matrix: M.toQt(M.chain(pHolder.view, M.T(0, 0, -26))) } }
        // right side wall with the Pixel keys
        Rectangle {
            width: 26; height: 734; radius: 10; border.width: 3; border.color: Theme.inkPhone
            gradient: Gradient { orientation: Gradient.Horizontal; GradientStop { position: 0; color: Theme.phoneWallA } GradientStop { position: 1; color: Theme.phoneWallB } }
            transform: Matrix4x4 { matrix: M.toQt(M.chain(pHolder.view, M.T(390, 50), M.about(0, 367, M.Ry(90)))) }
            Rectangle { x: 5; y: 124; width: 12; height: 58; radius: 6; color: Theme.phoneKeyHi; border.width: 2; border.color: Theme.inkPhone }
            Rectangle { x: 5; y: 210; width: 12; height: 118; radius: 6; color: Theme.phoneKey; border.width: 2; border.color: Theme.inkPhone }
        }
        PhoneBody {
            id: pBody
            showKeys: false
            layer.enabled: true; layer.smooth: true; layer.mipmap: !stage.lite
            layer.textureSize: Qt.size(width * stage.texScale, height * stage.texScale)
            transform: Matrix4x4 { matrix: M.toQt(pHolder.view) }
            Repeater {
                model: stage.allScreens
                delegate: Loader {
                    id: ld
                    required property string modelData
                    readonly property bool cur: stage.screen === modelData || (stage.wantLand && stage.prevScreen === modelData)
                    readonly property bool prev: stage.prevScreen === modelData && !stage.wantLand
                    anchors.fill: parent
                    active: cur || prev || item !== null
                    opacity: (cur && !stage.wantLand ? stage.swapT : (cur ? 1 : (prev ? 1 - stage.swapT : 0))) * (1 - stage.blankP)
                    visible: opacity > 0
                    enabled: stage.screen === modelData
                    x: stage.screen === modelData && stage.swapT < 1 ? (1 - stage.swapT) * 28 * stage.navDir : (prev && stage.swapT < 1 ? -stage.swapT * 28 * stage.navDir : 0)
                    focus: stage.screen === modelData
                    sourceComponent: stage.compFor(modelData, false)
                    onCurChanged: if (cur && item && item.focusField) item.focusField()
                    onLoaded: if (cur && item.focusField) item.focusField()
                }
            }
            // big mode: nav bar at the bottom of the phone (the side rail is hidden then)
            UiCandy {
                id: navBar
                readonly property bool isNavZone: true
                readonly property bool on: stage.big && !stage.wantLand && stage.shown
                property real navT: on ? 1 : 0
                Behavior on navT { NumberAnimation { duration: 260 * stage.dur; easing.type: Easing.OutCubic } }
                visible: navT > 0.01
                opacity: navT
                anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 10 - (1 - navT) * 20
                width: navRow.implicitWidth + 14; height: 40; radius: 20; bw: 2.5; ink: Theme.inkPhone; drop: 3; hi: 0; fill: Theme.paper
                Row {
                    id: navRow
                    anchors.centerIn: parent; spacing: 4
                    Repeater {
                        model: [["back", "back"], ["home", "home"], ["quick", "sliders"], ["islands", "map"], ["lite", "bolt"], ["settings", "gear"], ["rotate", "rotate"], ["big", "full"]]
                        delegate: UiCandy {
                            id: nb
                            required property var modelData
                            required property int index
                            readonly property bool cur: modelData[0] === "big" ? stage.big : modelData[0] === "lite" ? stage.lite : stage.screen === modelData[0]
                            property real t: 0
                            SequentialAnimation {
                                id: pop
                                PauseAnimation { duration: (navBar.on ? 120 + nb.index * 40 : 0) * stage.dur }
                                NumberAnimation { target: nb; property: "t"; to: navBar.on ? 1 : 0; duration: (navBar.on ? 300 : 150) * stage.dur; easing.type: navBar.on ? Easing.OutBack : Easing.InCubic }
                            }
                            Connections { target: navBar; function onOnChanged() { pop.restart() } }
                            Component.onCompleted: if (navBar.on) pop.restart()
                            transform: Translate { y: (1 - nb.t) * 14 }
                            opacity: nb.t
                            width: modelData[0] === "back" ? 40 : 36; height: 30; radius: 15; bw: cur ? 2 : 0; ink: Theme.inkPhone; drop: 0; hi: 0
                            fill: cur ? Theme.gOn : "transparent"; pressable: true
                            onClicked: modelData[0] === "rotate" ? stage.rotate() : modelData[0] === "big" ? stage.svc.phoneBig = !stage.svc.phoneBig
                                     : modelData[0] === "lite" ? stage.prefs.set("phoneLite", !stage.prefs.phoneLite)
                                     : modelData[0] === "back" ? stage.back()
                                     : modelData[0] === "home" ? (stage.history = [], stage.navDir = -1, stage.open("home")) : stage.go(modelData[0])
                            Glyph { anchors.centerIn: parent; name: nb.modelData[1]; size: 15; stroke: nb.modelData[0] === "back" ? 3 : 2.5 }
                        }
                    }
                }
            }
        }
    }

    // ── nav rail glued to the upright phone's right edge: back + jump to any screen ──
    // Asks where the edge really is on screen (through the 3D view) and follows it, tilted like the edge.
    Item {
        id: rail
        readonly property real tick: stage.r + stage.wob + stage.lk + stage.flatP + stage.hand + pHolder.scale + pHolder.y + pHolder.x
        readonly property point edgeTop: (tick, pBody.mapToItem(stage, 390, 120))
        readonly property point edgeBot: (tick, pBody.mapToItem(stage, 390, 520))
        readonly property real ang: Math.atan2(edgeBot.x - edgeTop.x, edgeBot.y - edgeTop.y) * 180 / Math.PI
        readonly property bool on: stage.shown && !stage.big && !stage.wantLand && stage.r > 0.6 && stage.hand < 0.5
        visible: pHolder.visible
        opacity: (1 - stage.hand) * (1 - stage.pv)
        x: edgeTop.x + 21; y: edgeTop.y              // a little air past the side keys
        rotation: -ang; transformOrigin: Item.TopLeft
        Column {
            id: railCol
            readonly property bool isNavZone: true
            spacing: 8
            Repeater {
                model: [["back", "back", "Back"], ["home", "home", "Home"], ["quick", "sliders", "Quick"], ["islands", "map", "Islands"],
                        ["lite", "bolt", "Light mode"], ["settings", "gear", "Settings"], ["rotate", "rotate", "Turn phone"], ["big", "full", "Big phone"]]
                delegate: UiCandy {
                    id: rb
                    required property var modelData
                    required property int index
                    readonly property bool cur: modelData[0] === "big" ? stage.big : modelData[0] === "lite" ? stage.lite : stage.screen === modelData[0]
                    // 0 = tucked behind the phone, 1 = out; staggered top → bottom coming out, bottom → top going in
                    property real t: 0
                    SequentialAnimation {
                        id: slide
                        PauseAnimation { duration: (rail.on ? rb.index * 45 : Math.max(0, 7 - rb.index) * 35) * stage.dur }
                        NumberAnimation { target: rb; property: "t"; to: rail.on ? 1 : 0; duration: (rail.on ? 320 : 200) * stage.dur; easing.type: rail.on ? Easing.OutBack : Easing.InCubic }
                    }
                    Connections { target: rail; function onOnChanged() { slide.restart() } }
                    Component.onCompleted: if (rail.on) slide.restart()
                    transform: Translate { x: (1 - rb.t) * -56 }
                    opacity: Math.max(0, rb.t * 1.4 - 0.4)
                    scale: 0.7 + 0.3 * rb.t
                    enabled: rb.t > 0.9
                    width: 46; height: 46; bw: 2.5; ink: Theme.inkPhone; drop: cur ? 2 : 4; hi: 3
                    fill: cur ? Theme.gOn : modelData[0] === "back" ? Theme.gSun : Theme.paper; pressable: true
                    onClicked: modelData[0] === "rotate" ? stage.rotate() : modelData[0] === "big" ? stage.svc.phoneBig = !stage.svc.phoneBig
                                     : modelData[0] === "lite" ? stage.prefs.set("phoneLite", !stage.prefs.phoneLite)
                             : modelData[0] === "back" ? stage.back()
                             : modelData[0] === "home" ? (stage.history = [], stage.navDir = -1, stage.open("home")) : stage.go(modelData[0])
                    Glyph { anchors.centerIn: parent; name: rb.modelData[1]; size: 19; stroke: rb.modelData[0] === "back" ? 3 : 2.5 }
                    UiCandy { visible: rb.hovered; x: rb.width + 8; y: (rb.height - height) / 2; width: tipT.implicitWidth + 18; height: 26; radius: 9
                        bw: 2; ink: Theme.inkPhone; drop: 0; hi: 0; fill: Theme.paper
                        UiText { id: tipT; anchors.centerIn: parent; px: 12; w: 700
                            text: rb.modelData[0] !== "lite" ? rb.modelData[2]
                                : stage.prefs.phoneLite ? "Light mode: on" : stage.svc.gaming ? "Light mode: on while gaming" : "Light mode: off" } }
                }
            }
        }
    }

    // ── landscape phone ──
    Item {
        id: lHolder
        x: stage.width / 2 - 460; y: stage.height / 2 - 190
        width: 920; height: 440
        readonly property real baseScale: 1.12                     // small mode: a little larger than the design
        scale: baseScale + stage.flat * (Math.min(stage.width * 0.75 / 1012, stage.height * 0.8 / 484) - baseScale)
        visible: stage.hand > 0.001 || stage.slideIn > 0.001
        opacity: Math.max(stage.hand, Math.min(1, stage.slideIn * 1.5)) * (1 - stage.pv)
        readonly property var inner: M.about(460, 220, stage.hand > 0.001
            ? M.chain(M.S(1.1), M.Ry(14 * (1 - stage.flat)), M.Rx(-24 * (1 - stage.flat)), M.Rz(-3 * (1 - stage.flat)))
            : M.chain(M.T(0, (1 - stage.slideIn) * 500), M.S(0.8 + 0.3 * stage.slideIn), M.Ry(14), M.Rx(-24), M.Rz(-3 + (1 - stage.slideIn) * 12)))
        readonly property var view: M.chain(M.F(), M.persp(2200, 460, 220), inner)
        Rectangle { y: 0; width: 920; height: 430; radius: 54; color: Theme.phoneBack
            transform: Matrix4x4 { matrix: M.toQt(M.chain(lHolder.view, M.T(0, 0, -22))) } }
        Rectangle { y: 0; width: 920; height: 430; radius: 54; color: "#2A4B55"
            transform: Matrix4x4 { matrix: M.toQt(M.chain(lHolder.view, M.T(0, 0, -11))) } }
        Rectangle {
            width: 820; height: 22; radius: 10; border.width: 3; border.color: Theme.inkPhone
            gradient: Gradient { GradientStop { position: 0; color: Theme.phoneWallA } GradientStop { position: 1; color: Theme.phoneWallB } }
            transform: Matrix4x4 { matrix: M.toQt(M.chain(lHolder.view, M.T(50, 0), M.about(410, 0, M.Rx(-90)))) }
            Rectangle { x: 120; y: 4; width: 58; height: 10; radius: 6; color: Theme.phoneKeyHi; border.width: 2; border.color: Theme.inkPhone }
            Rectangle { x: 200; y: 4; width: 118; height: 10; radius: 6; color: Theme.phoneKey; border.width: 2; border.color: Theme.inkPhone }
        }
        PhoneBody {
            id: lBody
            landscape: true; showKeys: false
            layer.enabled: true; layer.smooth: true; layer.mipmap: !stage.lite
            layer.textureSize: Qt.size(width * stage.texScale, height * stage.texScale)
            transform: Matrix4x4 { matrix: M.toQt(lHolder.view) }
            Repeater {
                model: stage.allScreens
                delegate: Loader {
                    required property string modelData
                    readonly property bool cur: stage.screen === modelData
                    readonly property bool prev: stage.prevScreen === modelData && stage.wantLand
                    width: parent.width; height: parent.height
                    // slide in from the side you're going to (like the upright phone), old screen slides out
                    x: cur && stage.swapT < 1 ? (1 - stage.swapT) * 40 * stage.navDir : (prev && stage.swapT < 1 ? -stage.swapT * 40 * stage.navDir : 0)
                    active: cur || prev || item !== null
                    opacity: (cur ? stage.swapT : (prev ? 1 - stage.swapT : 0)) * stage.landContent
                    visible: opacity > 0
                    enabled: cur
                    focus: cur
                    sourceComponent: stage.compFor(modelData, true)
                }
            }
        }
    }

    // ── screens ──
    property string pendingQuery: ""
    function compFor(n, land) {
        if (land && tallScreens.includes(n)) return n === "quick" ? cQuickTall : n === "clipboard" ? cClipTall : cProfileTall;
        return ({ home: cHome, quick: cQuick, islands: cIslands, clipboard: cClip, profile: cProfile, settings: cSettings,
                  settingsQuick: cSettingsQuick, wallpapers: cWallpapers })[n] || cSetPage;
    }
    // upright layouts inside a scroller for the short sideways phone
    Component { id: cQuickTall; ScrQuickWide { svc: stage.svc; onGo: s => stage.go(s); onBack: stage.back(); onClose: stage.close() } }
    Component { id: cClipTall; Flickable { clip: true; contentHeight: 760; boundsBehavior: Flickable.StopAtBounds
        ScrClipboard { width: parent.width; height: 760; focus: true; svc: stage.svc; onGo: s => stage.go(s); onDone: stage.close() } } }
    Component { id: cProfileTall; Flickable { clip: true; contentHeight: 820; boundsBehavior: Flickable.StopAtBounds
        ScrProfile { width: parent.width; height: 820; focus: true; svc: stage.svc; onGo: s => stage.go(s); onDone: stage.close() } } }
    Component { id: cHome; ScrHome { svc: stage.svc; onGo: s => stage.go(s); onLaunch: a => { stage.svc.launch(a); stage.close() }
        onTyped: t => { stage.pendingQuery = t; stage.open("search") } } }
    Component { id: cSearch; ScrSearch { svc: stage.svc; onGo: s => stage.go(s); onDone: stage.close()
        Connections { target: stage; function onPendingQueryChanged() { if (stage.pendingQuery !== "") { query = stage.pendingQuery; stage.pendingQuery = "" } } }
        Component.onCompleted: if (stage.pendingQuery !== "") { query = stage.pendingQuery; stage.pendingQuery = "" } } }
    Component { id: cQuick; ScrQuick { svc: stage.svc; onGo: s => s === "quickedit" ? stage.soon("Edit buttons") : stage.go(s) } }
    Component { id: cProfile; ScrProfile { svc: stage.svc; onGo: s => stage.go(s); onDone: stage.close() } }
    Component { id: cClip; ScrClipboard { svc: stage.svc; onGo: s => stage.go(s); onDone: stage.close() } }
    Component { id: cIslands; ScrIslands { svc: stage.svc; monitor: stage.monitor; onGo: s => stage.go(s); onDone: stage.close() } }
    Component { id: cSettings; ScrSettings { svc: stage.svc; onGo: s => stage.go(s); onClose: stage.close(); onBack: stage.back(); onSoon: w => stage.soon(w) } }
    Component { id: cSettingsQuick; ScrSettingsQuick { svc: stage.svc; prefs: stage.prefs; onGo: s => stage.go(s); onClose: stage.close(); onBack: stage.back(); onSoon: w => stage.soon(w) } }
    // Wi-Fi / Bluetooth / Sound / Power pages (kind comes from the screen name: settingsWifi → wifi)
    Component { id: cSetPage; ScrSetPage { svc: stage.svc; prefs: stage.prefs
        kind: ({ settingsWifi: "wifi", settingsBt: "bt", settingsSound: "sound", settingsPower: "power", settingsDisplays: "displays", settingsKeys: "keys", settingsTime: "time", settingsSystem: "system", settingsWindows: "windows", settingsTimeLang: "timelang", settingsMouse: "mouse", settingsApps: "apps", settingsPrivacy: "privacy", settingsDiskMap: "diskmap" })[parent ? parent.modelData : "settingsWifi"] || "wifi"
        onGo: s => stage.go(s); onClose: stage.close(); onBack: stage.back() } }
    Component { id: cWallpapers; ScrWallpapers { svc: stage.svc; prefs: stage.prefs; onGo: s => stage.go(s); onClose: stage.close(); onBack: stage.back(); onSoon: w => stage.soon(w) } }

    // Esc closes · Alt+← or the mouse back button goes back
    Keys.onEscapePressed: close()
    // keyboard (keys free in your Hyprland binds): Ctrl+F big/small · Ctrl+←/→ phone screen ↔ buttons · Ctrl+1…5 jump · Alt+← / Backspace back · F1 help
    function zoneOf(it) { let p = it; while (p) { if (p.isNavZone === true) return p; p = p.parent } return null }
    function focusFirst(zone) {
        let n = zone;
        for (let k = 0; k < 600; k++) {
            n = n.nextItemInFocusChain(true); if (!n) return;
            if (zoneOf(n.parent) === zone && n.activeFocusOnTab && n.visible) { n.forceActiveFocus(Qt.TabFocusReason); return }
        }
    }
    // when a screen opens, put the keyboard ring on its first button (unless a text box already has the cursor)
    Timer {
        id: focusSoon; interval: 420
        onTriggered: {
            if (!stage.shown) return;
            const a = stage.Window.activeFocusItem;
            if (a && a.cursorPosition !== undefined) return;             // a text field (Search, Clipboard…) keeps the cursor
            if (a && stage.zoneOf(a.parent) === (stage.wantLand ? lBody : pBody) && a.activeFocusOnTab) return;
            stage.focusFirst(stage.wantLand ? lBody : pBody);
        }
    }
    onScreenChanged: focusSoon.restart()
    function switchZone() {
        const screenZone = wantLand ? lBody : pBody;
        const buttons = wantLand ? null : (big ? navBar : railCol);
        const cur = zoneOf(stage.Window.activeFocusItem ? stage.Window.activeFocusItem.parent : null);
        if (buttons && cur !== buttons) focusFirst(buttons); else focusFirst(screenZone);
    }
    readonly property var ring: ["home", "quick", "islands", "clipboard", "settings"]
    property bool helpOn: false
    Keys.onPressed: e => {
        const ctrl = e.modifiers & Qt.ControlModifier, alt = e.modifiers & Qt.AltModifier;
        const i = Math.max(0, ring.indexOf(wantLand ? "settings" : screen));
        if (ctrl && e.key === Qt.Key_F) { svc.phoneBig = !svc.phoneBig }
        else if (ctrl && (e.key === Qt.Key_Right || e.key === Qt.Key_Left)) { switchZone() }
        else if (ctrl && e.key >= Qt.Key_1 && e.key <= Qt.Key_5) { go(ring[e.key - Qt.Key_1]) }
        else if ((alt && e.key === Qt.Key_Left) || e.key === Qt.Key_Backspace) { back() }
        else if (e.key === Qt.Key_F1) { helpOn = !helpOn }
        else return;
        e.accepted = true;
    }
    onShownChanged: if (!shown) { helpOn = false; if (svc) svc.wallPreview = "" }   // closing the phone also ends a wallpaper preview

    // F1: the key list, on top of everything
    UiCandy {
        visible: stage.helpOn && stage.shown
        z: 2000
        anchors.centerIn: parent
        width: 430; height: helpCol.implicitHeight + 34; radius: 24; bw: 3; ink: Theme.inkPhone; drop: 6; hi: 0; fill: Theme.cream
        Column {
            id: helpCol
            x: 20; y: 16; width: parent.width - 40; spacing: 6
            UiText { text: "Keyboard"; px: 22; w: 700; color: Theme.textDeep; height: 28 }
            Repeater {
                model: [["Tab · arrows", "Move between buttons"], ["Enter · Space", "Press the button"], ["Ctrl + F", "Big / small phone"],
                        ["Ctrl + ← / →", "Phone screen ↔ side buttons"], ["Ctrl + 1 … 5", "Home · Quick · Islands · Clipboard · Settings"],
                        ["Alt + ← · Backspace", "Back"], ["Esc", "Close"], ["F1", "Show / hide this"]]
                delegate: Item {
                    required property var modelData
                    width: helpCol.width; height: 26
                    UiCandy { width: kt.implicitWidth + 16; height: 24; radius: 8; bw: 2; ink: Theme.inkPhone; drop: 2; hi: 0; fill: Theme.paper
                        UiText { id: kt; anchors.centerIn: parent; text: modelData[0]; px: 12; w: 700 } }
                    UiText { x: 150; width: parent.width - 150; height: 24; text: modelData[1]; fam: "n"; px: 12; w: 800; color: Theme.textMuted }
                }
            }
        }
    }
    MouseArea { anchors.fill: parent; z: 1000; enabled: stage.shown; acceptedButtons: Qt.BackButton; onClicked: stage.back() }

    // wallpaper preview bar: the picture's name, Set as Desktop / Lockscreen, Back (← → still browse)
    UiCandy {
        visible: stage.pv > 0.01; opacity: stage.pv; z: 1001
        anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 40 + (1 - stage.pv) * -30
        width: pvRow.implicitWidth + 28; height: 64; radius: 24; bw: 3; drop: 5; hi: 0; ink: Theme.inkPhone; fill: Theme.cream
        Row {
            id: pvRow; anchors.centerIn: parent; spacing: 10
            Column { anchors.verticalCenter: parent.verticalCenter; width: 200
                UiText { width: parent.width; elide: Text.ElideMiddle; text: stage.svc ? stage.svc.wallPreview.split("/").pop() : ""; px: 13; w: 700 }
                UiText { text: "Preview · ← → next picture · Esc back"; fam: "n"; px: 10; w: 800; color: Theme.textSoft } }
            Repeater {
                model: [["wallpaper", "🖥  Set as Desktop"], ["lockWallpaper", "🔒  Lockscreen"]]
                delegate: UiCandy {
                    required property var modelData
                    readonly property bool done: !!stage.svc && stage.prefs[modelData[0]] === stage.svc.wallPreview
                    anchors.verticalCenter: parent.verticalCenter; width: pt.implicitWidth + 26; height: 38; radius: 13; bw: 2.5; drop: 3; hi: 0
                    fill: done ? Theme.gOn : Theme.paper; pressable: true
                    onClicked: stage.prefs.set(modelData[0], stage.svc.wallPreview)
                    UiText { id: pt; anchors.centerIn: parent; text: (parent.done ? "✓ " : "") + modelData[1]; px: 13; w: 700 }
                }
            }
            UiCandy { anchors.verticalCenter: parent.verticalCenter; width: bt.implicitWidth + 26; height: 38; radius: 13; bw: 2.5; drop: 3; hi: 3; fill: Theme.gGo; pressable: true
                onClicked: stage.svc.wallPreview = ""
                UiText { id: bt; anchors.centerIn: parent; text: "Back"; px: 13; w: 700; color: "#FFFFFF" } }
        }
    }
}
