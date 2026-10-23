import QtQuick

// Weather card (bar dropdown), SekaiPop-style: only what you need —
// condition, big temperature, high/low, place, humidity · wind · UV, and the next hours as a line.
// The small dark button under the icon refreshes.
DropCard {
    id: d
    property var svc
    readonly property var w: svc.weather
    width: 340; height: 304
    headerH: 128
    Component.onCompleted: if (!w.updated || Date.now() - w.updated.getTime() > 10 * 60 * 1000) svc.refreshWeather()

    UiText { x: 24; y: 18; text: (d.w.desc || "Loading…").toUpperCase(); fam: "n"; px: 11; w: 900; track: 1.4; color: Theme.textDeep; width: 200 }
    // big temperature, °C small and raised, high / low under it
    Row {
        x: 22; y: 30; spacing: 6
        UiStrokeText { text: d.w.ok ? d.w.tempN : "--"; px: 56; weight: 700; strokeW: 7; strokeColor: Theme.ink }
        Column {
            y: 6; spacing: 0
            UiStrokeText { text: "°C"; px: 18; weight: 700; strokeW: 4; strokeColor: Theme.ink }
            UiText { text: "↑ " + (d.w.ok ? d.w.max : "--") + "°"; fam: "n"; px: 12; w: 900; color: Theme.textDeep }
            UiText { text: "↓ " + (d.w.ok ? d.w.min : "--") + "°"; fam: "n"; px: 12; w: 900; color: Theme.textDeep }
        }
    }
    // condition icon, with the refresh button hanging off its bottom edge
    UiCandy {
        x: d.width - 106; y: 16; width: 84; height: 84; radius: 42; bw: 3; drop: 3; hi: 0; fill: Theme.gActive; rotation: Theme.tilt(1)
        Glyph { anchors.centerIn: parent; name: d.w.glyph || "cloud"; size: 38; stroke: 2.4 }
    }
    UiCandy {
        x: d.width - 56; y: 104; width: 34; height: 30; radius: 10; bw: 2.5; drop: 2; hi: 0; fill: Theme.inkPhone; pressable: true; rotation: Theme.tilt(3)
        onClicked: d.svc.refreshWeather()
        Glyph { anchors.centerIn: parent; name: "reload"; size: 15; stroke: 2.6; color: "#FFFFFF" }
    }
    // place: dark pill over the header's bottom edge
    UiCandy {
        x: 14; y: 106; width: Math.min(d.width - 110, place.implicitWidth + 40); height: 30; radius: 11; bw: 2.5; drop: 2; hi: 0; fill: Theme.inkPhone
        Glyph { x: 10; anchors.verticalCenter: parent.verticalCenter; name: "pin"; size: 14; stroke: 2.4; color: "#FFFFFF" }
        UiText { id: place; x: 29; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 37
            text: d.w.area || d.svc.city.replace(/\+/g, " ") || "Your area"; fam: "n"; px: 12; w: 900; color: "#FFFFFF" }
    }

    // humidity · wind · UV
    Row {
        x: 14; y: 146; spacing: 6
        Repeater {
            model: [["HUMIDITY", d.w.humidity + "%", "#D8F1F4", ""], ["WIND · " + (d.w.windDir || "-"), d.w.wind + " km/h", "#E6DEFB", "wind"], ["UV INDEX", d.w.uv, "#FFF1C2", ""]]
            delegate: UiCandy {
                required property var modelData
                required property int index
                width: (d.width - 28 - 12) / 3; height: 48; radius: 12; bw: 2.5; drop: 3; hi: 0; fill: Theme.adapt(modelData[2]); rotation: Theme.tilt(index)
                UiText { x: 10; y: 7; text: modelData[0]; fam: "n"; px: 9; w: 900; track: 1; color: Theme.textMuted }
                UiText { x: 10; y: 21; text: d.w.ok ? modelData[1] : "--"; px: 16; w: 700 }
                // arrow points where the wind blows to (wttr gives where it comes from)
                UiCandy { visible: modelData[3] === "wind" && d.w.ok; anchors.right: parent.right; anchors.rightMargin: 7; anchors.verticalCenter: parent.verticalCenter
                    width: 26; height: 26; radius: 13; bw: 2; drop: 0; hi: 0; fill: Theme.paper
                    Glyph { anchors.centerIn: parent; name: "arrowRight"; size: 13; stroke: 2.6; rotation: (d.w.windDeg || 0) + 180 - 90 } }
            }
        }
    }

    // next hours
    UiCandy {
        x: 14; y: 204; width: d.width - 28; height: 88; radius: 14; bw: 2.5; drop: 3; hi: 0; fill: Theme.cream
        WeatherLine { x: 4; y: 5; width: parent.width - 8; height: parent.height - 9; points: d.w.line || [] }
        UiText { visible: !d.w.ok; anchors.centerIn: parent; text: "No weather data yet…"; fam: "n"; px: 12; w: 800; color: Theme.textSoft }
    }
}
