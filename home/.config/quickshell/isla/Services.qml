pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Bluetooth
import Quickshell.Services.Notifications
import Quickshell.Services.SystemTray
import Quickshell.Services.Polkit

// ─────────────────────────────────────────────────────────────
//  Isla system data + actions (CachyOS · Hyprland).
//  Change things in the "YOUR SETTINGS" block. The rest is plumbing.
// ─────────────────────────────────────────────────────────────
Singleton {
    id: s

    // ═════════════ YOUR SETTINGS ═════════════
    // weather place (wttr.in): "" = where this connection is (Settings → Privacy & location)
    readonly property string city: Prefs.location && Prefs.weatherAuto ? "" : encodeURIComponent(Prefs.city.trim()).replace(/%20/g, "+")
    onCityChanged: refreshWeather()
    readonly property bool h24: Prefs.h24                // 24-hour clock (Settings → Time & language)
    property string mainMonitor: "HDMI-A-1"             // gets the big clock + notification bubbles
    property real dockSize: 0.75                        // dock size (1 = original, 0.75 = smaller)
    // Optional nicer names + workspace numbering per monitor (base 10 = workspaces 11–19 shown as 1–9)
    property var monitorNames: ({ "HDMI-A-1": { label: "ASUS · left", base: 0 }, "eDP-1": { label: "Laptop · right", base: 10 }, "eDP-2": { label: "Laptop · right", base: 10 } })
    // Dock apps (cmd runs the program; cls = its window class, for the running dot)
    property var dockApps: [
        { label: "Terminal", glyph: "terminal", tint: "#7CC47F", cmd: ["kitty"], cls: "kitty" },
        { label: "Files",    glyph: "folder",   tint: "#FFD45C", cmd: ["dolphin"], cls: "org.kde.dolphin" },
        { label: "Helium",   glyph: "globe",    tint: "#55BFC6", cmd: ["helium-browser"], cls: "helium" },
        { label: "VS Code",  glyph: "code",     tint: "#A893EC", cmd: ["code"], cls: "com.microsoft.VSCode" },
        { label: "Rider",    glyph: "wrench",   tint: "#EE7D9C", cmd: ["rider"], cls: "jetbrains-rider" },
        { label: "Steam",    glyph: "gamepad",  tint: "#2F9EAB", cmd: ["steam"], cls: "steam" }
    ]
    // Phone home screen (4 × 4). internal = opens a phone screen instead of a program.
    property var homeApps: [
        { label: "Terminal", glyph: "terminal", tint: "#7CC47F", cmd: ["kitty"] },
        { label: "Dolphin", glyph: "folder", tint: "#FFC23C", cmd: ["dolphin"] },
        { label: "Helium", glyph: "globe", tint: "#55BFC6", cmd: ["helium-browser"] },
        { label: "VS Code", glyph: "code", tint: "#8E7BE6", cmd: ["code"] },
        { label: "Rider", glyph: "wrench", tint: "#EE7D9C", cmd: ["rider"] },
        { label: "Steam", glyph: "gamepad", tint: "#2F7FA0", cmd: ["steam"] },
        { label: "Discord", glyph: "chat", tint: "#7C83F0", cmd: ["discord"] },
        { label: "Docker", glyph: "box", tint: "#3FA9DD", cmd: ["kitty", "--hold", "-d", Quickshell.env("HOME") + "/docker/postgres", "docker", "compose", "up", "-d"] },
        { label: "pgAdmin", glyph: "database", tint: "#3E9A5D", cmd: ["helium-browser", "http://localhost:5050"] },
        { label: "OBS Studio", glyph: "record", tint: "#E2607F", cmd: ["obs"] },
        { label: "btop", glyph: "pulse", tint: "#F08A5D", cmd: ["kitty", "btop"] },
        { label: "Calculator", glyph: "calc", tint: "#55BFC6", internal: "calc" },
        { label: "WARP", glyph: "shield", tint: "#F7A04B", toggle: "warp" },
        { label: "Music", glyph: "music", tint: "#C58AF0", cmd: ["vlc"] },
        { label: "Islands", glyph: "map", tint: "#F7A982", internal: "islands" },
        { label: "Settings", glyph: "gear", tint: "#5E7A84", internal: "settings" }
    ]
    // Searchable actions
    property var actions: [
        { title: "Screenshot region", sub: "Saved and copied", glyph: "scissors", tint: "#F7A982", keywords: "snip capture print screenshot", tool: "snip" },
        { title: "Color picker", sub: "Copy a colour from the screen", glyph: "dropper", tint: "#A893EC", keywords: "pick hex colour color", tool: "picker" },
        { title: "Toggle WARP VPN", sub: "warp-cli connect", glyph: "shield", tint: "#55BFC6", keywords: "vpn cloudflare warp steam", toggle: "warp" },
        { title: "Start postgres", sub: "docker compose up -d", glyph: "database", tint: "#3E9A5D", keywords: "docker pg db postgres", cmd: ["sh", "-c", "cd ~/docker/postgres && docker compose up -d"] },
        { title: "System monitor", sub: "btop", glyph: "pulse", tint: "#2F9EAB", keywords: "btop task cpu ram", cmd: ["kitty", "btop"] },
        { title: "Lock screen", sub: "loginctl lock-session", glyph: "lock", tint: "#5E7A84", keywords: "lock", cmd: ["loginctl", "lock-session"] },
        { title: "Suspend", sub: "Sleep the island", glyph: "moon", tint: "#A893EC", keywords: "sleep suspend", cmd: ["systemctl", "suspend"] },
        { title: "Reboot", sub: "Restart the computer", glyph: "reload", tint: "#EE7D9C", keywords: "restart reboot", cmd: ["systemctl", "reboot"] },
        { title: "Shut down", sub: "Turn the island off", glyph: "power", tint: "#E2607F", keywords: "poweroff shutdown off", cmd: ["systemctl", "poweroff"] }
    ]
    // Commands for bar tools and quick buttons
    property var tools: ({
        snip:       ["sh", "-c", "exec ~/.config/hypr/scripts/snip.sh"],
        picker:     ["sh", "-c", "hyprpicker -a"],
        clipboard:  ["sh", "-c", "cliphist list | fuzzel --dmenu | cliphist decode | wl-copy"],
        record:     ["python3", Quickshell.env("HOME") + "/.config/quickshell/isla/tools/obsctl.py", "toggle"]   // OBS: pick screen/window, start · stop
    })
    // Night light (hyprsunset) colour temperature
    property int nightTemp: 4500
    // Window class → icon + colour (Islands, dots)
    property var classLook: ({
        "kitty": ["terminal", "#7CC47F"], "org.kde.dolphin": ["folder", "#FFC23C"], "helium": ["globe", "#55BFC6"], "code": ["code", "#A893EC"],
        "jetbrains-rider": ["wrench", "#EE7D9C"], "steam": ["gamepad", "#2F9EAB"], "discord": ["chat", "#7C83F0"], "com.obsproject.Studio": ["record", "#E86A8A"],
        "firefox": ["globe", "#F7A04B"], "vlc": ["music", "#F7A04B"]
    })
    // ═════════════════════════════════════════

    // ── helpers ──
    function run(cmd) { if (cmd && cmd.length) Quickshell.execDetached(cmd) }
    // start apps through uwsm when it exists (CachyOS + UWSM), else directly
    function app(cmd) { run(["sh", "-c", "if command -v uwsm >/dev/null; then exec uwsm app -- \"$@\"; else exec \"$@\"; fi", "isla"].concat(cmd)) }
    // Hyprland 0.55+ with a Lua config wants hl.dsp.* dispatchers; older configs want the classic ones.
    property bool luaFile: false
    readonly property bool lua: Hyprland.usingLua === true || luaFile
    Process { running: true; command: ["sh", "-c", "test -f \"${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprland.lua\" && echo lua"]
        stdout: StdioCollector { onStreamFinished: s.luaFile = this.text.trim() === "lua" } }
    function hypr(luaCmd, classic) { Hyprland.dispatch(lua ? luaCmd : classic); refreshSoon.restart() }
    function copy(text) { Quickshell.clipboardText = text }
    function reloadShell() { Quickshell.reload(false) }
    readonly property var tints: ["#55BFC6", "#A893EC", "#7CC47F", "#EE7D9C", "#F7A982", "#FFC23C", "#2F9EAB", "#7C83F0"]
    function hash(t) { let h = 0; for (let i = 0; i < t.length; i++) h = (h * 31 + t.charCodeAt(i)) | 0; return Math.abs(h) }
    function lookFor(cls) { const c = (cls || "").toLowerCase(); for (const k in classLook) if (k.toLowerCase() === c) return classLook[k]; return ["grid", tints[hash(c) % tints.length]] }

    // ── clock ──
    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property date now: clock.date ?? new Date()     // clock.date is undefined for the first moment after a reload
    readonly property string timeText: Qt.formatTime(now, h24 ? "HH:mm" : "h:mm AP")
    readonly property string clockH: { const h = now.getHours(); const v = h24 ? h : (h % 12 || 12); return (v < 10 ? "0" : "") + v }
    readonly property string clockM: Qt.formatTime(now, "mm")
    readonly property string ampm: now.getHours() < 12 ? "AM" : "PM"
    readonly property string dateText: Qt.formatDate(now, "ddd, MMM d")
    readonly property string phoneDate: Qt.formatDate(now, "ddd, d MMM")
    readonly property string ribbonDate: Qt.formatDate(now, "dddd · MMM d").toUpperCase()
    property string hostName: "isla"
    readonly property string userHost: (Quickshell.env("USER") || "me") + "@" + hostName
    FileView { path: "/etc/hostname"; printErrors: false; onLoaded: s.hostName = text().trim() }

    // ── Hyprland: monitors, workspaces, windows ──
    property var hMonitors: []
    property var hWorkspaces: []
    property var clients: []
    Process { id: hyprQuery; command: ["sh", "-c", "hyprctl -j monitors; echo '@@'; hyprctl -j workspaces; echo '@@'; hyprctl -j clients"]
        stdout: StdioCollector { onStreamFinished: {
            const parts = this.text.split("@@");
            try { s.hMonitors = JSON.parse(parts[0]) } catch (e) {}
            try { s.hWorkspaces = JSON.parse(parts[1]) } catch (e) {}
            try { s.clients = JSON.parse(parts[2]).map(c => ({ cls: c["class"] || c.initialClass || "app", title: c.title, workspace: c.workspace.id, address: c.address })) } catch (e) {}
            if (s._rehome) { s._rehome = false; s.rehome() }
        } } }
    // a screen was unplugged: Hyprland parks its workspaces (e.g. ASUS 1-9) on the laptop, where ws.sh can't reach them →
    // move their windows to new workspaces of the screen they are on now, after its newest one
    property bool _rehome: true                          // also once at start (booted without the monitor)
    function rehome() {
        for (const w of hWorkspaces.slice().sort((a, b) => a.id - b.id)) {
            const b = base(w.monitor), wins = clients.filter(c => c.workspace === w.id);
            if (w.id < 1 || (w.id > b && w.id <= b + 9) || !wins.length || !hMonitors.some(m => m.name === w.monitor)) continue;
            const used = i => clients.some(c => c.workspace === b + i);
            let n = 0; for (let i = 1; i <= 9; i++) if (used(i)) n = i;
            if (n === 9) { n = 0; while (n < 9 && used(n + 1)) n++ }          // full to the end: first gap
            const to = b + Math.min(n + 1, 9);
            for (const c of wins) { moveWindowTo(c.address, to); c.workspace = to }
        }
    }
    Timer { id: refreshSoon; interval: 80; onTriggered: hyprQuery.running = true }
    // only events that change windows / workspaces / screens (title changes from browsers & terminals are constant: skip them)
    readonly property var _hyprEvents: ["openwindow", "closewindow", "movewindow", "movewindowv2", "workspace", "workspacev2", "createworkspace", "createworkspacev2",
        "destroyworkspace", "destroyworkspacev2", "moveworkspace", "moveworkspacev2", "renameworkspace", "focusedmon", "focusedmonv2", "monitoradded", "monitoraddedv2",
        "monitorremoved", "monitorremovedv2", "activespecial", "activespecialv2", "changefloatingmode", "fullscreen", "pin"]
    Connections { target: Hyprland; function onRawEvent(ev) { if (ev.name.startsWith("monitorremoved")) s._rehome = true; if (ev.name.startsWith("monitoradded") || ev.name.startsWith("monitorremoved")) s.loadScreens(); if (s._hyprEvents.includes(ev.name)) refreshSoon.restart() } }
    Timer { interval: 60000; running: true; repeat: true; onTriggered: hyprQuery.running = true }   // safety net only
    readonly property var monitors: hMonitors.map(m => ({ name: m.name, label: (monitorNames[m.name] && monitorNames[m.name].label) || m.name }))
    function base(mon) { return (monitorNames[mon] && monitorNames[mon].base) || 0 }
    // "ASUS · Workspace 1" for a Wayland toplevel (dock previews)
    function whereIs(t) {
        const h = Hyprland.toplevels.values.find(x => x.wayland === t); if (!h) return "";
        const addr = "0x" + String(h.address).replace(/^0x/, "");
        const c = clients.find(x => x.address === addr); if (!c) return "";
        const w = hWorkspaces.find(x => x.id === c.workspace), mon = w ? w.monitor : "";
        const label = ((monitorNames[mon] && monitorNames[mon].label) || mon).split(" · ")[0];
        return label + " · Workspace " + (c.workspace - base(mon));
    }
    function activeIdOn(mon) { const m = hMonitors.find(x => x.name === mon); return m ? m.activeWorkspace.id : -1 }
    function workspaceTitle(mon) { const id = activeIdOn(mon); return id < 0 ? "Workspace" : "Workspace " + (id - base(mon)) }
    function workspacesFor(mon) {
        const b = base(mon), cur = activeIdOn(mon), out = [];
        for (let i = 1; i <= 9; i++) {
            const id = b + i, wins = clients.filter(c => c.workspace === id);
            out.push({ number: i, id: id, kind: id === cur ? "current" : (wins.length ? "occupied" : "empty"), tints: wins.map(c => lookFor(c.cls)[1]) });
        }
        return out;
    }
    function barWorkspaces(mon) {
        const all = workspacesFor(mon); let n = 5;
        for (const w of all) if (w.kind !== "empty") n = Math.max(n, w.number);
        return all.slice(0, n);
    }
    function windowsOn(id) { return clients.filter(c => c.workspace === id).map(c => ({ cls: c.cls, title: c.title, tint: lookFor(c.cls)[1], address: c.address })) }
    function goWorkspace(id) { hypr("hl.dsp.focus({ workspace = " + id + " })", "workspace " + id) }
    // ── islands: close / swap (closing goes through the Wayland toplevel, never "close the active window") ──
    function toplevelOf(addr) {
        const a = String(addr).replace(/^0x/, "");
        const h = Hyprland.toplevels.values.find(t => String(t.address).replace(/^0x/, "") === a);
        return h ? h.wayland : null;
    }
    function closeWindow(addr) { const t = toplevelOf(addr); if (t) t.close(); refreshSoon.restart() }
    function closeWorkspace(id) { for (const c of clients.filter(c => c.workspace === id)) closeWindow(c.address) }
    function moveWindowTo(addr, ws) { hypr("hl.dsp.window.move({ workspace = " + ws + ", window = \"address:" + addr + "\", follow = false })", "movetoworkspacesilent " + ws + ",address:" + addr) }
    function swapWorkspaces(a, b) {
        if (a === b) return;
        const wa = clients.filter(c => c.workspace === a).map(c => c.address), wb = clients.filter(c => c.workspace === b).map(c => c.address);
        for (const w of wa) moveWindowTo(w, b);
        for (const w of wb) moveWindowTo(w, a);
    }
    function firstEmptyOn(mon) { const t = workspacesFor(mon).find(x => x.kind === "empty"); return t ? t.id : -1 }
    function focusWindow(addr) { hypr("hl.dsp.focus({ window = \"address:" + addr + "\" })", "focuswindow address:" + addr) }
    readonly property var dockLive: dockApps.map(a => Object.assign({}, a, { running: clients.some(c => (c.cls || "").toLowerCase() === (a.cls || "").toLowerCase()) }))

    // ── status poll (every 4 s) ──
    property var wifi: ({ on: true, ssid: "" })
    // live from BlueZ (no bluetoothctl polling)
    readonly property var bluetooth: { const a = Bluetooth.defaultAdapter; const c = a ? a.devices.values.filter(d => d.connected) : []
        return { on: !!a && a.enabled, devices: c.length, name: c.length ? (c[0].name || c[0].address) : "" } }
    property var warp: ({ connected: false })
    property bool imeVi: false
    property bool dnd: false
    property bool airplane: false
    // apps' light / dark (Prefs.appsDark, separate from Isla's own Prefs.dark) switches Qt, KDE and GTK apps (tools/appearance.py)
    Connections { target: Prefs; function onAppsDarkChanged() { if (Prefs.ready) s.run(["python3", Quickshell.shellDir + "/tools/appearance.py", Prefs.appsDark ? "dark" : "light"]) } }
    property string wallPreview: ""               // wallpaper picker "Preview": shown on the desktop until Set / Back                  // every radio (Wi-Fi + Bluetooth) blocked (rfkill)
    // Do not disturb: by hand, for a while (dndFor), or by itself while a game is focused (Prefs.dndGaming)
    readonly property bool dndOn: dnd || (Prefs.dndGaming && gaming)
    property real dndUntil: 0
    function dndFor(mins) { dnd = true; dndUntil = Date.now() + mins * 60000; dndTimer.interval = mins * 60000; dndTimer.restart() }
    function dndTomorrow() { const t = new Date(); t.setDate(t.getDate() + (t.getHours() >= 7 ? 1 : 0)); t.setHours(7, 0, 0, 0); dndFor((t - Date.now()) / 60000) }
    onDndChanged: if (!dnd) { dndTimer.stop(); dndUntil = 0 }
    Timer { id: dndTimer; onTriggered: s.dnd = false }
    property bool nightLight: false
    property bool keepAwake: false
    // Game mode (Settings → Quick): fewer animations — Hyprland animations off (state file read by animations.lua,
    // applied live with hyprctl eval), phone light mode, bar visualizer + spinning record paused. Blur and the
    // power profile are not touched. `calm` = game mode or a game focused (the animation-only part of gaming).
    readonly property bool gameMode: Prefs.gameMode
    readonly property bool calm: gameMode || gaming
    function applyGameMode() {
        const f = "$HOME/.local/state/hypr/gamemode";
        run(["sh", "-c", gameMode ? "mkdir -p \"$HOME/.local/state/hypr\" && touch " + f + " && hyprctl eval 'hl.config({ animations = { enabled = false } })'"
                                  : "rm -f " + f + " && hyprctl eval 'hl.config({ animations = { enabled = true } })'"]);
    }
    onGameModeChanged: if (Prefs.ready) applyGameMode()
    Connections { target: Prefs; function onReadyChanged() { if (Prefs.ready) s.applyGameMode() } }
    property bool easyEffects: false
    // OBS recording for the bar timer (SvcRecord.qml)
    property bool obsUp: false
    SvcRecord { id: recordPart; obsUp: s.obsUp }
    readonly property bool recording: recordPart.recording
    readonly property string recTime: recordPart.time
    property real volume: 0.5
    property bool muted: false
    property real micVolume: 1
    property bool micOn: true
    property real brightness: 0.8
    property real gamma: 1.0
    property var battery: ({ percent: 100, charging: false, plugged: false, status: "", minutes: -1, health: 100 })
    property string powerProfile: ""                    // asusctl: Quiet · Balanced · Performance
    function setProfile(p) { powerProfile = p; run(["asusctl", "profile", "set", p]) }
    property string netDown: "0 B/s"
    property string netUp: "0 B/s"
    property var _net: null
    function speed(b) { return b > 1048576 ? (b / 1048576).toFixed(1) + " MB/s" : (b > 1024 ? Math.round(b / 1024) + " KB/s" : Math.round(b) + " B/s") }
    // one small bash per refresh: files are read with bash's own `read` (no cat/awk/brightnessctl processes);
    // volume + mic come from PipeWire events below; warp-cli only runs while the WARP service is up
    Process { id: status; command: ["bash", "-c", [
            "g=$(nmcli -t -f WIFI,STATE,CONNECTIVITY g 2>/dev/null); echo wifi=${g%%:*}; g=${g#*:}; echo nm=${g%:*}; echo conn=${g##*:}",
            "a=$(nmcli -t -f ACTIVE,SIGNAL,SSID dev wifi 2>/dev/null | grep -m1 '^yes'); a=${a#yes:}; echo sig=${a%%:*}; echo ssid=${a#*:}",
            "if [ -S /run/cloudflare-warp/warp_service ] && warp-cli --accept-tos status 2>/dev/null | grep -q 'Status update: Connected'; then echo warp=on; else echo warp=off; fi",
            "for d in /sys/class/backlight/*; do read -r c 2>/dev/null < $d/brightness && read -r m 2>/dev/null < $d/max_brightness && [ \"$m\" -gt 0 ] && echo bri=$(( (c * 100 + m / 2) / m )); break; done",
            "for d in /sys/class/power_supply/BAT*; do read -r x 2>/dev/null < $d/capacity && echo bat=$x; read -r x 2>/dev/null < $d/status && echo batst=$x; e=; for f in energy_now energy_full energy_full_design power_now; do read -r y 2>/dev/null < $d/$f && e=\"$e $y\"; done; echo energy=$e; break; done",
            "for d in /sys/class/power_supply/A*; do read -r x 2>/dev/null < $d/online && echo ac=$x; break; done",
            "read -r x 2>/dev/null < /sys/firmware/acpi/platform_profile && echo prof=$x",
            "h0=; h1=; for d in /sys/class/rfkill/rfkill*; do read -r x 2>/dev/null < $d/soft && { [ \"$x\" = 0 ] && h0=0; [ \"$x\" = 1 ] && h1=1; }; done; echo rf=$h0$h1",
            "p=\" $(ps -eo comm= | tr '\\n' ' ')\"; for x in night:hyprsunset fx:easyeffects obs:obs; do case \"$p\" in *\" ${x#*:} \"*) echo ${x%%:*}=on;; *) echo ${x%%:*}=off;; esac; done",
            "rx=0; tx=0; { read -r _; read -r _; while read -r l; do set -- ${l/:/ }; [ \"$1\" = lo ] && continue; rx=$((rx + $2)); tx=$((tx + ${10})); done; } < /proc/net/dev; echo \"net=$rx $tx\""
        ].join("; ")]
        stdout: StdioCollector { onStreamFinished: {
            const v = {}; for (const l of this.text.split("\n")) { const i = l.indexOf("="); if (i > 0) v[l.slice(0, i)] = l.slice(i + 1).trim() }
            s.wifi = { on: v.wifi === "enabled", ssid: v.ssid || "" };
            s.wifiSignal = parseInt(v.sig) || 0;
            s.airplane = v.rf === "1";
            s.nmState = v.nm || ""; s.nmConn = v.conn || "";
            s.warp = { connected: v.warp === "on" };
            if (v.bri) s.brightness = parseInt(v.bri) / 100;
            if (v.bat) {
                const e = (v.energy || "").trim().split(/\s+/).map(Number);     // now, full, design, power (µWh / µW)
                const chg = v.batst === "Charging", dis = v.batst === "Discharging";
                const mins = e.length === 4 && e[3] > 0 ? Math.round((chg ? e[1] - e[0] : e[0]) / e[3] * 60) : -1;
                s.battery = { percent: parseInt(v.bat) || 0, charging: chg || v.batst === "Full", plugged: v.ac === "1", status: v.batst || "",
                              minutes: (chg || dis) ? mins : -1, health: e.length >= 3 && e[2] > 0 ? Math.round(e[1] / e[2] * 100) : 100 };
            }
            s.powerProfile = ({ quiet: "Quiet", balanced: "Balanced", performance: "Performance" })[v.prof] || s.powerProfile;
            s.nightLight = v.night === "on"; s.easyEffects = v.fx === "on"; s.obsUp = v.obs === "on";
            const n = (v.net || "0 0").split(" ").map(Number), t = Date.now();
            if (s._net) { const dt = (t - s._net.t) / 1000; s.netDown = s.speed((n[0] - s._net.r) / dt); s.netUp = s.speed((n[1] - s._net.x) / dt) }
            s._net = { r: n[0], x: n[1], t: t };
        } } }
    // volume / mute / mic follow PipeWire directly (event-based, no polling)
    readonly property var pwSinkAudio: Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio ? Pipewire.defaultAudioSink.audio : null
    readonly property var pwSrcAudio: Pipewire.defaultAudioSource && Pipewire.defaultAudioSource.audio ? Pipewire.defaultAudioSource.audio : null
    readonly property real pwVol: pwSinkAudio ? pwSinkAudio.volume : -1
    readonly property bool pwMuted: pwSinkAudio ? pwSinkAudio.muted : false
    readonly property real pwMic: pwSrcAudio ? pwSrcAudio.volume : -1
    readonly property bool pwMicMuted: pwSrcAudio ? pwSrcAudio.muted : false
    onPwVolChanged: if (pwVol >= 0) volume = pwVol
    onPwMutedChanged: muted = pwMuted
    onPwMicChanged: if (pwMic >= 0) micVolume = pwMic
    onPwMicMutedChanged: micOn = !pwMicMuted
    // Wi-Fi / battery / brightness / net speed: the bar shows them live → a timer, slower while a game is focused
    Timer { interval: s.gaming ? 12000 : 4000; running: true; repeat: true; triggeredOnStart: true; onTriggered: if (!status.running) status.running = true }
    Component.onCompleted: hyprQuery.running = true
    Timer { id: statusSoon; interval: 600; onTriggered: status.running = true }
    Timer { interval: 1000; repeat: true; running: s.wifiConnecting; onTriggered: if (!status.running) status.running = true }

    // EN/VI changes with Ctrl+Shift in fcitx5 — check it often so the bar follows quickly
    // fcitx's tray icon changes with the input method (fcitx_bamboo = VI, input-keyboard = EN): follow it, no polling.
    // If there's no fcitx tray icon, fall back to asking fcitx5-remote every 2 s.
    readonly property var fcitxTray: SystemTray.items.values.find(i => i.id === "Fcitx") || null
    readonly property string fcitxIcon: fcitxTray ? String(fcitxTray.icon) : ""
    onFcitxIconChanged: if (fcitxIcon) imeVi = !fcitxIcon.includes("keyboard")
    Process { id: imeQuery; command: ["fcitx5-remote"]
        stdout: StdioCollector { onStreamFinished: { const v = this.text.trim(); if (v) s.imeVi = v === "2" } } }
    Timer { interval: 2000; running: !s.fcitxTray; repeat: true; triggeredOnStart: true; onTriggered: if (!imeQuery.running) imeQuery.running = true }

    // ── Wi-Fi list (nmcli) ──
    property var wifiNets: []            // [{ ssid, signal, secure, active, known }] strongest first
    property bool wifiBusy: false
    property string wifiError: ""
    property string wifiTarget: ""       // ssid being connected right now (its row says "Connecting…")
    property string wifiErrFor: ""       // ssid the last error belongs to (shown in its row)
    function nmSplit(line) {             // nmcli -t escapes ":" as "\:"
        const out = []; let cur = "";
        for (let i = 0; i < line.length; i++) {
            if (line[i] === "\\" && i + 1 < line.length) { cur += line[++i]; continue }
            if (line[i] === ":") { out.push(cur); cur = ""; continue }
            cur += line[i];
        }
        out.push(cur); return out;
    }
    Process { id: wifiScanP; command: ["sh", "-c", "nmcli -t -f NAME,TYPE con show 2>/dev/null | grep ':802-11-wireless$'; echo '@@'; nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY dev wifi list --rescan auto 2>/dev/null"]
        stdout: StdioCollector { onStreamFinished: {
            const parts = this.text.split("@@");
            const known = parts[0].split("\n").filter(l => l).map(l => s.nmSplit(l)[0]);
            const seen = {};
            for (const l of (parts[1] || "").split("\n")) {
                if (!l) continue;
                const f = s.nmSplit(l); const ssid = f[1]; if (!ssid) continue;
                const n = { ssid: ssid, signal: parseInt(f[2]) || 0, secure: !!f[3] && f[3] !== "--", active: f[0] === "*", known: known.includes(ssid) };
                if (!seen[ssid] || n.active || n.signal > seen[ssid].signal) seen[ssid] = Object.assign(n, { active: !!(n.active || (seen[ssid] && seen[ssid].active)) });
            }
            s.wifiNets = Object.values(seen).sort((a, b) => (b.active - a.active) || (b.signal - a.signal));
        } } }
    readonly property bool wifiScanning: wifiScanP.running || wifiRescan.running
    // "reload": ask the card to really rescan first (takes a few seconds), then read the list
    Process { id: wifiRescan; command: ["nmcli", "dev", "wifi", "rescan"]; onExited: s.wifiScan() }
    function wifiRescanNow() { if (!wifiRescan.running) wifiRescan.running = true }
    function wifiScan() { if (!wifiScanP.running) wifiScanP.running = true }
    // one network's settings + live info (tools/wifi-info.py)
    property var wifiInfo: null
    Process { id: wifiInfoP
        stdout: StdioCollector { onStreamFinished: { try { s.wifiInfo = JSON.parse(this.text) } catch (e) { s.wifiInfo = null } } } }
    function loadWifiInfo(ssid) { wifiInfoP.running = false; wifiInfoP.command = ["python3", Quickshell.shellDir + "/tools/wifi-info.py", ssid]; wifiInfoP.running = true }
    // change settings of a saved network, then re-activate it if it's the one in use so they apply now
    property string wifiSaveMsg: ""
    Process { id: wifiMod
        property string ssid: ""
        stderr: StdioCollector { id: wifiModErr }
        onExited: code => { s.wifiSaveMsg = code === 0 ? "Saved ✓" : "Not saved — " + wifiModErr.text.trim().slice(0, 100); s.loadWifiInfo(ssid); statusSoon.restart(); wifiSaveClear.restart() } }
    Timer { id: wifiSaveClear; interval: 3000; onTriggered: s.wifiSaveMsg = "" }
    function wifiModify(info, args) {
        if (!info || !info.name || wifiMod.running) return;
        wifiSaveMsg = "Saving…"; wifiMod.ssid = info.ssid;
        const reup = info.active ? " && nmcli con up id \"$0\" >/dev/null" : "";
        wifiMod.command = ["sh", "-c", "nmcli con mod id \"$0\" \"$@\"" + reup, info.name].concat(args);
        wifiMod.running = true;
    }
    Process { id: wifiAct
        stdout: StdioCollector { id: wifiOut }
        stderr: StdioCollector { id: wifiErr }
        onExited: code => { const cancelled = s._wifiCancelled; s._wifiCancelled = false; s.wifiBusy = false
            s.wifiError = code === 0 || cancelled ? "" : (wifiErr.text || wifiOut.text).trim().replace(/^Error: /, "").slice(0, 120)
            s.wifiErrFor = code === 0 || cancelled ? "" : s.wifiTarget; s.wifiTarget = ""; s.wifiScan(); statusSoon.restart() } }
    // auto time zone (Settings → Time & language): after start and when the Wi-Fi network changes,
    // look up this connection's time zone and switch if it differs (asks for the password if needed)
    readonly property string _ssid: wifi && wifi.ssid ? wifi.ssid : ""
    on_SsidChanged: if (Prefs.autoTz && Prefs.location) autoTzT.restart()
    Timer { id: autoTzT; interval: 15000; running: Prefs.autoTz && Prefs.location; onTriggered: s.checkTimeZone() }
    function checkTimeZone() {
        run(["sh", "-c", "tz=$(python3 \"$0\" autotz); cur=$(timedatectl show -p Timezone --value); [ -n \"$tz\" ] && [ \"$tz\" != \"$cur\" ] && timedatectl set-timezone \"$tz\"",
             Quickshell.shellDir + "/tools/timelang.py"]);
    }

    // keyring password pop-ups drawn by Isla (tools/keyring-prompter.py takes over gcr-prompter's service)
    // keyAsk = {id, kind: password|confirm, title, message, description, warning, new} or null
    property var keyAsk: null
    // keyring prompter + Bluetooth agent run in ONE Python (tools/isla-agents.py): messages carry ch "key" | "bt",
    // answers go back as "key …" / "bt …"
    Process { id: agents; running: true; stdinEnabled: true
        command: ["python3", Quickshell.shellDir + "/tools/isla-agents.py"]
        stdout: SplitParser { onRead: line => { try {
            const m = JSON.parse(line);
            if (m.ch === "key") s.keyAsk = m.kind === "close" ? null : m;
            else if (m.ch === "bt") s.btAsk = m.kind === "cancel" ? null : m;
        } catch (e) {} } }
        onExited: { s.keyAsk = null; s.btAsk = null; agentsRestart.start() } }
    Timer { id: agentsRestart; interval: 3000; onTriggered: agents.running = true }
    function keyAnswer(ok, password) {
        if (!keyAsk) return;
        agents.write("key " + keyAsk.id + (ok ? " ok" + (keyAsk.kind === "password" ? " " + password : "") : " cancel") + "\n");
        keyAsk = null;
    }

    // Isla is the polkit agent: system changes (time zone, auto time, region…) ask for the password in PolkitDialog
    PolkitAgent { id: polkitAgent }
    readonly property var authFlow: polkitAgent.isActive ? polkitAgent.flow : null

    // Bluetooth pairing agent (tools/bt-agent.py): a phone/PC asking to pair shows its code in the pair dialog.
    // btAsk = {id, kind: confirm|authorize|display, name, addr, key} or null
    property var btAsk: null
    Timer { id: btDisplayHide; interval: 30000; running: !!s.btAsk && s.btAsk.kind === "display"; onTriggered: s.btAsk = null }
    // ans: "yes" | "no" | "trust" (= allow and trust from now on)
    function btAnswer(ans) {
        if (!btAsk) return;
        if (btAsk.kind === "newdev") { if (ans !== "no") _btPair(btAsk.addr, btAsk.path, ans === "trust") }
        else if (btAsk.kind !== "display") agents.write("bt " + btAsk.id + " " + ans + "\n");
        btAsk = null;
    }
    // tapping a new device in the panel: ask first (Pair only / Pair & trust), then pair + connect.
    // Codes (phones) show in the same dialog through the agent; failure shows in the device row.
    property string btPairAddr: ""
    property string btFailAddr: ""
    function btPairAsk(d) {
        if (btPairP.running) return;
        btAsk = { id: -1, kind: "newdev", name: d.name || d.address, addr: d.address,
                  path: d.dbusPath || ("/org/bluez/hci0/dev_" + d.address.replace(/:/g, "_")), key: null };
    }
    function _btPair(addr, path, trust) {
        btFailAddr = ""; btPairAddr = addr;
        btPairP.command = ["sh", "-c", "busctl call --timeout=60 org.bluez $2 org.bluez.Device1 Pair; [ $3 = 1 ] && bluetoothctl trust $1 >/dev/null; timeout 20 bluetoothctl connect $1 | grep -q 'Connection successful'", "sh", addr, path, trust ? "1" : "0"];
        btPairP.running = true;
    }
    Process { id: btPairP; onExited: code => { if (code !== 0) s.btFailAddr = s.btPairAddr; s.btPairAddr = "" } }

    // ✕ on the "Connecting…" row: stop waiting, and stop NetworkManager trying (a new network's half-made profile is removed)
    property bool _wifiCancelled: false
    property bool _wifiTargetKnown: false
    Process { id: wifiStop; onExited: { s.wifiScan(); statusSoon.restart() } }
    function wifiCancel() {
        if (!wifiAct.running || !wifiTarget) return;
        _wifiCancelled = true;
        wifiStop.command = ["nmcli", "con", _wifiTargetKnown ? "down" : "delete", "id", wifiTarget];
        wifiAct.running = false; wifiStop.running = true;
    }
    function wifiRun(cmd) { if (wifiAct.running) return; wifiBusy = true; wifiError = ""; wifiErrFor = ""; wifiAct.command = cmd; wifiAct.running = true }
    function wifiConnect(n, password) {
        if (wifiAct.running) return;
        wifiTarget = n.ssid; _wifiTargetKnown = n.known;
        if (n.known) wifiRun(["nmcli", "con", "up", "id", n.ssid]);
        else if (password) wifiRun(["nmcli", "dev", "wifi", "connect", n.ssid, "password", password]);
        else wifiRun(["nmcli", "dev", "wifi", "connect", n.ssid]);
    }
    function wifiDisconnect(n) { wifiRun(["nmcli", "con", "down", "id", n.ssid]) }
    function wifiForget(n) { wifiRun(["nmcli", "con", "delete", "id", n.ssid]) }

    signal appOpened()                             // shell closes the phone + dropdowns
    function openApp(cmd) { app(cmd); appOpened() }       // start a program and close the phone / dropdowns

    // ── idle timers (Settings → Power): lock, screens off, sleep — plugged-in / battery values from Prefs ──
    readonly property int _ix: battery.plugged ? 0 : 1
    function _mins(a) { return a && a.length > _ix ? Number(a[_ix]) || 0 : 0 }
    IdleMonitor { id: idleLockM; enabled: s._mins(Prefs.idleLock) > 0 && !s.keepAwake; timeout: Math.max(1, s._mins(Prefs.idleLock)) * 60; respectInhibitors: true
        onIsIdleChanged: if (isIdle) s.lockRequested() }
    IdleMonitor { id: idleScreenM; enabled: s._mins(Prefs.idleScreen) > 0 && !s.keepAwake; timeout: Math.max(1, s._mins(Prefs.idleScreen)) * 60; respectInhibitors: true
        onIsIdleChanged: if (isIdle) s.run(["sh", Quickshell.shellDir + "/tools/screen-off.sh"]) }
    IdleMonitor { id: idleSleepM; enabled: s._mins(Prefs.idleSleep) > 0 && !s.keepAwake; timeout: Math.max(1, s._mins(Prefs.idleSleep)) * 60; respectInhibitors: true
        onIsIdleChanged: if (isIdle) { s.lockRequested(); s.run(["sh", "-c", "sleep 2; systemctl suspend"]) } }   // lock first, then sleep

    // ── lid (Settings → Power): Isla tells logind it handles the lid (inhibitor lives only while Isla runs),
    //    Hyprland's lid switch binds (hypr/config/lid.lua) call lid() through IPC ──
    Process { running: true; command: ["sh", "-c", "exec systemd-inhibit --what=handle-lid-switch --who=Isla --why='Isla handles the lid' --mode=block tail --pid=$PPID -f /dev/null"] }
    readonly property string _laptopScreen: { const m = Hyprland.monitors.values.find(m => m.name.startsWith("eDP")); return m ? m.name : "eDP-1" }
    function _laptopDpms(on) { run(["hyprctl", "dispatch", "hl.dsp.dpms({ action = \"" + (on ? "on" : "off") + "\", monitor = \"" + _laptopScreen + "\" })"]) }
    function lid(closed) {
        if (!closed) { _laptopDpms(true); return }
        let a = (Prefs.lidClose || [])[_ix] || "sleep";
        if (a === "sleep" && Hyprland.monitors.values.length > 1) a = "screen";   // docked: keep working on the other screen
        if (a === "sleep") { lockRequested(); run(["sh", "-c", "sleep 2; systemctl suspend"]) }
        else if (a === "lock") { lockRequested(); _laptopDpms(false) }
        else if (a === "screen") _laptopDpms(false);
    }

    // ── screen time recorder (Noctalia did this; only runs while Noctalia is off) ──
    property var _stPending: ({})
    IdleMonitor { id: idle; timeout: 300; respectInhibitors: true }
    Timer { interval: 5000; running: true; repeat: true; onTriggered: {
        const t = ToplevelManager.activeToplevel;
        if (!t || !t.activated || idle.isIdle) return;
        const id = t.appId || ("title:" + t.title);
        const p = s._stPending; p[id] = (p[id] || 0) + 5; s._stPending = p;
    } }
    Process { id: stAdd }
    Timer { interval: 30000; running: true; repeat: true; onTriggered: {
        if (!Object.keys(s._stPending).length || stAdd.running) return;
        stAdd.command = ["sh", "-c", "pgrep -x noctalia >/dev/null || python3 \"$0\" \"$1\"", Quickshell.shellDir + "/tools/screentime-add.py", JSON.stringify(s._stPending)];
        s._stPending = ({}); stAdd.running = true;
    } }

    // ── data for the phone settings pages (loaded when a page opens) ──
    readonly property string scripts: Quickshell.env("HOME") + "/.config/hypr/scripts"
    property var screens: []                       // screenctl.py list
    Process { id: screensP; command: ["python3", s.scripts + "/screenctl.py", "list"]
        stdout: StdioCollector { onStreamFinished: { try { s.screens = JSON.parse(this.text) } catch (e) {} } } }
    function loadScreens() { if (!screensP.running) screensP.running = true }
    Process { id: screenAct; onExited: s.loadScreens() }
    function screenCmd(args) { if (screenAct.running) return; screenAct.command = ["python3", s.scripts + "/screenctl.py"].concat(args); screenAct.running = true }

    property var binds: []                         // keybinds.json
    property string bindMsg: ""
    Process { id: bindsP; command: ["cat", Quickshell.env("HOME") + "/.config/hypr/keybinds.json"]
        stdout: StdioCollector { onStreamFinished: { try { s.binds = JSON.parse(this.text) } catch (e) {} } } }
    function loadBinds() { if (!bindsP.running) bindsP.running = true }
    Process { id: bindSet
        stdout: StdioCollector { id: bindOut }
        onExited: code => { s.bindMsg = code === 0 ? "Saved ✓" : "Not saved — " + bindOut.text.trim().slice(0, 140); s.loadBinds() } }
    function addBind(name, cmd, keys) { if (bindSet.running) return; bindMsg = "Saving…"; bindSet.command = ["python3", Quickshell.shellDir + "/tools/addbind.py", "add", name, cmd, keys]; bindSet.running = true }
    function removeBind(index) { if (bindSet.running) return; bindMsg = "Removing…"; bindSet.command = ["python3", Quickshell.shellDir + "/tools/addbind.py", "remove", String(index)]; bindSet.running = true }
    function setBind(index, keys) { if (bindSet.running) return; bindMsg = "Saving…"; bindSet.command = ["python3", Quickshell.shellDir + "/tools/setbind.py", String(index), keys]; bindSet.running = true }
    function submap(name) { run(["hyprctl", "dispatch", "hl.dsp.submap(\"" + name + "\")"]) }

    property var screenTime: null                  // tools/screentime-summary.py
    Process { id: stSum; command: ["python3", Quickshell.shellDir + "/tools/screentime-summary.py"]
        stdout: StdioCollector { onStreamFinished: { try { s.screenTime = JSON.parse(this.text) } catch (e) {} } } }
    function loadScreenTime() { if (!stSum.running) stSum.running = true }

    property var sys: ({})                         // System page
    Process { id: sysP; command: ["sh", "-c", [
            "echo os=$(. /etc/os-release; echo $PRETTY_NAME)", "echo kernel=$(uname -r)", "echo host=$(cat /etc/hostname)",
            "echo cpu=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | sed 's/^ *//; s/ with .*//')",
            "echo ram=$(free -g | grep Mem: | tr -s ' ' | cut -d' ' -f2)", "echo up=$(uptime -p | sed 's/^up //')",
            "echo hypr=$(hyprctl version -j 2>/dev/null | grep -m1 '\"tag\"' | cut -d'\"' -f4)", "echo qs=$(qs --version 2>/dev/null | head -1 | cut -d' ' -f2)",
            "echo fw=$(systemctl is-active firewalld)", "echo ssh=$(systemctl is-active sshd)", "echo sshok=$(test -x /usr/local/bin/ssh-toggle && echo 1)",
            "echo limit=$(cat /sys/class/power_supply/BAT*/charge_control_end_threshold 2>/dev/null | head -1)",
            "echo share=$(systemctl --user list-timers --all 2>/dev/null | grep -c share-firewall)"
        ].join("; ")]
        stdout: StdioCollector { onStreamFinished: { const v = {}; for (const l of this.text.split("\n")) { const i = l.indexOf("="); if (i > 0) v[l.slice(0, i)] = l.slice(i + 1).trim() } s.sys = v } } }
    function loadSys() { if (!sysP.running) sysP.running = true }
    Process { id: sysAct; onExited: sysSoon.restart() }
    Timer { id: sysSoon; interval: 800; onTriggered: s.loadSys() }
    function sysCmd(cmd) { if (sysAct.running) return; sysAct.command = cmd; sysAct.running = true }

    // ── clipboard history (cliphist) ──
    property var clips: []                         // [{ id, text, kind, info, time }] newest first (time = ms, 0 = not known)
    readonly property string clipCache: Quickshell.env("HOME") + "/.cache/isla/clip"
    function clipKind(t) {
        if (t.startsWith("[[ binary data")) return "IMG";
        if (/^(https?|ftp):\/\/\S+$/.test(t.trim())) return "URL";
        if (/^(~|\/)[^\s]*$/.test(t.trim())) return "DIR";
        if (/^(sudo|cd|git|docker|ls|cp|mv|rm|mkdir|python3?|npm|pnpm|yarn|paru|yay|pacman|nmcli|hyprctl|systemctl|qs|ssh|curl|wget|cat|grep|kitty|bash|sh|fish|code|chmod|journalctl)\b/.test(t.trim())) return "CMD";
        return "TXT";
    }
    // copy times come from tools/clip-store.sh (the clipboard saver writes "<id> <unix time>")
    Process { id: clipList; command: ["sh", "-c", "cliphist list; echo '@@'; tail -n 600 \"$HOME/.cache/isla/cliptimes\" 2>/dev/null"]
        stdout: StdioCollector { onStreamFinished: {
            const parts = this.text.split("\n@@\n"), times = {};
            for (const l of (parts[1] || "").split("\n")) { const p = l.split(" "); if (p.length === 2) times[p[0]] = parseInt(p[1]) * 1000 }
            s.clips = parts[0].split("\n").filter(l => l.includes("\t")).map(l => {
                const i = l.indexOf("\t"), id = l.slice(0, i), t = l.slice(i + 1), k = s.clipKind(t);
                const m = /binary data ([\d.]+ \w+) (\w+) (\d+x\d+)/.exec(t);
                return { id: id, key: t, text: m ? m[2].toUpperCase() + " image · " + m[3] : t, kind: k, info: m ? m[1] : "", time: times[id] || 0, pinned: Prefs.clipPins.includes(t) };
            }).filter((c, i) => i < 300 || c.pinned);      // pinned ones stay even when old
        } } }
    // "just now", "5 min ago", "2 h ago", "Yesterday 14:20", "17 Oct 09:30"
    function ago(ms) {
        if (!ms) return "";
        const d = (Date.now() - ms) / 60000, t = new Date(ms), hm = Qt.formatTime(t, h24 ? "HH:mm" : "h:mm AP");
        if (d < 1) return "just now";
        if (d < 60) return Math.floor(d) + " min ago";
        const y = new Date(); y.setHours(0, 0, 0, 0);
        if (ms >= y.getTime()) return Math.floor(d / 60) + " h ago · " + hm;
        if (ms >= y.getTime() - 86400000) return "Yesterday " + hm;
        return Qt.formatDate(t, "d MMM") + " " + hm;
    }
    function loadClips() { if (!clipList.running) clipList.running = true }
    // new copy → tools/clip-store.sh appends to cliptimes → reload the list (no polling)
    FileView { path: Quickshell.env("HOME") + "/.cache/isla/cliptimes"; watchChanges: true; printErrors: false
        onFileChanged: { reload(); s.loadClips() } }
    Process { id: clipAct; onExited: s.loadClips() }
    function clipCopy(c) { run(["sh", "-c", "cliphist decode \"$0\" | wl-copy", c.id]) }
    function clipDelete(c) { if (clipAct.running) return; if (c.pinned) clipPin(c); clipAct.command = ["sh", "-c", "cliphist list | grep -m1 \"^$0\t\" | cliphist delete", c.id]; clipAct.running = true }
    // wipe keeps pinned items (deletes every line whose text is not in the pins)
    function clipWipe() { if (clipAct.running) return
        clipAct.command = ["bash", "-c", "cliphist list | awk -F'\\t' 'NR==FNR{p[$0];next} !(substr($0,index($0,\"\\t\")+1) in p)' <(printf '%s\\n' \"$@\") - | cliphist delete", "_"].concat(Prefs.clipPins)
        clipAct.running = true }
    function clipPin(c) { Prefs.set("clipPins", c.pinned ? Prefs.clipPins.filter(k => k !== c.key) : Prefs.clipPins.concat([c.key])); loadClips() }
    // full text / image file for the preview card
    property string clipFull: ""
    property string clipImage: ""
    Process { id: clipDec
        property string want: ""
        stdout: StdioCollector { id: clipDecOut }
        onExited: code => { if (code !== 0) return; if (clipDec.want.endsWith(".png")) s.clipImage = "file://" + clipDec.want + "?" + Date.now(); else s.clipFull = clipDecOut.text } }
    function clipPreview(c) {
        clipFull = ""; clipImage = ""; if (!c) return;
        clipDec.running = false;
        if (c.kind === "IMG") { const f = clipCache + "-" + c.id + ".png"; clipDec.want = f; clipDec.command = ["sh", "-c", "mkdir -p \"$(dirname \"$1\")\" && cliphist decode \"$0\" > \"$1.part\" && mv \"$1.part\" \"$1\"", c.id, f] }   // whole file or nothing (moving fast stops a half-written one)
        else { clipDec.want = ""; clipDec.command = ["sh", "-c", "cliphist decode \"$0\" | head -c 4000", c.id] }
        clipDec.running = true;
    }

    // ── PC monitor: CPU / RAM / GPU (SvcSysmon.qml) ──
    SvcSysmon { id: sysmonPart; gaming: s.gaming }
    property alias sysmon: sysmonPart.sysmon
    property alias cpuHist: sysmonPart.cpuHist
    property alias ramHist: sysmonPart.ramHist
    property alias gpuHist: sysmonPart.gpuHist
    property alias gpuName: sysmonPart.gpuName

    // ── live status for the bar icons (no waiting for the 4 s poll) ──
    PwObjectTracker { objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource] }
    readonly property real liveVol: Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio ? Pipewire.defaultAudioSink.audio.volume : volume
    readonly property bool liveMuted: Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio ? Pipewire.defaultAudioSink.audio.muted : muted
    // set the default output straight through PipeWire (instant); scroll steps build on the last target, not the stale reading
    property real _volTarget: -1
    Timer { id: volHold; interval: 600; onTriggered: s._volTarget = -1 }
    function setSinkVolume(v) {
        v = Math.max(0, Math.min(1, v));
        const n = Pipewire.defaultAudioSink;
        if (n && n.audio) { n.audio.muted = false; n.audio.volume = v } else run(["wpctl", "set-volume", "-l", "1", "@DEFAULT_AUDIO_SINK@", v.toFixed(2)]);
        volume = v;
    }
    function nudgeVolume(d) { const v = Math.max(0, Math.min(1, (_volTarget >= 0 ? _volTarget : liveVol) + d)); _volTarget = v; volHold.restart(); setSinkVolume(v) }
    readonly property string volIcon: liveMuted || liveVol <= 0.001 ? "mute" : liveVol < 0.34 ? "volLow" : liveVol < 0.67 ? "volMid" : "volume"
    readonly property var btAd: Bluetooth.defaultAdapter
    readonly property int btConnected: btAd ? btAd.devices.values.filter(d => d.connected).length : 0
    readonly property string btState: !btAd || !btAd.enabled ? "off" : btAd.discovering ? "searching" : btConnected > 0 ? "connected" : "on"
    property int wifiSignal: 0                      // 0–100 of the network in use (from the poll)
    property string nmState: ""                     // NetworkManager: connected · connecting · disconnected · asleep …
    property string nmConn: ""                      // connectivity: full · limited · portal · none · unknown
    readonly property bool wifiConnecting: wifiBusy || nmState.startsWith("connecting")
    readonly property bool noInternet: !!wifi.ssid && (nmConn === "limited" || nmConn === "portal" || nmConn === "none")
    property bool wifiFailed: false                 // a connect attempt just failed → red "!" for 15 s
    Timer { id: wifiFailTimer; interval: 15000; onTriggered: s.wifiFailed = false }
    onWifiErrorChanged: if (wifiError !== "") { wifiFailed = true; wifiFailTimer.restart() }
    readonly property string wifiIcon: !wifi.on ? "wifiOff" : wifiConnecting ? "connecting" : !wifi.ssid ? "none"
                                     : wifiSignal >= 67 ? "wifi" : wifiSignal >= 34 ? "wifi2" : "wifi1"
    readonly property string wifiBadge: wifiFailed ? "error" : (noInternet && !wifiConnecting ? "nointernet" : "")

    // ── profile (phone: avatar in Quick) ──
    property var profile: ({ user: Quickshell.env("USER") || "me", full: "", shell: "", uptime: 0 })
    Process { id: profP; command: ["sh", "-c", "getent passwd \"$USER\"; cut -d' ' -f1 /proc/uptime"]
        stdout: StdioCollector { onStreamFinished: {
            const L = this.text.trim().split("\n"), f = (L[0] || "").split(":");
            s.profile = { user: f[0] || s.profile.user, full: (f[4] || "").split(",")[0], shell: (f[6] || "").split("/").pop(), uptime: parseFloat(L[1]) || 0 };
        } } }
    function loadProfile() { if (!profP.running) profP.running = true }
    readonly property string desktopName: Quickshell.env("XDG_CURRENT_DESKTOP") || "Hyprland"
    function uptimeText(sec) { const d = Math.floor(sec / 86400), h = Math.floor(sec % 86400 / 3600), m = Math.floor(sec % 3600 / 60); return d ? d + "d " + h + "h" : h + "h " + m + "m" }
    readonly property string greeting: { const h = now.getHours(); return h < 5 ? "GOOD NIGHT" : h < 12 ? "GOOD MORNING" : h < 18 ? "GOOD AFTERNOON" : "GOOD EVENING" }
    // system changes need your password, so they run in a terminal where you type it yourself (never stored by Isla)
    function changePassword() { openApp(["kitty", "--title", "Change password", "sh", "-c", "echo 'Change the password for '$USER; echo; passwd; echo; read -p 'Press Enter to close… ' _"]) }
    function setSystemName(n) { openApp(["kitty", "--title", "Change name", "sh", "-c", "echo 'Set the full name to: '\"$0\"; echo; chfn -f \"$0\" && echo Done.; echo; read -p 'Press Enter to close… ' _", n]); profSoon.restart() }
    Timer { id: profSoon; interval: 20000; onTriggered: s.loadProfile() }

    // ── power menu ──
    property bool hasLocker: true                   // Isla has its own lock screen
    signal lockRequested()
    function trashFile(p) { run(["gio", "trash", p]) }
    signal phoneRotate()
    function rotatePhone() { phoneRotate() }
    // Wallpapers → Paste image (clipboard picture or a copied image link)
    property string pasteMsg: ""
    signal pastedWallpaper(string path)
    Process { id: pasteP; command: ["sh", Quickshell.shellDir + "/tools/paste-wallpaper.sh"]
        stdout: StdioCollector { id: pasteOut }
        onExited: code => {
            const f = pasteOut.text.trim();
            s.pasteMsg = code === 0 ? "Added ✓" : code === 3 ? "That link isn't a picture" : "Copy an image or an image link first";
            if (code === 0) s.pastedWallpaper(f);
            pasteMsgTimer.restart();
        } }
    Timer { id: pasteMsgTimer; interval: 3500; onTriggered: s.pasteMsg = "" }
    function pasteWallpaper() { if (!pasteP.running) { pasteMsg = "Pasting…"; pasteP.running = true } }
    signal wipePreviewRequested()
    function previewWipe() { wipePreviewRequested() }
    property bool phoneBig: false                  // landscape phone "big mode" (Settings)
    signal powerMenuRequested()
    function powerMenu() { powerMenuRequested() }
    function power(what) {
        if (what === "lock") lockRequested();
        else if (what === "logout") run(["sh", "-c", "command -v uwsm >/dev/null && uwsm stop || hyprctl dispatch exit"]);
        else if (what === "suspend") run(["systemctl", "suspend"]);
        else if (what === "reboot") run(["systemctl", "reboot"]);
        else if (what === "shutdown") run(["systemctl", "poweroff"]);
    }

    // keep awake = hold a sleep/idle inhibitor while on
    Process { id: inhibitor; command: ["systemd-inhibit", "--what=idle:sleep", "--who=Isla", "--why=Keep awake", "sleep", "infinity"]; running: s.keepAwake }

    function toggle(what) {
        if (what === "wifi") run(["nmcli", "radio", "wifi", wifi.on ? "off" : "on"]);
        else if (what === "bt") run(["bluetoothctl", "power", bluetooth.on ? "off" : "on"]);
        else if (what === "warp") run(["sh", Quickshell.shellDir + "/tools/warp.sh", warp.connected ? "off" : "on"]);
        else if (what === "ime") { imeVi = !imeVi; run(["fcitx5-remote", "-t"]) }
        else if (what === "dnd") dnd = !dnd;
        else if (what === "airplane") { airplane = !airplane; run(["rfkill", airplane ? "block" : "unblock", "all"]) }
        else if (what === "night") { nightLight = !nightLight; run(nightLight ? ["sh", "-c", "pgrep -x hyprsunset || hyprsunset -t " + nightTemp + " >/dev/null 2>&1 &"] : ["pkill", "-x", "hyprsunset"]) }
        else if (what === "awake") keepAwake = !keepAwake;
        else if (what === "game") Prefs.flip("gameMode");
        else if (what === "fx") run(easyEffects ? ["pkill", "-x", "easyeffects"] : ["sh", "-c", "easyeffects --gapplication-service >/dev/null 2>&1 &"]);
        else if (what === "mute") run(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]);
        else if (what === "mic") run(["wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle"]);
        statusSoon.restart();
    }
    function setVolume(v) { setSinkVolume(v) }
    function setMicVolume(v) { micVolume = v; run(["wpctl", "set-volume", "@DEFAULT_AUDIO_SOURCE@", v.toFixed(2)]) }
    function setBrightness(v) { brightness = v; run(["brightnessctl", "set", Math.round(Math.max(0.02, v) * 100) + "%"]) }
    function setGamma(v) { gamma = Math.max(0.5, v) }
    function tool(name) {
        if (name === "fullscreen") hypr("hl.dsp.window.fullscreen()", "fullscreen");
        else if (tools[name]) run(tools[name]);
    }

    // ── palette card: colours from the wallpaper / song cover / random → Custom theme (SvcPalette.qml) ──
    SvcPalette { id: palettePart; wallpaper: Prefs.wallpaper; art: s.media ? s.media.art : "" }
    readonly property alias palette: palettePart

    // ── calendar notes (SvcSchedule.qml): at their time a bubble that stays until clicked ──
    SvcSchedule { id: schedulePart
        onDue: n => s.pushToast({ app: "⏰ " + String(n.hour).padStart(2, "0") + ":" + String(n.min).padStart(2, "0"), body: n.text,
                                  image: n.image, tint: Theme.sun, pinned: true }) }
    property alias schedule: schedulePart

    // ── weather (SvcWeather.qml) ──
    SvcWeather { id: weatherPart; city: s.city }
    property alias weather: weatherPart.weather
    function refreshWeather() { weatherPart.refreshWeather() }

    // you're in a game (Steam / Proton / gamescope window focused) → the bar stops its moving bits so the GPU stays with the game
    readonly property bool gaming: { try { const t = Hyprland.activeToplevel
        return !!t && /^(steam_app.*|gamescope)$/.test(String((t.wayland && t.wayland.appId) || (t.lastIpcObject && t.lastIpcObject.class) || "")) } catch (e) { return false } }
    // ── music visualizer (cava, only while something is playing, not while gaming) ──
    property var viz: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    Process {
        id: cava
        command: ["cava", "-p", Quickshell.shellDir + "/cava.conf"]
        running: !!s.media && s.media.playing && !s.calm
        onRunningChanged: if (!running) s.viz = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        stdout: SplitParser { onRead: line => { const v = line.split(";").filter(x => x !== "").map(Number); if (v.length) s.viz = v } }
    }

    // ── media (MPRIS) ──
    readonly property var player: { const ps = Mpris.players.values; return ps.find(p => p.isPlaying) || ps[0] || null }
    property real _tick: 0
    readonly property var media: player ? { title: player.trackTitle || player.identity || "Music", artist: player.trackArtist || "", art: player.trackArtUrl || "",
        album: player.trackAlbum || "", app: player.identity || "", playing: player.isPlaying,
        position: (_tick, player.positionSupported ? player.position : 0), length: player.lengthSupported ? player.length : 0,
        canSeek: player.canSeek, shuffle: player.shuffleSupported ? player.shuffle : false, shuffleOk: player.shuffleSupported,
        loop: player.loopSupported ? player.loopState : 0, loopOk: player.loopSupported,
        progress: (_tick, player.length > 0 ? Math.max(0, Math.min(1, player.position / player.length)) : 0) } : null
    Timer { interval: 1000; running: !!s.player && s.player.isPlaying; repeat: true; onTriggered: { s.player.positionChanged(); s._tick++ } }
    function mmss(sec) { sec = Math.max(0, Math.floor(sec || 0)); return Math.floor(sec / 60) + ":" + String(sec % 60).padStart(2, "0") }
    function mediaSeek(frac) { if (player && player.canSeek && player.length > 0) { player.position = frac * player.length; _tick++ } }
    function mediaShuffle() { if (player && player.shuffleSupported) player.shuffle = !player.shuffle }
    function mediaLoop() { if (player && player.loopSupported) player.loopState = (player.loopState + 1) % 3 }    // none → track → playlist

    // colours from the album cover (pill tint, ring, visualizer)
    ColorQuantizer { id: artColors; source: s.media && s.media.art ? s.media.art : ""; depth: 2; rescaleSize: 48 }
    function _sat(c) { const mx = Math.max(c.r, c.g, c.b), mn = Math.min(c.r, c.g, c.b); return mx === 0 ? 0 : (mx - mn) / mx }
    readonly property var artPalette: {
        const cs = artColors.colors || []; if (!cs.length) return [Theme.sea, Theme.purple, Theme.berry];
        const sorted = cs.slice().sort((a, b) => s._sat(b) * (0.4 + Math.max(b.r, b.g, b.b)) - s._sat(a) * (0.4 + Math.max(a.r, a.g, a.b)));
        if (s._sat(sorted[0]) < 0.22) return [Theme.lilac, Theme.sea, Theme.berry];          // grey / black-and-white cover → Isla colours
        // keep colours bright enough to read on the pill
        const lift = c => Math.max(c.r, c.g, c.b) < 0.45 ? Qt.lighter(c, 1.6) : c;
        return [lift(sorted[0]), lift(sorted[Math.min(1, sorted.length - 1)]), lift(sorted[Math.min(2, sorted.length - 1)])];
    }
    readonly property color artAccent: Qt.darker(artPalette[0], 1.15)
    readonly property var artFill: [Qt.tint(Theme.cream, Qt.rgba(artPalette[0].r, artPalette[0].g, artPalette[0].b, 0.18)),
                                    Qt.tint(Theme.cream, Qt.rgba(artPalette[0].r, artPalette[0].g, artPalette[0].b, 0.42))]
    function mediaToggle() { if (player) player.togglePlaying() }
    function mediaNext() { if (player) player.next() }
    function mediaPrev() { if (player) player.previous() }

    // ── apps + search ──
    readonly property var entries: DesktopEntries.applications.values.filter(e => !e.noDisplay)
    function launch(a) { if (a.entry) { launchEntry(a); return } if (a.internal) return; if (a.toggle) toggle(a.toggle); else if (a.cmd) app(a.cmd) }
    function launchEntry(a) { if (a.entry) { if (a.entry.id) app([a.entry.id.replace(/\.desktop$/, "") + ".desktop"]); else a.entry.execute() } }
    function runAction(a) { if (a.toggle) toggle(a.toggle); else if (a.tool) tool(a.tool); else if (a.cmd) run(a.cmd) }
    function score(text, q) { const t = (text || "").toLowerCase(); if (t.startsWith(q)) return 3; if (t.includes(" " + q)) return 2; if (t.includes(q)) return 1; return 0 }
    function math(q) {
        if (!/^[\d\s+\-*/().,%^x×÷]+$/.test(q) || !/[+\-*/^%x×÷]/.test(q) || !/\d/.test(q)) return "";
        try { const v = Function("return (" + q.replace(/[x×]/g, "*").replace(/÷/g, "/").replace(/\^/g, "**").replace(/,/g, ".") + ")")();
              return Number.isFinite(v) ? "= " + String(+v.toFixed(8)) : "" } catch (e) { return "" }
    }
    // Isla's own screens, so typing "wifi" or "setting" offers the page (title, screen, glyph, tint, keywords)
    readonly property var phonePages: [
        ["Settings", "settings", "gear", "#5E7A84", "setting preferences options"],
        ["Calculator", "calc", "calc", "#55BFC6", "calculator calc math sum maths", "Isla app"],
        ["Wi-Fi", "settingsWifi", "wifi", "#55BFC6", "wifi wireless network internet dns"],
        ["Bluetooth", "settingsBt", "bluetooth", "#7C83F0", "bluetooth earbuds headphones controller pair"],
        ["Sound", "settingsSound", "volume", "#7CC47F", "sound audio volume speaker mic microphone output input mixer"],
        ["Power & battery", "settingsPower", "battery", "#FFC23C", "power battery brightness sleep turbo silent mode"],
        ["Time & language", "settingsTimeLang", "globe", "#7CC47F", "time date clock timezone zone region language keyboard layout typing vietnamese 24-hour"],
        ["Mouse & touchpad", "settingsMouse", "crosshair", "#8E7BE6", "mouse touchpad trackpad speed sensitivity tap click scroll natural cursor size text size accessibility"],
        ["Apps", "settingsApps", "box", "#F7A982", "apps default browser open with files video music pdf startup autostart login"],
        ["Privacy & location", "settingsPrivacy", "shield", "#EE7D9C", "privacy location gps weather city mic microphone camera screen sharing recording in use"],
        ["Disk map", "settingsDiskMap", "chart", "#FFC23C", "disk map storage space drive full big folders clean cache treemap"],
        ["Displays", "settingsDisplays", "monitor", "#8E7BE6", "display screen monitor resolution refresh hdr brightness scale"],
        ["Keyboard shortcuts", "settingsKeys", "keyboard", "#F7A982", "keyboard shortcut keybind hotkey keys"],
        ["Screen time", "settingsTime", "chart", "#2F9EAB", "screen time usage hours apps"],
        ["System", "settingsSystem", "gear", "#5E7A84", "system about charge limit firewall ssh"],
        ["Windows", "settingsWindows", "sliders", "#55BFC6", "window opacity transparent see-through border colour color thickness corner radius rounding gap gaps"],
        ["Shell, bar & dock", "settingsQuick", "barIcon", "#EE7D9C", "shell bar dock notifications size transition theme colour color look box style ring pop glass sakura mint airplane do not disturb"],
        ["Wallpapers", "wallpapers", "wallpaper", "#A08AEA", "wallpaper background picture lockscreen phone"],
        ["Clipboard", "clipboard", "clipboard", "#FFC23C", "clipboard copy paste history"],
        ["Islands", "islands", "map", "#F7A982", "islands workspaces windows"],
        ["Quick panel", "quick", "sliders", "#55BFC6", "quick panel toggles notifications"],
        ["Profile", "profile", "smile", "#FFD45C", "profile name password avatar user account"]
    ]
    // files by name (fd) / text inside files (ripgrep, personal folders only) — debounced, newest query wins
    property var fileHits: []
    property bool fileBusy: false
    property string _fq: ""
    property string _fmode: ""
    Timer { id: fileDebounce; interval: 260; onTriggered: {
        fileP.running = false;
        const home = Quickshell.env("HOME");
        fileP.command = s._fmode === "content"
            ? ["sh", "-c", "cd \"$HOME\" && timeout 4 rg -i -n -m1 --no-heading --max-filesize 2M --max-columns 200 --max-columns-preview -- \"$0\" Documents Desktop Projects Downloads dotfiles 2>/dev/null | head -n 40", s._fq]
            : ["sh", "-c", "cd \"$HOME\" && timeout 4 fd -i --max-results 40 -E .cache -E .local -E node_modules -- \"$0\" . 2>/dev/null", s._fq];
        s.fileBusy = true; fileP.running = true;
    } }
    Process { id: fileP
        stdout: StdioCollector { onStreamFinished: {
            const home = Quickshell.env("HOME"), out = [];
            for (const l of this.text.split("\n")) {
                if (!l) continue;
                if (s._fmode === "content") {
                    const m = /^(.*?):(\d+):(.*)$/.exec(l); if (!m) continue;
                    out.push({ path: home + "/" + m[1], name: m[1].split("/").pop(), dir: m[1].split("/").slice(0, -1).join("/"), line: m[3].trim().slice(0, 140), lineNo: m[2], isDir: false });
                } else {
                    const rel = l.replace(/^\.\//, "").replace(/\/$/, ""), isDir = l.endsWith("/");
                    out.push({ path: home + "/" + rel, name: rel.split("/").pop(), dir: rel.split("/").slice(0, -1).join("/"), line: "", isDir: isDir });
                }
            }
            s.fileHits = out; s.fileBusy = false;
        } } }
    function searchFiles(q, mode) { _fq = q; _fmode = mode; fileHits = []; if (!q || q.length < 2) { fileBusy = false; fileP.running = false; return } fileDebounce.restart() }
    function openPath(p, reveal) { openApp(reveal ? ["dolphin", "--select", p] : ["xdg-open", p]) }

    function search(query) {
        const q = (query || "").trim().toLowerCase();
        if (!q) return { apps: [], actions: actions.slice(0, 4).map(a => Object.assign({ kind: "action" }, a)), math: "", pages: [] };
        const pages = phonePages.map(p => ({ p: p, sc: Math.max(score(p[0], q) * 2, score(p[4], q)) })).filter(x => x.sc > 0)
            .sort((a, b) => b.sc - a.sc).slice(0, 3).map(x => ({ kind: "page", title: x.p[0], screen: x.p[1], glyph: x.p[2], tint: x.p[3], sub: x.p[5] }));
        const apps = entries.map(e => ({ e: e, sc: Math.max(score(e.name, q) * 2, score(e.genericName, q), score((e.keywords || []).join(" "), q)) }))
            .filter(x => x.sc > 0).sort((a, b) => b.sc - a.sc || a.e.name.localeCompare(b.e.name)).slice(0, 8)
            .map(x => { const l = lookFor(x.e.startupClass || x.e.id); return { kind: "app", name: x.e.name, generic: x.e.genericName || x.e.comment || "",
                glyph: l[0] !== "grid" ? l[0] : "", tint: l[1], icon: Quickshell.iconPath(x.e.icon, true), entry: x.e } });
        const acts = actions.map(a => ({ a: a, sc: Math.max(score(a.title, q) * 2, score(a.keywords, q)) })).filter(x => x.sc > 0)
            .sort((a, b) => b.sc - a.sc).slice(0, 3).map(x => Object.assign({ kind: "action" }, x.a));
        return { apps: apps, actions: acts, math: math(q), pages: pages };
    }

    // ── notifications ──
    property var notifications: []          // newest first, for the phone
    property var toast: null                // newest one (kept for older callers)
    property int toastSerial: 0
    // desktop bubbles: up to 3 on screen, the rest wait in a queue; each stays 4 s (paused while hovered), pinned ones until clicked
    property var toasts: []                 // on screen, newest first
    property var toastQueue: []
    property bool toastHover: false
    property int _toastKey: 0
    function pushToast(item) { toastQueue = toastQueue.concat([item]); pumpToasts() }
    function pumpToasts() {
        let on = toasts.slice(), q = toastQueue.slice();
        while (on.length < 3 && q.length) { const it = q.shift(); on = [Object.assign({}, it, { key: ++_toastKey, until: Date.now() + 4000 })].concat(on) }
        toasts = on; toastQueue = q;
    }
    function dropToast(key) { toasts = toasts.filter(t => t.key !== key); pumpToasts() }
    Timer { interval: 250; repeat: true; running: s.toasts.length > 0; onTriggered: {
        const now = Date.now();
        if (s.toastHover) { s.toasts = s.toasts.map(t => Object.assign({}, t, { until: Math.max(t.until, now + 1500) })); return }
        if (s.toasts.some(t => !t.pinned && t.until <= now)) { s.toasts = s.toasts.filter(t => t.pinned || t.until > now); s.pumpToasts() }
    } }
    NotificationServer {
        id: server
        keepOnReload: false
        bodySupported: true
        actionsSupported: true
        imageSupported: true
        onNotification: n => {
            n.tracked = true;
            const item = { id: n.id, app: n.appName || "Island", body: (n.summary && n.body ? n.summary + " — " + n.body : (n.body || n.summary || "")).replace(/<[^>]+>/g, ""),
                           tint: s.tints[s.hash(n.appName || "x") % s.tints.length], obj: n, time: new Date() };
            s.notifications = [item].concat(s.notifications.filter(x => x.id !== n.id)).slice(0, 30);
            n.closed.connect(() => {
                s.notifications = s.notifications.filter(x => x.obj !== n);
                if (s.toast && s.toast.obj === n) s.toast = null;
                s.toasts = s.toasts.filter(t => t.obj !== n); s.toastQueue = s.toastQueue.filter(t => t.obj !== n); s.pumpToasts();
            });
            if (!s.dndOn && Prefs.notifications) { s.toast = item; s.toastSerial++; s.pushToast(item) }
        }
    }
    function activateNotification(item) {
        const n = item.obj; if (!n) return;
        const def = n.actions.find(a => a.identifier === "default") || n.actions[0];
        if (def) def.invoke(); else n.dismiss();
    }
    function dismissNotification(item) { if (item.obj) item.obj.dismiss() }
    function clearNotifications() { for (const it of notifications.slice()) if (it.obj) it.obj.dismiss(); notifications = [] }
}
