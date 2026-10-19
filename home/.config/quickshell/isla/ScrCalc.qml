import QtQuick

// Calculator: display card (the sum on top, the live answer big), tilted candy keys; History swaps the keys for
// a list of past sums "96 + 23 = 119" (kept in Prefs, so it survives the phone closing).
// Typing works too: digits, + - * / ( ) . · Enter = · Backspace · Esc clears / leaves History, then closes · Ctrl+C copies the answer.
// The maths is Services.math (the same as search), so both agree.
Item {
    id: c
    property var svc
    property string expr: ""
    property bool showHist: false
    readonly property var hist: Prefs.calcHistory
    signal done()
    readonly property string live: svc.math(expr).replace(/^= /, "")
    function focusField() { c.forceActiveFocus() }
    function pretty(t) { return t.replace(/([+×÷^])/g, " $1 ").replace(/([\d)])-/g, "$1 − ") }   // 96+23 → 96 + 23
    readonly property int cursorPosition: expr.length   // the phone treats this screen as a text box: keys come here, no focus ring
    function put(k) {
        if (k === "C") expr = "";
        else if (k === "⌫") expr = expr.slice(0, -1);
        else if (k === "=") { if (live) { Prefs.set("calcHistory", [[expr, live]].concat(hist).slice(0, 30)); expr = live } }
        else expr += k;
    }
    Keys.onPressed: e => {
        if ((e.modifiers & Qt.ControlModifier) && e.key === Qt.Key_C) { svc.copy(live || expr); e.accepted = true }
        else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { put("="); e.accepted = true }
        else if (e.key === Qt.Key_Backspace) { put("⌫"); e.accepted = true }
        else if (e.key === Qt.Key_Escape) { if (showHist) showHist = false; else if (expr) put("C"); else c.done(); e.accepted = true }
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
            // History ↔ Keys
            UiCandy { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; width: hl.implicitWidth + 38; height: 28; radius: 10
                bw: 2.5; ink: Theme.inkPhone; drop: 3; hi: 0; rotation: 2; pressable: true; fill: c.showHist ? Theme.inkPhone : Theme.paper
                onClicked: { c.showHist = !c.showHist; c.focusField() }
                Glyph { x: 9; anchors.verticalCenter: parent.verticalCenter; name: c.showHist ? "calc" : "reload"; size: 13; stroke: 2.6; color: c.showHist ? Theme.sun : Theme.inkPhone }
                UiText { id: hl; x: 27; anchors.verticalCenter: parent.verticalCenter; text: c.showHist ? "Keys" : "History · " + c.hist.length; px: 13; w: 700
                    color: c.showHist ? "#FFFFFF" : Theme.inkPhone } }
        }
        // display: the sum small, the answer big (click copies it)
        DropCard {
            width: parent.width; height: 120; headerH: 120; ink: Theme.inkPhone; drop: 5
            UiTag { x: parent.width - width - 18; y: -9; z: 2; text: c.live ? "= LIVE" : "READY"; fill: c.live ? Theme.sun : Theme.berry; ink: Theme.inkPhone
                textColor: c.live ? Theme.inkPhone : "#FFFFFF"; tilt: 5; px: 11 }
            // the sum on its own line, the answer big under it (no overlap)
            UiText { x: 24; y: 16; width: parent.width - 48; height: 22; horizontalAlignment: Text.AlignRight; elide: Text.ElideLeft
                text: c.live ? c.pretty(c.expr) + " =" : "Enter =  ·  click the answer to copy"; fam: "n"; px: 15; w: 800
                color: Theme.inkPhone; opacity: c.live ? 1 : 0.6 }
            Item {
                x: 20; y: 42; width: parent.width - 40; height: 60; clip: true
                UiStrokeText { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    text: c.live || c.pretty(c.expr) || "0"; px: Math.max(24, 40 - Math.max(0, text.length - 9) * 2); weight: 700; strokeW: 7; strokeColor: Theme.inkPhone }
            }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: c.svc.copy(c.live || c.expr) }
        }
        // keys: paper numbers, dark operator tiles, pink clear, sun equals
        Grid {
            id: keys
            visible: !c.showHist
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
        // history: past sums, newest first — click one to use its answer
        Item {
            visible: c.showHist
            width: parent.width; height: keys.height
            ListView {
                id: hv
                width: parent.width; height: parent.height - 40
                clip: true; spacing: 6; boundsBehavior: Flickable.StopAtBounds
                topMargin: 3; leftMargin: 3; rightMargin: 3
                model: c.hist
                delegate: UiRow {
                    required property var modelData
                    required property int index
                    width: hv.width - 6; height: 46; glyph: "calc"; title: c.pretty(modelData[0]) + " = " + modelData[1]; sub: ""
                    rotation: Theme.tilt(index) * 0.4
                    onClicked: { c.expr = modelData[1]; c.showHist = false; c.focusField() }
                }
            }
            UiText { visible: !c.hist.length; anchors.centerIn: hv; text: "No sums yet — press = to keep one"; fam: "n"; px: 12; w: 800; color: Theme.textSoft }
            UiCandy { visible: c.hist.length > 0; anchors.bottom: parent.bottom; anchors.right: parent.right; width: cl.implicitWidth + 38; height: 30; radius: 10
                bw: 2.5; ink: Theme.inkPhone; drop: 3; hi: 0; rotation: -2; pressable: true; fill: Theme.berry
                onClicked: { Prefs.set("calcHistory", []); c.focusField() }
                Glyph { x: 9; anchors.verticalCenter: parent.verticalCenter; name: "trash"; size: 13; stroke: 2.6; color: "#FFFFFF" }
                UiText { id: cl; x: 27; anchors.verticalCenter: parent.verticalCenter; text: "Clear history"; px: 13; w: 700; color: "#FFFFFF" } }
        }
    }
}
