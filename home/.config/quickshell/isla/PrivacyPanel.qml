import QtQuick
import Quickshell
import Quickshell.Io

// Privacy & location page: what is using the mic / camera / screen right now (checked every 3 s, only
// while this page is open — tools/inuse.py), and Location: weather for where you are or a city you type,
// plus auto time zone. Location here = this connection's rough place (IP), no GPS.
Item {
    id: pv
    property var svc
    implicitHeight: col.implicitHeight
    property var use: ({ mic: [], camera: [], screen: [] })
    Process { id: useP; command: ["python3", Quickshell.shellDir + "/tools/inuse.py"]
        stdout: StdioCollector { onStreamFinished: { try { pv.use = JSON.parse(this.text) } catch (e) {} } } }
    Timer { interval: 3000; repeat: true; triggeredOnStart: true; running: pv.visible; onTriggered: if (!useP.running) useP.running = true }

    component Label: UiText { fam: "n"; px: 11; w: 900; track: 1.4; color: Theme.textSoft; height: 18 }
    component InUse: UiCandy {
        id: iu
        property string glyph
        property string title
        property var apps: []
        width: parent.width; height: 50; radius: 15; bw: 2.5; drop: apps.length ? 3 : 0; hi: 0
        fill: apps.length ? [Theme.peach, Theme.pinkSoft] : Theme.cream
        UiCandy { x: 9; y: 9; width: 32; height: 32; bw: 2; drop: 0; hi: 0; fill: iu.apps.length ? Theme.ink : Theme.paper
            Glyph { anchors.centerIn: parent; name: iu.glyph; size: 16; stroke: 2.4; color: iu.apps.length ? "#FFF3C4" : Theme.text } }
        Column { x: 50; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 64
            UiText { width: parent.width; text: iu.title; px: 14; w: 700; height: 17 }
            UiText { width: parent.width; elide: Text.ElideRight; fam: "n"; px: 10.5; w: 800; height: 14
                color: iu.apps.length ? Theme.berry : Theme.textSoft
                text: iu.apps.length ? "In use by " + iu.apps.join(", ") : "Not in use" } }
    }

    Column {
        id: col
        width: pv.width; spacing: 10

        Label { text: "IN USE RIGHT NOW" }
        InUse { glyph: "mic"; title: "Microphone"; apps: pv.use.mic }
        InUse { glyph: "record"; title: "Camera"; apps: pv.use.camera }
        InUse { glyph: "display"; title: "Screen sharing / recording"; apps: pv.use.screen }

        Item { width: 1; height: 4 }
        Label { text: "LOCATION" }
        UiRow {
            width: parent.width; glyph: "map"; title: "Location"
            sub: Prefs.location ? "Weather and time zone may use your rough place" : "Off · nothing uses your place"
            active: Prefs.location; onClicked: Prefs.set("location", !Prefs.location)
            UiSwitch { on: Prefs.location; onToggled: Prefs.set("location", !Prefs.location) }
        }
        UiText { width: parent.width; wrapMode: Text.Wrap; fam: "n"; px: 10.5; w: 800; color: Theme.textSoft
            text: "Your laptop has no GPS: the place comes from your internet connection (city level). Nothing else on the system asks for it." }
        UiRow {
            visible: Prefs.location
            width: parent.width; glyph: "sun"; title: "Weather for where I am"
            sub: Prefs.weatherAuto ? "Follows your connection" : "Uses the city below"
            active: Prefs.weatherAuto; onClicked: Prefs.set("weatherAuto", !Prefs.weatherAuto)
            UiSwitch { on: Prefs.weatherAuto; onToggled: Prefs.set("weatherAuto", !Prefs.weatherAuto) }
        }
        Column {
            visible: !Prefs.location || !Prefs.weatherAuto
            width: parent.width; spacing: 6
            UiText { text: "Weather city"; px: 13; w: 700; height: 18 }
            UiCandy {
                width: parent.width; height: 36; radius: 12; bw: 2.5; drop: 0; hi: 0; fill: Theme.paper
                Glyph { x: 10; anchors.verticalCenter: parent.verticalCenter; name: "search"; size: 15; stroke: 2.6 }
                TextInput {
                    id: cityIn; x: 32; width: parent.width - 42; anchors.verticalCenter: parent.verticalCenter; clip: true
                    font.family: Theme.body; font.weight: 800; font.pixelSize: 13; color: Theme.text
                    text: Prefs.city
                    onEditingFinished: if (text.trim() && text.trim() !== Prefs.city) Prefs.set("city", text.trim())
                    UiText { visible: !cityIn.text; text: "e.g. Da Nang"; fam: "n"; px: 13; w: 800; color: Theme.textSoft; anchors.verticalCenter: parent.verticalCenter }
                }
            }
            UiText { text: "Press Enter to save · now: " + (pv.svc.weather.ok ? pv.svc.weather.temp + " · " + (pv.svc.weather.desc || "") : "loading…")
                fam: "n"; px: 10.5; w: 800; color: Theme.textSoft }
        }
        UiRow {
            width: parent.width; glyph: "globe"; title: "Set time zone automatically"
            sub: !Prefs.location ? "Needs Location" : Prefs.autoTz ? "On" : "Off"
            active: Prefs.autoTz && Prefs.location
            onClicked: { Prefs.set("autoTz", !Prefs.autoTz); if (Prefs.autoTz) pv.svc.checkTimeZone() }
            UiSwitch { on: Prefs.autoTz && Prefs.location; onToggled: { Prefs.set("autoTz", !Prefs.autoTz); if (Prefs.autoTz) pv.svc.checkTimeZone() } }
        }
    }
}
