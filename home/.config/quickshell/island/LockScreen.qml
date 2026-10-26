import QtQuick
import QtQuick.Effects

// Island lock / login screen. Rest: lock wallpaper (or Island's dotted sky) + date + big sticker clock.
// Any key or click → the phone slides up (3/4 of the screen) and only the picture behind it blurs (never the desktop).
// Phone: who logs in, password with candy dots, Unlock / Log in, song playing, Restart / Shut down.
// One of these per screen (the phone only on the main one); they share password, phoneUp and the PAM check
// through `lock` (Island's shell.qml, or island-greeter's shell.qml with greeter: true).
Item {
    id: ls
    property var svc
    property var lock                       // lock controller: password, busy, failed, phoneUp, user, lockedAt, tryUnlock()
    property bool main: true                // phone only on the main screen
    property bool greeter: false            // login screen (island-greeter): "Log in" wording, user pick, no "Locked since"
    property bool reveal: false             // eye button: show the password as text instead of dots
    property string wall: Prefs.lockWallpaper   // lock wallpaper (Island's wallpaper preview passes another in)
    Connections { target: ls.lock; function onPasswordChanged() { if (ls.lock.password === "") ls.reveal = false } }
    readonly property real sc: height / 1080
    readonly property var users: ls.svc.users || [ls.svc.profile]
    readonly property var who: ls.users.find(u => u.user === ls.lock.user) || ls.users[0] || ({ user: "", full: "" })
    focus: true
    Component.onCompleted: svc.loadProfile()

    // 0 = clock, 1 = phone up; the blur, clock and phone all follow it
    property real upT: ls.lock.phoneUp ? 1 : 0
    Behavior on upT { NumberAnimation { duration: 460; easing.type: Easing.OutCubic } }
    // right password: the phone is pulled down off the screen (blur and hidden clock stay), then the scene change runs
    property real dropT: ls.lock.leaving ? 1 : 0
    Behavior on dropT { NumberAnimation { duration: 480; easing.type: Easing.InBack } }
    function raise() { ls.lock.phoneUp = true; idle.restart(); ls.forceActiveFocus() }
    // phone goes back down after 30 s with nothing typed
    Timer { id: idle; interval: 30000; running: ls.main && ls.lock.phoneUp; onTriggered: if (!ls.lock.busy && !ls.pwArmed) { ls.lock.password = ""; ls.lock.phoneUp = false } }

    // ── background: only this picture is blurred, so nothing of the desktop can show ──
    Item {
        id: bg
        anchors.fill: parent
        layer.enabled: ls.upT > 0
        layer.effect: MultiEffect { blurEnabled: true; blur: ls.upT; blurMax: 48; autoPaddingEnabled: false }
        Rectangle { anchors.fill: parent; color: "#A3D0E1" }
        Rectangle { x: parent.width - 660 * ls.sc; y: -360 * ls.sc; width: 1000 * ls.sc; height: 1000 * ls.sc; radius: width / 2; color: "#ADB6EA" }
        Rectangle { x: -260 * ls.sc; y: parent.height - 500 * ls.sc; width: 1160 * ls.sc; height: 1000 * ls.sc; radius: width / 2; color: "#C7E7EF" }
        Rectangle { x: parent.width * 0.5; y: parent.height - 320 * ls.sc; width: 700 * ls.sc; height: 700 * ls.sc; radius: width / 2; color: Theme.adapt("#E5DDF9") }
        UiDots { anchors.fill: parent; dot: Qt.rgba(1, 1, 1, 0.45); step: 32 * ls.sc; r: 2.4 * ls.sc }
        // chosen lock wallpaper (Wallpapers → Lockscreen) covers the sky
        Image { anchors.fill: parent; visible: ls.wall !== "" && status === Image.Ready; fillMode: Image.PreserveAspectCrop; asynchronous: true
            source: ls.wall ? "file://" + ls.wall : ""; sourceSize: Qt.size(ls.width, ls.height) }
    }
    Rectangle { anchors.fill: parent; color: Theme.inkPhone; opacity: 0.18 * ls.upT }

    // click anywhere: phone up
    MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onPressed: ls.raise() }

    Item {
        id: stage
        width: ls.width / ls.sc; height: 1080
        scale: ls.sc; transformOrigin: Item.TopLeft

        // date + big clock (fades up and away while the phone is up)
        Column {
            anchors.horizontalCenter: parent.horizontalCenter; y: 250 - 60 * ls.upT
            opacity: 1 - ls.upT; visible: opacity > 0
            spacing: 4
            UiStrokeText { anchors.horizontalCenter: parent.horizontalCenter; text: Qt.formatDate(ls.svc.now, "dddd, MMMM d"); px: 44; weight: 700; strokeW: 10; strokeColor: Theme.inkPhone; family: Theme.candy }
            Item {
                anchors.horizontalCenter: parent.horizontalCenter; width: bigClock.implicitWidth; height: bigClock.implicitHeight
                UiStrokeText { id: bigClock; text: ls.svc.clockH.replace(/^0/, "") + ":" + ls.svc.clockM; px: 260; weight: 400; strokeW: 24; strokeColor: Theme.inkPhone; family: Theme.candy; fillColor: Theme.adapt("#F2FAFD") }
                UiCandy { visible: !ls.svc.h24; x: parent.width - 6; y: 140; width: 90; height: 62; radius: 14; rotation: 5; bw: 3; ink: Theme.inkPhone; drop: 5; hi: 4; fill: Theme.gActive
                    UiText { anchors.centerIn: parent; text: ls.svc.ampm; px: 30; w: 700; color: "#FFFFFF" } }
            }
        }
        // hint at the bottom
        UiCandy {
            visible: ls.main && opacity > 0; opacity: 1 - ls.upT
            anchors.horizontalCenter: parent.horizontalCenter; y: 960
            width: hintT.implicitWidth + 44; height: 46; bw: 2.5; ink: Theme.inkPhone; drop: 4; hi: 0; fill: "#2C4A54"
            UiText { id: hintT; anchors.centerIn: parent; text: ls.greeter ? "Press any key to log in" : "Press any key to unlock"; px: 16; w: 700; color: "#FFFFFF" }
        }
        // ── the phone ──
        PhoneBody {
            id: phone
            visible: ls.main && ls.upT > 0 && ls.dropT < 1
            canBig: false
            scale: 810 / 844; transformOrigin: Item.TopLeft
            x: (stage.width - width * scale) / 2
            y: 1100 - (1100 - 135) * ls.upT + 1000 * ls.dropT
            readonly property real sw: screen.width          // 360 × 804 screen

            // status: time · battery
            UiText { x: 24; y: 16; text: ls.svc.clockH.replace(/^0/, "") + ":" + ls.svc.clockM + (ls.svc.h24 ? "" : " " + ls.svc.ampm); px: 17; w: 700 }
            Row { anchors.right: parent.right; anchors.rightMargin: 24; y: 18; spacing: 5
                BarBattery { size: 17; level: ls.svc.battery.percent / 100; charging: ls.svc.battery.charging; anchors.verticalCenter: parent.verticalCenter }
                UiText { text: ls.svc.battery.percent + "%"; px: 13; w: 700; anchors.verticalCenter: parent.verticalCenter } }

            // avatar + name
            UiCandy {
                x: (phone.sw - 112) / 2; y: 66; width: 112; height: 112; radius: 56; bw: 3.5; ink: Theme.inkPhone; drop: 5; hi: 4; fill: [Theme.sun, Theme.sunDeep]
                Glyph { anchors.centerIn: parent; visible: ls.who.user === ls.svc.profile.user; name: Prefs.avatar || "smile"; size: 56; stroke: 2.4; color: Theme.inkPhone }
                UiText { anchors.centerIn: parent; visible: ls.who.user !== ls.svc.profile.user; text: (ls.who.full || ls.who.user).charAt(0).toUpperCase(); px: 52; w: 700; color: Theme.inkPhone }
            }
            UiText { width: phone.sw; y: 194; horizontalAlignment: Text.AlignHCenter; text: (ls.who.user === ls.svc.profile.user && Prefs.displayName) || ls.who.full || ls.who.user; px: 28; w: 700; color: Theme.textDeep }
            UiCandy {
                x: (phone.sw - width) / 2; y: 236; width: subT.implicitWidth + 40; height: 34; bw: 2.5; ink: Theme.inkPhone; drop: 0; hi: 0; fill: "#2C4A54"
                Row { anchors.centerIn: parent; spacing: 7
                    Glyph { name: "lock"; size: 13; stroke: 2.6; color: "#FFFFFF"; anchors.verticalCenter: parent.verticalCenter }
                    UiText { id: subT; anchors.verticalCenter: parent.verticalCenter; px: 13; w: 700; color: "#FFFFFF"
                        text: ls.greeter ? "Welcome back" : "Locked since " + Qt.formatTime(ls.lock.lockedAt, ls.svc.h24 ? "HH:mm" : "h:mm AP") } }
            }

            // user pick (only when there is more than one)
            Row {
                visible: ls.greeter && ls.users.length > 1
                anchors.horizontalCenter: parent.horizontalCenter; y: 288; spacing: 8
                Repeater {
                    model: ls.greeter ? ls.users.slice(0, 4) : []
                    delegate: UiCandy {
                        required property var modelData
                        required property int index
                        readonly property bool on: modelData.user === ls.who.user
                        width: Math.min(84, (phone.sw - 48) / Math.min(4, ls.users.length) - 8); height: 36; radius: 18; bw: 2.5; ink: Theme.inkPhone
                        drop: on ? 1 : 3; hi: 2; rotation: Theme.tilt(index); fill: on ? Theme.gActive : Theme.paper; pressable: !ls.lock.busy
                        onClicked: { ls.lock.user = modelData.user; ls.lock.password = ""; ls.lock.failed = false; ls.forceActiveFocus() }
                        UiText { anchors.centerIn: parent; width: parent.width - 14; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; text: modelData.user; px: 13; w: 700 }
                    }
                }
            }

            // password
            Item {
                id: pwBox
                x: 24; y: 340; width: phone.sw - 48; height: 116
                property real shake: 0
                transform: Translate { x: Math.sin(pwBox.shake * Math.PI * 6) * 12 * (1 - pwBox.shake) }
                NumberAnimation { id: shakeAnim; target: pwBox; property: "shake"; from: 0; to: 1; duration: 520 }
                Connections { target: ls.lock; function onFailedChanged() { if (ls.lock.failed) shakeAnim.restart() } }
                // focus glow: breathes while ready for typing
                Rectangle {
                    x: -8; y: -8; width: parent.width + 16; height: parent.height + 16; radius: 32; color: "transparent"
                    border.width: 4; border.color: ls.lock.failed ? Theme.berry : Theme.sunDeep
                    visible: ls.activeFocus && !ls.lock.busy
                    SequentialAnimation on opacity { running: parent.visible; loops: Animation.Infinite
                        NumberAnimation { from: 1; to: 0.45; duration: 900; easing.type: Easing.InOutSine }
                        NumberAnimation { from: 0.45; to: 1; duration: 900; easing.type: Easing.InOutSine } }
                }
                UiCandy {
                    anchors.fill: parent; radius: 26; bw: 3.5; ink: Theme.inkPhone; drop: 6; hi: 0; fill: Theme.cream
                    UiText { anchors.horizontalCenter: parent.horizontalCenter; y: 14; text: ls.lock.failed ? "Wrong password — try again" : ls.lock.busy ? "Checking…" : "Password"
                        px: 20; w: 700; color: ls.lock.failed ? Theme.berry : Theme.textDeep }
                    Rectangle {
                        x: 18; y: 54; width: parent.width - 36; height: 40; radius: 20; color: "#2C4A54"
                        UiText { visible: ls.reveal && ls.lock.password.length > 0; anchors.centerIn: parent; width: parent.width - 80; horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideLeft; text: ls.lock.password; px: 17; w: 700; color: "#FFF3C4" }
                        // eye: show / hide the password
                        Rectangle {
                            visible: ls.lock.password.length > 0
                            anchors.right: parent.right; anchors.rightMargin: 6; anchors.verticalCenter: parent.verticalCenter
                            width: 30; height: 30; radius: 15; color: eyeMa.containsMouse ? "#3D5F6A" : "transparent"
                            Glyph { anchors.centerIn: parent; name: ls.reveal ? "eyeOff" : "eye"; size: 18; stroke: 2.4; color: "#FFF3C4" }
                            MouseArea { id: eyeMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ls.reveal = !ls.reveal }
                        }
                        Row {
                            visible: !ls.reveal
                            anchors.centerIn: parent; anchors.horizontalCenterOffset: ls.lock.password.length ? -8 : 0; spacing: 7
                            Repeater {
                                model: Math.min(ls.lock.password.length, 11)
                                delegate: Rectangle {
                                    required property int index
                                    width: 15; height: 15; radius: 7.5; y: index % 2 ? 2 : -2
                                    color: [Theme.sea, Theme.berry, Theme.sunDeep, Theme.leaf, Theme.lilac, Theme.peach][index % 6]
                                    border.width: 2; border.color: Theme.inkPhone
                                    scale: 0; Component.onCompleted: scale = 1
                                    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
                                }
                            }
                            // blinking cursor after the dots
                            Rectangle {
                                visible: ls.activeFocus && !ls.lock.busy
                                width: 3; height: 20; radius: 1.5; color: "#FFF3C4"; anchors.verticalCenter: parent.verticalCenter
                                SequentialAnimation on opacity { running: parent.visible; loops: Animation.Infinite
                                    NumberAnimation { to: 0; duration: 500; easing.type: Easing.InQuad } NumberAnimation { to: 1; duration: 500; easing.type: Easing.OutQuad } }
                            }
                            UiText { visible: ls.lock.password.length === 0; text: ls.greeter ? "type to log in" : "type to unlock"; fam: "n"; px: 12; w: 800; color: "#88A5AD"; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                }
            }
            // unlock / log in
            UiCandy {
                x: 24; y: 478; width: phone.sw - 48; height: 62; radius: 24; bw: 3.5; ink: Theme.inkPhone; drop: 6; hi: 4; fill: Theme.gActive; pressable: !ls.lock.busy
                onClicked: { ls.lock.tryUnlock(); ls.forceActiveFocus() }
                Row { anchors.centerIn: parent; spacing: 12
                    UiText { text: ls.greeter ? "Log in" : "Unlock"; px: 22; w: 700; color: Theme.textDeep; anchors.verticalCenter: parent.verticalCenter }
                    Rectangle { width: 46; height: 30; radius: 15; color: "#2C4A54"; anchors.verticalCenter: parent.verticalCenter
                        Glyph { anchors.centerIn: parent; name: "arrowRight"; size: 16; stroke: 2.8; color: "#FFFFFF" } } }
                UiTag { x: 14; y: -14; text: "Enter"; fill: Theme.sun; ink: Theme.inkPhone; textColor: Theme.textDeep; px: 11; padX: 9; tilt: -8 }
            }
            // song playing (lock only: the login screen has no player)
            UiCandy {
                visible: !!ls.svc.media
                x: 24; y: 566; width: phone.sw - 48; height: 58; radius: 18; bw: 3; ink: Theme.inkPhone; drop: 4; hi: 0; fill: "#2C4A54"; rotation: -1.5
                Glyph { x: 18; anchors.verticalCenter: parent.verticalCenter; name: "music"; size: 20; stroke: 2.4; color: "#FFFFFF" }
                Column { x: 50; anchors.verticalCenter: parent.verticalCenter
                    UiText { width: phone.sw - 120; text: ls.svc.media ? ls.svc.media.title : ""; px: 14; w: 700; color: "#FFFFFF"; elide: Text.ElideRight }
                    UiText { width: phone.sw - 120; text: ls.svc.media ? ls.svc.media.artist : ""; fam: "n"; px: 11; w: 800; color: "#BFD7DD"; elide: Text.ElideRight } }
            }

            // Restart / Shut down: each counts down 4 s (tap again = now); while one counts, the other is Cancel
            Row {
                x: 24; y: 690; spacing: 12
                Repeater {
                    model: [["reboot", "reload", "Restart", Theme.gLeaf], ["shutdown", "power", "Shut down", Theme.gBerry]]
                    delegate: UiCandy {
                        id: pbtn
                        required property var modelData
                        readonly property bool arm: ls.pwArmed === modelData[0]
                        readonly property bool cancel: ls.pwArmed !== "" && !arm
                        width: (phone.sw - 60) / 2; height: 50; radius: 18; bw: 3; ink: Theme.inkPhone; drop: arm ? 2 : 4; hi: 3
                        fill: arm ? modelData[3] : Theme.paper; pressable: true
                        onClicked: { if (cancel) ls.pwCancel(); else ls.pwPick(modelData[0]); ls.forceActiveFocus() }
                        Row { anchors.centerIn: parent; spacing: 8
                            Glyph { name: pbtn.cancel ? "close" : modelData[1]; size: 18; stroke: 2.6; anchors.verticalCenter: parent.verticalCenter }
                            UiText { anchors.verticalCenter: parent.verticalCenter; px: 15; w: 700
                                text: pbtn.cancel ? "Cancel" : pbtn.arm ? modelData[2] + " " + ls.pwLeft : modelData[2] } }
                    }
                }
            }
            UiText { width: phone.sw; y: 762; horizontalAlignment: Text.AlignHCenter; text: "Esc to hide"; fam: "n"; px: 11; w: 800; color: Theme.textSoft }
        }
    }

    property string pwArmed: ""
    property int pwLeft: 0
    Timer { id: pwTimer; interval: 1000; repeat: true; onTriggered: { ls.pwLeft--; if (ls.pwLeft <= 0) ls.pwGo() } }
    function pwPick(id) { if (pwArmed === id) { pwGo(); return } pwArmed = id; pwLeft = 4; pwTimer.restart() }
    function pwCancel() { pwArmed = ""; pwTimer.stop() }
    function pwGo() { const id = pwArmed; pwCancel(); if (id) svc.power(id) }

    // scene change on top of everything (from the lock controller)
    SceneWipe { anchors.fill: parent; z: 100; mode: ls.lock.lockWipe || "none"; t: ls.lock.lockT || 0 }

    // keyboard: first key brings the phone up (a letter is typed too); then type, Enter unlocks, Backspace deletes,
    // Esc cancels a countdown → clears → hides the phone
    Keys.onPressed: e => {
        e.accepted = true;
        if (ls.lock.busy) return;
        const ch = e.text && e.text.length === 1 && e.text.charCodeAt(0) >= 32 ? e.text : "";
        if (!ls.lock.phoneUp) { if (e.key !== Qt.Key_Escape) { ls.raise(); if (ch && ch !== " ") ls.lock.password += ch } return }
        idle.restart();
        if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) ls.lock.tryUnlock();
        else if (e.key === Qt.Key_Backspace) ls.lock.password = (e.modifiers & Qt.ControlModifier) ? "" : ls.lock.password.slice(0, -1);
        else if (e.key === Qt.Key_Escape) { if (ls.pwArmed) ls.pwCancel(); else if (ls.lock.password) ls.lock.password = ""; else ls.lock.phoneUp = false }
        else if (ch) { ls.lock.password += ch; ls.lock.failed = false }
    }
}
