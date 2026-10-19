import QtQuick
import Quickshell
import Quickshell.Io

// Part of Services: calendar notes (Calendar → a day → an hour). Saved to ~/.local/state/isla/schedule.json,
// pictures copied next to it (schedule/). At a note's time — only if you're logged in then — `due(note)` fires;
// Services shows it as a bubble that stays until you click it. Notes whose time passed while logged out stay quiet.
// Once per start (= every boot): notes more than 30 days old are deleted, with their pictures.
Scope {
    id: sc
    readonly property string dir: Quickshell.env("HOME") + "/.local/state/isla"
    property var notes: []                    // { id, date: "2026-10-20", hour, min, text, image }
    signal due(var note)
    function key(d) { return d.getFullYear() + "-" + String(d.getMonth() + 1).padStart(2, "0") + "-" + String(d.getDate()).padStart(2, "0") }
    function when(n) { const p = n.date.split("-").map(Number); return new Date(p[0], p[1] - 1, p[2], n.hour, n.min).getTime() }
    function onDay(date) { return notes.filter(n => n.date === date).sort((a, b) => a.hour * 60 + a.min - b.hour * 60 - b.min) }
    readonly property var days: { const o = {}; for (const n of notes) o[n.date] = true; return o }      // dots on the month grid
    function save() { file.setText(JSON.stringify(notes, null, 1) + "\n") }
    function add(date, hour, min, text, image) {
        if (!text.trim() && !image) return
        seen = Math.max(seen, Date.now())                // a note added for an earlier hour stays quiet
        notes = notes.concat([{ id: Date.now().toString(36), date: date, hour: hour, min: min, text: text.trim(), image: image || "" }]); save()
    }
    function update(id, hour, min, text, image) {
        const old = notes.find(x => x.id === id); if (!old) return
        if (old.image && old.image !== image) rm.exec(["rm", "-f", old.image])
        notes = notes.map(x => x.id === id ? Object.assign({}, x, { hour: hour, min: min, text: text.trim(), image: image || "" }) : x); save()
    }
    function remove(id) {
        const n = notes.find(x => x.id === id); if (n && n.image) rm.exec(["rm", "-f", n.image])
        notes = notes.filter(x => x.id !== id); save()
    }
    Process { id: rm }

    // a picture for a note: from the clipboard, or picked with a file dialog → copied into schedule/ → `picked(path)`
    signal picked(string path)
    function pasteImage() { pick.run('f="$1/schedule/$(date +%s%N).png"; mkdir -p "${f%/*}"; wl-paste --type image/png > "$f" 2>/dev/null && [ -s "$f" ] && echo "$f" || rm -f "$f"') }
    function chooseImage() { pick.run('s=$(zenity --file-selection --title="Picture for the note" --file-filter="Pictures | *.png *.jpg *.jpeg *.webp *.gif") || exit 0
        e="${s##*.}"; f="$1/schedule/$(date +%s%N).$e"; mkdir -p "${f%/*}"; cp "$s" "$f" && echo "$f"') }
    Process { id: pick
        function run(script) { if (!running) { command = ["sh", "-c", script, "_", sc.dir]; running = true } }
        stdout: StdioCollector { onStreamFinished: { const p = this.text.trim(); if (p) sc.picked(p) } } }

    FileView {
        id: file
        path: sc.dir + "/schedule.json"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { try { sc.notes = JSON.parse(text()) } catch (e) { sc.notes = [] }
            if (sc.pruned) return; sc.pruned = true
            const old = sc.notes.filter(n => sc.when(n) < Date.now() - 30 * 86400000); if (!old.length) return
            const pics = old.map(n => n.image).filter(x => x); if (pics.length) rm.exec(["rm", "-f"].concat(pics))
            sc.notes = sc.notes.filter(n => !old.includes(n)); sc.save() }
    }
    // reminders: anything whose time came since the last look (first look = now, so nothing old pops up)
    property real seen: Date.now()
    property bool pruned: false
    // sleeps until the next note (at most 60 s, so a suspend can't make it miss one)
    readonly property real next: { let m = Infinity; for (const n of notes) { const t = when(n); if (t > seen && t < m) m = t } return m }
    Timer {
        running: sc.next < Infinity; repeat: true; interval: Math.max(1000, Math.min(60000, sc.next - Date.now() + 500))
        onTriggered: { const now = Date.now()
            for (const n of sc.notes) { const t = sc.when(n); if (t > sc.seen && t <= now) sc.due(n) }
            sc.seen = now }
    }
}
