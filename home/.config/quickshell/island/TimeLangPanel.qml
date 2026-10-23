import QtQuick
import Quickshell
import Quickshell.Io

// Time & language page: auto time, time zone (search list), auto time zone, 24-hour clock,
// region format, keyboard layouts, EN/VI typing (fcitx5). System changes go through timedatectl /
// localectl, which ask for the password in Island's polkit dialog. Data: tools/timelang.py.
Item {
    id: tl
    property var svc
    implicitHeight: col.implicitHeight
    property var d: ({ ntp: true, synced: true, tz: "", zones: [], lang: "", region: "", locale: ({}), regions: [], ims: [], trigger: "", share: "All" })
    property var inp: ({ kb_layout: "us", kb_options: "" })
    property bool tzOpen: false
    property string tzFilter: ""
    property string msg: ""
    readonly property string tool: Quickshell.shellDir + "/tools/timelang.py"
    readonly property string inputTool: Quickshell.env("HOME") + "/.config/hypr/scripts/inputctl.py"

    function load() { getP.running = true; inGet.running = true }
    Component.onCompleted: load()
    Process { id: getP; command: ["python3", tl.tool]
        stdout: StdioCollector { onStreamFinished: { try { tl.d = JSON.parse(this.text) } catch (e) {} } } }
    Process { id: inGet; command: ["python3", tl.inputTool, "get"]
        stdout: StdioCollector { onStreamFinished: { try { tl.inp = JSON.parse(this.text) } catch (e) {} } } }
    // a system change: run it, then read everything again (the polkit dialog shows if a password is needed)
    Process { id: act
        stderr: StdioCollector { id: actErr }
        onExited: code => { tl.msg = code === 0 ? "" : (actErr.text.includes("auth") || actErr.text.includes("ermission") ? "Not changed — password was cancelled" : "Not changed"); tl.load() } }
    function sys(cmd) { if (act.running) return; msg = ""; act.command = cmd; act.running = true }
    function setInput(args) { inSet.command = ["python3", inputTool, "set"].concat(args); inSet.running = true }
    Process { id: inSet; onExited: inGet.running = true }

    // names people know, for the codes the system uses
    readonly property var regionNames: ({ en_US: "English (US)", en_GB: "English (UK)", vi_VN: "Tiếng Việt", fr_FR: "Français", de_DE: "Deutsch", ja_JP: "日本語", ko_KR: "한국어", zh_CN: "中文" })
    function regionName(c) { const k = String(c).replace(/\.utf-?8$/i, "").replace(/\.UTF-8$/, ""); return regionNames[k] || k }
    readonly property var layouts: [["us", "English (US)"], ["gb", "English (UK)"], ["vn", "Vietnamese"], ["fr", "French"], ["de", "German"], ["jp", "Japanese"], ["kr", "Korean"], ["ru", "Russian"]]
    readonly property var curLayouts: (inp.kb_layout || "us").split(",")
    readonly property var switchKeys: [["grp:alt_shift_toggle", "Alt + Shift"], ["grp:win_space_toggle", "Super + Space"], ["grp:caps_toggle", "Caps Lock"]]
    function toggleLayout(code) {
        let l = curLayouts.slice();
        if (l.includes(code)) { if (l.length === 1) return; l = l.filter(x => x !== code) } else l.push(code);
        const opts = l.length > 1 ? (inp.kb_options && inp.kb_options.startsWith("grp:") ? inp.kb_options : "grp:alt_shift_toggle") : "";
        setInput(["kb_layout=" + l.join(","), "kb_options=" + opts]);
    }
    readonly property var imNames: ({ "keyboard-us": "English", "bamboo": "Vietnamese (Bamboo)", "unikey": "Vietnamese (Unikey)" })

    component Label: UiText { fam: "n"; px: 11; w: 900; track: 1.4; color: Theme.textSoft; height: 18 }
    component Chip: UiCandy {
        id: ch
        property string text
        property bool on: false
        width: chT.implicitWidth + 26; height: 32; radius: 10; bw: 2; drop: on ? 0 : 2; hi: 0
        fill: on ? Theme.gOn : Theme.cream; pressable: true
        UiText { id: chT; anchors.centerIn: parent; text: (ch.on ? "✓ " : "") + ch.text; px: 12.5; w: 700 }
    }

    Column {
        id: col
        width: tl.width; spacing: 10

        UiText { visible: tl.msg !== ""; width: parent.width; text: tl.msg; fam: "n"; px: 11.5; w: 800; color: Theme.berry; wrapMode: Text.Wrap }

        // ── clock ──
        Label { text: "DATE & TIME" }
        UiCandy {
            width: parent.width; height: 74; radius: 16; bw: 2.5; drop: 3; hi: 0; ink: Theme.inkPhone; fill: Theme.gSea
            UiText { x: 16; y: 10; text: tl.svc.timeText; px: 28; w: 700 }
            UiText { x: 16; y: 46; text: Qt.formatDate(tl.svc.now, "dddd, d MMMM yyyy"); fam: "n"; px: 11.5; w: 800; color: Theme.textSoft }
            UiTag { anchors.right: parent.right; anchors.rightMargin: 14; y: 12; text: tl.d.synced ? "SYNCED" : "NOT SYNCED"; fill: tl.d.synced ? Theme.leaf : Theme.orange; ink: Theme.inkPhone; px: 11; tilt: 4 }
        }
        UiRow {
            width: parent.width; glyph: "reload"; title: "Set time automatically"; sub: tl.d.ntp ? "From the internet" : "Off · the clock may drift"
            active: tl.d.ntp
            onClicked: tl.sys(["timedatectl", "set-ntp", tl.d.ntp ? "false" : "true"])
            UiSwitch { on: tl.d.ntp; onToggled: tl.sys(["timedatectl", "set-ntp", tl.d.ntp ? "false" : "true"]) }
        }
        UiRow {
            width: parent.width; glyph: "calendar"; title: "24-hour clock"; sub: Prefs.h24 ? "14:30" : "2:30 PM"
            active: Prefs.h24; onClicked: Prefs.set("h24", !Prefs.h24)
            UiSwitch { on: Prefs.h24; onToggled: Prefs.set("h24", !Prefs.h24) }
        }

        // ── time zone ──
        Item { width: 1; height: 2 }
        Label { text: "TIME ZONE" }
        UiRow {
            width: parent.width; glyph: "globe"; title: tl.d.tz ? tl.d.tz.replace(/_/g, " ").replace("/", " · ") : "…"
            sub: tl.tzOpen ? "Pick one below" : "Tap to change"; active: tl.tzOpen; busy: act.running
            onClicked: { tl.tzOpen = !tl.tzOpen; tzQ.text = "" }
            Glyph { name: "arrowRight"; size: 15; stroke: 2.6; rotation: tl.tzOpen ? 90 : 0 }
        }
        UiCandy {
            visible: tl.tzOpen
            width: parent.width; height: 250; radius: 14; bw: 2; drop: 0; hi: 0; fill: Theme.paper
            UiCandy {
                x: 8; y: 8; width: parent.width - 16; height: 32; radius: 10; bw: 2; drop: 0; hi: 0; fill: Theme.cream
                Glyph { x: 9; anchors.verticalCenter: parent.verticalCenter; name: "search"; size: 14; stroke: 2.6 }
                TextInput {
                    id: tzQ; x: 30; width: parent.width - 40; anchors.verticalCenter: parent.verticalCenter; clip: true
                    font.family: Theme.body; font.weight: 800; font.pixelSize: 13; color: Theme.text
                    onTextChanged: tl.tzFilter = text
                    UiText { visible: !tzQ.text; text: "Search a city, e.g. Tokyo"; fam: "n"; px: 12; w: 800; color: Theme.textSoft; anchors.verticalCenter: parent.verticalCenter }
                }
            }
            ListView {
                id: tzList
                x: 8; y: 46; width: parent.width - 16; height: parent.height - 54; clip: true; spacing: 4; boundsBehavior: Flickable.StopAtBounds
                model: { const f = tl.tzFilter.toLowerCase().replace(/ /g, "_"); return tl.d.zones.filter(z => !f || z.toLowerCase().includes(f)).slice(0, 200) }
                delegate: UiCandy {
                    required property string modelData
                    readonly property bool cur: modelData === tl.d.tz
                    width: tzList.width; height: 32; radius: 9; bw: 2; drop: 0; hi: 0; fill: cur ? Theme.gOn : Theme.cream; pressable: !cur
                    onClicked: { tl.sys(["timedatectl", "set-timezone", modelData]); tl.tzOpen = false }
                    UiText { x: 10; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 20; elide: Text.ElideRight
                        text: (cur ? "✓ " : "") + modelData.replace(/_/g, " ").replace(/\//g, " · "); px: 12.5; w: 700 }
                }
            }
        }
        UiRow {
            width: parent.width; glyph: "map"; title: "Set time zone automatically"
            sub: !Prefs.location ? "Needs Location (Privacy & location)" : Prefs.autoTz ? "Follows where you are when the network changes" : "Off"
            active: Prefs.autoTz && Prefs.location
            onClicked: { Prefs.set("autoTz", !Prefs.autoTz); if (!Prefs.autoTz) return; tl.svc.checkTimeZone() }
            UiSwitch { on: Prefs.autoTz && Prefs.location; onToggled: { Prefs.set("autoTz", !Prefs.autoTz); if (Prefs.autoTz) tl.svc.checkTimeZone() } }
        }

        // ── region / language ──
        Item { width: 1; height: 2 }
        Label { text: "REGION FORMAT · DATES, NUMBERS, MONEY" }
        Flow {
            width: parent.width; spacing: 8
            Repeater {
                model: tl.d.regions
                delegate: Chip {
                    required property string modelData
                    text: tl.regionName(modelData); on: tl.regionName(tl.d.region) === tl.regionName(modelData)
                    onClicked: {
                        if (on) return;
                        const vars = ["LANG=" + (tl.d.lang || "en_US.UTF-8")];
                        for (const k of ["LC_NUMERIC", "LC_TIME", "LC_MONETARY", "LC_PAPER", "LC_NAME", "LC_ADDRESS", "LC_TELEPHONE", "LC_MEASUREMENT", "LC_IDENTIFICATION"]) vars.push(k + "=" + modelData);
                        tl.sys(["localectl", "set-locale"].concat(vars));
                    }
                }
            }
        }
        Label { text: "LANGUAGE OF APPS" }
        Flow {
            width: parent.width; spacing: 8
            Repeater {
                model: tl.d.regions
                delegate: Chip {
                    required property string modelData
                    text: tl.regionName(modelData); on: tl.regionName(tl.d.lang) === tl.regionName(modelData)
                    onClicked: {
                        if (on) return;
                        const vars = ["LANG=" + modelData + ".UTF-8"];
                        for (const k in tl.d.locale) if (k !== "LANG") vars.push(k + "=" + tl.d.locale[k]);
                        tl.sys(["localectl", "set-locale"].concat(vars));
                    }
                }
            }
        }
        UiText { width: parent.width; wrapMode: Text.Wrap; fam: "n"; px: 10.5; w: 800; color: Theme.textSoft
            text: "Region and language changes show after you log out and back in." }

        // ── keyboard layouts ──
        Item { width: 1; height: 2 }
        Label { text: "KEYBOARD LAYOUTS" }
        Flow {
            width: parent.width; spacing: 8
            Repeater {
                model: tl.layouts
                delegate: Chip {
                    required property var modelData
                    text: modelData[1]; on: tl.curLayouts.includes(modelData[0])
                    onClicked: tl.toggleLayout(modelData[0])
                }
            }
        }
        Column {
            visible: tl.curLayouts.length > 1
            width: parent.width; spacing: 8
            UiText { text: "Switch layouts with"; px: 13; w: 700; height: 18 }
            Flow {
                width: parent.width; spacing: 8
                Repeater {
                    model: tl.switchKeys
                    delegate: Chip {
                        required property var modelData
                        text: modelData[1]; on: tl.inp.kb_options === modelData[0]
                        onClicked: tl.setInput(["kb_options=" + modelData[0]])
                    }
                }
            }
        }

        // ── EN / VI typing ──
        Item { width: 1; height: 2 }
        Label { text: "TYPING · EN / VI" }
        UiCandy {
            width: parent.width; height: imCol.implicitHeight + 24; radius: 15; bw: 2.5; drop: 0; hi: 0; fill: Theme.cream
            Column {
                id: imCol; x: 12; y: 12; width: parent.width - 24; spacing: 8
                Flow {
                    width: parent.width; spacing: 6
                    Repeater {
                        model: tl.d.ims
                        delegate: UiTag { required property string modelData; text: tl.imNames[modelData] || modelData; px: 12; fill: modelData === "keyboard-us" ? Theme.seaSoft : Theme.sun; ink: Theme.inkPhone; tilt: 0 }
                    }
                }
                Row {
                    spacing: 6
                    UiText { text: "Switch with"; fam: "n"; px: 11.5; w: 800; color: Theme.textSoft; anchors.verticalCenter: parent.verticalCenter }
                    Repeater {
                        model: (tl.d.trigger || "").replace("Control", "Ctrl").replace(/_[LR]$/, "").split("+")
                        delegate: UiCandy { required property string modelData; width: kt.implicitWidth + 14; height: 24; radius: 7; bw: 2; drop: 2; hi: 0; fill: Theme.paper
                            UiText { id: kt; anchors.centerIn: parent; text: modelData; px: 11; w: 700 } }
                    }
                }
            }
        }
        UiRow {
            width: parent.width; glyph: "keyboard"; title: "Same EN / VI in every window"
            sub: tl.d.share === "All" ? "Switching once works everywhere" : "Each window remembers its own"
            active: tl.d.share === "All"
            onClicked: tl.sys(["python3", tl.tool, "share", tl.d.share === "All" ? "No" : "All"])
            UiSwitch { on: tl.d.share === "All"; onToggled: tl.sys(["python3", tl.tool, "share", tl.d.share === "All" ? "No" : "All"]) }
        }
        UiRow {
            width: parent.width; glyph: "sliders"; title: "More typing settings"; sub: "Add languages, change the switch key"
            onClicked: tl.svc.openApp("fcitx5-configtool")
            Glyph { name: "external"; size: 15; stroke: 2.6 }
        }
    }
}
