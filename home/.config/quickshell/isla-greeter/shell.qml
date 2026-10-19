//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Greetd
import Quickshell.Services.Pam

// Isla login screen (runs under greetd as the "greeter" user, inside a small Hyprland: greeter.lua).
// It is Isla's own LockScreen.qml in greeter mode. On the right password greetd starts the Hyprland session.
// Without greetd (test window) it checks your password with PAM instead and just quits.
ShellRoot {
    id: root
    readonly property bool real: Greetd.available
    readonly property var session: ["uwsm", "start", "-e", "-D", "Hyprland", "hyprland.desktop"]

    Scope {
        id: lockCtl
        property string password: ""
        property bool busy: false
        property bool failed: false
        property date lockedAt: new Date()
        property string lockWipe: "full"           // opens from the cream cover, like Isla's own boot
        property real lockT: 0

        function tryUnlock() {
            if (busy || password === "" || !Svc.profile.user) return;
            busy = true; failed = false;
            if (root.real) Greetd.createSession(Svc.profile.user);
            else if (!pam.start()) fail();
        }
        function fail() { busy = false; failed = true; password = "" }
        function reset() { if (Greetd.state !== GreetdState.Inactive) Greetd.cancelSession(); fail() }

        Connections {
            target: Greetd
            function onAuthMessage(message, error, responseRequired, echoResponse) { if (responseRequired) Greetd.respond(lockCtl.password) }
            // greetd already ends the session after a wrong password (an extra cancel confuses Quickshell)
            function onAuthFailure(message) { lockCtl.fail() }
            function onError(error) { console.warn("greetd:", error); lockCtl.reset() }
            function onReadyToLaunch() { closeAnim.restart() }
        }
        PamContext {
            id: pam
            config: "login"
            user: Svc.profile.user
            onResponseRequiredChanged: if (responseRequired) respond(lockCtl.password)
            onCompleted: result => { if (result === PamResult.Success) closeAnim.restart(); else lockCtl.fail() }
            onError: err => lockCtl.fail()
        }

        // first frame: cream + leaf, then the iris opens onto the login screen
        Timer { running: true; interval: 700; onTriggered: { lockCtl.lockT = 0; lockCtl.lockWipe = "revealL"; openAnim.restart() } }
        NumberAnimation { id: openAnim; target: lockCtl; property: "lockT"; from: 0; to: 1; duration: 850; onFinished: lockCtl.lockWipe = "none" }
        // right password: the iris closes to cream + leaf, the desktop's Isla opens from the same cover
        SequentialAnimation {
            id: closeAnim
            ScriptAction { script: { lockCtl.lockT = 0; lockCtl.lockWipe = "coverL" } }
            NumberAnimation { target: lockCtl; property: "lockT"; from: 0; to: 1; duration: 560 }
            ScriptAction { script: lockCtl.lockWipe = "full" }
            PauseAnimation { duration: 250 }
            ScriptAction { script: root.finish() }
        }
    }
    // check.sh only (fake greetd): types a wrong password, then the right one, with no keyboard needed
    readonly property bool autotest: Quickshell.env("ISLA_GREETER_TEST") === "1"
    Timer { running: root.autotest; interval: 2500; onTriggered: { lockCtl.password = "wrong-pass"; lockCtl.tryUnlock() } }
    Connections { target: lockCtl; enabled: root.autotest; function onFailedChanged() { if (lockCtl.failed) retry.start() } }
    Timer { id: retry; interval: 1200; onTriggered: { lockCtl.password = "isla-test"; lockCtl.tryUnlock() } }

    function finish() {
        if (real) Greetd.launch(session, [], false);
        else { sessionLock.locked = false; Qt.quit() }
    }
    // the wrapper (isla-greeter-session) only falls back to the text login if this marker is missing
    Connections {
        target: Greetd
        function onLaunched() {
            Quickshell.execDetached(["touch", Quickshell.env("XDG_RUNTIME_DIR") + "/isla-greeter-ok"]);
            quitSoon.start();
        }
    }
    Timer { id: quitSoon; interval: 150; onTriggered: { sessionLock.locked = false; Qt.quit() } }

    WlSessionLock {
        id: sessionLock
        locked: true
        WlSessionLockSurface {
            color: Prefs.wipeBgs[Prefs.wipeBg] ? Prefs.wipeBgs[Prefs.wipeBg][0] : "#FFF4E0"
            LockScreen { anchors.fill: parent; svc: Svc; lock: lockCtl; greeter: true; Component.onCompleted: forceActiveFocus() }
        }
    }
}
