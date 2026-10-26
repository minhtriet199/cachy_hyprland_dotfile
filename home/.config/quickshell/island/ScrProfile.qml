import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Widgets

// Profile (phone, from the avatar in Quick): card with greeting, avatar, name, @user, uptime / shell / desktop,
// today's screen time. Below: pick an avatar, change the shown name, change the password.
// Name: saved in Island at once; "Also for login" runs chfn in a terminal. Password: passwd in a terminal
// (you type it there — Island never sees or stores it).
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

        ProfileCard { width: parent.width; svc: pf.svc }

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
                selected: picked
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
            width: parent.width; glyph: "lock"; title: "Change password"; sub: "Opens a terminal — type it there, Island never sees it"
            onClicked: pf.svc.changePassword()
            Glyph { name: "external"; size: 15; stroke: 2.6 }
        }
    }
}
