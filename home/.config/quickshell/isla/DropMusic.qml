import QtQuick
import Quickshell.Widgets

// Music dropdown (click the music pill's title): big cover, song / artist / album, which app plays it,
// seek bar with times, shuffle · ⏮ · ⏯ · ⏭ · repeat. Colours come from the cover.
DropCard {
    id: d
    property var svc
    readonly property var m: svc.media
    readonly property color accent: svc.artAccent
    width: 360; height: 84 + 150 + 58
    headerColor: Qt.tint(Theme.cream, Qt.rgba(svc.artPalette[0].r, svc.artPalette[0].g, svc.artPalette[0].b, 0.45)); headerH: 84

    // big cover, half over the header
    UiCandy {
        x: 18; y: 18; width: 132; height: 132; radius: 22; bw: 3; drop: 5; hi: 0; fill: Theme.lilacSoft; rotation: -3
        ClippingRectangle {
            anchors.fill: parent; anchors.margins: 3; radius: 19; color: Theme.lilacSoft
            Glyph { anchors.centerIn: parent; visible: big.status !== Image.Ready; name: "music"; size: 48; stroke: 2.2; color: "#FFFFFF" }
            Image { id: big; anchors.fill: parent; fillMode: Image.PreserveAspectCrop; visible: status === Image.Ready
                source: d.m ? d.m.art : ""; sourceSize: Qt.size(264, 264) }
        }
    }
    UiTag { visible: !!d.m && d.m.app !== ""; x: d.width - width - 24; y: 20; text: d.m ? d.m.app : ""; fill: d.accent; ink: Theme.ink; px: 15; padX: 13; tilt: 4 }
    Column {
        x: 166; y: 92; width: d.width - 166 - 16; spacing: 2
        UiMarquee { width: parent.width; height: 22; text: d.m ? d.m.title : ""; px: 18; w: 700 }
        UiMarquee { width: parent.width; height: 16; text: d.m ? d.m.artist : ""; fam: "n"; px: 12; w: 800; color: Theme.textMuted }
        UiMarquee { visible: !!d.m && d.m.album !== ""; width: parent.width; height: 15; text: d.m ? d.m.album : ""; fam: "n"; px: 11; w: 700; color: Theme.textSoft }
    }

    // seek
    Column {
        x: 18; y: 84 + 80; width: d.width - 36; spacing: 4
        UiSlider {
            width: parent.width; height: 12; max: 1; color: d.accent
            value: d.m ? d.m.progress : 0
            enabled: !!d.m && d.m.canSeek
            onPicked: v => d.svc.mediaSeek(v)
        }
        Item {
            width: parent.width; height: 14
            UiText { text: d.svc.mmss(d.m ? d.m.position : 0); fam: "n"; px: 10.5; w: 900; color: Theme.textSoft; height: 14 }
            UiText { anchors.right: parent.right; text: d.svc.mmss(d.m ? d.m.length : 0); fam: "n"; px: 10.5; w: 900; color: Theme.textSoft; height: 14 }
        }
    }

    // controls
    Row {
        anchors.horizontalCenter: parent.horizontalCenter; y: 84 + 80 + 44; spacing: 12
        UiCandy { width: 34; height: 34; bw: 2; drop: 2; hi: 0; anchors.verticalCenter: parent.verticalCenter
            fill: d.m && d.m.shuffle ? Theme.gOn : Theme.paper; opacity: d.m && d.m.shuffleOk ? 1 : 0.35; pressable: !!d.m && d.m.shuffleOk
            onClicked: d.svc.mediaShuffle()
            UiText { anchors.centerIn: parent; text: "⇄"; px: 16; w: 700 } }
        UiCandy { width: 40; height: 40; bw: 2.5; drop: 3; hi: 0; fill: Theme.paper; pressable: true; anchors.verticalCenter: parent.verticalCenter
            onClicked: d.svc.mediaPrev()
            Glyph { anchors.centerIn: parent; name: "prev"; size: 15; stroke: 2.6 } }
        UiCandy { width: 54; height: 54; bw: 3; drop: 4; hi: 4; fill: Theme.gGo; pressable: true; anchors.verticalCenter: parent.verticalCenter
            onClicked: d.svc.mediaToggle()
            Glyph { anchors.centerIn: parent; name: d.m && d.m.playing ? "pause" : "play"; size: 20; stroke: 3.2; color: "#FFFFFF" } }
        UiCandy { width: 40; height: 40; bw: 2.5; drop: 3; hi: 0; fill: Theme.paper; pressable: true; anchors.verticalCenter: parent.verticalCenter
            onClicked: d.svc.mediaNext()
            Glyph { anchors.centerIn: parent; name: "next"; size: 15; stroke: 2.6 } }
        UiCandy { width: 34; height: 34; bw: 2; drop: 2; hi: 0; anchors.verticalCenter: parent.verticalCenter
            fill: d.m && d.m.loop > 0 ? Theme.gOn : Theme.paper; opacity: d.m && d.m.loopOk ? 1 : 0.35; pressable: !!d.m && d.m.loopOk
            onClicked: d.svc.mediaLoop()
            UiText { anchors.centerIn: parent; text: d.m && d.m.loop === 1 ? "↻¹" : "↻"; px: 16; w: 700 } }
    }
}
