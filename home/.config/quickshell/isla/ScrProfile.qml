import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Widgets

// Profile (phone, from the avatar in Quick): card with greeting, avatar, name, @user, uptime / shell / desktop,
// today's screen time. Below: pick an avatar, change the shown name, change the password.
// Name: saved in Isla at once; "Also for login" runs chfn in a terminal. Password: passwd in a terminal
// (you type it there — Isla never sees or stores it).
Item {
    id: pf
    property var svc
    signal go(string screen)
    signal done()
    readonly property real cw: width - 36
    readonly property var p: svc.profile
    readonly property string shownName: Prefs.displayName || p.full || p.user
    property bool editing: false
    readonly property var today: svc.screenTime && svc.screenTime.days ? svc.screenTime.days[6] : null
    onVisibleChanged: if (visible) { svc.loadProfile(); svc.loadScreenTime(); editing = false }
    Component.onCompleted: { svc.loadProfile(); svc.loadScreenTime() }
    function hm(sec) { const h = Math.floor(sec / 3600), m = Math.round(sec % 3600 / 60); return h ? h + "h " + m + "m" : m + "m" }

    Column {
        x: 18; y: 16; width: pf.cw; spacing: 12
        PhoneStatus { svc: pf.svc; timePx: 16 }

        // ── card ──
        UiCandy {
            width: parent.width; height: 300; radius: 28; bw: 3; ink: Theme.inkPhone; drop: 6; hi: 0; fill: Theme.paper
            // header
            Item {
                x: 3; y: 3; width: parent.width - 6; height: 110
                Rectangle { anchors.fill: parent; radius: 25; color: "#F8D3C4" }
                Rectangle { y: parent.height - 25; width: parent.width; height: 25; color: "#F8D3C4" }
                UiDots { anchors.fill: parent; radius: 25; dot: Qt.rgba(1, 1, 1, 0.6); step: 16; r: 2 }
            }
            Rectangle { x: 3; y: 113; width: parent.width - 6; height: 3; color: Theme.inkPhone }
            UiCandy { x: parent.width - width - 16; y: 16; width: gt.implicitWidth + 24; height: 30; rotation: 4; bw: 2.5; ink: Theme.inkPhone; drop: 2; hi: 0; fill: Theme.paper
                UiText { id: gt; anchors.centerIn: parent; text: pf.svc.greeting; px: 12; w: 700 } }
            // avatar
            UiCandy {
                x: 18; y: 50; width: 92; height: 92; radius: 24; bw: 3; ink: Theme.inkPhone; drop: 5; hi: 6; hiColor: Qt.rgba(1, 1, 1, 0.5); fill: Theme.sun
                Glyph { anchors.centerIn: parent; name: Prefs.avatar || "smile"; size: 46; stroke: 2.2; color: Theme.inkPhone }
            }
            Column {
                x: 124; y: 120; width: parent.width - 124 - 16
                UiText { width: parent.width; height: 32; text: pf.shownName; px: 26; w: 700; color: Theme.textDeep }
                UiText { width: parent.width; text: "@" + pf.p.user; fam: "n"; px: 13; w: 800; color: Theme.textSoft }
            }
            // stats
            Row {
                x: 16; y: 182; spacing: 8
                Repeater {
                    model: [["UPTIME", pf.svc.uptimeText(pf.p.uptime), "#D8F1F4"], ["SHELL", pf.p.shell || "—", "#F6C9D6"], ["DESKTOP", pf.svc.desktopName, "#E6DEFB"]]
                    delegate: UiCandy {
                        required property var modelData
                        width: (pf.cw - 32 - 16) / 3; height: 58; radius: 14; bw: 2.5; ink: Theme.inkPhone; drop: 0; hi: 0; fill: modelData[2]
                        UiText { anchors.horizontalCenter: parent.horizontalCenter; y: 9; text: modelData[0]; fam: "n"; px: 9.5; w: 900; track: 1.2; color: Theme.textMuted }
                        UiText { anchors.horizontalCenter: parent.horizontalCenter; y: 26; width: parent.width - 10; horizontalAlignment: Text.AlignHCenter; text: modelData[1]; px: 15; w: 700 }
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
                    Rectangle { x: 2; y: 2; height: 8; radius: 4; width: (parent.width - 4) * Math.min(1, (pf.today ? pf.today.total : 0) / (12 * 3600))
                        gradient: Gradient { orientation: Gradient.Horizontal; GradientStop { position: 0; color: Theme.sunDeep } GradientStop { position: 1; color: Theme.berry } } }
                }
                UiCandy { id: tag; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; width: tt.implicitWidth + 16; height: 24; radius: 8
                    bw: 2; ink: Theme.inkPhone; drop: 0; hi: 0; fill: Theme.sun
                    UiText { id: tt; anchors.centerIn: parent; text: pf.today ? pf.hm(pf.today.total) : "—"; px: 12; w: 700 } }
            }
        }

        // ── avatar picker ──
        UiText { text: "AVATAR"; fam: "n"; px: 11; w: 900; track: 1.4; color: Theme.textSoft; height: 16 }
        Row {
            spacing: 8
            Repeater {
                model: ["smile", "gamepad", "music", "code", "globe", "pulse"]
                delegate: UiCandy {
                    required property string modelData
                    readonly property bool picked: (Prefs.avatar || "smile") === modelData
                    width: (pf.cw - 40) / 6; height: width; radius: 12; bw: 2.5; ink: Theme.inkPhone; drop: picked ? 3 : 0; hi: 0
                    fill: picked ? Theme.sun : Theme.cream; pressable: true
                    onClicked: Prefs.set("avatar", modelData)
                    Glyph { anchors.centerIn: parent; name: modelData; size: 20; stroke: 2.4; color: Theme.inkPhone }
                }
            }
        }

        // ── phone background ──
        UiText { text: "PHONE BACKGROUND"; fam: "n"; px: 11; w: 900; track: 1.4; color: Theme.textSoft; height: 16 }
        FolderListModel { id: pics; folder: "file://" + Quickshell.env("HOME") + "/Pictures/Wallpapers"; showDirs: false
            nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.JPG", "*.PNG"]; sortField: FolderListModel.Time }
        ListView {
            width: parent.width; height: 48; orientation: ListView.Horizontal; spacing: 8; clip: true
            boundsBehavior: Flickable.StopAtBounds
            WheelHandler { onWheel: e => parent.contentX = Math.max(0, Math.min(Math.max(0, parent.contentWidth - parent.width), parent.contentX - e.angleDelta.y / 2)) }
            model: Object.keys(Prefs.phoneBgs).concat(Array.from({ length: pics.count }, (_, i) => pics.get(i, "filePath")))
            delegate: UiCandy {
                id: bgOpt
                required property string modelData
                readonly property bool photo: modelData.startsWith("/")
                readonly property bool picked: Prefs.phoneBg === modelData
                width: 44; height: 44; radius: 12; bw: picked ? 3 : 2.5; ink: picked ? Theme.purple : Theme.inkPhone; drop: picked ? 3 : 0; hi: 0
                fill: photo ? Theme.paper : Prefs.phoneBgs[modelData][0]; pressable: true
                onClicked: Prefs.set("phoneBg", modelData)
                Grid { visible: !photo; anchors.centerIn: parent; columns: 3; spacing: 5
                    Repeater { model: 9; delegate: Rectangle { width: 3.5; height: 3.5; radius: 2; color: bgOpt.photo ? "transparent" : Prefs.phoneBgs[bgOpt.modelData][1] } } }
                ClippingRectangle { visible: photo; anchors.fill: parent; anchors.margins: 3; radius: 9; color: "transparent"
                    Image { anchors.fill: parent; fillMode: Image.PreserveAspectCrop; asynchronous: true; source: photo ? "file://" + modelData : ""; sourceSize: Qt.size(88, 88) } }
            }
        }
        UiText { visible: pics.count === 0; width: parent.width; wrapMode: Text.Wrap; fam: "n"; px: 10.5; w: 800; color: Theme.textSoft
            text: "Put pictures in ~/Pictures/Wallpapers to use them here too" }

        // ── name ──
        UiRow {
            visible: !pf.editing
            width: parent.width; glyph: "pencil"; title: "Change name"; sub: pf.shownName
            onClicked: { pf.editing = true; nameIn.text = pf.shownName; nameIn.forceActiveFocus(); nameIn.selectAll() }
            Glyph { name: "arrowRight"; size: 15; stroke: 2.6 }
        }
        UiCandy {
            visible: pf.editing
            width: parent.width; height: 104; radius: 16; bw: 2.5; ink: Theme.inkPhone; drop: 3; hi: 0; fill: Theme.gSun
            UiCandy {
                x: 10; y: 10; width: parent.width - 20; height: 38; radius: 11; bw: 2; ink: Theme.inkPhone; drop: 0; hi: 0; fill: Theme.paper
                TextInput {
                    id: nameIn
                    x: 12; width: parent.width - 24; anchors.verticalCenter: parent.verticalCenter; clip: true
                    font.family: Theme.display; font.weight: 600; font.pixelSize: 16; color: Theme.text
                    maximumLength: 40
                    onAccepted: saveBtn.clicked()
                    Keys.onEscapePressed: pf.editing = false
                }
            }
            Row {
                x: 10; y: 58; spacing: 8
                UiCandy { id: saveBtn; width: 80; height: 34; radius: 11; bw: 2.5; ink: Theme.inkPhone; drop: 2; hi: 3; fill: Theme.gGo; pressable: true
                    onClicked: { Prefs.set("displayName", nameIn.text.trim()); pf.editing = false }
                    UiText { anchors.centerIn: parent; text: "Save"; px: 13; w: 700; color: "#FFFFFF" } }
                UiCandy { width: 140; height: 34; radius: 11; bw: 2.5; ink: Theme.inkPhone; drop: 2; hi: 0; fill: Theme.paper; pressable: true
                    onClicked: { const n = nameIn.text.trim(); if (n) { Prefs.set("displayName", n); pf.svc.setSystemName(n) } pf.editing = false }
                    UiText { anchors.centerIn: parent; text: "Also for login ↗"; px: 12; w: 700 } }
                UiCandy { width: 34; height: 34; radius: 11; bw: 2; ink: Theme.inkPhone; drop: 0; hi: 0; fill: Theme.paper; pressable: true
                    onClicked: pf.editing = false
                    Glyph { anchors.centerIn: parent; name: "close"; size: 12; stroke: 2.8 } }
            }
        }

        // ── password ──
        UiRow {
            width: parent.width; glyph: "lock"; title: "Change password"; sub: "Opens a terminal — type it there, Isla never sees it"
            onClicked: pf.svc.changePassword()
            Glyph { name: "external"; size: 15; stroke: 2.6 }
        }
    }
}
