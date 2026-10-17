pragma Singleton
import QtQuick
import Quickshell

// ─────────────────────────────────────────────────────────────
//  Isla design tokens — copied from the Claude Design canvas.
//  Every size in Isla is in "design pixels" (1920×1080 screen).
//  Each screen scales the whole shell by  screenHeight / 1080.
// ─────────────────────────────────────────────────────────────
Singleton {
    id: t

    // ── Fonts (bundled in ./fonts, no install needed) ──
    readonly property string display: "Fredoka"     // titles, pills, numbers
    readonly property string body: "Nunito"         // small text
    readonly property string candy: "Titan One"     // big sticker clock
    property list<FontLoader> _fonts: [
        FontLoader { source: Qt.resolvedUrl("fonts/Fredoka-SemiBold.ttf") },
        FontLoader { source: Qt.resolvedUrl("fonts/Fredoka-Bold.ttf") },
        FontLoader { source: Qt.resolvedUrl("fonts/Nunito-Bold.ttf") },
        FontLoader { source: Qt.resolvedUrl("fonts/Nunito-ExtraBold.ttf") },
        FontLoader { source: Qt.resolvedUrl("fonts/Nunito-Black.ttf") },
        FontLoader { source: Qt.resolvedUrl("fonts/TitanOne-Regular.ttf") }
    ]

    // ── Ink (outlines + solid drop shadows) ──
    readonly property color ink: "#3D5A66"          // bar, dock, desktop widgets
    readonly property color inkPhone: "#213F48"     // phone + settings
    readonly property color inkClock: "#2B4A54"     // sticker clock

    // ── Text ──
    readonly property color text: "#33505B"
    readonly property color textSoft: "#5E7A84"
    readonly property color textMuted: "#4F6B75"
    readonly property color textDeep: "#213F48"

    // ── Surfaces ──
    readonly property color cream: "#FFF9EC"
    readonly property color paper: "#FFFDF6"
    readonly property color sand: "#F2E3C6"
    readonly property color screenDot: "#F1E2C2"
    readonly property color hi: Qt.rgba(1, 1, 1, 0.75)   // inset top highlight

    // ── Candy pill gradients [top, bottom] ──
    readonly property var gSea:    ["#E6F8FA", "#BEE9EE"]
    readonly property var gLilac:  ["#F1ECFE", "#D9CEFA"]
    readonly property var gPeach:  ["#FFEDE3", "#FBCDB5"]
    readonly property var gSun:    ["#FFF7DA", "#FFE39A"]
    readonly property var gBerry:  ["#FDE8EE", "#F6BFD0"]
    readonly property var gLeaf:   ["#E7F6E7", "#BFE6C2"]
    readonly property var gChip:   ["#E6F8FA", "#C4ECF0"]
    readonly property var gActive: ["#C9B9F7", "#9C86E6"]   // current workspace, active tab
    readonly property var gPhone:  ["#8FD9DE", "#55BFC6"]
    readonly property var gOn:     ["#D8F1F4", "#A9DDE4"]   // toggled tile
    readonly property var gGo:     ["#93D296", "#6BB86F"]   // selected search row
    readonly property var gDock:   ["#FFFDF7", "#FFF0D4"]
    readonly property var gTab:    ["#C9B9F7", "#A08AEA"]
    readonly property var gLilacSoft: ["#D9CEFA", "#B7A5F2"]
    readonly property var gSettings:  ["#E6DEFB", "#C9B9F7"]

    // ── Solid accents ──
    readonly property color leaf: "#7CC47F"
    readonly property color leafDeep: "#3E9A5D"
    readonly property color sun: "#FFD45C"
    readonly property color sunDeep: "#FFC23C"
    readonly property color sea: "#55BFC6"
    readonly property color seaDeep: "#2F9EAB"
    readonly property color lilac: "#A893EC"
    readonly property color lilacSoft: "#B9A6F0"
    readonly property color purple: "#8E7BE6"
    readonly property color berry: "#EE7D9C"
    readonly property color peach: "#F7A982"
    readonly property color orange: "#F7A04B"
    readonly property color indigo: "#7C83F0"
    readonly property color slate: "#5E7A84"
    readonly property color pinkSoft: "#F6BFD0"
    readonly property color seaSoft: "#A9DDE4"

    // ── Phone body ──
    readonly property color phoneA: "#6FA2AC"
    readonly property color phoneB: "#2F5A65"
    readonly property color phoneKey: "#7DB3BD"
    readonly property color phoneKeyHi: "#A9DDE4"
    readonly property color phoneWallA: "#4C7F8A"
    readonly property color phoneWallB: "#2C5560"
    readonly property color phoneBack: "#1A333B"
    readonly property color scrim: Qt.rgba(33 / 255, 63 / 255, 72 / 255, 0.30)

    // Colour by name, so configs can say tint: "berry"
    function c(name) { return t[name] !== undefined ? t[name] : sea }

    // ── Motion ──
    readonly property int fast: 140
    readonly property int base: 260
    readonly property int slow: 460
}
