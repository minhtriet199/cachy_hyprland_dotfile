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
    // what each phone shows (the hidden one keeps its last page; nothing is built for the wrong shape)
    property string portShown: "home"
    property string landShown: ""
    property bool shownLand: false               // was `screen` shown on the sideways phone
    property bool prevLand: false                // … and `prevScreen`
    property bool shown: false
    // Settings → Look → Phone window: lives in a normal app window (always the flat "big" pose, no scrim, no big ↔ small)
    property bool windowed: false
    readonly property bool big: windowed || !!svc && svc.phoneBig
    property real flat: big && (wantLand || hand > 0.001 || turning) ? 1 : 0     // 1 = no tilt (big landscape); held while it turns away
    Behavior on flat { NumberAnimation { duration: 380 * stage.dur; easing.type: Easing.OutCubic } }
    property real flatP: big ? 1 : 0                                   // big portrait: centred, larger, upright (kept while sideways, so a turn lands on it)
    Behavior on flatP { NumberAnimation { duration: 420 * stage.dur; easing.type: Easing.OutCubic } }
    // ── overlay ↔ window hand-over (Super+Z): ONE phone moves; the other one takes over in the same spot in one frame ──
    // handT 1 = flat, at the window phone's size, right on the window phone: its window's middle is (handMx, handMy) on
    // this stage, window handW × handH (design px). Sideways the phone sits 40 left / 18 up in its window (side buttons)
    // and 30 below the middle here.
    property real handT: 0
    property real handMx: width / 2
    property real handMy: height / 2
    property real handW: 410
    property real handH: 868
    readonly property real handX: handMx - (wantLand ? 40 : 0) - width / 2
    readonly property real handY: handMy - (wantLand ? 18 + 30 : 0) - height / 2
    readonly property real handFitP: winFitP(handW, handH)
    readonly property real handFitL: winFitL(handW, handH)
    readonly property real fp: Math.max(flatP, handT)          // upright flat amount actually drawn
    readonly property real fl: Math.max(flat, handT)           // … sideways
    function winFitP(w, h) { return Math.min(1.25, (h - 24) / 844, (w - 24) / 390) }     // a window hugs the phone
    function winFitL(w, h) { return Math.min((w - 104) / 1012, (h - 60) / 484) }        // … with room for the side buttons
    readonly property real fitP: windowed ? winFitP(width, height) : Math.min(1.25, height * 0.9 / 844) * (1 - handT) + handFitP * handT
    readonly property real fitL: windowed ? winFitL(width, height) : Math.min(width * 0.75 / 1012, height * 0.8 / 484) * (1 - handT) + handFitL * handT
    Translate { id: handMove; x: stage.handX * stage.handT; y: stage.handY * stage.handT }
    NumberAnimation { id: handAnim; target: stage; property: "handT"; duration: 480 * stage.dur; easing.type: Easing.InOutCubic; onFinished: stage.handDone() }
    signal handDone()
    signal handShown()                                          // took over and is on screen: the other phone can go
    function handTo(t) { handAnim.stop(); handAnim.from = handT; handAnim.to = t; handAnim.start() }
    function handAim(mx, my, w, h) { handMx = mx; handMy = my; handW = w; handH = h }
    // show / hide at once, already up and in place (no rise / drop)
    function appear(scr, land) {
        riseAnim.stop(); dropAnim.stop(); slideAnim.stop(); wobAnim.stop(); toLand.stop(); toPort.stop(); ringAnim.stop();
        history = []; orient = land ? "landscape" : "portrait"; viaTurn = land; turn = land ? 1 : 0; hand = land ? 1 : 0;
        slideIn = 0; rise = 1; wobT = 1; ringW = 0; turning = false;
        if (windowed && svc) svc.phoneBig = true;
        setScreen(scr); swapAnim.stop(); swapT = 1; shown = true; focusSoon.restart();
    }
    function vanish() {
        if (!shown) return;
        riseAnim.stop(); dropAnim.stop(); slideAnim.stop(); handAnim.stop(); toLand.stop(); toPort.stop(); prepMax.stop(); prepFrames = 0;
        history = []; shown = false; rise = 0; hand = 0; slideIn = 0; turning = false; handT = 0;
        turn = 0; viaTurn = false; orient = "portrait"; screen = "home"; portShown = "home"; shownLand = false; closed();
    }
    // the other phone hands over: req = { page, land, hand: { x, y, w, h } } → appear right on top of it, then say so
    property int handWait: 0
    function takeOver(req) {
        if (req.hand) { handAnim.stop(); handT = 1; appear(req.page, req.land); handAim(req.hand.x, req.hand.y, req.hand.w, req.hand.h) }
        else appear(req.page, req.land);
        handWait = 2; handMax.restart();
    }
    Connections { target: stage.Window.window; enabled: stage.handWait > 0
        function onFrameSwapped() { stage.handWait = stage.handWait - 1; if (stage.handWait <= 0) { handMax.stop(); stage.handShown() } } }
    Timer { id: handMax; interval: 300; onTriggered: if (stage.handWait > 0) { stage.handWait = 0; stage.handShown() } }
    // light mode (side button ⚡, or on by itself while a game has focus): the phone face is drawn at a lower
    // sharpness, animations are about half as long and the wobble is skipped — less GPU work next to the game
    // wallpaper live preview (Wallpapers → Preview): the desktop shows the picture and the phone shrinks into the
    // bottom-right corner, still working (keep picking, turn it). A windowed phone just stays where it is.
    readonly property bool previewing: !!svc && svc.wallPreview !== ""
    property real pv: previewing && !windowed ? 1 : 0
    Behavior on pv { NumberAnimation { duration: 320 * stage.dur; easing.type: Easing.OutCubic } }
    // corner pose: scale k about the phone's middle (o) and move that point to t; shared by both phones so a turn still lines up
    property real cK: wantLand ? 560 / (920 * (big ? Math.min(width * 0.75 / 1012, height * 0.8 / 484) : 1.12))
                               : 470 / (844 * (big ? Math.min(1.25, height * 0.9 / 844) : 1.1))
    property real cOx: wantLand || big ? width / 2 : width / 2 - 45
    property real cOy: wantLand ? height / 2 + 30 : big ? height / 2 : height       // small upright phone: keep its bottom on the screen edge
    property real cTx: width - (wantLand ? 420 : 330)
    property real cTy: wantLand ? height - 250 : big ? height - 270 : height
    Behavior on cK { NumberAnimation { duration: 320 * stage.dur; easing.type: Easing.OutCubic } }
    Behavior on cOx { NumberAnimation { duration: 320 * stage.dur; easing.type: Easing.OutCubic } }
    Behavior on cOy { NumberAnimation { duration: 320 * stage.dur; easing.type: Easing.OutCubic } }
    Behavior on cTx { NumberAnimation { duration: 320 * stage.dur; easing.type: Easing.OutCubic } }
    Behavior on cTy { NumberAnimation { duration: 320 * stage.dur; easing.type: Easing.OutCubic } }
    readonly property real cS: 1 + (cK - 1) * pv
    Scale { id: cornerScale; origin.x: stage.cOx; origin.y: stage.cOy; xScale: stage.cS; yScale: stage.cS }
    Translate { id: cornerMove; x: (stage.cTx - stage.cOx) * stage.pv; y: (stage.cTy - stage.cOy) * stage.pv }
    readonly property bool lite: (!!prefs && prefs.phoneLite) || (!!svc && svc.calm)
    readonly property real dur: lite ? 0.45 : 1
    // light mode = a flat phone: no 3D tilt (lighter to draw, e.g. while a game keeps the GPU busy); turning still works
    property real tilt: lite ? 0 : 1
    Behavior on tilt { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
    property real texScale: lite ? (big ? 2 : 1.4) : (big ? 4 : 2.2)          // phone face is drawn flat at this sharpness, then tilted
    readonly property var landScreens: ["settings", "settingsQuick", "wallpapers", "settingsWifi", "settingsBt", "settingsSound", "settingsPower", "settingsDisplays", "settingsKeys", "settingsTime", "settingsSystem", "settingsWindows", "settingsTimeLang", "settingsMouse", "settingsApps", "settingsPrivacy", "settingsDiskMap", "settingsRecovery"]
    // orientation never changes by itself: every screen opens the way the phone is held; only ↻ turns it.
    // A fresh phone opens upright.
    property string orient: "portrait"
    function landFor(scr) { return orient === "landscape" }
    readonly property bool wantLand: landFor(screen)
    readonly property var allScreens: ["home", "quick", "islands", "clipboard", "clipHidden", "profile", "calc", "settings", "settingsQuick", "wallpapers",
                                       "settingsWifi", "settingsBt", "settingsSound", "settingsPower", "settingsDisplays", "settingsKeys", "settingsTime", "settingsSystem", "settingsWindows", "settingsTimeLang", "settingsMouse", "settingsApps", "settingsPrivacy", "settingsDiskMap", "settingsRecovery"]
    readonly property var tallScreens: ["quick", "clipboard", "clipHidden", "profile", "calc"]       // upright layouts that scroll on the short sideways phone
    function rotate() {
        if (!shown) return;
        const was = wantLand;
        orient = was ? "portrait" : "landscape";
        transition(screen, !was, was);
    }
    Connections { target: stage.svc; function onPhoneRotate() { stage.rotate() }
        function onPhoneEsc() { if (stage.shown) stage.dismiss() } }
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
        if (windowed && svc) svc.phoneBig = true;      // pages leave room for the big phone's nav bar
        else if (!shown && svc && Prefs.phoneRemember) svc.phoneBig = Prefs.phoneBigLast;   // reopen big / small as left
        if (land) {
            if (rise > 0.5 && !was) { viaTurn = true; setScreen(scr); swapAnim.stop(); swapT = 1; prepTurn(toLand) }
            else if (was && (hand > 0.5 || slideIn > 0.5)) setScreen(scr)
            else { viaTurn = false; setScreen(scr); slideAnim.from = slideIn; slideAnim.to = 1; slideAnim.restart() }
        } else {
            if (was && viaTurn && hand > 0.5) { setScreen(scr); swapAnim.stop(); swapT = 1; prepTurn(toPort) }
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
        else if (!windowed) close();             // as a window it stays open on home, like any app
    }
    // Esc: closes the overlay phone; as a window it only goes back (close it like a window: ✕ / Super+W)
    function dismiss() { if (windowed) back(); else close() }
    function riseUp() { riseAnim.from = rise; riseAnim.to = 1; riseAnim.easing.type = Easing.OutBack; riseAnim.restart(); if (lite) wobT = 1; else { wobT = 0; wobAnim.restart() } }
    function close() {
        if (!shown) return;
        history = [];
        if (svc && !windowed && Prefs.phoneRemember) Prefs.set("phoneBigLast", svc.phoneBig);
        if (svc) svc.phoneBig = false;           // next open starts small (or as left, with Reopen "As I left it")
        shown = false;
        toLand.stop(); toPort.stop(); prepMax.stop(); prepFrames = 0; turning = false; ringW = 0;
        dropAnim.restart();
    }
    function setScreen(s) {
        const same = s === screen;
        if (!same) { prevScreen = screen; prevLand = shownLand }
        shownLand = wantLand; if (wantLand) landShown = s; else portShown = s;
        if (!same) { screen = s; swapT = 0; swapAnim.restart() }
    }
    property real swapT: 1
    NumberAnimation { id: swapAnim; target: stage; property: "swapT"; from: 0; to: 1; duration: 340 * stage.dur; easing.type: Easing.OutCubic }

    NumberAnimation { id: riseAnim; target: stage; property: "rise"; duration: 650 * stage.dur; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
    NumberAnimation { id: wobAnim; target: stage; property: "wobT"; from: 0; to: 1; duration: 1100 * stage.dur }
    NumberAnimation { id: slideAnim; target: stage; property: "slideIn"; duration: 700 * stage.dur; easing.type: Easing.OutBack; easing.overshoot: 1.3 }
    // the turn (like SekaiPop): both phones turn together, the sideways one lying over the upright one, and their
    // screens dissolve into each other (new page in early, old one out late, so it's never see-through)
    property bool turning: false
    readonly property real landAlpha: M.smooth(0.02, 0.55, turn)
    readonly property real portAlpha: 1 - M.smooth(0.35, 0.92, turn)
    readonly property real px: Window.window ? Window.window.width / Math.max(1, width) * Window.window.devicePixelRatio : 1   // device pixels per stage unit
    readonly property var turnCurve: [0.30, 0.0, 0.20, 1.0, 1.0, 1.0]     // leaves gently, glides into place
    // it waits until the new page has really been drawn (2 frames, at most 260 ms): the heavy first draw
    // no longer eats the start of the turn
    property int prepFrames: 0
    property var prepNext: null
    function prepTurn(anim) { toLand.stop(); toPort.stop(); turning = true; hand = 0; prepNext = anim; prepFrames = 2; prepMax.restart() }
    function startTurn() { prepMax.stop(); prepFrames = 0; if (prepNext) prepNext.restart(); prepNext = null }
    Connections { target: stage.Window.window; enabled: stage.prepFrames > 0
        function onFrameSwapped() { stage.prepFrames = stage.prepFrames - 1; if (stage.prepFrames <= 0) stage.startTurn() } }
    Timer { id: prepMax; interval: 260; onTriggered: stage.startTurn() }
    // ring-out: carries a little past where it lands and swings back
    property real ringW: 0
    property real ringSign: 1
    SequentialAnimation {
        id: ringAnim
        PauseAnimation { duration: 450 * stage.dur }
        NumberAnimation { target: stage; property: "ringW"; to: stage.lite ? 0 : 2.5 * stage.ringSign; duration: 210; easing.type: Easing.InOutSine }
        NumberAnimation { target: stage; property: "ringW"; to: stage.lite ? 0 : -0.25 * stage.ringSign; duration: 190; easing.type: Easing.InOutSine }
        NumberAnimation { target: stage; property: "ringW"; to: 0; duration: 100; easing.type: Easing.InOutSine }
    }
    SequentialAnimation {
        id: toLand
        ScriptAction { script: { stage.ringSign = -1; ringAnim.restart() } }
        NumberAnimation { target: stage; property: "turn"; to: 1; duration: 720 * stage.dur; easing.type: Easing.BezierSpline; easing.bezierCurve: stage.turnCurve }
        ScriptAction { script: { stage.hand = 1; stage.turning = false } }
    }
    SequentialAnimation {
        id: toPort
        ScriptAction { script: { stage.ringSign = 1; ringAnim.restart() } }
        NumberAnimation { target: stage; property: "turn"; to: 0; duration: 720 * stage.dur; easing.type: Easing.BezierSpline; easing.bezierCurve: stage.turnCurve }
        ScriptAction { script: stage.turning = false }
    }
    SequentialAnimation {
        id: dropAnim
        ParallelAnimation {
            NumberAnimation { target: stage; property: "rise"; to: 0; duration: 400 * stage.dur; easing.type: Easing.InBack }
            NumberAnimation { target: stage; property: "slideIn"; to: 0; duration: 380 * stage.dur; easing.type: Easing.InBack }
            NumberAnimation { target: stage; property: "hand"; to: 0; duration: 260 * stage.dur }
        }
        ScriptAction { script: { stage.turn = 0; stage.viaTurn = false; stage.orient = "portrait"; stage.screen = "home"; stage.portShown = "home"; stage.shownLand = false; stage.closed() } }
    }

    // ── scrim (click outside = close) ──
    Rectangle {
        visible: !stage.windowed
        anchors.fill: parent; color: Theme.scrim; opacity: Math.min(1, stage.visibleAmount) * (1 - stage.pv) * (1 - stage.handT)
        MouseArea { anchors.fill: parent; enabled: stage.shown; onClicked: stage.previewing ? stage.svc.wallPreview = "" : stage.close() }
    }

    // ── portrait phone ──
    readonly property real lk: turn                  // the turn's curve is in its animation (turnCurve)
    readonly property real r: rise
    // while turning, the phone fades as ONE flat picture (no back plate showing through its face)
    Item {
        id: portWrap
        anchors.fill: parent
        transform: [cornerScale, cornerMove, handMove]
        layer.enabled: stage.turning
        layer.textureSize: Qt.size(width * stage.px, height * stage.px)
        opacity: stage.turning ? Math.max(0.004, stage.portAlpha) : 1     // 0.004: still drawn while the turn gets ready
        Item {
            id: pHolder
            x: stage.width / 2 - 240 + 45 * stage.fp
            // Settings → Look → Phone: lift the small upright phone (gone while big or sideways, so it still lands on those)
            property real spot: ({ Middle: 140, High: 270 }[stage.prefs ? stage.prefs.phoneSpot : ""] || 0)
            Behavior on spot { NumberAnimation { duration: 420 * stage.dur; easing.type: Easing.OutCubic } }
            readonly property real baseY: stage.height + 250 - 844 - spot * (1 - stage.lk)     // as designed: bottom of the phone below the screen edge
            y: baseY + stage.fp * ((stage.height / 2 - 422) - baseY)
            width: 390; height: 844
            // small upright phone is drawn 10% bigger; it eases back to 1 while turning so it still lands on the sideways phone
            readonly property real smallScale: 1.1
            scale: (1 - stage.fp) * (1 + (smallScale - 1) * (1 - stage.lk)) + stage.fp * stage.fitP
            visible: stage.r > 0.001 && (stage.hand < 1 || stage.turning)
            opacity: stage.turning ? 1 : 1 - stage.hand
            readonly property var place: M.chain(M.T(x, y), M.about(195, 422, M.S(scale)))
            readonly property real piv: 422 * (1 - stage.lk)
            readonly property var inner: M.about(195, 422, M.chain(
                M.T(0, (1 - stage.r) * 1150), M.T(51 * stage.lk, (-343.5 - (stage.height - 1080) / 2) * stage.lk + piv)   /* lands exactly on the sideways phone at any shell size */, M.S(1 + 0.213 * stage.lk),
                M.Ry(-32 * (1 - stage.fp) * stage.tilt + 46 * stage.lk), M.Rx(5 * (1 - stage.fp) * stage.tilt - 29 * stage.lk),
                M.Rz((5 * (1 - stage.fp) - (1 - stage.r) * 14 + (stage.wob + stage.ringW) * (1 - stage.lk)) * stage.tilt - 98 * stage.lk),
                M.T(0, -piv)))
            readonly property var view: M.chain(M.F(), M.persp(1500 + 700 * stage.lk, 195 + 51 * stage.lk, 422 - 343.5 * stage.lk), inner)
            // back plate
            Flat3D { m: M.chain(pHolder.view, M.T(0, 0, -26)); Rectangle { width: 390; height: 834; radius: 54; color: Theme.phoneBack } }
            // right side wall with the Pixel keys
            Flat3D {
                // seen almost edge-on (squeezed to a few px): mipmaps keep the keys smooth instead of jagged (tiny texture)
                m: M.chain(pHolder.view, M.T(390, 50), M.about(0, 367, M.Ry(90))); tex: 3; layer.mipmap: true
                Rectangle {
                    width: 26; height: 734; radius: 10; border.width: 3; border.color: Theme.inkPhone
                    gradient: Gradient { orientation: Gradient.Horizontal; GradientStop { position: 0; color: Theme.phoneWallA } GradientStop { position: 1; color: Theme.phoneWallB } }
                    Rectangle { x: 5; y: 124; width: 12; height: 58; radius: 6; color: Theme.phoneKeyHi; border.width: 2; border.color: Theme.inkPhone }
                    Rectangle { x: 5; y: 210; width: 12; height: 118; radius: 6; color: Theme.phoneKey; border.width: 2; border.color: Theme.inkPhone }
                }
            }
            Flat3D {
                m: pHolder.view; tex: stage.texScale; layer.mipmap: !stage.lite
                PhoneBody {
                    id: pBody
                    showKeys: false
                    Repeater {
                        id: pScreens
                        model: stage.allScreens
                        delegate: Loader {
                            id: ld
                            required property string modelData
                            readonly property bool cur: stage.portShown === modelData
                            readonly property bool prev: stage.prevScreen === modelData && !stage.prevLand && !stage.wantLand
                            width: parent.width; height: parent.height
                            y: cur ? -stage.peek : 0
                            active: cur || prev || item !== null
                            opacity: cur && !stage.wantLand ? stage.swapT : (cur ? 1 : (prev ? 1 - stage.swapT : 0))
                            visible: opacity > 0
                            enabled: cur && !stage.wantLand
                            x: stage.screen === modelData && stage.swapT < 1 ? (1 - stage.swapT) * 28 * stage.navDir : (prev && stage.swapT < 1 ? -stage.swapT * 28 * stage.navDir : 0)
                            focus: cur && !stage.wantLand
                            sourceComponent: stage.compFor(modelData, false)
                            onCurChanged: if (cur && item && item.focusField) item.focusField()
                            onLoaded: if (cur && item.focusField) item.focusField()
                        }
                    }
                    // small overlay phone: its bottom sits below the screen edge → the wheel (where the page itself
                    // doesn't scroll) slides the page up so the bottom can be reached
                    WheelHandler { enabled: stage.peekMax > 0
                        onWheel: e => stage.peek = Math.max(0, Math.min(stage.peekMax, stage.peek - e.angleDelta.y / 2)) }
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
                                model: [["back", "back"], ["home", "home"], ["quick", "sliders"], ["islands", "map"], ["lite", "bolt"], ["settings", "gear"], ["rotate", "rotate"], ["big", "full"]].slice(0, stage.windowed || stage.handT > 0 ? 7 : 8)
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
        }
    }

    // ── nav rail glued to the phone's right edge (upright small, or sideways small/big): back + jump to any screen ──
    // Asks where the edge really is on screen (through the 3D view) and follows it, tilted like the edge.
    Item {
        id: rail
        readonly property bool land: stage.wantLand
        readonly property real tick: stage.r + stage.wob + stage.lk + stage.flatP + stage.hand + pHolder.scale + pHolder.y + pHolder.x
                                     + stage.flat + stage.slideIn + stage.ringW + lHolder.scale + stage.cS + cornerMove.x + cornerMove.y + handMove.x + handMove.y
        readonly property point edgeTop: (tick, land ? lBody.mapToItem(stage, 920, 40) : pBody.mapToItem(stage, 390, 120))
        readonly property point edgeBot: (tick, land ? lBody.mapToItem(stage, 920, 400) : pBody.mapToItem(stage, 390, 520))
        readonly property real ang: Math.atan2(edgeBot.x - edgeTop.x, edgeBot.y - edgeTop.y) * 180 / Math.PI
        readonly property bool on: stage.shown && (land ? !stage.turning && (stage.hand > 0.5 || stage.slideIn > 0.9)
                                                        : !stage.big && stage.r > 0.6 && stage.hand < 0.5)
        visible: land ? lHolder.visible : pHolder.visible
        opacity: land ? 1 : 1 - stage.hand
        x: edgeTop.x + 21 * scale; y: edgeTop.y      // a little air past the side keys
        rotation: -ang; transformOrigin: Item.TopLeft
        scale: stage.cS                              // shrinks with the phone in the wallpaper preview corner
        Column {
            id: railCol
            readonly property bool isNavZone: true
            spacing: 8
            Repeater {
                model: [["back", "back", "Back"], ["home", "home", "Home"], ["quick", "sliders", "Quick"], ["islands", "map", "Islands"],
                        ["lite", "bolt", "Light mode"], ["settings", "gear", "Settings"], ["rotate", "rotate", "Turn phone"], ["big", "full", "Big phone"]].slice(0, stage.windowed || stage.handT > 0 ? 7 : 8)
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
                                : stage.prefs.phoneLite ? "Light mode: on" : stage.svc.gameMode ? "Light mode: on (Game mode)" : stage.svc.gaming ? "Light mode: on while gaming" : "Light mode: off" } }
                }
            }
        }
    }

    // ── landscape phone ──
    // while turning, the phone fades as ONE flat picture (no back plate showing through its face)
    Item {
        id: landWrap
        anchors.fill: parent
        transform: [cornerScale, cornerMove, handMove]
        layer.enabled: stage.turning
        layer.textureSize: Qt.size(width * stage.px, height * stage.px)
        opacity: stage.turning ? Math.max(0.004, stage.landAlpha) : 1     // 0.004: still drawn while the turn gets ready
        Item {
            id: lHolder
            // window: a little left / up so the side buttons fit next to it
            x: stage.width / 2 - 460 - (stage.windowed ? 40 : 0); y: stage.height / 2 - 190 - (stage.windowed ? 48 : 0)
            width: 920; height: 440
            readonly property real baseScale: 1.12                     // small mode: a little larger than the design
            scale: baseScale + stage.fl * (stage.fitL - baseScale)
            visible: stage.hand > 0.001 || stage.slideIn > 0.001 || stage.turning
            opacity: stage.turning ? 1 : Math.max(stage.hand, Math.min(1, stage.slideIn * 1.5))
            readonly property var inner: M.about(460, 220, stage.hand > 0.001 || stage.turning
                ? M.chain(M.S(1.1), M.Ry(14 * (1 - stage.fl) * stage.tilt), M.Rx(-24 * (1 - stage.fl) * stage.tilt), M.Rz(-3 * (1 - stage.fl) * stage.tilt + stage.ringW))
                : M.chain(M.T(0, (1 - stage.slideIn) * 500), M.S(0.8 + 0.3 * stage.slideIn), M.Ry(14 * stage.tilt), M.Rx(-24 * stage.tilt), M.Rz((-3 + (1 - stage.slideIn) * 12) * stage.tilt)))
            readonly property var rest: M.chain(M.F(), M.persp(2200, 460, 220), inner)
            // while turning: lie over the upright phone (a quarter turn round, same size), then ease into its own place
            readonly property var landOnPort: M.chain(M.T(195, 422), M.Rz(90), M.S(844 / 920), M.T(-460, -220))
            readonly property var view: {
                if (!stage.turning) return rest;
                const a = M.norm(M.chain(M.about(460, 220, M.S(1 / scale)), M.T(-x, -y), pHolder.place, pHolder.view, landOnPort)), b = M.norm(rest), s = M.smooth(0.55, 1, stage.turn);
                return a.map((v, i) => v + (b[i] - v) * s);
            }
            Flat3D { m: M.chain(lHolder.view, M.T(0, 0, -22)); Rectangle { width: 920; height: 430; radius: 54; color: Theme.phoneBack } }
            Flat3D { m: M.chain(lHolder.view, M.T(0, 0, -11)); Rectangle { width: 920; height: 430; radius: 54; color: "#2A4B55" } }
            Flat3D {
                m: M.chain(lHolder.view, M.T(50, 0), M.about(410, 0, M.Rx(-90))); tex: 3; layer.mipmap: true      // edge-on: mipmaps keep the keys smooth
                Rectangle {
                    width: 820; height: 22; radius: 10; border.width: 3; border.color: Theme.inkPhone
                    gradient: Gradient { GradientStop { position: 0; color: Theme.phoneWallA } GradientStop { position: 1; color: Theme.phoneWallB } }
                    Rectangle { x: 120; y: 4; width: 58; height: 10; radius: 6; color: Theme.phoneKeyHi; border.width: 2; border.color: Theme.inkPhone }
                    Rectangle { x: 200; y: 4; width: 118; height: 10; radius: 6; color: Theme.phoneKey; border.width: 2; border.color: Theme.inkPhone }
                }
            }
            Flat3D {
                m: lHolder.view; tex: stage.texScale; layer.mipmap: !stage.lite
                PhoneBody {
                    id: lBody
                    landscape: true; showKeys: false
                    Repeater {
                        id: lScreens
                        model: stage.allScreens
                        delegate: Loader {
                            required property string modelData
                            readonly property bool cur: stage.landShown === modelData
                            readonly property bool prev: stage.prevScreen === modelData && stage.prevLand && stage.wantLand
                            width: parent.width; height: parent.height
                            // slide in from the side you're going to (like the upright phone), old screen slides out
                            x: cur && stage.wantLand && stage.swapT < 1 ? (1 - stage.swapT) * 40 * stage.navDir : (prev && stage.swapT < 1 ? -stage.swapT * 40 * stage.navDir : 0)
                            active: cur || prev || item !== null
                            opacity: cur && stage.wantLand ? stage.swapT : (cur ? 1 : (prev ? 1 - stage.swapT : 0))
                            visible: opacity > 0
                            enabled: cur && stage.wantLand
                            focus: cur && stage.wantLand
                            sourceComponent: stage.compFor(modelData, true)
                        }
                    }
                }
            }
        }
    }

    // ── screens ──
    property string pendingQuery: ""
    function compFor(n, land) {
        if (land && tallScreens.includes(n)) return n === "quick" ? cQuickTall : n === "clipboard" ? cClipTall : n === "clipHidden" ? cHidTall : n === "calc" ? cCalcTall : cProfileTall;
        return ({ home: cHome, quick: cQuick, islands: cIslands, clipboard: cClip, clipHidden: cHid, profile: cProfile, calc: cCalc, settings: cSettings,
                  settingsQuick: cSettingsQuick, wallpapers: cWallpapers })[n] || cSetPage;
    }
    // upright layouts inside a scroller for the short sideways phone
    Component { id: cQuickTall; ScrQuickWide { svc: stage.svc; onGo: s => stage.go(s); onBack: stage.back(); onClose: stage.close() } }
    Component { id: cClipTall; Flickable { clip: true; contentHeight: 760; boundsBehavior: Flickable.StopAtBounds
        ScrClipboard { width: parent.width; height: 760; focus: true; svc: stage.svc; onGo: s => stage.go(s); onDone: stage.close() } } }
    Component { id: cHidTall; Flickable { clip: true; contentHeight: 760; boundsBehavior: Flickable.StopAtBounds
        ScrClipboard { width: parent.width; height: 760; focus: true; hidden: true; svc: stage.svc; onGo: s => stage.go(s); onDone: stage.close() } } }
    Component { id: cProfileTall; Flickable { clip: true; contentHeight: 820; boundsBehavior: Flickable.StopAtBounds
        ScrProfile { width: parent.width; height: 820; focus: true; svc: stage.svc; onGo: s => stage.go(s); onDone: stage.close() } } }
    Component { id: cHome; ScrHome { svc: stage.svc; onGo: s => stage.go(s); onLaunch: a => { stage.svc.launch(a); stage.close() }
        onTyped: t => { stage.pendingQuery = t; stage.open("search") } } }
    Component { id: cSearch; ScrSearch { svc: stage.svc; onGo: s => stage.go(s); onDone: stage.close()
        Connections { target: stage; function onPendingQueryChanged() { if (stage.pendingQuery !== "") { query = stage.pendingQuery; stage.pendingQuery = "" } } }
        Component.onCompleted: if (stage.pendingQuery !== "") { query = stage.pendingQuery; stage.pendingQuery = "" } } }
    Component { id: cQuick; ScrQuick { svc: stage.svc; onGo: s => s === "quickedit" ? stage.soon("Edit buttons") : stage.go(s) } }
    Component { id: cCalcTall; Flickable { clip: true; contentHeight: 600; boundsBehavior: Flickable.StopAtBounds
        ScrCalc { width: parent.width; height: 600; focus: true; svc: stage.svc; onDone: stage.close() } } }
    Component { id: cCalc; ScrCalc { svc: stage.svc; onDone: stage.close() } }
    Component { id: cProfile; ScrProfile { svc: stage.svc; onGo: s => stage.go(s); onDone: stage.close() } }
    Component { id: cClip; ScrClipboard { svc: stage.svc; onGo: s => stage.go(s); onDone: stage.close() } }
    Component { id: cHid; ScrClipboard { hidden: true; svc: stage.svc; onGo: s => stage.go(s); onDone: stage.close() } }
    Component { id: cIslands; ScrIslands { svc: stage.svc; monitor: stage.monitor; onGo: s => stage.go(s); onDone: stage.close() } }
    Component { id: cSettings; ScrSettings { svc: stage.svc; onGo: s => stage.go(s); onClose: stage.close(); onBack: stage.back(); onSoon: w => stage.soon(w) } }
    Component { id: cSettingsQuick; ScrSettingsQuick { svc: stage.svc; prefs: stage.prefs; onGo: s => stage.go(s); onClose: stage.close(); onBack: stage.back(); onSoon: w => stage.soon(w) } }
    // Wi-Fi / Bluetooth / Sound / Power pages (kind comes from the screen name: settingsWifi → wifi)
    Component { id: cSetPage; ScrSetPage { svc: stage.svc; prefs: stage.prefs
        kind: ({ settingsWifi: "wifi", settingsBt: "bt", settingsSound: "sound", settingsPower: "power", settingsDisplays: "displays", settingsKeys: "keys", settingsTime: "time", settingsSystem: "system", settingsWindows: "windows", settingsTimeLang: "timelang", settingsMouse: "mouse", settingsApps: "apps", settingsPrivacy: "privacy", settingsDiskMap: "diskmap", settingsRecovery: "recovery" })[parent ? parent.modelData : "settingsWifi"] || "wifi"
        onGo: s => stage.go(s); onClose: stage.close(); onBack: stage.back() } }
    Component { id: cWallpapers; ScrWallpapers { svc: stage.svc; prefs: stage.prefs; onGo: s => stage.go(s); onClose: stage.close(); onBack: stage.back(); onSoon: w => stage.soon(w) } }

    // Esc closes (window: goes back) · Alt+← or the mouse back button goes back
    Keys.onEscapePressed: dismiss()
    // keyboard (keys free in your Hyprland binds): Ctrl+F big/small · Ctrl+S turn · Ctrl+←/→ phone screen ↔ buttons · Ctrl+1…5 jump · Alt+← / Backspace back · F1 help
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
            const rep = stage.wantLand ? lScreens : pScreens;                 // a screen with its own text box (Clipboard, Calculator) takes the keys
            for (let i = 0; i < rep.count; i++) { const l = rep.itemAt(i); if (l && l.cur && l.item && l.item.focusField) { l.item.focusField(); return } }
            stage.focusFirst(stage.wantLand ? lBody : pBody);
        }
    }
    onScreenChanged: { focusSoon.restart(); peek = 0 }
    // ── small overlay phone: how far the page can slide up (the phone's bottom is below the screen edge, less when lifted) ──
    readonly property real hideNow: shown && !big && !windowed && !wantLand ? Math.max(0, 290 - pHolder.spot) : 0
    Binding { when: stage.shown && !stage.windowed; target: stage.svc; property: "phoneHide"; value: stage.hideNow }
    // pages whose own lists already end above the edge (svc.phoneHide) don't slide
    readonly property real peekMax: portShown === "home" || portShown === "islands" || portShown.startsWith("settings") ? 0 : hideNow
    property real peek: 0
    Behavior on peek { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
    onPeekMaxChanged: peek = Math.min(peek, peekMax)
    Binding { target: pBody.screen; property: "clip"; value: stage.peek > 0 }
    // Tab / arrows onto a button below the edge → slide up to it; back near the top → slide back
    Connections {
        target: stage.Window.window
        function onActiveFocusItemChanged() {
            const a = stage.Window.activeFocusItem;
            if (!a || stage.peekMax <= 0 || stage.zoneOf(a.parent) !== pBody || a.cursorPosition !== undefined) return;
            const scr = pBody.screen, top = a.mapToItem(scr, 0, 0).y + stage.peek, bot = top + a.height;
            const seen = scr.height - stage.peekMax;            // page height that's on screen without sliding
            stage.peek = Math.max(0, Math.min(stage.peekMax, bot + 16 - seen, top - 16))
        }
    }
    function switchZone() {
        const screenZone = wantLand ? lBody : pBody;
        const buttons = big && !wantLand ? navBar : railCol;
        const cur = zoneOf(stage.Window.activeFocusItem ? stage.Window.activeFocusItem.parent : null);
        if (buttons && cur !== buttons) focusFirst(buttons); else focusFirst(screenZone);
    }
    readonly property var ring: ["home", "quick", "islands", "clipboard", "settings"]
    property bool helpOn: false
    Keys.onPressed: e => {
        const ctrl = e.modifiers & Qt.ControlModifier, alt = e.modifiers & Qt.AltModifier;
        const i = Math.max(0, ring.indexOf(wantLand ? "settings" : screen));
        if (ctrl && e.key === Qt.Key_F) { if (!windowed) svc.phoneBig = !svc.phoneBig }
        else if (ctrl && e.key === Qt.Key_S) { rotate() }
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
                model: [["Tab · arrows", "Move between buttons"], ["Enter · Space", "Press the button"], ["Ctrl + F", "Big / small phone"], ["Ctrl + S", "Turn the phone"],
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
}
