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
// whole Jake (JakeWipe puppet), same box units — the face above sits at the top of a tall bean, eyes poking out on the
// right like the show. Limbs are two-part noodles that rotate (0° = straight down, + = clockwise on screen).
var bean = { x: -4, y: -16, w: 122, h: 240 }
var pivot = { x: 57, y: 104 }                       // middle of the bean: turns and squashes happen around here
var arms = [{ x: 9, y: 120 }, { x: 109, y: 120 }]   // shoulders (left, right)
var hips = [{ x: 30, y: 212 }, { x: 84, y: 212 }]
var arm = { up: 46, low: 38, w: 11, hand: 7 }
var leg = { len: 92, w: 12, footW: 24, footH: 11 }
var feet = 212 + 92 + 6                             // y of the soles when standing
var tail = "M 2 188 C -16 194 -22 212 -14 226"
var winkLine = "M 87 30 Q 103 40 119 30"            // right eye shut
