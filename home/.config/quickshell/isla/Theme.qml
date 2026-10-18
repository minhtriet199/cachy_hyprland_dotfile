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

    // ── Colour themes (Settings → Shell → Look). A palette only lists what it changes; the rest stays Isla.
    //    Kind colours (leaf, sun, peach, berry…) keep their meaning in every theme. ──
    readonly property var palettes: ({
        isla: { name: "Isla" },
        sakura: { name: "Sakura", ink: "#6A4C93", inkPhone: "#5B3F86", inkClock: "#62458C", text: "#5B3F86", textSoft: "#9A7FB8", textMuted: "#7E64A3", textDeep: "#4A2F72",
            cream: "#FFF4FB", paper: "#FFF9FD", sand: "#F6DDF0", screenDot: "#F3D6EC",
            gSea: ["#FCE8F7", "#F6CDEE"], gChip: ["#FCE8F7", "#F6CDEE"], gOn: ["#FCE3F6", "#F6C6EC"], gActive: ["#E6B8F2", "#C98BE3"], gTab: ["#E6B8F2", "#C190E6"],
            gPhone: ["#F2B5E3", "#D98BCB"], gSettings: ["#F3DDF9", "#E6B8F2"], gDock: ["#FFF9FD", "#FBE6F5"], gLilacSoft: ["#E6B8F2", "#C98BE3"],
            sea: "#E58BC9", seaDeep: "#C565A9", seaSoft: "#F6C6EC", lilac: "#C190E6", lilacSoft: "#D3ABEE", purple: "#9B6BD6",
            phoneA: "#C99BD9", phoneB: "#6A4C93", phoneKey: "#D6AEE3", phoneKeyHi: "#F2CCF0", phoneWallA: "#9C76B8", phoneWallB: "#5B3F86", phoneBack: "#3A2556" },
        mint: { name: "Mint", ink: "#2F5D50", inkPhone: "#244B40", inkClock: "#2A5347", text: "#30584C", textSoft: "#5E8A7C", textMuted: "#4D7A6C", textDeep: "#244B40",
            cream: "#F3FBF6", paper: "#FAFFFC", sand: "#DCEFE3", screenDot: "#D5EBDD",
            gSea: ["#E3F7EC", "#C2EBD5"], gChip: ["#E3F7EC", "#C2EBD5"], gOn: ["#DDF5E8", "#B4E6CB"], gActive: ["#9FDCC0", "#6CC39E"], gTab: ["#9FDCC0", "#73C7A2"],
            gPhone: ["#8FD9B8", "#55B98F"], gSettings: ["#D7F2E4", "#A9DFC4"], gDock: ["#FAFFFC", "#E2F5EA"], gLilacSoft: ["#B4E6CB", "#8FD3B3"],
            sea: "#55B98F", seaDeep: "#2F9A6E", seaSoft: "#B4E6CB",
            phoneA: "#6FAC94", phoneB: "#2F5D50", phoneKey: "#86C2AA", phoneKeyHi: "#B4E6CB", phoneWallA: "#4C8A72", phoneWallB: "#2C5548", phoneBack: "#1A3A30" },
        sunset: { name: "Sunset", ink: "#6B4038", inkPhone: "#5A322B", inkClock: "#633A32", text: "#6B4038", textSoft: "#A2746A", textMuted: "#8A5D53", textDeep: "#5A322B",
            cream: "#FFF6EE", paper: "#FFFBF6", sand: "#F7DFCB", screenDot: "#F3D8C2",
            gSea: ["#FFEBDD", "#FBD2BA"], gChip: ["#FFEBDD", "#FBD2BA"], gOn: ["#FFE6D6", "#FBC6A8"], gActive: ["#F9B79A", "#EE8B6A"], gTab: ["#F9B79A", "#F0936F"],
            gPhone: ["#F7B08F", "#E5845F"], gSettings: ["#FDE3D3", "#F9B79A"], gDock: ["#FFFBF6", "#FFE9D6"], gLilacSoft: ["#F9B79A", "#EE8B6A"],
            sea: "#EE8B6A", seaDeep: "#D06A48", seaSoft: "#FBC6A8",
            phoneA: "#D9967E", phoneB: "#6B4038", phoneKey: "#E6AE98", phoneKeyHi: "#FBC6A8", phoneWallA: "#A86A57", phoneWallB: "#5A322B", phoneBack: "#3A1E19" },
        lavender: { name: "Lavender", ink: "#4B4E8C", inkPhone: "#3C3F7A", inkClock: "#444784", text: "#45487F", textSoft: "#7C7FB0", textMuted: "#62659A", textDeep: "#3C3F7A",
            cream: "#F6F5FF", paper: "#FBFAFF", sand: "#E3E1F7", screenDot: "#DDDAF4",
            gSea: ["#EAE8FE", "#D2CEF9"], gChip: ["#EAE8FE", "#D2CEF9"], gOn: ["#E6E4FD", "#C9C5F7"], gActive: ["#B9B2F3", "#8F86E6"], gTab: ["#B9B2F3", "#968DEA"],
            gPhone: ["#A8A2EE", "#7C74D9"], gSettings: ["#E3DFFC", "#C3BBF5"], gDock: ["#FBFAFF", "#ECEAFD"],
            sea: "#7C83F0", seaDeep: "#5A61D0", seaSoft: "#C9C5F7",
            phoneA: "#8F92C9", phoneB: "#3C3F7A", phoneKey: "#A3A6D8", phoneKeyHi: "#C9C5F7", phoneWallA: "#6669A8", phoneWallB: "#33366C", phoneBack: "#1F2148" }
    })
    // more themes made from one hue (0…1); sat 0 = greys. "custom" follows the hue slider in Settings → Shell → Look
    function makePalette(name, h, sat) {
        const c = (dh, s, l) => Qt.hsla(((h + dh) % 1 + 1) % 1, s * sat, l, 1);
        return { name: name, hue: h, ink: c(0, .35, .30), inkPhone: c(0, .38, .24), inkClock: c(0, .36, .27),
            text: c(0, .30, .28), textSoft: c(0, .22, .52), textMuted: c(0, .25, .42), textDeep: c(0, .38, .22),
            cream: c(0, .9, .97), paper: c(0, 1, .985), sand: c(0, .5, .88), screenDot: c(0, .45, .86),
            gSea: [c(0, .8, .94), c(0, .65, .86)], gChip: [c(0, .8, .94), c(0, .65, .86)], gOn: [c(0, .75, .92), c(0, .6, .80)],
            gActive: [c(.04, .6, .80), c(.04, .55, .68)], gTab: [c(.04, .6, .80), c(.04, .55, .70)], gLilacSoft: [c(.04, .6, .80), c(.04, .55, .68)],
            gPhone: [c(0, .55, .76), c(0, .5, .62)], gSettings: [c(0, .7, .92), c(0, .6, .80)], gDock: [c(0, 1, .985), c(0, .8, .93)],
            sea: c(0, .55, .62), seaDeep: c(0, .55, .48), seaSoft: c(0, .6, .80), lilac: c(.05, .6, .72), lilacSoft: c(.05, .6, .78), purple: c(.05, .55, .62),
            phoneA: c(0, .3, .56), phoneB: c(0, .35, .28), phoneKey: c(0, .32, .64), phoneKeyHi: c(0, .6, .80), phoneWallA: c(0, .3, .42), phoneWallB: c(0, .35, .26), phoneBack: c(0, .4, .15) };
    }
    readonly property var madePalettes: {
        const o = {};
        for (const [k, n, h] of [["cherry", "Cherry", .98], ["coral", "Coral", .03], ["peach", "Peach", .07], ["lemon", "Lemon", .14], ["matcha", "Matcha", .25],
                                 ["forest", "Forest", .36], ["teal", "Teal", .47], ["sky", "Sky", .56], ["ocean", "Ocean", .61], ["indigo", "Indigo", .67],
                                 ["grape", "Grape", .77], ["rose", "Rose", .92]]) o[k] = makePalette(n, h, 1);
        o.mono = makePalette("Mono", .55, .12);
        o.custom = makePalette("Custom", Prefs.themeHue, 1);
        return o;
    }
    readonly property var allPalettes: Object.assign({}, palettes, madePalettes)
    readonly property var pal: allPalettes[Prefs.theme] || palettes.isla
    function v(k, d) { return pal[k] !== undefined ? pal[k] : d }
    // box style (Settings → Shell → Look): candy · ring · pop · soft · flat · glass — see UiCandy
    readonly property string boxStyle: Prefs.boxStyle || "candy"
    readonly property bool ring: boxStyle === "ring"

    // ── Ink (outlines + solid drop shadows) ──
    readonly property color ink: v("ink", "#3D5A66")          // bar, dock, desktop widgets
    readonly property color inkPhone: v("inkPhone", "#213F48")     // phone + settings
    readonly property color inkClock: v("inkClock", "#2B4A54")     // sticker clock

    // ── Text ──
    readonly property color text: v("text", "#33505B")
    readonly property color textSoft: v("textSoft", "#5E7A84")
    readonly property color textMuted: v("textMuted", "#4F6B75")
    readonly property color textDeep: v("textDeep", "#213F48")

    // ── Surfaces ──
    readonly property color cream: v("cream", "#FFF9EC")
    readonly property color paper: v("paper", "#FFFDF6")
    readonly property color sand: v("sand", "#F2E3C6")
    readonly property color screenDot: v("screenDot", "#F1E2C2")
    readonly property color hi: Qt.rgba(1, 1, 1, 0.75)   // inset top highlight

    // ── Candy pill gradients [top, bottom] ──
    readonly property var gSea:    v("gSea", ["#E6F8FA", "#BEE9EE"])
    readonly property var gLilac:  v("gLilac", ["#F1ECFE", "#D9CEFA"])
    readonly property var gPeach:  ["#FFEDE3", "#FBCDB5"]
    readonly property var gSun:    ["#FFF7DA", "#FFE39A"]
    readonly property var gBerry:  ["#FDE8EE", "#F6BFD0"]
    readonly property var gLeaf:   ["#E7F6E7", "#BFE6C2"]
    readonly property var gChip:   v("gChip", ["#E6F8FA", "#C4ECF0"])
    readonly property var gActive: v("gActive", ["#C9B9F7", "#9C86E6"])   // current workspace, active tab
    readonly property var gPhone:  v("gPhone", ["#8FD9DE", "#55BFC6"])
    readonly property var gOn:     v("gOn", ["#D8F1F4", "#A9DDE4"])   // toggled tile
    readonly property var gGo:     ["#93D296", "#6BB86F"]   // selected search row
    readonly property var gDock:   v("gDock", ["#FFFDF7", "#FFF0D4"])
    readonly property var gTab:    v("gTab", ["#C9B9F7", "#A08AEA"])
    readonly property var gLilacSoft: v("gLilacSoft", ["#D9CEFA", "#B7A5F2"])
    readonly property var gSettings:  v("gSettings", ["#E6DEFB", "#C9B9F7"])

    // ── Solid accents ──
    readonly property color leaf: "#7CC47F"
    readonly property color leafDeep: "#3E9A5D"
    readonly property color sun: "#FFD45C"
    readonly property color sunDeep: "#FFC23C"
    readonly property color sea: v("sea", "#55BFC6")
    readonly property color seaDeep: v("seaDeep", "#2F9EAB")
    readonly property color lilac: v("lilac", "#A893EC")
    readonly property color lilacSoft: v("lilacSoft", "#B9A6F0")
    readonly property color purple: v("purple", "#8E7BE6")
    readonly property color berry: "#EE7D9C"
    readonly property color peach: "#F7A982"
    readonly property color orange: "#F7A04B"
    readonly property color indigo: "#7C83F0"
    readonly property color slate: "#5E7A84"
    readonly property color pinkSoft: v("pinkSoft", "#F6BFD0")
    readonly property color seaSoft: v("seaSoft", "#A9DDE4")

    // ── Phone body ──
    readonly property color phoneA: v("phoneA", "#6FA2AC")
    readonly property color phoneB: v("phoneB", "#2F5A65")
    readonly property color phoneKey: v("phoneKey", "#7DB3BD")
    readonly property color phoneKeyHi: v("phoneKeyHi", "#A9DDE4")
    readonly property color phoneWallA: v("phoneWallA", "#4C7F8A")
    readonly property color phoneWallB: v("phoneWallB", "#2C5560")
    readonly property color phoneBack: v("phoneBack", "#1A333B")
    readonly property color scrim: Qt.rgba(33 / 255, 63 / 255, 72 / 255, 0.30)

    // Colour by name, so configs can say tint: "berry"
    function c(name) { return t[name] !== undefined ? t[name] : sea }

    // ── Motion ──
    readonly property int fast: 140
    readonly property int base: 260
    readonly property int slow: 460
}
