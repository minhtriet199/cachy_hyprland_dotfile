.pragma library
// Jake (lock screen picture + "Jake" transition), drawn as SVG paths in a 140 × 100 box — the face from
// ~/Pictures/Wallpapers/wp5005945-jake-the-dog-desktop-wallpapers.jpg (1301 px wide, face at x 575..715, y 350..450).
// tools/jake-wallpaper.py reads these same paths to render the sharp 2K wallpaper, so the animation lines up with it.
function circle(cx, cy, r) { return "M " + (cx - r) + " " + cy + " a " + r + " " + r + " 0 1 0 " + (2 * r) + " 0 a " + r + " " + r + " 0 1 0 " + (-2 * r) + " 0 Z" }
function ellipse(cx, cy, rx, ry) { return "M " + (cx - rx) + " " + cy + " a " + rx + " " + ry + " 0 1 0 " + (2 * rx) + " 0 a " + rx + " " + ry + " 0 1 0 " + (-2 * rx) + " 0 Z" }
var bg = "#F5B424"           // the wallpaper's orange
var fur = "#F5B424"
var ink = "#120A06"
var line = 2.1           // outline width in box units
var box = { w: 140, h: 100, srcX: 575, srcY: 350, srcW: 1301 }   // where the box sits in the original picture
var eyeL = { cx: 31, cy: 31, r: 18, sx: -5, sy: 4 }             // white eye + black crescent offset (shadow side)
var eyeR = { cx: 103, cy: 28, r: 18, sx: 5, sy: 4 }
var muzzle = "M 72 28 C 92 28 106 40 108 58 C 110 72 112 88 100 93 C 88 98 80 92 79 84 L 77 72 C 74 70 70 70 67 72 L 65 84 C 64 92 56 98 44 93 C 32 88 34 72 36 58 C 38 40 52 28 72 28 Z"
var mouth = "M 62 70 Q 72 75 82 70"
var nose = ellipse(73, 57, 14, 9)
// whole Jake for the walk (same box units; the face above sits on top). Head = the orange that was the wallpaper.
var head = { cx: 72, cy: 44, w: 156, h: 124 }       // rounded box around the face
var body = ellipse(72, 124, 46, 32)
var legs = [{ x: 44, y: 144, w: 18, h: 30 }, { x: 82, y: 144, w: 18, h: 30 }]
var arms = [{ x: 19, y: 100, w: 14, h: 34 }, { x: 111, y: 100, w: 14, h: 34 }]
var tail = "M 114 132 C 136 130 144 114 135 102"
var winkLine = "M 87 30 Q 103 40 119 30"            // right eye shut
