//@ pragma UseQApplication
// Isla Shell — a cozy island desktop for Hyprland (Quickshell config).
// Run it:  qs -c isla
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
    function phone(screen) { phoneRequest(focusedName(), screen || "home") }

    // Keybinds — in Hyprland (Lua):  hl.bind("SUPER + space", hl.dsp.global("quickshell:islaPhone"))
    GlobalShortcut { name: "islaPhone";      description: "Isla: phone";       onPressed: shell.phone("home") }
    GlobalShortcut { name: "islaSearch";     description: "Isla: search";      onPressed: shell.phone("search") }
    GlobalShortcut { name: "islaQuick";      description: "Isla: quick panel"; onPressed: shell.phone("quick") }
    GlobalShortcut { name: "islaIslands";    description: "Isla: workspaces";  onPressed: shell.phone("islands") }
    GlobalShortcut { name: "islaSettings";   description: "Isla: settings";    onPressed: shell.phone("settings") }
    GlobalShortcut { name: "islaWallpapers"; description: "Isla: wallpapers";  onPressed: shell.phone("wallpapers") }

    // Quickshell's own "Config reloaded" box → a real Isla notification instead (bubble + bell list)
    Connections {
        target: Quickshell
        function onReloadCompleted() { Quickshell.inhibitReloadPopup(); Quickshell.execDetached(["sh", "-c", "sleep 0.6; notify-send -a Isla 'Isla reloaded' 'Your changes are live ✿'"]) }
        function onReloadFailed(err) { Quickshell.inhibitReloadPopup(); Quickshell.execDetached(["sh", "-c", "sleep 0.6; notify-send -a Isla -u critical 'Isla reload failed' \"$0\"", String(err).slice(0, 300)]) }
    }

    // ── lock screen (Wayland session lock + PAM, same password rules as hyprlock) ──
    Scope {
        id: lockCtl
        property string password: ""
        property bool busy: false
        property bool failed: false
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
            id: toDeskAnim                                   // lock → desktop: close on the lock screen, open on the desktop
            ScriptAction { script: { lockCtl.lockT = 0; lockCtl.lockWipe = "coverL" } }
            NumberAnimation { target: lockCtl; property: "lockT"; from: 0; to: 1; duration: 560 }
            ScriptAction { script: lockCtl.deskWipe = "full" }
            PauseAnimation { duration: 120 }          // let the desktop cover appear under the lock screen first
            ScriptAction { script: { sessionLock.locked = false; lockCtl.password = "" } }
            PauseAnimation { duration: 300 }          // leaf moment
            ScriptAction { script: { lockCtl.lockWipe = "none"; lockCtl.deskT = 0; lockCtl.deskWipe = "revealR" } }
            NumberAnimation { target: lockCtl; property: "deskT"; from: 0; to: 1; duration: 650 }
            ScriptAction { script: lockCtl.deskWipe = "none" }
        }
        // first start: if greetd auto-logs in (initial_session) and the Hyprland session is brand new (< 90 s), Isla starts
        // LOCKED — the lock screen acts as the login screen. With the real Isla login screen (isla-greeter, no auto-login)
        // you already typed your password, so it only plays the reveal, same as a later restart of Isla.
        PersistentProperties { id: lockPersist; reloadableId: "islaLockPersist"; property bool started: false }
        Process {
            id: sessionAge
            command: ["sh", "-c", "grep -q '^\\[initial_session\\]' /etc/greetd/config.toml 2>/dev/null || { echo 99999; exit; }; ps -o etimes= -p $(pgrep -xo Hyprland || echo 1) | tr -d ' '"]
            stdout: StdioCollector { onStreamFinished: {
                const age = parseInt(this.text) || 99999;
                if (age < 90) { lockCtl.lockedAt = new Date(); lockCtl.lockWipe = "full"; sessionLock.locked = true; bootReveal.start() }
                else startWipe.start()
            } }
        }
        // lock surfaces need a moment to be on screen; the cream + leaf cover holds until then, then the desktop cover goes away
        Timer { id: bootReveal; interval: 900; onTriggered: { lockCtl.deskWipe = "none"; lockCtl.lockT = 0; lockCtl.lockWipe = "revealL"; bootRevealAnim.restart() } }
        NumberAnimation { id: bootRevealAnim; target: lockCtl; property: "lockT"; from: 0; to: 1; duration: 850; onFinished: lockCtl.lockWipe = "none" }
        Timer { id: startWipe; interval: 450; onTriggered: { lockCtl.deskT = 0; lockCtl.deskWipe = "revealR"; startAnim.restart() } }
        NumberAnimation { id: startAnim; target: lockCtl; property: "deskT"; from: 0; to: 1; duration: 850; onFinished: lockCtl.deskWipe = "none" }
        Component.onCompleted: if (!lockPersist.started) { lockPersist.started = true; deskWipe = "full"; sessionAge.running = true }   // covered from the first frame
        // first-time safety test: locks, and unlocks by itself after 30 s if the password box doesn't work
        Timer { id: lockTestTimer; interval: 30000; onTriggered: sessionLock.locked = false }
        function lockTest() { lockNow(); lockTestTimer.restart() }
        function lockNow() { if (sessionLock.locked || toLockAnim.running) return; shell.phoneClose(); password = ""; failed = false; lockedAt = new Date(); toLockAnim.restart() }
        function tryUnlock() { if (busy || password === "") return; busy = true; failed = false; if (!pam.start()) { busy = false; failed = true } }
        PamContext {
            id: pam
            config: "hyprlock"                       // /etc/pam.d/hyprlock → login
            onResponseRequiredChanged: if (responseRequired) respond(lockCtl.password)
            onCompleted: result => {
                lockCtl.busy = false;
                if (result === PamResult.Success) { lockTestTimer.stop(); toDeskAnim.restart() }
                else { lockCtl.failed = true; lockCtl.password = "" }
            }
            onError: err => { lockCtl.busy = false; lockCtl.failed = true; lockCtl.password = "" }
        }
        WlSessionLock {
            id: sessionLock
            WlSessionLockSurface {
                color: "#A3D0E1"
                LockScreen { anchors.fill: parent; svc: Services; lock: lockCtl; Component.onCompleted: forceActiveFocus() }
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

    // From a terminal:  qs -c isla ipc call isla phone search
    IpcHandler {
        target: "isla"
        function phone(screen: string): void { shell.phone(screen) }
        function close(): void { shell.phoneClose() }
        function lid(state: string): void { Services.lid(state === "closed") }
        function wallpaper(path: string): void { Prefs.set("wallpaper", path) }
        function bar(): void { Prefs.flip("bar") }
        function drop(which: string): void { shell.dropRequest(shell.focusedName(), which) }
        function power(): void { shell.powerRequest(shell.focusedName()) }
        function lock(): void { lockCtl.lockNow() }
        function locktest(): void { lockCtl.lockTest() }
        function big(): void { Services.phoneBig = !Services.phoneBig }
        function preview(): void { Services.previewWipe() }
        function gamemode(): void { Services.toggle("game") }      // qs -c isla ipc call isla gamemode
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
                property real dropX: 0

                // ── scene change overlay (lock / unlock / first start / preview) ──
                PanelWindow {
                    visible: lockCtl.deskWipe !== "none"
                    screen: scr.modelData
                    anchors { top: true; bottom: true; left: true; right: true }
                    exclusionMode: ExclusionMode.Ignore
                    color: "transparent"
                    WlrLayershell.layer: WlrLayer.Overlay
                    WlrLayershell.namespace: "isla-wipe"
                    IrisWipe { anchors.fill: parent; mode: lockCtl.deskWipe; t: lockCtl.deskT }
                }

                // ── wallpaper ──
                PanelWindow {
                    screen: scr.modelData
                    anchors { top: true; bottom: true; left: true; right: true }
                    exclusionMode: ExclusionMode.Ignore
                    WlrLayershell.layer: WlrLayer.Background
                    WlrLayershell.namespace: "isla-wallpaper"
                    color: "#D3EAF0"
                    Wallpaper { anchors.fill: parent; path: Services.wallPreview || Prefs.wallpaper }
                }

                // ── top bar ──
                PanelWindow {
                    visible: Prefs.bar
                    screen: scr.modelData
                    anchors { top: scr.barTop; bottom: !scr.barTop; left: true; right: true }
                    implicitHeight: Math.ceil(scr.band * scr.sc)
                    exclusiveZone: Math.ceil((scr.band - 4) * scr.sc)
                    color: "transparent"
                    WlrLayershell.namespace: "isla-bar"
                    Item {
                        width: scr.dw; height: scr.band
                        scale: scr.sc; transformOrigin: Item.TopLeft
                        UiCandy { visible: Prefs.barStyle === "Float"; x: 8; y: scr.barPad - 6; width: parent.width - 16; height: 62; radius: 26; fill: Theme.cream; drop: 0; hi: 3 }
                        Rectangle { visible: Prefs.barStyle === "Straight"; width: parent.width; height: scr.band - 4; y: scr.barTop ? 0 : 4; color: Theme.ink
                            Rectangle { x: 0; y: scr.barTop ? 0 : 3; width: parent.width; height: parent.height - 3; color: Theme.cream } }
                        TopBar {
                            svc: Services; monitor: scr.name
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
                    WlrLayershell.namespace: "isla-dropdown"
                    // leave the bar uncovered so another pill can be clicked straight away
                    margins.top: scr.barTop && Prefs.bar ? Math.ceil(scr.band * scr.sc) : 0
                    margins.bottom: !scr.barTop && Prefs.bar ? Math.ceil(scr.band * scr.sc) : 0
                    Item {
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
                                           : ["wifi", "bt", "sound"].includes(scr.drop) ? cPanel : scr.drop === "sys" ? cSys : scr.drop === "music" ? cMusic : cCalendar
                            opacity: status === Loader.Ready ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 140 } }
                        }
                        Connections { target: Services; function onAppOpened() { scr.drop = "" } }
                        Connections {
                            target: shell
                            function onDropRequest(monitor, which) {
                                if (monitor !== scr.name) { scr.drop = ""; return }
                                scr.dropX = scr.dw / 2; scr.drop = scr.drop === which ? "" : which
                            }
                        }
                        Component { id: cBattery; DropBattery { svc: Services } }
                        Component { id: cCalendar; DropCalendar { svc: Services } }
                        Component { id: cWeather; DropWeather { svc: Services } }
                        Component { id: cNotifs; DropNotifs { svc: Services } }
                        Component { id: cPanel; DropPanel { svc: Services; kind: scr.drop } }
                        Component { id: cSys; DropSys { svc: Services } }
                        Component { id: cMusic; DropMusic { svc: Services } }
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
                    WlrLayershell.namespace: "isla-power"
                    Connections { target: Services; function onAppOpened() { shell.phoneClose() } }
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
                    WlrLayershell.namespace: "isla-dock"
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

                // ── big sticker clock (main monitor) ──
                PanelWindow {
                    visible: scr.isMain
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
                    WlrLayershell.namespace: "isla-clock"
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
                    WlrLayershell.namespace: "isla-notification"
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
                                onClicked: { Services.activateNotification(modelData); Services.dropToast(modelData.key) }
                                onDismissed: Services.dropToast(modelData.key)
                            }
                        }
                    }
                }

                // ── password prompt for system changes (polkit), main monitor top middle, only while asking ──
                LazyLoader {
                    active: scr.isMain && !!Services.authFlow
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
                        WlrLayershell.namespace: "isla-polkit"
                        PolkitDialog { id: authBox; x: 10; flow: Services.authFlow; scale: scr.sc; transformOrigin: Item.TopLeft }
                    }
                }

                // ── keyring password pop-up (main monitor, top middle, only while asking) ──
                LazyLoader {
                    active: scr.isMain && !!Services.keyAsk
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
                        WlrLayershell.namespace: "isla-keyring"
                        KeyringDialog { id: keyBox; x: 10; svc: Services; scale: scr.sc; transformOrigin: Item.TopLeft }
                    }
                }

                // ── Bluetooth pair / connect request (main monitor, top middle): only exists while asking ──
                LazyLoader {
                    active: scr.isMain && !!Services.btAsk
                    PanelWindow {
                        screen: scr.modelData
                        anchors.top: true
                        margins.top: scr.barTop && Prefs.bar ? Math.round((scr.band + 6) * scr.sc) : Math.round(12 * scr.sc)
                        implicitWidth: Math.ceil(390 * scr.sc)
                        implicitHeight: Math.ceil((pairBox.height + 16) * scr.sc)
                        exclusionMode: ExclusionMode.Ignore
                        color: "transparent"
                        WlrLayershell.layer: WlrLayer.Overlay
                        WlrLayershell.namespace: "isla-bluetooth"
                        BtPairDialog { id: pairBox; x: 10; svc: Services; scale: scr.sc; transformOrigin: Item.TopLeft }
                    }
                }

                // ── the phone: built on first open (only on that screen), removed 3 min after it closes ──
                // (≈ 120 MB per screen while it exists; the first open after removal takes ≈ 0.15–0.45 s)
                property bool phoneLive: false
                property string phonePending: ""
                Timer { id: phoneIdle; interval: 180000; onTriggered: scr.phoneLive = false }
                Connections {
                    target: shell
                    function onPhoneRequest(monitor, screen) { if (monitor === scr.name && !scr.phoneLive) { scr.phonePending = screen; scr.phoneLive = true } }
                }
                LazyLoader {
                active: scr.phoneLive
                PanelWindow {
                    id: phoneWin
                    onVisibleChanged: if (visible) phoneIdle.stop(); else phoneIdle.restart()
                    screen: scr.modelData
                    visible: stage.shown || stage.visibleAmount > 0.001
                    anchors { top: true; bottom: true; left: true; right: true }
                    exclusionMode: ExclusionMode.Ignore
                    color: "transparent"
                    WlrLayershell.layer: WlrLayer.Overlay
                    WlrLayershell.keyboardFocus: stage.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
                    WlrLayershell.namespace: "isla-phone"
                    Item {
                        focus: true
                        width: scr.dw; height: scr.modelData.height / scr.sc
                        scale: scr.sc; transformOrigin: Item.TopLeft
                        PhoneStage {
                            id: stage
                            anchors.fill: parent
                            focus: true
                            svc: Services; prefs: Prefs; monitor: scr.name
                            onSoon: w => { soon.text = w + " is coming in the next Isla update ✿"; soon.show = true; soonTimer.restart() }
                            // the request that built the phone: open that screen now
                            Component.onCompleted: if (scr.phonePending) { const p = scr.phonePending; scr.phonePending = ""; go(p) }
                        }
                        Toast {
                            id: soon
                            property string text: ""
                            property bool show: false
                            anchors.horizontalCenter: parent.horizontalCenter; y: show ? 90 : 60
                            opacity: show ? 1 : 0
                            app: "Isla"; body: text; tint: Theme.lilac
                            Behavior on opacity { NumberAnimation { duration: 180 } }
                            Behavior on y { NumberAnimation { duration: 240; easing.type: Easing.OutBack } }
                        }
                        Timer { id: soonTimer; interval: 2600; onTriggered: soon.show = false }
                    }
                    Connections {
                        target: shell
                        function onPhoneRequest(monitor, screen) {
                            if (monitor !== scr.name) { stage.close(); return }
                            if (stage.shown && stage.screen === screen) { stage.close(); return }   // same key again = close
                            stage.go(screen);
                        }
                        function onPhoneClose() { stage.close() }
                    }
                }
                }
            }
        }
    }
}
