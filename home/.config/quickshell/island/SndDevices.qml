import QtQuick
import Quickshell.Services.Pipewire

// One device section of SoundPanel (output or input): label, mute, volume, device list.
Column {
    property var panel
    id: dl
    property string label: ""
    property var list: []
    property var current: null
    property bool isOut: true
    spacing: 6
    Item {
        width: parent.width; height: 26
        UiText { anchors.verticalCenter: parent.verticalCenter; text: dl.label; fam: "n"; px: 11; w: 900; track: 1.4; color: Theme.textSoft }
        UiCandy {
            visible: !!dl.current
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            width: 26; height: 26; bw: 2; drop: 0; hi: 0; fill: dl.current && dl.current.audio.muted ? Theme.berry : Theme.paper; pressable: true
            onClicked: dl.current.audio.muted = !dl.current.audio.muted
            Glyph { anchors.centerIn: parent; name: dl.isOut ? (dl.current && dl.current.audio.muted ? "mute" : "volume") : "mic"; size: 13; stroke: 2.6 }
        }
    }
    UiSlider {
        visible: !!dl.current
        width: parent.width; max: 1.0
        value: dl.current ? dl.current.audio.volume : 0
        color: dl.isOut ? Theme.leaf : Theme.berry
        onPicked: v => { dl.current.audio.muted = false; dl.current.audio.volume = v }
    }
    Repeater {
        model: dl.list
        delegate: UiRow {
            required property var modelData
            width: dl.width; height: 44
            glyph: dl.isOut ? ((panel.nameOf(modelData).toLowerCase().match(/head|buds|bass|airpod/)) ? "headphones" : "speakerOn") : "mic"
            title: panel.nameOf(modelData)
            sub: modelData === dl.current ? "In use · " + Math.round((modelData.audio.volume || 0) * 100) + "%" : ""
            active: modelData === dl.current
            onClicked: dl.isOut ? Pipewire.preferredDefaultAudioSink = modelData : Pipewire.preferredDefaultAudioSource = modelData
        }
    }
}

