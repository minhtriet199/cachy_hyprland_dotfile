import QtQuick

// Weather dropdown (wttr.in): condition, big temp, high/low, city, 6 stat tiles, forecast Hourly · Days.
DropCard {
    id: d
    property var svc
    property bool daysMode: true
    readonly property var w: svc.weather
    readonly property var rows: w.ok ? (daysMode ? w.days : w.hours) : []
    width: 340; height: 400
    headerColor: Theme.gSun[1]; headerH: 132
    Component.onCompleted: if (!w.updated || Date.now() - w.updated.getTime() > 10 * 60 * 1000) svc.refreshWeather()

    UiText { x: 20; y: 16; text: (d.w.desc || "Loading…").toUpperCase(); fam: "n"; px: 11; w: 900; track: 1.4; color: Theme.textMuted; width: 220 }
    UiStrokeText { x: 16; y: 34; text: (d.w.ok ? d.w.tempN : "--") + "°"; px: 50; weight: 700; strokeW: 7; strokeColor: Theme.ink }
    Column {
        x: 108; y: 46; spacing: 2
        UiText { text: "↑ " + (d.w.max || "--") + "°"; fam: "n"; px: 12; w: 900 }
        UiText { text: "↓ " + (d.w.min || "--") + "°"; fam: "n"; px: 12; w: 900 }
    }
    UiText { x: 20; y: 104; text: "⌖ " + d.svc.city.replace(/\+/g, " "); fam: "n"; px: 12; w: 800; width: 220 }
    UiCandy {
        x: d.width - 82; y: 26; width: 62; height: 62; bw: 3; drop: 3; hi: 0; fill: Theme.paper
        Glyph { anchors.centerIn: parent; name: d.w.glyph || "cloud"; size: 28; stroke: 2.4 }
    }

    // stat tiles
    Grid {
        x: 16; y: 148; columns: 3; spacing: 8
        Repeater {
            model: [["HUMIDITY", d.w.humidity + "%", "#D8F1F4"], ["WIND", d.w.wind + " km/h", "#E6DEFB"], ["UV INDEX", d.w.uv, "#FFF1C2"],
                    ["FEELS LIKE", d.w.feels + "°", "#FDDCCB"], ["PRESSURE", d.w.pressure, "#D6EED7"], ["VISIBILITY", d.w.visibility + " km", "#FBD5E0"]]
            delegate: UiCandy {
                required property var modelData
                width: (d.width - 32 - 16) / 3; height: 48; radius: 10; bw: 2; drop: 0; hi: 0; fill: modelData[2]
                UiText { x: 9; y: 7; text: modelData[0]; fam: "n"; px: 9; w: 900; track: 1; color: Theme.textMuted }
                UiText { x: 9; y: 22; text: d.w.ok ? modelData[1] : "--"; px: 15; w: 700 }
            }
        }
    }

    // forecast
    UiText { x: 20; y: 270; text: "FORECAST"; fam: "n"; px: 11; w: 900; track: 1.4; color: Theme.textSoft }
    UiCandy {
        x: d.width - width - 16; y: 260; width: 104; height: 30; radius: 10; bw: 2; drop: 0; hi: 0; fill: Theme.sand
        Row {
            anchors.centerIn: parent; spacing: 2
            Repeater {
                model: ["Hourly", "Days"]
                delegate: UiCandy {
                    required property string modelData
                    readonly property bool sel: (modelData === "Days") === d.daysMode
                    width: 48; height: 22; radius: 8; bw: sel ? 2 : 0; drop: 0; hi: 0
                    fill: sel ? Theme.sun : "transparent"; pressable: true
                    onClicked: d.daysMode = modelData === "Days"
                    UiText { anchors.centerIn: parent; text: modelData; fam: "n"; px: 10; w: 800 }
                }
            }
        }
    }
    Column {
        x: 16; y: 302; spacing: 8
        Repeater {
            model: d.rows
            delegate: Item {
                required property var modelData
                required property int index
                width: d.width - 32; height: 24
                UiCandy { width: 62; height: 22; radius: 7; bw: 2; drop: 0; hi: 0; fill: index === 0 ? Theme.sun : Theme.paper
                    UiText { anchors.centerIn: parent; text: modelData.label; fam: "n"; px: 10; w: 900 } }
                UiText { x: 72; width: 36; height: 22; text: (d.daysMode ? modelData.max : modelData.temp) + "°"; px: 14; w: 700 }
                Item {
                    x: 112; y: 7; width: parent.width - 112 - 48; height: 8
                    Rectangle { anchors.fill: parent; radius: 4; color: Theme.sand }
                    Rectangle { height: 8; radius: 4
                        width: parent.width * Math.max(0.08, Math.min(1, ((d.daysMode ? modelData.max : modelData.temp) - 15) / 25))
                        gradient: Gradient { orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: Theme.sea } GradientStop { position: 1; color: Theme.sunDeep } } }
                }
                UiText { anchors.right: parent.right; width: 44; height: 22; horizontalAlignment: Text.AlignRight
                    text: modelData.rain + "%"; fam: "n"; px: 12; w: 900; color: Theme.seaDeep }
            }
        }
    }
    UiText { visible: !d.w.ok; x: 20; y: 310; text: "No weather data yet…"; fam: "n"; px: 12; w: 800; color: Theme.textSoft }
}
