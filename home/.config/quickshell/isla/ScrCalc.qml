import QtQuick

// Calculator: display card (sum + live answer), last answers as chips, tilted candy keys.
// Typing works too: digits, + - * / ( ) . · Enter = · Backspace · Esc clears, then closes · Ctrl+C copies the answer.
// The maths is Services.math (the same as search), so both agree.
Item {
    id: c
    property var svc
    property string expr: ""
    property var history: []                 // last answers, newest first
    signal done()
    readonly property string live: svc.math(expr).replace(/^= /, "")
    function focusField() { c.forceActiveFocus() }
    readonly property int cursorPosition: expr.length   // the phone treats this screen as a text box: keys come here, no focus ring
    function put(k) {
        if (k === "C") expr = "";
        else if (k === "⌫") expr = expr.slice(0, -1);
        else if (k === "=") { if (live) { history = [live].concat(history.filter(h => h !== live)).slice(0, 4); expr = live } }
        else expr += k;
    }
    Keys.onPressed: e => {
        if ((e.modifiers & Qt.ControlModifier) && e.key === Qt.Key_C) { svc.copy(live || expr); e.accepted = true }
        else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { put("="); e.accepted = true }
        else if (e.key === Qt.Key_Backspace) { put("⌫"); e.accepted = true }
        else if (e.key === Qt.Key_Escape) { if (expr) put("C"); else c.done(); e.accepted = true }
        else if (/^[\d+\-*/().,x^]$/.test(e.text)) { put(e.text === "*" ? "×" : e.text === "/" ? "÷" : e.text); e.accepted = true }
    }

    Column {
        x: 18; y: 16; width: parent.width - 36
        spacing: 10
        PhoneStatus { svc: c.svc; timePx: 16 }
        // title
        Item {
            width: parent.width; height: 34
            UiCandy { width: 30; height: 30; radius: 9; bw: 2.5; ink: Theme.inkPhone; drop: 0; hi: 0; fill: Theme.sea; anchors.verticalCenter: parent.verticalCenter
                Glyph { anchors.centerIn: parent; name: "calc"; size: 15; stroke: 2.6 } }
            UiText { x: 40; anchors.verticalCenter: parent.verticalCenter; text: "Calculator"; px: 22; w: 700; color: Theme.textDeep }
        }
        // display: the sum small, the answer big (click copies it)
        DropCard {
            width: parent.width; height: 120; headerH: 120; ink: Theme.inkPhone; drop: 5
            UiTag { x: parent.width - width - 18; y: -9; z: 2; text: c.live ? "= LIVE" : "READY"; fill: c.live ? Theme.sun : Theme.berry; ink: Theme.inkPhone
                textColor: c.live ? Theme.inkPhone : "#FFFFFF"; tilt: 5; px: 11 }
            UiText { visible: c.live !== ""; x: 24; y: 20; width: parent.width - 48; horizontalAlignment: Text.AlignRight; elide: Text.ElideLeft
                text: c.expr; fam: "n"; px: 15; w: 800; color: Theme.inkPhone }
            Item {
                x: 20; y: 30; width: parent.width - 40; height: 56; clip: true
                UiStrokeText { id: ans; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    text: c.live || c.expr || "0"; px: Math.max(26, 46 - Math.max(0, text.length - 9) * 2.4); weight: 700; strokeW: 7; strokeColor: Theme.inkPhone }
            }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: c.svc.copy(c.live || c.expr) }
            // last answers: click one to use it
            Row {
                x: 20; y: parent.height - 32; spacing: 6
                UiText { anchors.verticalCenter: parent.verticalCenter; text: c.history.length ? "LAST" : "Enter = · click the answer to copy"; fam: "n"; px: 10.5; w: 900; track: 1; color: Theme.inkPhone; opacity: 0.75 }
                Repeater {
                    model: c.history
                    delegate: PhoneKeycap { required property string modelData; required property int index
                        text: modelData; rotation: Theme.tilt(index) * 2; fill: index ? Theme.paper : Theme.sun; onClicked: c.expr += modelData }
                }
            }
        }
        // keys: paper numbers, dark operator tiles, pink clear, sun equals
        Grid {
            id: keys
            columns: 4; spacing: 7
            readonly property real kw: (parent.width - 3 * spacing) / 4
            Repeater {
                model: ["C", "(", ")", "÷", "7", "8", "9", "×", "4", "5", "6", "-", "1", "2", "3", "+", "0", ".", "⌫", "="]
                delegate: UiCandy {
                    id: key
                    required property string modelData
                    required property int index
                    readonly property bool op: "÷×-+()⌫".includes(modelData)
                    width: keys.kw; height: 48; radius: 14; bw: 2.5; ink: Theme.inkPhone; drop: 4; hi: 0; pressable: true
                    rotation: Theme.tilt(index) * 0.8
                    fill: modelData === "=" ? Theme.sun : modelData === "C" ? Theme.berry : op ? Theme.inkPhone : Theme.paper
                    onClicked: { c.put(modelData); c.focusField() }
                    UiText { anchors.centerIn: parent; text: key.modelData === "-" ? "−" : key.modelData; px: 24; w: 700
                        color: key.modelData === "C" ? "#FFFFFF" : key.op ? Theme.sun : Theme.inkPhone }
                }
            }
        }
    }
}
