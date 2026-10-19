import QtQuick
import Quickshell
import Quickshell.Io

// Part of Services: OBS recording for the bar timer. tools/obsctl.py writes isla-share/rec when it starts ("<start ms>")
// and stops ("0") a recording — watched here, no polling. While recording, OBS is asked every 10 s in case it was
// stopped from OBS itself; `obsUp` (from the Services status poll) false = OBS closed = not recording.
Scope {
    id: r
    property bool obsUp: false
    property real since: 0                      // ms since epoch, 0 = not recording
    readonly property bool recording: since > 0 && obsUp
    property string time: "00:00"
    FileView {
        path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/isla-share/rec"
        watchChanges: true; printErrors: false
        onFileChanged: reload()
        onLoaded: r.since = parseFloat(text()) || 0
        onLoadFailed: r.since = 0
    }
    Process { id: ask; command: ["python3", Quickshell.env("HOME") + "/.config/quickshell/isla/tools/obsctl.py", "status"]
        stdout: StdioCollector { onStreamFinished: { try { if (!JSON.parse(this.text).rec) r.since = 0 } catch (e) {} } } }
    Timer { interval: 10000; repeat: true; running: r.recording; onTriggered: if (!ask.running) ask.running = true }
    Timer { interval: 1000; repeat: true; triggeredOnStart: true; running: r.recording
        onTriggered: { const t = Math.max(0, Math.floor((Date.now() - r.since) / 1000)), h = Math.floor(t / 3600), p = n => String(n).padStart(2, "0")
            r.time = (h ? h + ":" : "") + p(Math.floor(t / 60) % 60) + ":" + p(t % 60) } }
}
