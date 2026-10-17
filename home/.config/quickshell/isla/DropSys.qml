import QtQuick

// System dropdown (bar CPU/RAM/GPU pill): live graphs for CPU, RAM and GPU, temperatures, VRAM, fans, btop button.
DropCard {
    id: d
    property var svc
    readonly property var m: svc.sysmon
    width: 360; height: 84 + 14 + 3 * 92 + 40 + 16 + 36 + 16
    headerColor: Theme.gChip[1]; headerH: 84

    UiCandy { x: 16; y: 18; width: 48; height: 48; bw: 2.5; drop: 3; hi: 0; fill: Theme.paper
        Glyph { anchors.centerIn: parent; name: "pulse"; size: 23; stroke: 2.4 } }
    Column { x: 78; y: 22
        UiText { text: "System"; px: 22; w: 700; height: 26 }
        UiText { text: "CPU " + d.m.cpuTemp + "°C · GPU " + d.m.gpuTemp + "°C"; fam: "n"; px: 11; w: 800; color: Theme.textMuted } }

    Column {
        x: 16; y: 84 + 14; width: d.width - 32; spacing: 12
        Repeater {
            model: [
                ["CPU", d.m.cpu + "%", d.m.cpuTemp + "°C · 16 threads", d.svc.cpuHist, Theme.sea],
                ["RAM", d.m.ram + "%", d.m.ramUsed.toFixed(1) + " / " + d.m.ramTotal.toFixed(1) + " GB", d.svc.ramHist, Theme.purple],
                ["GPU", d.m.gpu + "%", d.m.gpuTemp + "°C · VRAM " + d.m.vramUsed.toFixed(1) + " / " + d.m.vramTotal.toFixed(0) + " GB", d.svc.gpuHist, Theme.berry]
            ]
            delegate: Column {
                id: sec
                required property var modelData
                width: parent.width; spacing: 4
                Item {
                    width: parent.width; height: 20
                    UiText { text: modelData[0]; fam: "n"; px: 11; w: 900; track: 1.4; color: Theme.textSoft; height: 20 }
                    UiText { x: 42; text: modelData[1]; px: 16; w: 700; height: 20 }
                    UiText { anchors.right: parent.right; text: modelData[2]; fam: "n"; px: 11; w: 800; color: Theme.textMuted; height: 20 }
                }
                // graph: last 40 samples (2 s each), newest on the right
                UiCandy {
                    width: parent.width; height: 56; radius: 10; bw: 2; drop: 0; hi: 0; fill: Theme.cream
                    Row {
                        x: 6; y: 5; height: parent.height - 10; spacing: 2
                        layoutDirection: Qt.RightToLeft; width: parent.width - 12
                        Repeater {
                            model: modelData[3].slice().reverse()
                            delegate: Item {
                                required property var modelData
                                width: (parent.width - 39 * 2) / 40; height: parent.height
                                Rectangle { anchors.bottom: parent.bottom; width: parent.width; radius: 2
                                    height: Math.max(2, parent.height * Math.min(1, modelData / 100)); color: sec.modelData[4] }
                            }
                        }
                    }
                }
            }
        }
        Item {
            width: parent.width; height: 28
            UiText { anchors.verticalCenter: parent.verticalCenter; text: "Fans  ·  CPU " + d.m.fanCpu + " rpm  ·  GPU " + d.m.fanGpu + " rpm"; fam: "n"; px: 11; w: 800; color: Theme.textMuted }
        }
        UiCandy {
            width: parent.width; height: 36; radius: 12; bw: 2.5; drop: 3; hi: 0; fill: Theme.paper; pressable: true
            onClicked: d.svc.openApp(["kitty", "btop"])
            UiText { anchors.centerIn: parent; text: "Open btop (task manager)"; px: 13; w: 700 }
        }
    }
}
