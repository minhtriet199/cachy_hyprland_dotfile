import QtQuick
import Quickshell
import Quickshell.Io

// Part of Services: Island Link. One open connection to island-link-pc's control socket: its state arrives as events
// (no polling), Download mode's state goes out, and what the phone asks for comes in and runs through Services, the same
// way Island's own buttons do. If the helper isn't running this only retries now and then.
Scope {
    id: lk
    property var svc
    property var state: ({ phones: [], terminal: false, termOpen: false, pairing: false })
    readonly property bool up: sock.connected
    readonly property var phone: state.phones.length ? state.phones[0] : null
    readonly property bool online: !!phone && phone.connected
    readonly property bool termOpen: state.termOpen
    property string qr: ""                     // the pairing QR's picture while it's valid
    property string qrError: ""
    property real qrUntil: 0
    property int qrStamp: 0                    // a new picture at the same path: reload it

    function send(line) { if (sock.connected) { sock.write(line + "\n"); sock.flush() } }
    function pair() { qrError = ""; send("pair") }
    function forget(id) { send("forget " + id) }
    function setTerminal(on) { send("terminal " + (on ? 1 : 0)) }
    function closeTerm() { send("term-close") }
    // the phone's screen in a window here: island-link-pc asks the phone (a tap + "Start now" there) and opens it
    property string screenError: ""
    function showScreen() { screenError = ""; send("screen") }

    Socket {
        id: sock
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/island-link/ctl.sock"
        connected: true
        onConnectedChanged: if (connected) { lk.send("subscribe"); lk.send("dl " + lk.dlState) } else lk.state = ({ phones: [], terminal: false, termOpen: false, pairing: false })
        parser: SplitParser { onRead: line => {
            let v; try { v = JSON.parse(line) } catch (e) { return }
            if (v.ev === "state") lk.state = v;
            else if (v.ev === "pair") {
                if (v.qr) { lk.qr = "file://" + v.qr; lk.qrStamp++; lk.qrUntil = v.expires * 1000 }
                else lk.qrError = v.error || "Install qrencode to show the code";
            }
            else if (v.ev === "do") lk.run(v.what);
            else if (v.ev === "error") lk.screenError = v.error || "";
        } }
    }
    Timer { interval: 15000; repeat: true; running: !sock.connected; onTriggered: { sock.connected = false; sock.connected = true } }
    // the QR burns out: on pairing, or after 3 min
    Timer { interval: Math.max(1, lk.qrUntil - Date.now()); running: lk.qr !== ""; onTriggered: lk.qr = "" }
    onOnlineChanged: if (online) qr = ""

    // what the phone asked for; island-link-pc only lets these names through
    function run(what) {
        const d = svc.download;
        if (what === "dl.start-keep") d.begin("keep");
        else if (what === "dl.start-shutdown") d.begin("shutdown");
        else if (what === "dl.stop") d.stop();
        else if (what === "dl.keep") d.keepUsing();
        else if (what === "dl.shutdown") d.shutDownNow();
        else if (what === "dl.after-keep") d.after = "keep";
        else if (what === "dl.after-shutdown") d.after = "shutdown";
        else if (["lock", "suspend", "reboot", "shutdown"].includes(what)) svc.power(what);
    }

    // Download mode for the phone's progress bar; only changes while the mode is on
    readonly property var d: svc.download
    readonly property string dlState: JSON.stringify({ on: d.on, after: d.after, items: d.items, speed: d.speed, saw: d.saw, quiet: d.quiet,
                                                       asking: d.asking, countdown: d.countdown, names: d.doneNames })
    onDlStateChanged: send("dl " + dlState)
}
