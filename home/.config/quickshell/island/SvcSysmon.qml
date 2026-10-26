import QtQuick
import Quickshell
import Quickshell.Io

// Part of Services: PC monitor for the bar + System dropdown — CPU / RAM / both GPUs / power every 2 s (6 s while a game is focused),
// graphs keep the last 40 samples. Use it through Services.sysmon / cpuHist / ramHist / gpuHist / igpuHist / gpuName / igpuName.
Scope {
    id: m
    property bool gaming: false
    property var sysmon: ({ cpu: 0, cpuTemp: 0, ram: 0, ramUsed: 0, ramTotal: 0, gpu: 0, gpuTemp: 0, vramUsed: 0, vramTotal: 0, fanCpu: 0, fanGpu: 0,
                         gpuW: 0, gpuAsleep: false, apuW: 0, batW: 0, onBattery: false, igpu: 0, igpuTemp: 0, igpuVram: 0, igpuVramTotal: 0, igpuShared: 0, ok: false })
    property var cpuHist: []
    property var ramHist: []
    property var gpuHist: []
    property var igpuHist: []
    property var _cpuPrev: null
    function _push(h, v) { const a = h.concat([v]); return a.length > 40 ? a.slice(a.length - 40) : a }
    // one bash, files read with bash's own `read` (no cat/grep/tr/cut processes)
    Process { id: sysmonP; command: ["bash", "-c", [
            "read -r l < /proc/stat; echo \"$l\"",
            "mt=; ma=; while read -r k v _; do case $k in MemTotal:) mt=$v;; MemAvailable:) ma=$v; break;; esac; done < /proc/meminfo; echo $mt; echo $ma",
            // biggest VRAM = the gaming GPU (RX 6700S), smallest = the built-in one (680M)
            "best=; max=0; ig=; min=0; for c in /sys/class/drm/card[0-9]; do t=0; read -r t 2>/dev/null < $c/device/mem_info_vram_total; [ \"$t\" -gt \"$max\" ] && { max=$t; best=$c; }; [ \"$t\" -gt 0 ] && { [ $min = 0 ] || [ \"$t\" -lt $min ]; } && { min=$t; ig=$c; }; done",
            "g=; vu=; gt=; read -r g 2>/dev/null < $best/device/gpu_busy_percent; read -r vu 2>/dev/null < $best/device/mem_info_vram_used; for h in $best/device/hwmon/hwmon*/temp1_input; do read -r gt 2>/dev/null < $h; break; done; echo \"gpu=$g vu=$vu vt=$max gt=$gt\"",
            // power: the gaming GPU's own sensor only while it's awake (never wake it), the APU sensor (CPU + 680M), the battery
            "rs=; read -r rs 2>/dev/null < $best/device/power/runtime_status; gw=; [ \"$rs\" = active ] && for h in $best/device/hwmon/hwmon*; do read -r gw 2>/dev/null < $h/power1_average; break; done; echo \"gw=$gw gz=$([ \"$rs\" = suspended ] && echo 1 || echo 0)\"",
            "[ -n \"$ig\" ] && [ \"$ig\" != \"$best\" ] && { ib=; iv=; ig2=; it=; iw=; read -r ib 2>/dev/null < $ig/device/gpu_busy_percent; read -r iv 2>/dev/null < $ig/device/mem_info_vram_used; read -r ig2 2>/dev/null < $ig/device/mem_info_gtt_used; for h in $ig/device/hwmon/hwmon*; do read -r it 2>/dev/null < $h/temp1_input; read -r iw 2>/dev/null < $h/power1_input || read -r iw 2>/dev/null < $h/power1_average; break; done; echo \"ib=$ib iv=$iv ivt=$min igtt=$ig2 it=$it iw=$iw\"; }",
            "bs=; bp=; for b in /sys/class/power_supply/BAT*; do read -r bs 2>/dev/null < $b/status; read -r bp 2>/dev/null < $b/power_now; break; done; echo \"bw=$bp bd=$([ \"$bs\" = Discharging ] && echo 1 || echo 0)\"",
            "for h in /sys/class/hwmon/hwmon*; do n=; read -r n 2>/dev/null < $h/name; [ \"$n\" = k10temp ] && { read -r x 2>/dev/null < $h/temp1_input; echo ct=$x; }; [ \"$n\" = asus ] && { fc=; fg=; read -r fc 2>/dev/null < $h/fan1_input; read -r fg 2>/dev/null < $h/fan2_input; echo \"fc=$fc fg=$fg\"; }; done"
        ].join("; ")]
        stdout: StdioCollector { onStreamFinished: {
            const L = this.text.split("\n"), v = {};
            const c = L[0].split(/\s+/).slice(1).map(Number), idle = c[3] + c[4], total = c.reduce((a, b) => a + b, 0);
            let cpu = 0; if (m._cpuPrev) { const dt = total - m._cpuPrev.t, di = idle - m._cpuPrev.i; cpu = dt > 0 ? Math.round((1 - di / dt) * 100) : 0 }
            m._cpuPrev = { t: total, i: idle };
            const memT = parseInt(L[1]) || 1, memA = parseInt(L[2]) || 0;
            for (const l of L.slice(3)) for (const kv of l.split(" ")) { const i = kv.indexOf("="); if (i > 0) v[kv.slice(0, i)] = parseFloat(kv.slice(i + 1)) || 0 }
            const ram = Math.round((1 - memA / memT) * 100);
            m.sysmon = { ok: true, cpu: cpu, cpuTemp: Math.round((v.ct || 0) / 1000), ram: ram, ramUsed: (memT - memA) / 1048576, ramTotal: memT / 1048576,
                         gpu: Math.round(v.gpu || 0), gpuTemp: Math.round((v.gt || 0) / 1000), vramUsed: (v.vu || 0) / 1073741824, vramTotal: (v.vt || 0) / 1073741824,
                         fanCpu: v.fc || 0, fanGpu: v.fg || 0,
                         gpuW: (v.gw || 0) / 1e6, gpuAsleep: v.gz === 1, apuW: (v.iw || 0) / 1e6, batW: (v.bw || 0) / 1e6, onBattery: v.bd === 1,
                         igpu: Math.round(v.ib || 0), igpuTemp: Math.round((v.it || 0) / 1000), igpuVram: (v.iv || 0) / 1073741824,
                         igpuVramTotal: (v.ivt || 0) / 1073741824, igpuShared: (v.igtt || 0) / 1073741824 };
            m.cpuHist = m._push(m.cpuHist, cpu); m.ramHist = m._push(m.ramHist, ram); m.gpuHist = m._push(m.gpuHist, Math.round(v.gpu || 0)); m.igpuHist = m._push(m.igpuHist, Math.round(v.ib || 0));
        } } }
    Timer { interval: m.gaming ? 6000 : 2000; running: true; repeat: true; triggeredOnStart: true; onTriggered: if (!sysmonP.running) sysmonP.running = true }   // bar CPU/RAM/GPU, slower in games
    // the gaming GPU's real name (e.g. "RX 6700S"), read once from Vulkan
    property string gpuName: "GPU"
    property string igpuName: "680M"
    Process { running: true; command: ["sh", "-c", "vulkaninfo --summary 2>/dev/null | grep -A1 DISCRETE_GPU | sed -n 's/.*deviceName *= *//p' | head -1"]
        stdout: StdioCollector { onStreamFinished: { const n = this.text.trim().replace(/\s*\(.*\)$/, "").replace(/^(AMD|NVIDIA)\s+(Radeon\s+|GeForce\s+)?/, ""); if (n) m.gpuName = n } } }
    Process { running: true; command: ["sh", "-c", "vulkaninfo --summary 2>/dev/null | grep -A1 INTEGRATED_GPU | sed -n 's/.*deviceName *= *//p' | head -1"]
        stdout: StdioCollector { onStreamFinished: { const n = this.text.trim().replace(/\s*\(.*\)$/, "").replace(/^(AMD|Intel)\s+(Radeon\s+)?/, ""); if (n) m.igpuName = n } } }
}
