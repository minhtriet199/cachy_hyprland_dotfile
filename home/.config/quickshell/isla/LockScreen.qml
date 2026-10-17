import QtQuick
import Quickshell.Services.Pam

// Isla lock screen (canvas "Lock"): dotted sky with soft blobs, sticker date + big clock + AM/PM tag,
// name card with the song playing, battery, "Locked since", password box with candy dots, Unlock button.
// One of these per screen; they share the password text and the PAM check through `lock` (shell.qml).
Item {
    id: ls
    property var svc
    property var lock                       // shell's lock controller: password, busy, failed, lockedAt, tryUnlock()
    property bool main: true                // password box only on the main screen
    readonly property real sc: height / 1080
    focus: true
    Component.onCompleted: svc.loadProfile()

    // ── background ──
    Rectangle { anchors.fill: parent; color: "#A3D0E1" }
    Rectangle { x: parent.width - 660 * ls.sc; y: -360 * ls.sc; width: 1000 * ls.sc; height: 1000 * ls.sc; radius: width / 2; color: "#ADB6EA" }
    Rectangle { x: -260 * ls.sc; y: parent.height - 500 * ls.sc; width: 1160 * ls.sc; height: 1000 * ls.sc; radius: width / 2; color: "#C7E7EF" }
    Rectangle { x: parent.width * 0.5; y: parent.height - 320 * ls.sc; width: 700 * ls.sc; height: 700 * ls.sc; radius: width / 2; color: "#E5DDF9" }
    UiDots { anchors.fill: parent; dot: Qt.rgba(1, 1, 1, 0.45); step: 32 * ls.sc; r: 2.4 * ls.sc }
    // chosen lock wallpaper (Wallpapers → Lockscreen) covers the sky
    Image { anchors.fill: parent; visible: Prefs.lockWallpaper !== "" && status === Image.Ready; fillMode: Image.PreserveAspectCrop; asynchronous: true
        source: Prefs.lockWallpaper ? "file://" + Prefs.lockWallpaper : ""; sourceSize: Qt.size(ls.width, ls.height) }

    Item {
        width: ls.width / ls.sc; height: 1080
        scale: ls.sc; transformOrigin: Item.TopLeft

        // date + clock
        UiStrokeText { x: 330; y: 48; text: Qt.formatDate(ls.svc.now, "dddd, MMMM d"); px: 40; weight: 700; strokeW: 9; strokeColor: Theme.inkPhone; family: Theme.candy }
        Row {
            x: 318; y: 118; spacing: 14
            UiStrokeText { text: ls.svc.clockH.replace(/^0/, "") + ":" + ls.svc.clockM; px: 230; weight: 400; strokeW: 22; strokeColor: Theme.inkPhone; family: Theme.candy; fillColor: "#F2FAFD" }
            UiCandy { visible: !ls.svc.h24; y: 120; width: 86; height: 60; radius: 14; rotation: 5; bw: 3; ink: Theme.inkPhone; drop: 5; hi: 4; fill: Theme.gActive
                UiText { anchors.centerIn: parent; text: ls.svc.ampm; px: 30; w: 700; color: "#FFFFFF" } }
        }

        // name + music card
        UiCandy {
            x: 46; y: 112; width: 248; height: ls.svc.media ? 158 : 96; radius: 20; bw: 3; ink: Theme.inkPhone; drop: 6; hi: 0; fill: "#2C4A54"
            UiCandy {
                x: 10; y: 10; width: parent.width - 20; height: 68; radius: 14; bw: 2.5; ink: Theme.inkPhone; drop: 0; hi: 0; fill: Theme.gLilac
                UiDots { anchors.fill: parent; anchors.margins: 3; radius: 11; dot: Qt.rgba(1, 1, 1, 0.55); step: 12; r: 1.6 }
                Column { x: 16; y: 14
                    UiText { text: Prefs.displayName || ls.svc.profile.full || ls.svc.profile.user; px: 21; w: 700; color: Theme.textDeep; height: 24 }
                    UiText { text: "Screen locked"; fam: "n"; px: 11; w: 800; color: Theme.textDeep } }
                Rectangle { x: parent.width - 50; y: 15; width: 38; height: 38; radius: 19; color: Theme.sun; border.width: 2.5; border.color: Theme.inkPhone }
            }
            Row {
                visible: !!ls.svc.media
                x: 22; y: 98; spacing: 12
                Glyph { name: "music"; size: 20; stroke: 2.4; color: "#FFFFFF"; anchors.verticalCenter: parent.verticalCenter }
                Column {
                    UiText { width: 170; text: ls.svc.media ? ls.svc.media.title : ""; px: 15; w: 700; color: "#FFFFFF"; height: 18 }
                    UiText { width: 170; text: ls.svc.media ? ls.svc.media.artist : ""; fam: "n"; px: 11; w: 800; color: "#BFD7DD" }
                }
            }
        }

        // battery
        UiCandy {
            x: parent.width - 158; y: 40; width: 110; height: 48; bw: 3; ink: Theme.inkPhone; drop: 4; hi: 3; fill: Theme.gLeaf
            Row { anchors.centerIn: parent; spacing: 6
                BarBattery { size: 20; level: ls.svc.battery.percent / 100; charging: ls.svc.battery.charging; anchors.verticalCenter: parent.verticalCenter }
                UiText { text: ls.svc.battery.percent + "%"; px: 17; w: 700; anchors.verticalCenter: parent.verticalCenter } }
        }

        // locked since
        UiCandy {
            visible: ls.main
            x: 330; y: 962; width: lst.implicitWidth + 46; height: 44; bw: 2.5; ink: Theme.inkPhone; drop: 0; hi: 0; fill: "#2C4A54"
            Row { anchors.centerIn: parent; spacing: 8
                Glyph { name: "lock"; size: 15; stroke: 2.6; color: "#FFFFFF"; anchors.verticalCenter: parent.verticalCenter }
                UiText { id: lst; text: "Locked since " + Qt.formatTime(ls.lock.lockedAt, ls.svc.h24 ? "HH:mm" : "h:mm AP"); px: 15; w: 700; color: "#FFFFFF"; anchors.verticalCenter: parent.verticalCenter } }
        }

        // password + unlock
        Item {
            id: pwRow
            visible: ls.main
            x: parent.width - 1000; y: 910; width: 810; height: 124
            property real shake: 0
            transform: Translate { x: Math.sin(pwRow.shake * Math.PI * 6) * 14 * (1 - pwRow.shake) }
            NumberAnimation { id: shakeAnim; target: pwRow; property: "shake"; from: 0; to: 1; duration: 520 }
            Connections { target: ls.lock; function onFailedChanged() { if (ls.lock.failed) shakeAnim.restart() } }

            // focus glow: soft yellow ring that breathes while the box is ready for typing
            Rectangle {
                x: -9; y: -9; width: 538; height: 138; radius: 36; color: "transparent"
                border.width: 5; border.color: ls.lock.failed ? Theme.berry : Theme.sunDeep
                visible: ls.activeFocus && !ls.lock.busy
                SequentialAnimation on opacity { running: parent.visible; loops: Animation.Infinite
                    NumberAnimation { from: 1; to: 0.45; duration: 900; easing.type: Easing.InOutSine }
                    NumberAnimation { from: 0.45; to: 1; duration: 900; easing.type: Easing.InOutSine } }
            }
            UiCandy {
                width: 520; height: 120; radius: 28; bw: 3.5; ink: Theme.inkPhone; drop: 6; hi: 0; fill: Theme.cream
                UiText { anchors.horizontalCenter: parent.horizontalCenter; y: 16; text: ls.lock.failed ? "Wrong password — try again" : ls.lock.busy ? "Checking…" : "Password"
                    px: 24; w: 700; color: ls.lock.failed ? Theme.berry : Theme.textDeep }
                Rectangle {
                    x: 24; y: 58; width: parent.width - 48; height: 40; radius: 20; color: "#2C4A54"
                    Row {
                        anchors.centerIn: parent; spacing: 10
                        Repeater {
                            model: Math.min(ls.lock.password.length, 18)
                            delegate: Rectangle {
                                required property int index
                                width: 17; height: 17; radius: 8.5; y: index % 2 ? 2 : -2
                                color: [Theme.sea, Theme.berry, Theme.sunDeep, Theme.leaf, Theme.lilac, Theme.peach][index % 6]
                                border.width: 2; border.color: Theme.inkPhone
                                scale: 0; Component.onCompleted: scale = 1
                                Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
                            }
                        }
                        // blinking cursor after the dots
                        Rectangle {
                            visible: ls.activeFocus && !ls.lock.busy
                            width: 3; height: 22; radius: 1.5; color: "#FFF3C4"; anchors.verticalCenter: parent.verticalCenter
                            SequentialAnimation on opacity { running: parent.visible; loops: Animation.Infinite
                                NumberAnimation { to: 0; duration: 500; easing.type: Easing.InQuad } NumberAnimation { to: 1; duration: 500; easing.type: Easing.OutQuad } }
                        }
                    }
                    UiText { visible: ls.lock.password.length === 0; anchors.centerIn: parent; anchors.horizontalCenterOffset: 16; text: "type to unlock"; fam: "n"; px: 13; w: 800; color: "#88A5AD" }
                }
            }
            UiCandy {
                x: 550; width: 258; height: 120; radius: 28; bw: 3.5; ink: Theme.inkPhone; drop: 6; hi: 4; fill: Theme.gActive; pressable: !ls.lock.busy
                onClicked: ls.lock.tryUnlock()
                UiText { anchors.horizontalCenter: parent.horizontalCenter; y: 16; text: "Unlock"; px: 24; w: 700; color: Theme.textDeep }
                Rectangle { x: 34; y: 58; width: parent.width - 68; height: 40; radius: 20; color: "#2C4A54"
                    Glyph { anchors.centerIn: parent; name: "arrowRight"; size: 18; stroke: 2.8; color: "#FFFFFF" } }
            }
            UiTag { x: 568; y: -14; text: "Enter"; fill: Theme.sun; ink: Theme.inkPhone; textColor: Theme.textDeep; px: 12; padX: 10; tilt: -8 }
        }
    }

    // stripe wipe on top of everything (from shell's lock controller)
    IrisWipe { anchors.fill: parent; z: 100; mode: ls.lock.lockWipe || "none"; t: ls.lock.lockT || 0 }

    // keyboard: type the password, Enter unlocks, Backspace deletes, Esc clears
    Keys.onPressed: e => {
        if (ls.lock.busy) { e.accepted = true; return }
        if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) ls.lock.tryUnlock();
        else if (e.key === Qt.Key_Backspace) ls.lock.password = (e.modifiers & Qt.ControlModifier) ? "" : ls.lock.password.slice(0, -1);
        else if (e.key === Qt.Key_Escape) ls.lock.password = "";
        else if (e.text && e.text.length === 1 && e.text.charCodeAt(0) >= 32) { ls.lock.password += e.text; ls.lock.failed = false }
        e.accepted = true;
    }
}
