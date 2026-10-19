import QtQuick
import QtQuick.Effects

// Profile card (phone Profile page + desktop widget): greeting, avatar, name, @user, uptime / shell / desktop, today's screen time.
UiCandy {
    id: pc
    property var svc
    readonly property var p: svc.profile
    readonly property string shownName: Prefs.displayName || p.full || p.user
    readonly property var today: svc.screenTime && svc.screenTime.days ? svc.screenTime.days[6] : null
    function hm(sec) { const h = Math.floor(sec / 3600), m = Math.round(sec % 3600 / 60); return h ? h + "h " + m + "m" : m + "m" }
    // on the desktop it stays up: refresh uptime every minute, screen time every 5 min (only while visible)
    Timer { interval: 60000; running: pc.visible; repeat: true; onTriggered: { pc.svc.loadProfile(); if (++pc._n % 5 === 0) pc.svc.loadScreenTime() } }
    property int _n: 0
    Component.onCompleted: { svc.loadProfile(); svc.loadScreenTime() }
    height: 300; radius: 28; bw: 3; ink: Theme.inkPhone; drop: 6; hi: 0; fill: Theme.paper
    // header: your wallpaper in an inset box (SekaiPop style; a dotted accent box when there's no wallpaper)
    Item {
        x: 10; y: 10; width: parent.width - 20; height: 110
        Rectangle { visible: !wall.visible; anchors.fill: parent; radius: 20; color: Theme.gActive[0]
            UiDots { anchors.fill: parent; radius: 20; dot: Qt.rgba(1, 1, 1, 0.5); step: 9; r: 1.4 } }
        Rectangle { id: bannerShape; anchors.fill: parent; radius: 20; visible: false; layer.enabled: true }   // rounded mask
        Image { id: wallImg; anchors.fill: parent; visible: false; fillMode: Image.PreserveAspectCrop; asynchronous: true
            source: Prefs.wallpaper ? "file://" + Prefs.wallpaper : ""; sourceSize: Qt.size(width * 2, height * 2) }
        MultiEffect { id: wall; anchors.fill: parent; source: wallImg; maskEnabled: true; maskSource: bannerShape; visible: wallImg.status === Image.Ready }
        Rectangle { anchors.fill: parent; radius: 20; color: "transparent"; border.width: 2.5; border.color: Theme.inkPhone }
    }
    UiCandy { x: parent.width - width - 22; y: 20; width: gt.implicitWidth + 24; height: 30; rotation: -2; bw: 2.5; ink: Theme.inkPhone; drop: 2; hi: 0; fill: Theme.paper
        UiText { id: gt; anchors.centerIn: parent; text: pc.svc.greeting; px: 12; w: 700 } }
    // avatar
    UiCandy {
        x: 18; y: 50; width: 92; height: 92; radius: 24; bw: 3; ink: Theme.inkPhone; drop: 5; hi: 6; hiColor: Qt.rgba(1, 1, 1, 0.5); fill: Theme.sun
        Glyph { anchors.centerIn: parent; name: Prefs.avatar || "smile"; size: 46; stroke: 2.2; color: Theme.inkPhone }
    }
    Column {
        x: 124; y: 120; width: parent.width - 124 - 16
        UiText { width: parent.width; height: 32; text: pc.shownName; px: 26; w: 700; color: Theme.textDeep }
        UiText { width: parent.width; text: "@" + pc.p.user; fam: "n"; px: 13; w: 800; color: Theme.textSoft }
    }
    // stats
    Row {
        x: 16; y: 182; spacing: 8
        Repeater {
            model: [["UPTIME", pc.svc.uptimeText(pc.p.uptime), Theme.inkPhone], ["SHELL", pc.p.shell || "—", Theme.gActive], ["DESKTOP", pc.svc.desktopName, Theme.inkPhone]]
            delegate: UiCandy {
                required property var modelData
                id: st
                required property int index
                readonly property bool dark: index !== 1
                width: (pc.width - 32 - 16) / 3; height: 58; radius: 14; bw: 3; ink: Theme.inkPhone; drop: 3; hi: 0; fill: modelData[2]; rotation: Theme.tilt(index + 1)
                UiText { anchors.horizontalCenter: parent.horizontalCenter; y: 9; text: modelData[0]; fam: "n"; px: 9.5; w: 900; track: 1.2; color: st.dark ? Qt.rgba(1, 1, 1, 0.7) : Theme.textDeep }
                UiText { anchors.horizontalCenter: parent.horizontalCenter; y: 26; width: parent.width - 10; horizontalAlignment: Text.AlignHCenter; text: modelData[1]; px: 15; w: 700; color: st.dark ? "#FFFFFF" : Theme.textDeep }
            }
        }
    }
    // today
    Item {
        x: 16; y: 254; width: parent.width - 32; height: 26
        UiText { anchors.verticalCenter: parent.verticalCenter; text: "TODAY"; fam: "n"; px: 11; w: 900; track: 1.4; color: Theme.textSoft }
        Item {
            x: 58; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 58 - tag.width - 10; height: 12
            Rectangle { anchors.fill: parent; radius: 6; color: Theme.sand; border.width: 2; border.color: Theme.inkPhone }
            Rectangle { x: 2; y: 2; height: 8; radius: 4; width: (parent.width - 4) * Math.min(1, (pc.today ? pc.today.total : 0) / (12 * 3600))
                gradient: Gradient { orientation: Gradient.Horizontal; GradientStop { position: 0; color: Theme.sunDeep } GradientStop { position: 1; color: Theme.berry } }
                // diamond marker at the end of the bar
                Rectangle { x: parent.width - 7; y: -3; width: 14; height: 14; rotation: 45; color: Theme.berry; border.width: 2; border.color: Theme.inkPhone } }
        }
        UiCandy { id: tag; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; width: tt.implicitWidth + 16; height: 24; radius: 8
            bw: 2; ink: Theme.inkPhone; drop: 0; hi: 0; fill: Theme.sun
            UiText { id: tt; anchors.centerIn: parent; text: pc.today ? pc.hm(pc.today.total) : "—"; px: 12; w: 700 } }
    }
}
