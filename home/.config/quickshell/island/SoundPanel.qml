import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Widgets

// Sound: output device + volume, input device + volume, and a mixer with one slider per app playing sound.
// mode: "all" · "out" (output + apps) · "in" (input only)
Item {
    id: snd
    property var svc
    property string mode: "all"
    property bool wide: false                 // phone landscape: two columns
    readonly property var nodes: Pipewire.nodes.values.filter(n => n.audio && n.ready !== false)
    readonly property var outs: nodes.filter(n => !n.isStream && n.isSink)
    readonly property var ins: nodes.filter(n => !n.isStream && !n.isSink && (n.properties["media.class"] || "").startsWith("Audio/Source"))
    readonly property var apps: nodes.filter(n => n.isStream && (n.properties["media.class"] || "") === "Stream/Output/Audio")
    implicitHeight: wide ? Math.max(left.implicitHeight, right.implicitHeight) : left.implicitHeight + (right.visible ? right.implicitHeight + 14 : 0)

    // volumes/mutes of nodes are only live while tracked
    PwObjectTracker { objects: Pipewire.nodes.values }

    function nameOf(n) {
        const id = n.name || "";
        if (id.startsWith("alsa_output") && id.includes("hdmi")) return "Monitor speakers (HDMI)";
        if (id.startsWith("alsa_output") && id.includes("analog")) return "Laptop speakers";
        if (id.startsWith("alsa_input") && id.includes("analog")) return "Laptop microphone";
        return n.description || n.nickname || id || "Device";
    }
    function appName(n) { return n.properties["application.name"] || n.properties["media.name"] || nameOf(n) }

    Column {
        id: left
        width: snd.wide ? (snd.width - 20) / 2 : snd.width; spacing: 14
        SndDevices { panel: snd; visible: snd.mode !== "in"; width: parent.width; label: "OUTPUT"; list: snd.outs; current: Pipewire.defaultAudioSink; isOut: true }
        SndDevices { panel: snd; visible: snd.mode !== "out" && !snd.wide; width: parent.width; label: "INPUT"; list: snd.ins; current: Pipewire.defaultAudioSource; isOut: false }
    }
    Column {
        id: right
        x: snd.wide ? left.width + 20 : 0; y: snd.wide ? 0 : left.implicitHeight + 14
        width: snd.wide ? (snd.width - 20) / 2 : snd.width; spacing: 14
        visible: snd.mode !== "in"
        SndDevices { panel: snd; visible: snd.wide; width: parent.width; label: "INPUT"; list: snd.ins; current: Pipewire.defaultAudioSource; isOut: false }
        Column {
            width: parent.width; spacing: 8
            UiText { text: "APPS"; fam: "n"; px: 11; w: 900; track: 1.4; color: Theme.textSoft; height: 20 }
            UiText { visible: snd.apps.length === 0; text: "No app is playing sound"; fam: "n"; px: 12; w: 800; color: Theme.textSoft; height: 22 }
            Repeater {
                model: snd.apps
                delegate: Item {
                    id: ap
                    required property var modelData
                    width: parent.width; height: 42
                    IconImage { x: 0; y: 2; implicitSize: 22; asynchronous: true
                        source: Quickshell.iconPath(ap.modelData.properties["application.icon-name"] || (ap.modelData.properties["application.process.binary"] || "").toLowerCase(), "audio-x-generic") }
                    readonly property bool off: !!ap.modelData.audio.muted
                    UiText { x: 30; y: 0; width: parent.width - 30; height: 20; text: snd.appName(ap.modelData); px: 13; w: 700 }
                    // mute just this app
                    UiCandy { id: muteB; anchors.right: parent.right; y: 24 + 6 - 11; width: 22; height: 22; radius: 11; bw: 2; drop: 0; hi: 0
                        fill: ap.off ? Theme.pinkSoft : Theme.paper; pressable: true
                        onClicked: ap.modelData.audio.muted = !ap.off
                        Glyph { anchors.centerIn: parent; name: ap.off ? "mute" : "volume"; size: 12; stroke: 2.4 }
                        // hover: the app's volume as a sticker tooltip
                        UiTag { visible: muteB.hovered; z: 5; anchors.right: parent.right; y: -height - 6; tilt: -4; px: 11
                            text: ap.off ? "muted" : Math.round((ap.modelData.audio.volume || 0) * 100) + "%"
                            fill: ap.off ? Theme.pinkSoft : Theme.paper; ink: Theme.ink; textColor: Theme.textDeep } }
                    UiSlider { x: 30; y: 24; width: parent.width - 30 - muteB.width - 10; height: 12; max: 1.0; color: ap.off ? Theme.sand : Theme.sea
                        tip: ap.off ? "muted" : Math.round(shown * 100) + "%"
                        value: ap.modelData.audio.volume || 0
                        onPicked: v => { ap.modelData.audio.muted = false; ap.modelData.audio.volume = v } }
                }
            }
        }
    }
}
