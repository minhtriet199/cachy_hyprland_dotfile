import QtQuick
import Quickshell
import Quickshell.Io

// System dropdown (bar CPU/RAM/GPU pill): power use, live graphs for CPU, RAM and both GPUs, temperatures, VRAM, the 4 apps using the most
// right now, fans, btop button.
DropCard {
    id: d
    property var svc
    readonly property var m: svc.sysmon
    width: 360; height: 84 + 14 + 20 + 12 + 4 * 92 + 12 + 18 + 4 * 30 + 40 + 16 + 36 + 16
    // power: on battery the battery's drain (= the whole laptop); plugged in only the chips report it (CPU + 680M share one sensor)
    readonly property bool batPower: m.onBattery && m.batW > 0
    readonly property string powerWatts: Math.round(batPower ? m.batW : m.apuW + m.gpuW) + " W"
    readonly property string powerParts: (batPower ? "from battery · " : "") + "CPU+" + d.svc.igpuName + " " + Math.round(m.apuW) + " W · "
        + d.svc.gpuName + " " + (m.gpuAsleep ? "asleep" : Math.round(m.gpuW) + " W")

    // top apps: every process's CPU ticks + memory from /proc (one cat, only while this dropdown is open, every 2 s),
    // grouped by program name; CPU = share of the whole machine since the last look, RAM = resident memory
    property var topApps: []
    property var _prev: ({})
    property real _prevAt: 0
    Process { id: topP; command: ["sh", "-c", "cat /proc/[0-9]*/stat 2>/dev/null"]
        stdout: StdioCollector { onStreamFinished: d.readTop(this.text) } }
    Timer { interval: 2000; running: true; repeat: true; triggeredOnStart: true; onTriggered: if (!topP.running) topP.running = true }
    function readTop(text) {
        const now = Date.now(), dt = (now - _prevAt) / 1000, prev = _prev, cur = {}, apps = {};
        for (const line of text.split("\n")) {
            const m = /^(\d+) \((.*)\) (.*)$/.exec(line); if (!m) continue;
            const f = m[3].split(" "), ticks = +f[11] + +f[12], rss = +f[21] * 4096;
            if (!rss) continue;                                              // kernel threads
            cur[m[1]] = ticks;
            const nm = d.alias[m[2]] || m[2], a = apps[nm] || (apps[nm] = { name: nm, cpu: 0, ram: 0 });
            a.ram += rss; if (_prevAt && prev[m[1]] !== undefined) a.cpu += (ticks - prev[m[1]]) / 100 / dt / 16 * 100;
        }
        _prev = cur; _prevAt = now;
        const total = d.m.ramTotal * 1073741824 || 1;
        topApps = Object.values(apps).sort((a, b) => (b.cpu + b.ram / total * 100) - (a.cpu + a.ram / total * 100)).slice(0, 4);
    }
    // program name → app (helpers grouped under the app they belong to)
    readonly property var alias: ({ steamwebhelper: "steam", "steam-runtime": "steam", "Web Content": "firefox", qs: "Island" })
    function appOf(n) { const k = alias[n] || n; if (k === "Island") return { name: "Island", icon: "" }
        const e = DesktopEntries.byId(k) || DesktopEntries.heuristicLookup(k); return e ? { name: e.name, icon: e.icon } : { name: n, icon: "" } }
    headerH: 84

    UiCandy { x: 22; y: 20; width: 44; height: 44; bw: 2.5; drop: 3; hi: 0; fill: Theme.paper
        Glyph { anchors.centerIn: parent; name: "pulse"; size: 23; stroke: 2.4 } }
    Column { x: 78; y: 21
        UiText { text: "System"; px: 22; w: 700; height: 26 }
        UiText { text: "CPU " + d.m.cpuTemp + "°C · GPU " + d.m.gpuTemp + "°C"; fam: "n"; px: 11; w: 800; color: Theme.textMuted }
    }

    Column {
        x: 16; y: 84 + 14; width: d.width - 32; spacing: 12
        // power, same look as the rows below (no graph): on battery the battery's drain (= the whole laptop),
        // plugged in only the chips report it (CPU + 680M share one sensor)
        Item {
            visible: d.m.ok; width: parent.width; height: 20
            UiText { id: pwl; text: "POWER"; fam: "n"; px: 11; w: 900; track: 1.4; color: Theme.textSoft; height: 20 }
            UiText { id: pwv; x: Math.max(42, pwl.implicitWidth + 10); text: d.powerWatts; px: 16; w: 700; height: 20 }
            UiText { anchors.right: parent.right; width: parent.width - pwv.x - pwv.implicitWidth - 10; horizontalAlignment: Text.AlignRight; elide: Text.ElideLeft
                text: d.powerParts; fam: "n"; px: 11; w: 800; color: Theme.textMuted; height: 20 }
        }
        Repeater {
            model: [
                ["CPU", d.m.cpu + "%", d.m.cpuTemp + "°C · 16 threads", d.svc.cpuHist, Theme.sea],
                ["RAM", d.m.ramUsed.toFixed(1) + " GB", d.m.ram + "% of " + d.m.ramTotal.toFixed(1) + " GB", d.svc.ramHist, Theme.purple],
                ["GPU · " + d.svc.igpuName, d.m.igpu + "%", d.m.igpuTemp + "°C · VRAM " + d.m.igpuVram.toFixed(1) + " / " + d.m.igpuVramTotal.toFixed(1) + " + " + d.m.igpuShared.toFixed(1) + " GB shared", d.svc.igpuHist, Theme.leaf],
                ["GPU · " + d.svc.gpuName, d.m.gpuAsleep ? "asleep" : d.m.gpu + "%", d.m.gpuAsleep ? "sleeping (saves battery)" : d.m.gpuTemp + "°C · VRAM " + d.m.vramUsed.toFixed(1) + " / " + d.m.vramTotal.toFixed(0) + " GB · " + Math.round(d.m.gpuW) + " W", d.svc.gpuHist, Theme.berry]
            ]
            delegate: Column {
                id: sec
                required property var modelData
                width: parent.width; spacing: 4
                Item {
                    width: parent.width; height: 20
                    UiText { id: lab; text: modelData[0]; fam: "n"; px: 11; w: 900; track: 1.4; color: Theme.textSoft; height: 20 }
                    UiText { x: Math.max(42, lab.implicitWidth + 10); text: modelData[1]; px: 16; w: 700; height: 20 }
                    UiText { anchors.right: parent.right; text: modelData[2]; fam: "n"; px: 11; w: 800; color: Theme.textMuted; height: 20 }
                }
                // graph: last 40 samples (2 s each), newest on the right
                UiCandy {
                    width: parent.width; height: 56; radius: 12; bw: 2.5; drop: 3; hi: 0; fill: Theme.cream
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
        Column {
            width: parent.width; spacing: 4
            UiText { text: "TOP APPS"; fam: "n"; px: 11; w: 900; track: 1.4; color: Theme.textSoft; height: 18 }
            Repeater {
                model: d.topApps
                delegate: UiCandy {
                    id: ta
                    required property var modelData
                    required property int index
                    readonly property var app: d.appOf(modelData.name)
                    width: parent.width; height: 26; radius: 9; bw: 2; drop: 0; hi: 0; fill: Theme.cream
                    Image { x: 7; anchors.verticalCenter: parent.verticalCenter; width: 16; height: 16; sourceSize: Qt.size(32, 32); asynchronous: true
                        source: Quickshell.iconPath(ta.app.icon || ta.modelData.name, "application-x-executable") }
                    UiText { x: 30; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 30 - stats.width - 14; elide: Text.ElideRight; text: ta.app.name; px: 12.5; w: 700 }
                    UiText { id: stats; anchors.right: parent.right; anchors.rightMargin: 9; anchors.verticalCenter: parent.verticalCenter; fam: "n"; px: 11; w: 900; color: Theme.textMuted
                        text: "CPU " + Math.round(ta.modelData.cpu) + "%  ·  " + (ta.modelData.ram >= 1073741824 ? (ta.modelData.ram / 1073741824).toFixed(1) + " GB" : Math.round(ta.modelData.ram / 1048576) + " MB") }
                }
            }
        }
        Item {
            width: parent.width; height: 28
            UiText { anchors.verticalCenter: parent.verticalCenter; text: "Fans  ·  CPU " + d.m.fanCpu + " rpm  ·  GPU " + d.m.fanGpu + " rpm"; fam: "n"; px: 11; w: 800; color: Theme.textMuted }
        }
        UiCandy {
            width: parent.width; height: 36; radius: 12; bw: 2.5; drop: 3; hi: 0; fill: Theme.inkPhone; pressable: true; rotation: Theme.tilt(2)
            onClicked: d.svc.openApp(["kitty", "btop"])
            UiText { anchors.centerIn: parent; text: "Open btop (task manager)"; px: 13; w: 700; color: "#FFFFFF" }
        }
    }
}
