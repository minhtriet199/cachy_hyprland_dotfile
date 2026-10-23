import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Part of Services: to-do boards (bar ✓ card, big window). One Markdown file per board in ~/Documents/Todo:
//   - [ ] text               an item ("- [x]" = done)
//       - [name](<path>)     a file under it (pictures / videos show as thumbnails, other files as links)
// Opening a file pins the card on top; when the window that opened for it closes, the card unpins.
// Loads on the first open of the card (Prefs.todoLast, else a new blank board).
Scope {
    id: t
    property var svc
    readonly property string dir: Quickshell.env("HOME") + "/Documents/Todo"
    property string path: ""                        // the open board
    readonly property string name: path ? path.split("/").pop().replace(/\.md$/, "") : ""
    property var items: []                          // { text, done, files: [path] }
    readonly property int done: items.filter(i => i.done).length
    property var boards: []                         // { path, name, time (ms), done, total }, newest first
    property bool pinned: false                     // card stays up over other windows (clicks go through around it)
    property bool bigOpen: false                    // the big window

    function kind(f) {
        const e = f.split(".").pop().toLowerCase();
        return ["png", "jpg", "jpeg", "webp", "gif", "bmp", "avif"].includes(e) ? "img" : ["mp4", "mkv", "webm", "mov", "avi", "m4v"].includes(e) ? "video" : "file"
    }

    // ── board file ⇄ items ──
    function parse(txt) {
        const out = [];
        for (const l of txt.split("\n")) {
            let m = /^- \[([ xX])\] ?(.*)$/.exec(l);
            if (m) { out.push({ text: m[2], done: m[1] !== " ", files: [] }); continue }
            m = /^\s+- \[.*?\]\(<?(.*?)>?\)\s*$/.exec(l);
            if (m && out.length) out[out.length - 1].files.push(m[1]);
        }
        return out;
    }
    function render() {
        return "# " + name + "\n\n" + items.map(i => "- [" + (i.done ? "x" : " ") + "] " + i.text.replace(/\n/g, " ")
            + i.files.map(f => "\n    - [" + f.split("/").pop() + "](<" + f + ">)").join("")).join("\n") + "\n";
    }
    function setItems(v) { items = v; if (path) { file.setText(render()); listSoon.restart() } }
    function add(txt, files) { if (!txt.trim() && !files.length) return; setItems(items.concat([{ text: txt.trim(), done: false, files: files }])) }
    function toggle(i) { setItems(items.map((x, k) => k === i ? Object.assign({}, x, { done: !x.done }) : x)) }
    function edit(i, txt) { setItems(items.map((x, k) => k === i ? Object.assign({}, x, { text: txt.trim() }) : x)) }
    function remove(i) { setItems(items.filter((x, k) => k !== i)) }
    function unattach(i, f) { setItems(items.map((x, k) => k === i ? Object.assign({}, x, { files: x.files.filter(y => y !== f) }) : x)) }
    FileView {
        id: file
        path: t.path
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: t.items = t.parse(text())
        onLoadFailed: t.items = []
    }

    // ── boards ──
    function open(p) { path = p; Prefs.set("todoLast", p) }
    property bool started: false
    function start() { if (started) return; started = true; listP.first = true; listP.running = true }
    function newBoard() { act.go('mkdir -p "$1"; n="New board"; i=1; while [ -e "$1/$n.md" ]; do i=$((i+1)); n="New board $i"; done; printf "# %s\\n\\n" "$n" > "$1/$n.md" && echo "$1/$n.md"', [], p => t.open(p)) }
    function rename(n) {
        n = n.replace(/[\/\n]/g, " ").trim(); if (!n || n === name || !path) return
        act.go('[ -e "$1/$2.md" ] && exit 0; mv "$3" "$1/$2.md" && echo "$1/$2.md"', [n, path], p => { if (p) { t.open(p); t.setItems(t.items) } })
    }
    function removeBoard(p) { act.go('rm -f "$2"', [p], () => { if (p === t.path) { t.path = ""; t.items = [] } }) }
    Process {
        id: act
        property var then: null
        function go(script, args, cb) { if (running) return; then = cb; command = ["sh", "-c", script, "_", t.dir].concat(args); running = true }
        stdout: StdioCollector { onStreamFinished: { const p = this.text.trim(); if (act.then) act.then(p); listSoon.restart() } }
    }
    Timer { id: listSoon; interval: 300; onTriggered: listP.running = true }
    function list() { listP.running = true }
    Process {
        id: listP
        property bool first: false
        command: ["sh", "-c", 'cd "$0" 2>/dev/null || exit 0; for f in *.md; do [ -e "$f" ] || continue; printf "%s\\t%s\\t%s\\t%s\\n" "$PWD/$f" "$(stat -c %Y "$f")" "$(grep -c "^- \\[[xX]\\]" "$f")" "$(grep -c "^- \\[[ xX]\\]" "$f")"; done', t.dir]
        stdout: StdioCollector { onStreamFinished: {
            t.boards = this.text.split("\n").filter(l => l).map(l => { const p = l.split("\t");
                return { path: p[0], name: p[0].split("/").pop().replace(/\.md$/, ""), time: parseInt(p[1]) * 1000, done: parseInt(p[2]) || 0, total: parseInt(p[3]) || 0 } })
                .sort((a, b) => b.time - a.time);
            if (listP.first) { listP.first = false; if (t.boards.some(b => b.path === Prefs.todoLast)) t.path = Prefs.todoLast; else t.newBoard() }
        } }
    }

    // ── attachments: a picture from the clipboard (saved into files/), or any files from a dialog (linked where they are) ──
    signal picked(var files)
    function pasteImage() { pick.go('f="$1/files/$(date +%s%N).png"; mkdir -p "${f%/*}"; wl-paste --type image/png > "$f" 2>/dev/null && [ -s "$f" ] && echo "$f" || rm -f "$f"') }
    function chooseFiles() { pick.go('zenity --file-selection --multiple --separator="\n" --title="Attach to the to-do" 2>/dev/null || true') }
    Process {
        id: pick
        function go(script) { if (!running) { command = ["sh", "-c", script, "_", t.dir]; running = true } }
        stdout: StdioCollector { onStreamFinished: { const f = this.text.split("\n").filter(x => x); if (f.length) t.picked(f) } }
    }

    // ── open a file (Ctrl = show it in Dolphin): the card pins until the window that opened for it closes ──
    property string watchAddr: ""
    property real watchSince: 0
    function openFile(f, reveal) {
        pinned = true; watchAddr = ""; watchSince = Date.now();
        svc.app(reveal ? ["dolphin", "--select", f] : ["xdg-open", f]);
    }
    Connections {
        target: Hyprland
        function onRawEvent(ev) {
            if (ev.name === "openwindow" && t.watchSince && !t.watchAddr && Date.now() - t.watchSince < 15000) t.watchAddr = ev.data.split(",")[0];
            else if (ev.name === "closewindow" && t.watchAddr && ev.data === t.watchAddr) { t.watchAddr = ""; t.watchSince = 0; t.pinned = false }
        }
    }
    onPinnedChanged: if (!pinned) { watchAddr = ""; watchSince = 0 }
}
