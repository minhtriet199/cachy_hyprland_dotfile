import QtQuick

// The lock / unlock scene change, by Settings → Shell → Lock & unlock transition → Type:
// "iris" = IrisWipe (circle + icon) · "jake" = JakeWipe (built only while picked). Same mode + t for both.
Item {
    id: sw
    property real t: 0
    property string mode: "none"
    readonly property bool jake: Prefs.wipeKind === "jake"
    visible: mode !== "none"
    IrisWipe { anchors.fill: parent; visible: !sw.jake && sw.mode !== "none"; mode: sw.jake ? "none" : sw.mode; t: sw.t }
    Loader { anchors.fill: parent; active: sw.jake
        sourceComponent: JakeWipe { mode: sw.mode; t: sw.t } }
}
