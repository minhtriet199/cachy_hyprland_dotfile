//@ pragma UseQApplication
// Island Shell — a cozy island desktop for Hyprland (Quickshell config).
// Run it:  qs -c island
import QtQuick
import Quickshell
import Quickshell.Services.Pam
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io

ShellRoot {
    id: shell

    // Open the phone on the monitor you are using.
    signal phoneRequest(string monitor, string screen)
    signal phoneClose()
    signal dropRequest(string monitor, string which)
    signal powerRequest(string monitor)
    function focusedName() { return Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : (Quickshell.screens.length ? Quickshell.screens[0].name : "") }
    // a closed phone opens as the overlay (or the way it was left, Settings → Shell → Reopen), as a window with
    // asWindow (Super+Z); an open phone keeps its mode
    function phone(screen, asWindow) {
        const w = asWindow !== undefined ? !!asWindow : Prefs.phoneRemember && Prefs.phoneWinLast;
        if (!phoneOpen && Prefs.phoneWindow !== w) { _quietMode = true; Prefs.phoneWindow = w; _quietMode = false }
        phoneRequest(focusedName(), screen || "home")
    }
    property bool _quietMode: false

    // Keybinds — in Hyprland (Lua):  hl.bind("SUPER + space", hl.dsp.global("quickshell:islandPhone"))
    GlobalShortcut { name: "islandPhone";      description: "Island: phone";       onPressed: shell.phone("home") }
    GlobalShortcut { name: "islandSearch";     description: "Island: search";      onPressed: shell.phone("search") }
    GlobalShortcut { name: "islandQuick";      description: "Island: quick panel"; onPressed: shell.phone("quick") }
    GlobalShortcut { name: "islandIslands";    description: "Island: workspaces";  onPressed: shell.phone("islands") }
    GlobalShortcut { name: "islandSettings";   description: "Island: settings";    onPressed: shell.phone("settings") }
    GlobalShortcut { name: "islandWallpapers"; description: "Island: wallpapers";  onPressed: shell.phone("wallpapers") }

    // Quickshell's own "Config reloaded" box → a real Island notification instead (bubble + bell list)
    Connections {
        target: Quickshell
        function onReloadCompleted() { Quickshell.inhibitReloadPopup(); Quickshell.execDetached(["sh", "-c", "sleep 0.6; notify-send -a Island 'Island reloaded' 'Your changes are live ✿'"]) }
        function onReloadFailed(err) { Quickshell.inhibitReloadPopup(); Quickshell.execDetached(["sh", "-c", "sleep 0.6; notify-send -a Island -u critical 'Island reload failed' \"$0\"", String(err).slice(0, 300)]) }
    }

    // ── lock screen (Wayland session lock + PAM, same password rules as hyprlock) ──
    Scope {
        id: lockCtl
        property string password: ""
        property bool busy: false
        property bool failed: false
        property bool phoneUp: false                    // lock phone slid up (LockScreen)
        property bool leaving: false                    // right password: phone pulled down before the scene change
        property string user: ""                        // lock: always you (only the login screen picks)
        property date lockedAt: new Date()
        // scene change (circle iris + leaf): desk* plays on the desktop (overlay window), lock* on the lock screen; together they look like one change
        property string deskWipe: "none"
        property real deskT: 0
        property string lockWipe: "none"
        property real lockT: 0
        SequentialAnimation {
            id: toLockAnim                                   // desktop → lock: close on the desktop, open on the lock screen
            ScriptAction { script: { lockCtl.deskT = 0; lockCtl.deskWipe = "coverR" } }
            NumberAnimation { target: lockCtl; property: "deskT"; from: 0; to: 1; duration: 560 }
            ScriptAction { script: { lockCtl.lockWipe = "full"; sessionLock.locked = true } }
            PauseAnimation { duration: 380 }          // leaf moment
            ScriptAction { script: { lockCtl.deskWipe = "none"; lockCtl.lockT = 0; lockCtl.lockWipe = "revealL" } }
            NumberAnimation { target: lockCtl; property: "lockT"; from: 0; to: 1; duration: 650 }
            ScriptAction { script: lockCtl.lockWipe = "none" }
        }
        SequentialAnimation {
            id: toDeskAnim                                   // lock → desktop: phone pulled down and gone, then close on the lock screen, open on the desktop
            ScriptAction { script: lockCtl.leaving = true }
            PauseAnimation { duration: 560 }          // phone gone
            ScriptAction { script: { lockCtl.lockT = 0; lockCtl.lockWipe = "coverL" } }
            NumberAnimation { target: lockCtl; property: "lockT"; from: 0; to: 1; duration: 560 }
            ScriptAction { script: lockCtl.deskWipe = "full" }
            PauseAnimation { duration: 120 }          // let the desktop cover appear under the lock screen first
            ScriptAction { script: { sessionLock.locked = false; lockCtl.password = ""; lockCtl.phoneUp = false; lockCtl.leaving = false } }
            PauseAnimation { duration: 300 }          // leaf moment
            ScriptAction { script: { lockCtl.lockWipe = "none"; lockCtl.deskT = 0; lockCtl.deskWipe = "revealR" } }
            NumberAnimation { target: lockCtl; property: "deskT"; from: 0; to: 1; duration: 650 }
            ScriptAction { script: { lockCtl.deskWipe = "none"; lockCtl.busy = false } }
        }
        // first start: if greetd auto-logged in (island-greeter `island-session autologin` leaves $XDG_RUNTIME_DIR/isla-autologin
        // until the first unlock), Island starts LOCKED — the lock screen is the login screen, and that unlock runs
        // hypr scripts/after-unlock.sh (shortcuts on, startup apps). After the Island login screen you already typed your
        // password, so it only plays the reveal, same as a later restart of Island.
        PersistentProperties { id: lockPersist; reloadableId: "islandLockPersist"; property bool started: false }
        property bool bootLock: false
        Process {
            id: sessionAge
            command: ["sh", "-c", "[ -e \"${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/isla-autologin\" ] && echo lock"]
            stdout: StdioCollector { onStreamFinished: {
                if (this.text.trim() === "lock") { lockCtl.bootLock = true; lockCtl.lockedAt = new Date(); lockCtl.lockWipe = "none"; sessionLock.locked = true; bootReveal.start() }
                else { lockCtl.deskWipe = "full"; startWipe.start() }
            } }
        }
        // boot: the login (lock) screen shows as it is — no scene change before it, the change plays after you log in.
        // The desktop cover stays under it until the lock surfaces are up, then goes.
        Timer { id: bootReveal; interval: 900; onTriggered: lockCtl.deskWipe = "none" }
        Timer { id: startWipe; interval: 450; onTriggered: { lockCtl.deskT = 0; lockCtl.deskWipe = "revealR"; startAnim.restart() } }
        NumberAnimation { id: startAnim; target: lockCtl; property: "deskT"; from: 0; to: 1; duration: 850; onFinished: lockCtl.deskWipe = "none" }
        Component.onCompleted: if (!lockPersist.started) { lockPersist.started = true; deskWipe = "blank"; sessionAge.running = true }   // covered from the first frame (plain until we know if it's the login)
        // first-time safety test: locks, and unlocks by itself after 30 s if the password box doesn't work
        Timer { id: lockTestTimer; interval: 30000; onTriggered: { sessionLock.locked = false; lockCtl.phoneUp = false } }
        function lockTest() { lockNow(); lockTestTimer.restart() }
        function lockNow() { if (sessionLock.locked || toLockAnim.running) return; shell.phoneClose(); password = ""; failed = false; phoneUp = false; leaving = false; lockedAt = new Date(); toLockAnim.restart() }
        function tryUnlock() { if (busy || password === "") return; busy = true; failed = false; if (!pam.start()) { busy = false; failed = true } }
        PamContext {
            id: pam
            config: "hyprlock"                       // /etc/pam.d/hyprlock → login
            onResponseRequiredChanged: if (responseRequired) respond(lockCtl.password)
            onCompleted: result => {
                if (result === PamResult.Success) {
                    lockTestTimer.stop(); toDeskAnim.restart()      // busy until the desktop is back
                    if (lockCtl.bootLock) { lockCtl.bootLock = false; Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.exec_cmd(\"~/.config/hypr/scripts/after-unlock.sh\")"]) }
                }
                else { lockCtl.busy = false; lockCtl.failed = true; lockCtl.password = "" }
            }
            onError: err => { lockCtl.busy = false; lockCtl.failed = true; lockCtl.password = "" }
        }
        // (the pointer is always drawn by Hyprland — hypr config/inputs.lua no_hardware_cursors = 1 — so the lock no longer
        //  switches it: putting it back to 2 after unlocking brought the black-square cursor back, 2026-10-27)
        WlSessionLock {
            id: sessionLock
            WlSessionLockSurface {
                id: lockSurf
                color: "#A3D0E1"
                LockScreen { anchors.fill: parent; svc: Services; lock: lockCtl; Component.onCompleted: forceActiveFocus() }
                // Download mode while locked: the dim download view sits on the lock (a key / mouse wakes → the lock screen)
                Rectangle {
                    visible: Services.download.on && Services.download.dim
                    anchors.fill: parent; color: "#000000"
                    readonly property real sc: (lockSurf.screen ? lockSurf.screen.height : 1080) / 1080 * Prefs.size
                    DownloadScreen { width: parent.width / parent.sc; height: parent.height / parent.sc; scale: parent.sc; transformOrigin: Item.TopLeft; svc: Services }
                }
            }
        }
        Connections { target: Services; function onLockRequested() { lockCtl.lockNow() } }
        // Settings → Transition → Preview: close and open on the desktop (no lock)
        Connections { target: Services; function onWipePreviewRequested() { if (!previewAnim.running) previewAnim.restart() } }
        SequentialAnimation {
            id: previewAnim
            ScriptAction { script: { shell.phoneClose(); lockCtl.deskT = 0; lockCtl.deskWipe = "coverR" } }
            NumberAnimation { target: lockCtl; property: "deskT"; from: 0; to: 1; duration: 560 }
            ScriptAction { script: lockCtl.deskWipe = "full" }
            PauseAnimation { duration: 600 }
            ScriptAction { script: { lockCtl.deskT = 0; lockCtl.deskWipe = "revealR" } }
            NumberAnimation { target: lockCtl; property: "deskT"; from: 0; to: 1; duration: 650 }
            ScriptAction { script: lockCtl.deskWipe = "none" }
        }
    }

    // stand-in lock controller for the lock screen preview: same fields as lockCtl, but it can't unlock or lock anything
    QtObject {
        id: lockPreviewCtl
        property string password: ""
        property bool busy: false
        property bool failed: false
        property bool phoneUp: false
        property bool leaving: false
        property string user: ""
        property var lockedAt: new Date()
        property string lockWipe: "none"
        property real lockT: 0
        function tryUnlock() {}
    }

    // ── screen-share picker: only built while asked ──
    property string shareList: ""
    LazyLoader {
        id: shareL
        active: false
        SharePicker {
            screen: Quickshell.screens.find(x => x.name === shell.focusedName()) || Quickshell.screens[0]
            listFile: shell.shareList
            onDone: shareL.active = false
        }
    }

    // ── snip editor: only built while a snip is open ──
    property var snipReq: null
    LazyLoader {
        id: snipL
        active: false
        SnipEditor {
            screen: Quickshell.screens.find(x => x.name === shell.snipReq.mon) || Quickshell.screens[0]
            crop: shell.snipReq.crop; shot: shell.snipReq.shot; sel: shell.snipReq.sel; dpr: shell.snipReq.dpr
            onDone: snipL.active = false
        }
    }

    // ── "where's my mouse" rings (double-tap Ctrl, hypr/config/locate.lua): only built while showing ──
    property var locateReq: null
    LazyLoader {
        id: locateL
        active: false
        LocatePointer {
            screen: shell.locateReq.scr; at: shell.locateReq.at
            onDone: locateL.active = false
        }
    }

    // ── phone as a normal app window (Settings → Phone → Open as: Window): one for all screens, built on first open and
    //    kept (owner wants it smooth over saving RAM, 2026-10-26); closing the window (X / your close key) removes it ──
    // ── pop-ups that ask something (password, keyring, Bluetooth pair) open on the screen you're on when they come,
    //    and stay there while asking (the pointer crossing screens doesn't move them); main screen if that one is gone ──
    property var askMon: ({ authFlow: "", keyAsk: "", btAsk: "" })
    function pinAsk(k) { const m = Object.assign({}, askMon); m[k] = Services[k] ? focusedName() : ""; askMon = m }
    function askHere(mon, name, isMain) { return Quickshell.screens.some(x => x.name === mon) ? mon === name : isMain }
    Connections {
        target: Services
        function onAuthFlowChanged() { shell.pinAsk("authFlow") }
        function onKeyAskChanged() { shell.pinAsk("keyAsk") }
        function onBtAskChanged() { shell.pinAsk("btAsk") }
    }
    property bool phoneWinLive: false
    property var phoneWinPending: null             // a page name, or a take-over request (below)
    Connections {
        target: shell
        function onPhoneRequest(monitor, screen) { if (Prefs.phoneWindow && !shell.phoneWinLive) { shell.phoneWinPending = screen; shell.phoneWinLive = true } }
    }
    // ── Super+Z / Settings → Open as: ONE phone moves between overlay and window (closed phone: opens Home the new way) ──
    // overlay → window: the overlay phone glides to where the window goes (middle of the screen's free area) at the window
    //   phone's size; meanwhile the window opens hidden on the same page, is put exactly there, shown, then the overlay goes.
    // window → overlay: the overlay phone appears right on top of the window phone, the window goes, the phone glides home.
    property bool phoneOpen: false
    property string phonePage: "home"
    property bool phoneLand: false
    property string phoneMon: ""                   // screen of the open overlay phone
    // going to use the other screen (the pointer moves there, so Hyprland focuses it) closes the overlay phone —
    // after 0.4 s, so just brushing past the edge doesn't (a click there closes it at once: island-phone-away below).
    // Not while a screen change waits for Keep: moving a screen can leave the pointer on the other one.
    Connections { target: Hyprland; function onFocusedMonitorChanged() { phoneAway.restart() } }
    Timer { id: phoneAway; interval: 400
        onTriggered: if (shell.phoneOpen && !Prefs.phoneWindow && !shell.phoneGhost && !Services.screenKeepLeft && shell.phoneMon && Hyprland.focusedMonitor && Hyprland.focusedMonitor.name !== shell.phoneMon) shell.phoneClose() }
    property bool phoneGhost: false                // window phone up but hidden (the overlay phone still covers that spot)
    property var swapTo: null                      // where the window goes (global logical px)
    property int swapWait: 0                       // overlay glide done + window up = 2
    signal phoneSwapOut(string monitor, real mx, real my, real w, real h)   // overlay: glide onto a window phone at (mx, my) design px
    signal phoneSwapWin(var req)                                         // window: take over (hidden) on req.page
    signal phoneSwapIn(string monitor, var req)                          // overlay: take over from the window phone
    signal phoneSwapDone(bool toWin)                                     // the phone that handed over goes
    function winSize(land) { return land ? Qt.size(900, 440) : Qt.size(410, 868) }     // a fresh phone window (design px)
    function scFor(s) { return s.height / 1080 * Prefs.size }
    Connections { target: Prefs; function onPhoneWindowChanged() { if (!Prefs.ready) return; if (Prefs.phoneRemember) Prefs.set("phoneWinLast", Prefs.phoneWindow); if (shell._quietMode) return; if (shell.phoneOpen) swapProbe.running = true; else shell.phone("home", Prefs.phoneWindow) } }
    Process {
        id: swapProbe
        command: ["sh", "-c", "hyprctl -j monitors; echo @; hyprctl -j clients"]
        stdout: StdioCollector { onStreamFinished: { const p = this.text.split("\n@\n"); shell.swapGo(JSON.parse(p[0]), JSON.parse(p[1])) } }
    }
    function swapGo(mons, wins) {
        const req = { page: phonePage, land: phoneLand };
        if (Prefs.phoneWindow) {
            const s = Quickshell.screens.find(x => x.name === phoneMon), m = mons.find(x => x.name === phoneMon);
            if (!s || !m) { phoneSwapDone(true); phone(phonePage); return }
            const r = m.reserved || [0, 0, 0, 0], sc = scFor(s), ws = winSize(phoneLand);
            const cx = r[0] + (s.width - r[0] - r[2]) / 2, cy = r[1] + (s.height - r[1] - r[3]) / 2;
            swapTo = { x: Math.round(s.x + cx - ws.width * sc / 2), y: Math.round(s.y + cy - ws.height * sc / 2), w: Math.round(ws.width * sc), h: Math.round(ws.height * sc) };
            swapWait = 0; phoneGhost = true; swapSafety.restart();
            phoneSwapOut(phoneMon, cx / sc, cy / sc, ws.width, ws.height);
            if (phoneWinLive) phoneSwapWin(req); else { phoneWinPending = req; phoneWinLive = true }
        } else {
            const w = wins.find(c => c.title === "Island Phone"), gx = w ? w.at[0] + w.size[0] / 2 : -1, gy = w ? w.at[1] + w.size[1] / 2 : -1;
            const s = Quickshell.screens.find(m => gx >= m.x && gx < m.x + m.width && gy >= m.y && gy < m.y + m.height);
            if (!s) { phoneSwapDone(false); phone(phonePage); return }
            const sc = scFor(s);
            req.hand = { x: (gx - s.x) / sc, y: (gy - s.y) / sc, w: w.size[0] / sc, h: w.size[1] / sc };
            phoneSwapIn(s.name, req);
        }
    }
    // overlay → window, both ready: put the window exactly under the overlay phone, show it, then the overlay goes
    function swapStep() {
        swapWait = swapWait + 1; if (swapWait < 2) return;
        const t = swapTo, sel = "window = \"title:^(Island Phone)$\"";
        swapPlace.command = ["sh", "-c", "hyprctl dispatch \"$0\" >/dev/null; hyprctl dispatch \"$1\" >/dev/null",
            "hl.dsp.window.resize({ x = " + t.w + ", y = " + t.h + ", " + sel + " })", "hl.dsp.window.move({ x = " + t.x + ", y = " + t.y + ", " + sel + " })"];
        swapPlace.running = true;
    }
    Process { id: swapPlace; onExited: swapShow.restart() }
    Timer { id: swapShow; interval: 60; onTriggered: { shell.phoneGhost = false; swapGone.restart() } }
    Timer { id: swapGone; interval: 50; onTriggered: { swapSafety.stop(); shell.phoneSwapDone(true) } }
    Timer { id: swapSafety; interval: 3000; onTriggered: if (shell.phoneGhost) { shell.phoneGhost = false; shell.phoneSwapDone(true) } }   // never stay hidden
    // ── to-do board as a big window (⤢ on the to-do card): same board, bigger text ──
    LazyLoader {
        active: Services.todo.bigOpen
        FloatingWindow {
            title: "Island Todo"
            implicitWidth: 760; implicitHeight: 900
            color: Theme.paper
            visible: true
            onClosed: Services.todo.bigOpen = false
            // title + progress stay at the top, the writing box at the bottom; only the list scrolls
            Item {
                anchors.fill: parent; anchors.margins: 28
                Row {
                    id: bigHead
                    width: parent.width; spacing: 16
                    UiStrokeText { id: bigTitle; text: Services.todo.name; px: 44; weight: 700; strokeW: 7; strokeColor: Theme.ink }
                    UiText { anchors.verticalCenter: bigTitle.verticalCenter; text: Services.todo.done + " / " + Services.todo.items.length + " done"
                        fam: "n"; px: 18; w: 900; track: 1; color: Theme.textSoft }
                }
                TodoBoard { y: bigHead.height + 18; width: parent.width; height: parent.height - y; todo: Services.todo; k: 1.6; fill: true }
            }
        }
    }
    LazyLoader {
        active: shell.phoneWinLive
        FloatingWindow {
            id: phoneApp
            readonly property real sc: (screen ? screen.height : 1080) / 1080 * Prefs.size     // the screen it's on (Hyprland places it)
            title: "Island Phone"
            // upright / sideways shape; Hyprland only uses it for the first size, so a turn asks it to resize (stays centred)
            implicitWidth: shell.winSize(wstage.wantLand).width * sc
            implicitHeight: shell.winSize(wstage.wantLand).height * sc
            Connections { target: wstage; function onWantLandChanged() { if (phoneApp.visible) Quickshell.execDetached(["hyprctl", "dispatch",
                "hl.dsp.window.resize({ x = " + Math.round(phoneApp.implicitWidth) + ", y = " + Math.round(phoneApp.implicitHeight) + ", window = \"title:^(Island Phone)$\" })"]) } }
            minimumSize: Qt.size(320 * sc, 420 * sc)
            visible: wstage.shown || wstage.visibleAmount > 0.001
            onClosed: { wstage.shown = false; shell.phoneWinLive = false }
            onBackingWindowVisibleChanged: if (backingWindowVisible && shell.phoneGhost) shell.swapStep()
            color: "transparent"          // only the phone shows; Hyprland's border / shadow / blur are off for it (windowrules.lua)
            Item {
                focus: true
                opacity: shell.phoneGhost ? 0 : 1
                width: phoneApp.width / phoneApp.sc; height: phoneApp.height / phoneApp.sc
                scale: phoneApp.sc; transformOrigin: Item.TopLeft
                PhoneStage {
                    id: wstage
                    anchors.fill: parent
                    focus: true
                    windowed: true
                    onShownChanged: if (Prefs.phoneWindow) shell.phoneOpen = shown
                    onScreenChanged: if (Prefs.phoneWindow) shell.phonePage = screen
                    onWantLandChanged: if (Prefs.phoneWindow) shell.phoneLand = wantLand
                    svc: Services; prefs: Prefs; monitor: phoneApp.screen ? phoneApp.screen.name : shell.focusedName()
                    Component.onCompleted: if (shell.phoneWinPending) { const p = shell.phoneWinPending; shell.phoneWinPending = null; typeof p === "string" ? go(p) : takeOver(p) }
                }
            }
            Connections {
                target: shell
                function onPhoneRequest(monitor, screen) {
                    if (!Prefs.phoneWindow) { wstage.close(); return }
                    if (wstage.shown && wstage.screen === screen) { wstage.close(); return }   // same key again = close
                    wstage.go(screen);
                }
                function onPhoneClose() { wstage.close() }
                function onPhoneSwapWin(req) { wstage.takeOver(req) }
                function onPhoneSwapDone(toWin) { if (!toWin) wstage.vanish() }
            }
        }
    }

    // From a terminal:  qs -c island ipc call island phone search
    IpcHandler {
        target: "island"
        function phone(screen: string): void { shell.phone(screen) }
        // Download mode: "toggle" · "keep" (done dialog → Keep using) · "start-shutdown" / "start-keep" (on, no question)
        // — qs -c island ipc call island download toggle
        function download(what: string): void {
            if (what === "keep") Services.download.keepUsing();
            else if (what.startsWith("start-")) Services.download.begin(what.slice(6));
            else Services.toggle("download")
        }
        function close(): void { shell.phoneClose() }
        // Super+Z: open phone → overlay ↔ window; closed phone → opens as a window
        function phonemode(): void { if (shell.phoneGhost || swapProbe.running) return; if (shell.phoneOpen) Prefs.phoneWindow = !Prefs.phoneWindow; else shell.phone("home", true) }
        function lid(state: string): void { Services.lid(state === "closed") }
        function wallpaper(path: string): void { Prefs.set("wallpaper", path) }
        function bar(): void { Prefs.flip("bar") }
        function drop(which: string): void { shell.dropRequest(shell.focusedName(), which) }
        // snip editor (hypr/scripts/snip.sh): "crop.png|screen.ppm|MONITOR|x|y|w|h|scale" (logical px on that screen)
        // screen-share picker (tools/share-pick.sh, for OBS / Discord / browser): shows on the screen you're on
        function sharePick(listFile: string): void { Services.busyDone("rec"); shell.shareList = listFile; shareL.active = false; shareL.active = true }
        function shareClose(): void { shareL.active = false }
        function snip(req: string): void { const f = req.split("|"); shell.snipReq = { crop: f[0], shot: f[1], mon: f[2],
            sel: Qt.rect(+f[3], +f[4], +f[5], +f[6]), dpr: +f[7] || 1 }; snipL.active = true }
        // pointer at X Y (Hyprland's global logical px) → rings on the screen under it
        function locate(x: real, y: real): void {
            const scr = Quickshell.screens.find(m => x >= m.x && x < m.x + m.width && y >= m.y && y < m.y + m.height) || Quickshell.screens[0]
            locateL.active = false; shell.locateReq = { scr: scr, at: Qt.point(x - scr.x, y - scr.y) }; locateL.active = true }
        function power(): void { shell.powerRequest(shell.focusedName()) }
        function lock(): void { lockCtl.lockNow() }
        function locktest(): void { lockCtl.lockTest() }
        function big(): void { Services.phoneBig = !Services.phoneBig }
        function rotate(): void { Services.rotatePhone() }       // turn the open phone upright ↔ sideways
        function preview(): void { Services.previewWipe() }
        function gamemode(): void { Services.toggle("game") }      // qs -c island ipc call island gamemode
        // palette card: wallpaper · music · random · shuffle · apply · undo · get (prints source, colours, picked, applied)
        function palette(cmd: string): string {
            const p = Services.palette;
            if (["wallpaper", "music", "random"].includes(cmd)) p.load(cmd);
            else if (cmd === "shuffle") p.shuffle(); else if (cmd === "apply") p.apply(); else if (cmd === "undo") p.revert();
            return JSON.stringify({ source: p.source, colors: p.colors, sel: p.sel, applied: p.applied, theme: Prefs.theme, hue: Prefs.themeHue, canUndo: !!p.undo });
        }
    }

    Variants {
        model: Quickshell.screens
        delegate: Component {
            Scope {
                id: scr
                required property var modelData
                readonly property string name: modelData.name
                readonly property real sc: modelData.height / 1080 * Prefs.size     // design px → screen px
                readonly property real dw: modelData.width / sc                       // screen width in design px
                readonly property bool isMain: name === Services.mainMonitor || Quickshell.screens.length === 1
                    || !Quickshell.screens.some(x => x.name === Services.mainMonitor) && Quickshell.screens[0].name === name
                readonly property bool barTop: Prefs.barPos !== "Bottom"
                readonly property real barPad: 6                                    // gap above/below the bar (design px)
                readonly property real band: 50 + barPad * 2                         // bar strip height (design px)
                property string drop: ""                                            // open bar dropdown
                readonly property bool dropPinned: drop === "todo" && Services.todo.pinned   // stays up, clicks go through around it
                // a card opening takes the pointer from the bar until it moves (a 2nd click on the pill did nothing) →
                // put the pointer back on its own spot, so a click on the same pill closes the card at once
                onDropChanged: { if (drop !== "todo") Services.todo.pinned = false; if (drop !== "") Services.pointerNudge() }
                property real dropX: 0

                // ── scene change overlay (lock / unlock / first start / preview) ──
                PanelWindow {
                    visible: lockCtl.deskWipe !== "none"
                    screen: scr.modelData
                    anchors { top: true; bottom: true; left: true; right: true }
                    exclusionMode: ExclusionMode.Ignore
                    color: "transparent"
                    WlrLayershell.layer: WlrLayer.Overlay
                    WlrLayershell.namespace: "island-wipe"
                    IrisWipe { anchors.fill: parent; mode: lockCtl.deskWipe; t: lockCtl.deskT }
                }

                // ── wallpaper ──
                PanelWindow {
                    screen: scr.modelData
                    anchors { top: true; bottom: true; left: true; right: true }
                    exclusionMode: ExclusionMode.Ignore
                    WlrLayershell.layer: WlrLayer.Background
                    WlrLayershell.namespace: "island-wallpaper"
                    color: "#D3EAF0"
                    Wallpaper { anchors.fill: parent; path: Services.wallPreview && Services.wallPreviewFor === "Desktop" ? Services.wallPreview : Prefs.wallpaper }
                }

                // ── lock screen preview (wallpaper picker → Lockscreen → 👁): the real lock screen's look with the picked
                //    wallpaper, nothing locked (a stand-in controller); a click / Esc goes back. Only built while previewing.
                //    Under the overlay phone (it steps into the corner, keep flipping pictures); a window phone can't be above it. ──
                LazyLoader {
                    active: Services.wallPreview !== "" && Services.wallPreviewFor === "Lockscreen"
                    PanelWindow {
                        screen: scr.modelData
                        anchors { top: true; bottom: true; left: true; right: true }
                        exclusionMode: ExclusionMode.Ignore
                        color: "#A3D0E1"
                        WlrLayershell.layer: Prefs.phoneWindow ? WlrLayer.Overlay : WlrLayer.Top
                        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None       // the phone keeps the keyboard (Esc stops the preview)
                        WlrLayershell.namespace: "island-lock-preview"
                        LockScreen { anchors.fill: parent; svc: Services; lock: lockPreviewCtl; main: scr.isMain; wall: Services.wallPreview }
                        MouseArea { anchors.fill: parent; z: 200; onPressed: Services.wallPreview = "" }
                        UiCandy { z: 201; anchors.horizontalCenter: parent.horizontalCenter; anchors.top: parent.top; anchors.topMargin: 24 * scr.sc
                            width: pvT.implicitWidth + 36; height: 34; radius: 17; bw: 2.5; drop: 3; hi: 0; fill: Theme.paper; scale: scr.sc
                            UiText { id: pvT; anchors.centerIn: parent; text: "Lock screen preview · " + (Prefs.phoneWindow ? "click or Esc to go back" : "pick on the phone · click outside or Esc to go back"); fam: "n"; px: 12.5; w: 900 } }
                    }
                }

                // ── top bar ──
                PanelWindow {
                    visible: Prefs.bar
                    screen: scr.modelData
                    anchors { top: scr.barTop; bottom: !scr.barTop; left: true; right: true }
                    implicitHeight: Math.ceil(scr.band * scr.sc)
                    exclusiveZone: Math.ceil((scr.band - 4) * scr.sc)
                    color: "transparent"
                    WlrLayershell.namespace: "island-bar"
                    Item {
                        width: scr.dw; height: scr.band
                        scale: scr.sc; transformOrigin: Item.TopLeft
                        // empty bar space closes an open card, like clicking anywhere else (the pills sit on top)
                        MouseArea { anchors.fill: parent; enabled: scr.drop !== "" && !scr.dropPinned; acceptedButtons: Qt.AllButtons; onClicked: scr.drop = "" }
                        UiCandy { visible: Prefs.barStyle === "Float"; x: 8; y: scr.barPad - 6; width: parent.width - 16; height: 62; radius: 26; fill: Theme.cream; drop: 0; hi: 3 }
                        Rectangle { visible: Prefs.barStyle === "Straight"; width: parent.width; height: scr.band - 4; y: scr.barTop ? 0 : 4; color: Theme.ink
                            Rectangle { x: 0; y: scr.barTop ? 0 : 3; width: parent.width; height: parent.height - 3; color: Theme.cream } }
                        TopBar {
                            svc: Services; monitor: scr.name; k: scr.sc; tipUp: !scr.barTop
                            x: 18; width: parent.width - 36; y: scr.barPad
                            onOpenPhone: s => { scr.drop = ""; shell.phoneRequest(scr.name, s) }
                            onOpenDropdown: (w, cx) => { scr.dropX = 18 + cx; scr.drop = scr.drop === w ? "" : w }
                            onOpenPower: { scr.drop = ""; shell.powerRequest(scr.name) }
                        }
                    }
                }

                // ── bar dropdowns (battery · calendar · weather) ──
                PanelWindow {
                    visible: scr.drop !== ""
                    screen: scr.modelData
                    anchors { top: true; bottom: true; left: true; right: true }
                    exclusionMode: ExclusionMode.Ignore
                    color: "transparent"
                    WlrLayershell.layer: WlrLayer.Overlay
                    WlrLayershell.keyboardFocus: scr.drop !== "" ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
                    WlrLayershell.namespace: "island-dropdown"
                    // leave the bar uncovered so another pill can be clicked straight away
                    margins.top: scr.barTop && Prefs.bar ? Math.ceil(scr.band * scr.sc) : 0
                    margins.bottom: !scr.barTop && Prefs.bar ? Math.ceil(scr.band * scr.sc) : 0
                    mask: Region { item: scr.dropPinned ? dropLoader : dropRoot }
                    Item {
                        id: dropRoot
                        width: scr.dw; height: scr.modelData.height / scr.sc - (Prefs.bar ? scr.band : 0)
                        scale: scr.sc; transformOrigin: Item.TopLeft
                        focus: true
                        Keys.onEscapePressed: scr.drop = ""
                        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onClicked: scr.drop = "" }
                        Loader {
                            id: dropLoader
                            active: scr.drop !== ""
                            x: Math.max(12, Math.min(scr.dw - width - 12, scr.dropX - width / 2))
                            y: scr.barTop ? 2 : parent.height - height - 8
                            sourceComponent: scr.drop === "battery" ? cBattery : scr.drop === "weather" ? cWeather : scr.drop === "notifs" ? cNotifs
                                           : ["wifi", "bt", "sound"].includes(scr.drop) ? cPanel : scr.drop === "sys" ? cSys : scr.drop === "music" ? cMusic : scr.drop === "palette" ? cPalette
                                           : scr.drop === "todo" ? cTodo : cCalendar
                            opacity: status === Loader.Ready ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 140 } }
                        }
                        Connections { target: Services; function onAppOpened() { if (!scr.dropPinned) scr.drop = "" } }
                        Connections {
                            target: shell
                            function onDropRequest(monitor, which) {
                                if (monitor !== scr.name) { scr.drop = ""; return }
                                scr.dropX = scr.dw / 2; scr.drop = scr.drop === which ? "" : which
                            }
                        }
                        Component { id: cBattery; DropBattery { svc: Services; onSettings: { scr.drop = ""; shell.phoneRequest(scr.name, "settingsPower") } } }
                        Component { id: cCalendar; DropCalendar { svc: Services; onSettings: { scr.drop = ""; shell.phoneRequest(scr.name, "settingsTimeLang") } } }
                        Component { id: cWeather; DropWeather { svc: Services } }
                        Component { id: cNotifs; DropNotifs { svc: Services } }
                        Component { id: cPanel; DropPanel { svc: Services; kind: scr.drop } }
                        Component { id: cSys; DropSys { svc: Services } }
                        Component { id: cMusic; DropMusic { svc: Services } }
                        Component { id: cPalette; PaletteCard { svc: Services } }
                        Component { id: cTodo; DropTodo { svc: Services } }
                    }
                }

                // ── power menu ──
                PanelWindow {
                    id: powerWin
                    property bool show: false
                    visible: show
                    screen: scr.modelData
                    anchors { top: true; bottom: true; left: true; right: true }
                    exclusionMode: ExclusionMode.Ignore
                    color: "transparent"
                    WlrLayershell.layer: WlrLayer.Overlay
                    WlrLayershell.keyboardFocus: show ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
                    WlrLayershell.namespace: "island-power"
                    Connections { target: Services; function onAppOpened() { if (!Prefs.phoneWindow) shell.phoneClose() } }   // the window phone stays
                    Connections {
                        target: Services
                        function onPowerMenuRequested() { shell.phoneClose(); if (scr.name === shell.focusedName()) shell.powerRequest(scr.name) }
                    }
                    Connections {
                        target: shell
                        function onPowerRequest(monitor) {
                            powerWin.show = monitor === scr.name && !powerWin.show;
                            if (powerWin.show) { power.sel = 2; power.armed = ""; power.forceActiveFocus() }
                        }
                    }
                    Rectangle { anchors.fill: parent; color: Theme.scrim; opacity: powerWin.show ? 1 : 0 }
                    MouseArea { anchors.fill: parent; onClicked: powerWin.show = false }
                    Item {
                        width: scr.dw; height: scr.modelData.height / scr.sc
                        scale: scr.sc; transformOrigin: Item.TopLeft
                        PowerMenu {
                            id: power
                            anchors.centerIn: parent
                            svc: Services
                            focus: true
                            scale: powerWin.show ? 1 : 0.9
                            Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }
                            onClosed: powerWin.show = false
                        }
                    }
                }

                // ── dock (auto-hides; touch the bottom edge to show it) ──
                PanelWindow {
                    id: dockWin
                    readonly property real k: scr.sc * Services.dockSize
                    readonly property real boxH: dock.height + 8                  // dock + its drop shadow + 2 px gap
                    readonly property bool shown: dockHover.hovered || dock.popupHovered || dock.hoverKey !== "" || holdTimer.running
                    visible: Prefs.dock
                    screen: scr.modelData
                    anchors { bottom: true }
                    margins.bottom: (!scr.barTop && Prefs.bar) ? Math.round(scr.band * scr.sc) : 0
                    implicitWidth: Math.ceil((dock.width + 8) * k)
                    implicitHeight: Math.ceil(boxH * k)
                    exclusiveZone: 0
                    color: "transparent"
                    WlrLayershell.namespace: "island-dock"
                    // while a game is focused the bottom edge belongs to the game (edge scrolling), so no hover strip
                    mask: Region { item: dockWin.shown ? dockBox : Services.gaming ? null : dockTrigger }
                    onShownChanged: if (!shown) dock.hoverKey = ""
                    Timer { id: holdTimer; interval: 450 }                         // small delay before hiding
                    Item {
                        id: dockBox
                        width: dock.width + 8; height: dockWin.boxH
                        scale: dockWin.k; transformOrigin: Item.TopLeft
                        HoverHandler { id: dockHover; onHoveredChanged: if (!hovered) holdTimer.restart() }
                        Item { id: dockTrigger; anchors.bottom: parent.bottom; width: parent.width; height: 3 / dockWin.k }
                        Dock {
                            id: dock; x: 4; svc: Services
                            y: dockWin.shown ? 0 : dockWin.boxH + 4
                            Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                            onOpenPhone: s => shell.phoneRequest(scr.name, s)
                        }
                    }
                    // hover tooltip with live window previews
                    PopupWindow {
                        visible: dockWin.shown && dock.hoverKey !== ""
                        color: "transparent"
                        anchor.window: dockWin
                        anchor.rect.x: (4 + dock.hoverX) * dockWin.k
                        anchor.rect.y: 0
                        anchor.rect.width: 1; anchor.rect.height: 1
                        anchor.edges: Edges.Top
                        anchor.gravity: Edges.Top
                        implicitWidth: Math.ceil((preview.width + 8) * scr.sc)
                        implicitHeight: Math.ceil((preview.height + 14) * scr.sc)
                        Item {
                            width: preview.width + 8; height: preview.height + 14
                            scale: scr.sc; transformOrigin: Item.TopLeft
                            HoverHandler { onHoveredChanged: dock.popupHovered = hovered }
                            DockPreview { id: preview; x: 4; y: 2; svc: Services; name: dock.hoverName; wins: dock.hoverWins; onPicked: dock.hoverKey = "" }
                        }
                    }
                }

                // ── big sticker clock (every monitor) ──
                PanelWindow {
                    screen: scr.modelData
                    anchors { top: true; right: true }
                    margins.top: Math.round((370 - 30) * scr.sc)
                    margins.right: Math.round((64 - 30) * scr.sc)
                    implicitWidth: Math.ceil((bigClock.width + 64) * scr.sc)
                    implicitHeight: Math.ceil((bigClock.height + 40) * scr.sc)
                    exclusionMode: ExclusionMode.Ignore
                    color: "transparent"
                    mask: Region {}
                    WlrLayershell.layer: WlrLayer.Bottom
                    WlrLayershell.namespace: "island-clock"
                    Item {
                        width: bigClock.width + 64; height: bigClock.height + 40
                        scale: scr.sc; transformOrigin: Item.TopLeft
                        StickerClock { id: bigClock; x: 34; y: 30; svc: Services }
                    }
                }

                // ── notification bubbles (main monitor): up to 3 stacked under the bar, more wait in a queue ──
                PanelWindow {
                    id: toastWin
                    visible: scr.isMain && (Services.toasts.length > 0 || stack.height > 1)
                    screen: scr.modelData
                    anchors { top: true; right: true }
                    margins.top: scr.barTop && Prefs.bar ? Math.round((scr.band + 2) * scr.sc) : Math.round(8 * scr.sc)
                    margins.right: Math.round(40 * scr.sc)
                    implicitWidth: Math.ceil(376 * scr.sc)
                    implicitHeight: Math.max(1, Math.ceil((stack.contentHeight + 16) * scr.sc))
                    exclusionMode: ExclusionMode.Ignore
                    color: "transparent"
                    WlrLayershell.layer: WlrLayer.Overlay
                    WlrLayershell.namespace: "island-notification"
                    Item {
                        width: 376; height: stack.contentHeight + 16
                        scale: scr.sc; transformOrigin: Item.TopLeft
                        HoverHandler { onHoveredChanged: Services.toastHover = hovered }
                        ListView {
                            id: stack
                            x: 8; y: 2; width: 360; height: contentHeight
                            interactive: false; spacing: 6
                            model: Services.toasts
                            add: Transition { ParallelAnimation {
                                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200 }
                                NumberAnimation { property: "scale"; from: 0.9; to: 1; duration: 260; easing.type: Easing.OutBack } } }
                            displaced: Transition { NumberAnimation { properties: "y"; duration: 240; easing.type: Easing.OutCubic } }
                            remove: Transition { NumberAnimation { property: "opacity"; to: 0; duration: 160 } }
                            delegate: Toast {
                                required property var modelData
                                width: 360
                                app: modelData.app; body: modelData.body; tint: modelData.tint
                                image: modelData.image || ""; pinned: !!modelData.pinned
                                onClicked: { Services.activateNotification(modelData); Services.dropToast(modelData.key) }
                                onDismissed: Services.dropToast(modelData.key)
                            }
                        }
                    }
                }

                // ── password prompt for system changes (polkit), top middle of the screen you're on, only while asking ──
                LazyLoader {
                    active: !!shell.askMon.authFlow && shell.askHere(shell.askMon.authFlow, scr.name, scr.isMain)
                    PanelWindow {
                        screen: scr.modelData
                        anchors.top: true
                        margins.top: scr.barTop && Prefs.bar ? Math.round((scr.band + 6) * scr.sc) : Math.round(12 * scr.sc)
                        implicitWidth: Math.ceil(390 * scr.sc)
                        implicitHeight: Math.ceil((authBox.height + 16) * scr.sc)
                        exclusionMode: ExclusionMode.Ignore
                        color: "transparent"
                        WlrLayershell.layer: WlrLayer.Overlay
                        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
                        WlrLayershell.namespace: "island-polkit"
                        PolkitDialog { id: authBox; x: 10; flow: Services.authFlow; scale: scr.sc; transformOrigin: Item.TopLeft }
                    }
                }

                // ── keyring password pop-up (screen you're on, top middle, only while asking) ──
                LazyLoader {
                    active: !!shell.askMon.keyAsk && shell.askHere(shell.askMon.keyAsk, scr.name, scr.isMain)
                    PanelWindow {
                        screen: scr.modelData
                        anchors.top: true
                        margins.top: scr.barTop && Prefs.bar ? Math.round((scr.band + 6) * scr.sc) : Math.round(12 * scr.sc)
                        implicitWidth: Math.ceil(420 * scr.sc)
                        implicitHeight: Math.ceil((keyBox.height + 16) * scr.sc)
                        exclusionMode: ExclusionMode.Ignore
                        color: "transparent"
                        WlrLayershell.layer: WlrLayer.Overlay
                        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
                        WlrLayershell.namespace: "island-keyring"
                        KeyringDialog { id: keyBox; x: 10; svc: Services; scale: scr.sc; transformOrigin: Item.TopLeft }
                    }
                }

                // ── Bluetooth pair / connect request (screen you're on, top middle): only exists while asking ──
                LazyLoader {
                    active: !!shell.askMon.btAsk && shell.askHere(shell.askMon.btAsk, scr.name, scr.isMain)
                    PanelWindow {
                        screen: scr.modelData
                        anchors.top: true
                        margins.top: scr.barTop && Prefs.bar ? Math.round((scr.band + 6) * scr.sc) : Math.round(12 * scr.sc)
                        implicitWidth: Math.ceil(390 * scr.sc)
                        implicitHeight: Math.ceil((pairBox.height + 16) * scr.sc)
                        exclusionMode: ExclusionMode.Ignore
                        color: "transparent"
                        WlrLayershell.layer: WlrLayer.Overlay
                        WlrLayershell.namespace: "island-bluetooth"
                        BtPairDialog { id: pairBox; x: 10; svc: Services; scale: scr.sc; transformOrigin: Item.TopLeft }
                    }
                }

                // ── an app is opening: a spinner next to the pointer (click-through, only while Services.launching) ──
                PanelWindow {
                    id: spinWin
                    readonly property point at: Qt.point(Services.cursor.x - scr.modelData.x, Services.cursor.y - scr.modelData.y)
                    visible: Services.launching && at.x >= 0 && at.y >= 0 && at.x < scr.modelData.width && at.y < scr.modelData.height
                    screen: scr.modelData
                    anchors { top: true; bottom: true; left: true; right: true }
                    exclusionMode: ExclusionMode.Ignore
                    color: "transparent"
                    mask: Region {}
                    WlrLayershell.layer: WlrLayer.Overlay
                    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                    WlrLayershell.namespace: "island-launch-spinner"
                    UiCandy {
                        x: spinWin.at.x + 16; y: spinWin.at.y + 16; width: 24; height: 24; radius: 12; bw: 2; drop: 2; hi: 0; fill: Theme.paper
                        Glyph { anchors.centerIn: parent; name: "reload"; size: 14; stroke: 2.6
                            RotationAnimator on rotation { from: 0; to: 360; duration: 800; loops: Animation.Infinite; running: Services.launching } }
                    }
                }

                // ── Download mode (SvcDownload.qml): the dim download screen on one screen (the others are off) ──
                PanelWindow {
                    visible: Services.download.on && Services.download.dim && Services.download.aodScreen === scr.name
                    screen: scr.modelData
                    anchors { top: true; bottom: true; left: true; right: true }
                    exclusionMode: ExclusionMode.Ignore
                    color: "#000000"
                    WlrLayershell.layer: WlrLayer.Overlay
                    // it takes the keys while it shows: the key you press to wake isn't typed into an app, and a key right
                    // after it dims still wakes (the idle watch only counts input after 2 quiet seconds)
                    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
                    WlrLayershell.namespace: "island-download"
                    MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; hoverEnabled: true      // clicks don't reach the apps under it
                        onPressed: Services.download.dim = false; onPositionChanged: Services.download.dim = false }
                    DownloadScreen { width: scr.dw; height: scr.modelData.height / scr.sc; scale: scr.sc; transformOrigin: Item.TopLeft; svc: Services
                        focus: true; Keys.onPressed: e => { Services.download.dim = false; e.accepted = true } }
                }
                // before it starts: shut down or keep using when it's done (DownloadAsk.qml), on the screen you're on
                PanelWindow {
                    visible: Services.download.choosing && Hyprland.focusedMonitor && Hyprland.focusedMonitor.name === scr.name
                    onVisibleChanged: if (visible) shell.phoneClose()      // the phone sits above it
                    screen: scr.modelData
                    anchors { top: true; bottom: true; left: true; right: true }
                    exclusionMode: ExclusionMode.Ignore
                    color: Theme.scrim
                    WlrLayershell.layer: WlrLayer.Overlay
                    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
                    WlrLayershell.namespace: "island-download-ask"
                    MouseArea { anchors.fill: parent }
                    DownloadAsk { anchors.centerIn: parent; scale: scr.sc; svc: Services }
                }
                // … and when it's done: "Downloads finished" + 2 min to shut down, on the screen you're on
                PanelWindow {
                    visible: Services.download.asking && Hyprland.focusedMonitor && Hyprland.focusedMonitor.name === scr.name
                    screen: scr.modelData
                    anchors { top: true; bottom: true; left: true; right: true }
                    exclusionMode: ExclusionMode.Ignore
                    color: Theme.scrim
                    WlrLayershell.layer: WlrLayer.Overlay
                    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
                    WlrLayershell.namespace: "island-download-done"
                    MouseArea { anchors.fill: parent }
                    DownloadDone { anchors.centerIn: parent; scale: scr.sc; svc: Services }
                }

                // ── overlay phone open on ANOTHER screen: a see-through catcher here, a click closes the phone
                //    (the phone keeps the keyboard, so without this this screen could be clicked but not typed in) ──
                PanelWindow {
                    visible: shell.phoneOpen && !Prefs.phoneWindow && shell.phoneMon !== "" && shell.phoneMon !== scr.name
                    screen: scr.modelData
                    anchors { top: true; bottom: true; left: true; right: true }
                    exclusionMode: ExclusionMode.Ignore
                    color: "transparent"
                    WlrLayershell.layer: WlrLayer.Overlay
                    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                    WlrLayershell.namespace: "island-phone-away"
                    MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onPressed: shell.phoneClose() }
                }

                // ── the phone: built when Island starts, on every screen, and never removed — so every open is instant
                // (≈ 120 MB per screen; building it on demand made the first open take ≈ 0.15–0.45 s. Owner chose smooth, 2026-10-26)
                property bool phoneLive: true
                property var phonePending: null              // a page name, or a take-over request from the window phone
                Connections {
                    target: shell
                    function onPhoneRequest(monitor, screen) { if (monitor === scr.name && !scr.phoneLive && !Prefs.phoneWindow) { scr.phonePending = screen; scr.phoneLive = true } }
                    function onPhoneSwapIn(monitor, req) { if (monitor === scr.name && !scr.phoneLive) { scr.phonePending = req; scr.phoneLive = true } }
                }
                LazyLoader {
                active: scr.phoneLive
                PanelWindow {
                    id: phoneWin
                    screen: scr.modelData
                    visible: stage.shown || stage.visibleAmount > 0.001
                    anchors { top: true; bottom: true; left: true; right: true }
                    exclusionMode: ExclusionMode.Ignore
                    color: "transparent"
                    WlrLayershell.layer: WlrLayer.Overlay
                    WlrLayershell.keyboardFocus: stage.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
                    WlrLayershell.namespace: "island-phone"
                    Item {
                        focus: true
                        width: scr.dw; height: scr.modelData.height / scr.sc
                        scale: scr.sc; transformOrigin: Item.TopLeft
                        PhoneStage {
                            id: stage
                            anchors.fill: parent
                            focus: true
                            svc: Services; prefs: Prefs; monitor: scr.name
                            onShownChanged: if (!Prefs.phoneWindow) { shell.phoneOpen = shown; if (shown) shell.phoneMon = scr.name }
                            onScreenChanged: if (!Prefs.phoneWindow) shell.phonePage = screen
                            onWantLandChanged: if (!Prefs.phoneWindow) shell.phoneLand = wantLand
                            onHandDone: if (Prefs.phoneWindow && shell.phoneGhost) shell.swapStep()      // glided onto the window's spot
                            onHandShown: { shell.phoneSwapDone(false); Services.phoneBig = false; handTo(0) }   // on top of the window phone: it goes, glide home
                            onSoon: w => { soon.text = w + " is coming in the next Island update ✿"; soon.show = true; soonTimer.restart() }
                            // the request that built the phone: open that screen now
                            Component.onCompleted: if (scr.phonePending) { const p = scr.phonePending; scr.phonePending = null; typeof p === "string" ? go(p) : takeOver(p) }
                        }
                        Toast {
                            id: soon
                            property string text: ""
                            property bool show: false
                            anchors.horizontalCenter: parent.horizontalCenter; y: show ? 90 : 60
                            opacity: show ? 1 : 0
                            app: "Island"; body: text; tint: Theme.lilac
                            Behavior on opacity { NumberAnimation { duration: 180 } }
                            Behavior on y { NumberAnimation { duration: 240; easing.type: Easing.OutBack } }
                        }
                        Timer { id: soonTimer; interval: 2600; onTriggered: soon.show = false }
                    }
                    Connections {
                        target: shell
                        function onPhoneRequest(monitor, screen) {
                            if (monitor !== scr.name || Prefs.phoneWindow) { stage.close(); return }
                            if (stage.shown && stage.screen === screen) { stage.close(); return }   // same key again = close
                            stage.go(screen);
                        }
                        function onPhoneClose() { stage.close() }
                        function onPhoneSwapOut(monitor, mx, my, w, h) { if (monitor !== scr.name || !stage.shown) return; stage.handAim(mx, my, w, h); Services.phoneBig = true; stage.handTo(1) }
                        function onPhoneSwapIn(monitor, req) { if (monitor === scr.name) stage.takeOver(req) }
                        function onPhoneSwapDone(toWin) { if (toWin) stage.vanish() }
                    }
                }
                }
            }
        }
    }
}
