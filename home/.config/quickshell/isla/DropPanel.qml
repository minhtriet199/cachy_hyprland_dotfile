import QtQuick
import Quickshell.Services.Pipewire
import Quickshell.Bluetooth

// Bar dropdown for the status pill icons: kind = "wifi" · "bt" · "sound".
DropCard {
    id: d
    property var svc
    property string kind: "wifi"
    readonly property var info: kind === "wifi" ? ["wifi", "Wi-Fi", svc.wifi.on ? (svc.wifi.ssid || "Not connected") : "Off", Theme.gSea[1]]
                              : kind === "bt" ? ["bluetooth", "Bluetooth", btText, Theme.gChip[1]]
                              : ["volume", "Sound", Pipewire.defaultAudioSink ? (Pipewire.defaultAudioSink.description || "Output") : "", Theme.gLeaf[1]]
    readonly property string btText: {
        const a = Bluetooth.defaultAdapter; if (!a || !a.enabled) return "Off";
        const c = a.devices.values.filter(x => x.connected).map(x => x.name);
        return c.length ? c.join(", ") : "No device connected";
    }
    width: 360; height: headerH + 14 + loader.height + 16
    headerColor: info[3]; headerH: 72

    UiCandy { x: 16; y: 14; width: 44; height: 44; bw: 2.5; drop: 3; hi: 0; fill: Theme.paper
        Glyph { anchors.centerIn: parent; name: d.info[0]; size: 21; stroke: 2.4 } }
    Column { x: 72; y: 16; width: d.width - 72 - 16
        UiText { text: d.info[1]; px: 21; w: 700; height: 24 }
        UiText { width: parent.width; text: d.info[2]; fam: "n"; px: 11; w: 800; color: Theme.textMuted } }

    Loader {
        id: loader
        x: 16; y: d.headerH + 14; width: d.width - 32
        height: item ? item.implicitHeight : 0
        sourceComponent: d.kind === "wifi" ? cWifi : d.kind === "bt" ? cBt : cSound
    }
    Component { id: cWifi; WifiPanel { svc: d.svc; listH: 300 } }
    Component { id: cBt; BtPanel { svc: d.svc; listH: 300 } }
    Component { id: cSound; SoundPanel { svc: d.svc } }
}
