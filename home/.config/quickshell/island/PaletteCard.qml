import QtQuick

// Palette card (Settings → Quick → Look), SekaiPop-style: 5 colours from the wallpaper / the song's cover / random.
// Tap a colour to pick it · Shuffle · copy its hex · Apply = Island's Custom theme on that colour · Undo = theme from before.
DropCard {
    id: d
    property var svc
    readonly property var pl: svc.palette
    width: 340; height: 262
    headerH: 60

    // title + "Applied"
    Row {
        x: 18; y: 16; spacing: 8
        UiCandy { width: 30; height: 30; radius: 10; bw: 2; drop: 0; hi: 0; fill: Theme.paper
            Glyph { anchors.centerIn: parent; name: "dropper"; size: 15; stroke: 2.4 } }
        UiStrokeText { y: -2; text: "Palette"; px: 24; weight: 700; strokeW: 5; strokeColor: Theme.ink }
    }
    UiCandy {
        visible: d.pl.applied
        x: d.width - width - 16; y: 17; width: apT.implicitWidth + 34; height: 26; radius: 9; bw: 2; drop: 0; hi: 0; fill: Theme.paper
        Glyph { x: 8; anchors.verticalCenter: parent.verticalCenter; name: "check"; size: 12; stroke: 2.8 }
        UiText { id: apT; x: 24; anchors.verticalCenter: parent.verticalCenter; text: "Applied"; fam: "n"; px: 11; w: 900 }
    }

    // source: Wallpaper · Music · Random
    UiCandy {
        x: 16; y: 74; width: d.width - 32; height: 32; radius: 11; bw: 2; drop: 0; hi: 0; fill: Theme.sand
        Row {
            anchors.centerIn: parent; spacing: 3
            Repeater {
                model: [["wallpaper", "Wallpaper"], ["music", "Music"], ["random", "Random"]]
                delegate: UiCandy {
                    required property var modelData
                    readonly property bool on: d.pl.source === modelData[0]
                    width: (d.width - 32 - 12) / 3; height: 24; radius: 8; bw: on ? 2 : 0; drop: 0; hi: 0
                    fill: on ? Theme.lilacSoft : "transparent"; pressable: true
                    onClicked: d.pl.load(modelData[0])
                    UiText { anchors.centerIn: parent; text: modelData[1]; fam: "n"; px: 11; w: 900 }
                }
            }
        }
    }

    // the 5 colours
    Row {
        x: 16; y: 118; spacing: 6
        Repeater {
            model: d.pl.colors
            delegate: UiCandy {
                required property string modelData
                required property int index
                readonly property bool picked: d.pl.sel === index
                width: (d.width - 32 - 24) / 5; height: 74; radius: 12; bw: picked ? 3 : 2.5; drop: picked ? 5 : 3; hi: 0; rotation: Theme.tilt(index)
                fill: modelData; pressable: true
                y: picked ? -3 : 0
                onClicked: d.pl.sel = index
                UiCandy { anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 6
                    width: parent.width - 10; height: 18; radius: 6; bw: 0; drop: 0; hi: 0; fill: Qt.rgba(1, 1, 1, 0.82)
                    UiText { anchors.centerIn: parent; text: modelData.slice(1).toUpperCase(); fam: "n"; px: 9; w: 900; color: Theme.textDeep } }
            }
        }
    }
    UiText { visible: !d.pl.colors.length; x: 20; y: 146; width: d.width - 40
        text: d.pl.loading ? "Reading colours…" : d.pl.source === "music" ? "No song cover to read" : "No picture to read"; fam: "n"; px: 12; w: 800; color: Theme.textSoft }

    // Shuffle · copy · Apply · Undo
    Row {
        x: 16; y: 206; spacing: 8
        UiCandy {
            width: 92; height: 40; radius: 12; bw: 2.5; drop: 3; hi: 0; fill: Theme.paper; pressable: true; rotation: Theme.tilt(0)
            onClicked: d.pl.shuffle()
            Glyph { x: 12; anchors.verticalCenter: parent.verticalCenter; name: "reload"; size: 15; stroke: 2.5 }
            UiText { x: 34; anchors.verticalCenter: parent.verticalCenter; text: "Shuffle"; fam: "n"; px: 12; w: 900 }
        }
        UiCandy {
            width: 40; height: 40; radius: 12; bw: 2.5; drop: 3; hi: 0; fill: Theme.paper; pressable: d.pl.colors.length > 0
            onClicked: d.svc.copy(d.pl.colors[d.pl.sel])
            Glyph { anchors.centerIn: parent; name: "clipboard"; size: 16; stroke: 2.4 }
        }
        UiCandy {
            width: d.width - 32 - 92 - 40 - 84 - 24; height: 40; radius: 12; bw: 2.5; drop: d.pl.applied ? 0 : 3; hi: 0
            fill: d.pl.applied ? Theme.sand : Theme.inkPhone; pressable: !d.pl.applied && d.pl.colors.length > 0; rotation: Theme.tilt(3)
            onClicked: d.pl.apply()
            UiText { anchors.centerIn: parent; text: d.pl.applied ? "Applied" : "Apply"; fam: "n"; px: 13; w: 900; color: d.pl.applied ? Theme.text : "#FFFFFF" }
        }
        UiCandy {
            width: 84; height: 40; radius: 12; bw: 2.5; drop: d.pl.undo ? 3 : 0; hi: 0; fill: d.pl.undo ? Theme.paper : Theme.sand; pressable: !!d.pl.undo
            opacity: d.pl.undo ? 1 : 0.55
            onClicked: d.pl.revert()
            Glyph { x: 11; anchors.verticalCenter: parent.verticalCenter; name: "back"; size: 14; stroke: 2.6 }
            UiText { x: 32; anchors.verticalCenter: parent.verticalCenter; text: "Undo"; fam: "n"; px: 12; w: 900 }
        }
    }
}
