import QtQuick

// Isla text. fam: "f" Fredoka (titles) · "n" Nunito (small text) · "t" Titan One (candy)
Text {
    property string fam: "f"
    property int w: 600
    property real px: 16
    property real track: 0
    font.family: fam === "n" ? Theme.body : (fam === "t" ? Theme.candy : Theme.display)
    font.weight: w
    font.pixelSize: px
    font.letterSpacing: track
    color: Theme.text
    verticalAlignment: Text.AlignVCenter
    elide: Text.ElideRight
}
