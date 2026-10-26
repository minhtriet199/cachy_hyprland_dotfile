import QtQuick

// Settings → Windows: number box next to a slider. Enter or click away applies; Esc puts the value back; ↑/↓ = ±1.
UiCandy {
    id: nbx
    property var page                    // the Windows page (values + put())
    property string key
    property bool pct: false
    property string unit: pct ? "%" : "px"
    property real vmin: 0
    property real vmax: 10
    readonly property int shown: Math.round(page.num(key) * (pct ? 100 : 1))
    onShownChanged: if (!ti.activeFocus) ti.text = shown
    function apply() {
        const n = parseInt(ti.text); if (isNaN(n)) { ti.text = shown; return }
        const k = pct ? 100 : 1, c = Math.max(vmin * k, Math.min(vmax * k, n))
        ti.text = c; page.put(key, pct ? c / 100 : c)
    }
    width: 70; height: 30; radius: 10; bw: 2; drop: 0; hi: 0; ink: Theme.inkPhone; fill: ti.activeFocus ? Theme.cream : Theme.paper
    TextInput {
        id: ti
        x: 8; width: parent.width - 16 - unit.implicitWidth - 3; anchors.verticalCenter: parent.verticalCenter
        horizontalAlignment: TextInput.AlignRight; selectByMouse: true
        font.family: Theme.display; font.pixelSize: 14; font.weight: 700; color: Theme.text
        validator: IntValidator { bottom: 0; top: 999 }
        Component.onCompleted: text = nbx.shown
        onEditingFinished: nbx.apply()
        Keys.onEscapePressed: { text = nbx.shown; focus = false }
        Keys.onUpPressed: { text = (parseInt(text) || 0) + 1; nbx.apply() }
        Keys.onDownPressed: { text = (parseInt(text) || 0) - 1; nbx.apply() }
    }
    UiText { id: unit; anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter
        text: nbx.unit; fam: "n"; px: 10.5; w: 900; color: Theme.textSoft }
}
