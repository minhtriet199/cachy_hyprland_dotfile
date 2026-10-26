#!/usr/bin/env python3
# Draws the "Jake" transition frame by frame (hand-drawn look: brush outlines that thicken and taper, a little line
# wobble that differs on every drawing, squash / stretch, smear and impact frames) and saves them as PNGs for
# JakeWipe.qml, which plays them at 12 fps.
#   jake-frames.py [OUT_DIR]      default: ../assets/jake next to this script
#   jake-frames.py --sheet PNG    also writes a contact sheet of every frame (to look at them)
# Writes NAME_NN.png (cropped to the drawing) + frames.js (crop boxes, canvas size, face spot) for JakeWipe.qml.
# Face shapes come from JakeShapes.js (the same face the lock-screen picture has).
import json, math, os, random, re, sys
import cairo

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = open(os.path.join(HERE, "..", "JakeShapes.js")).read()
FUR, INK, WHITE = (0xF5 / 255, 0xB4 / 255, 0x24 / 255), (0x12 / 255, 0x0A / 255, 0x06 / 255), (1, 1, 1)
W, H = 800, 900                 # canvas per frame
S = 1.6                         # px per unit
AX, AY = W / 2, H * 0.5         # where the anchor (Jake's middle when standing, see JakeWipe) sits on the canvas


def var(name):
    return re.search(r"^var %s = (.+?)(?:\s*//.*)?$" % name, SRC, re.M).group(1).strip().strip('"')


def nums(name):
    return {k: float(v) for k, v in re.findall(r"(\w+): (-?[\d.]+)", var(name))}


# ── geometry helpers ──
def catmull(pts, closed=False, n=10):
    """Smooth curve through the points (Catmull-Rom), as a dense point list."""
    if len(pts) < 2:
        return pts
    P = pts + pts[:3] if closed else [pts[0]] + pts + [pts[-1]]
    out, m = [], len(pts) if closed else len(pts) - 1
    for i in range(m):
        p0, p1, p2, p3 = P[i], P[i + 1], P[i + 2], P[i + 3]
        for s in range(n):
            t = s / n
            t2, t3 = t * t, t * t * t
            out.append(tuple(0.5 * ((2 * p1[k]) + (-p0[k] + p2[k]) * t + (2 * p0[k] - 5 * p1[k] + 4 * p2[k] - p3[k]) * t2
                                    + (-p0[k] + 3 * p1[k] - 3 * p2[k] + p3[k]) * t3) for k in (0, 1)))
    if not closed:
        out.append(pts[-1])
    return out


def bez_sample(d, n=12):
    """Points along an SVG path made of absolute M / L / C / Q / Z (what JakeShapes.js uses)."""
    toks = re.findall(r"[MLCQZ]|-?[\d.]+", d)
    pts, i, cur, start = [], 0, (0, 0), (0, 0)
    while i < len(toks):
        c = toks[i]; i += 1
        if c == "M":
            cur = start = (float(toks[i]), float(toks[i + 1])); i += 2; pts.append(cur)
        elif c == "L":
            cur = (float(toks[i]), float(toks[i + 1])); i += 2; pts.append(cur)
        elif c in "CQ":
            k = 3 if c == "C" else 2
            ctrl = [(float(toks[i + 2 * j]), float(toks[i + 2 * j + 1])) for j in range(k)]; i += 2 * k
            q = [cur] + ctrl
            for s in range(1, n + 1):
                t = s / n
                if k == 3:
                    x = (1 - t) ** 3 * q[0][0] + 3 * (1 - t) ** 2 * t * q[1][0] + 3 * (1 - t) * t * t * q[2][0] + t ** 3 * q[3][0]
                    y = (1 - t) ** 3 * q[0][1] + 3 * (1 - t) ** 2 * t * q[1][1] + 3 * (1 - t) * t * t * q[2][1] + t ** 3 * q[3][1]
                else:
                    x = (1 - t) ** 2 * q[0][0] + 2 * (1 - t) * t * q[1][0] + t * t * q[2][0]
                    y = (1 - t) ** 2 * q[0][1] + 2 * (1 - t) * t * q[1][1] + t * t * q[2][1]
                pts.append((x, y))
            cur = q[-1]
        elif c == "Z":
            pts.append(start)
    return pts


def ellipse_pts(cx, cy, rx, ry, n=36):
    return [(cx + rx * math.cos(2 * math.pi * i / n), cy + ry * math.sin(2 * math.pi * i / n)) for i in range(n)]


class Draw:
    """One drawing. Every point goes through `j` (the hand's wobble, new each drawing) and the frame transform."""

    def __init__(self, seed, wob=1.1):
        self.rnd = random.Random(seed)
        self.wob = wob
        self.surf = cairo.ImageSurface(cairo.FORMAT_ARGB32, W, H)
        self.cr = cairo.Context(self.surf)
        self.cr.set_line_cap(cairo.LINE_CAP_ROUND); self.cr.set_line_join(cairo.LINE_JOIN_ROUND)
        self.shift = [0, 0]

    def j(self, pts, amt=1.0):
        a = self.wob * amt
        return [(x + self.rnd.uniform(-a, a), y + self.rnd.uniform(-a, a)) for x, y in pts]

    def px(self, p):
        return AX + (p[0] + self.shift[0]) * S, AY + (p[1] + self.shift[1]) * S

    def fill(self, pts, col):
        cr = self.cr
        cr.move_to(*self.px(pts[0]))
        for p in pts[1:]:
            cr.line_to(*self.px(p))
        cr.close_path(); cr.set_source_rgb(*col); cr.fill()

    def brush(self, pts, w=2.4, taper=True, closed=False, col=INK, heavy=None):
        """Ink line with changing width: thin at the ends, fuller in the middle, extra weight around `heavy` (0..1)."""
        if len(pts) < 2:
            return
        if closed:
            pts = pts + [pts[0]]
        n = len(pts)
        L, R = [], []
        for i, p in enumerate(pts):
            a, b = pts[max(0, i - 1)], pts[min(n - 1, i + 1)]
            dx, dy = b[0] - a[0], b[1] - a[1]
            d = math.hypot(dx, dy) or 1
            nx, ny = -dy / d, dx / d
            s = i / (n - 1)
            ww = w * (0.9 + 0.25 * math.sin(s * math.pi * 3 + self.rnd.random()))
            if taper and not closed:
                ww *= 0.25 + 0.75 * math.sin(math.pi * min(1, max(0, s * 1.15 - 0.05)))
            if heavy is not None:
                ww *= 1 + 0.7 * max(0, 1 - abs(s - heavy) * 4)
            L.append((p[0] + nx * ww / 2, p[1] + ny * ww / 2)); R.append((p[0] - nx * ww / 2, p[1] - ny * ww / 2))
        self.fill(L + R[::-1], col)

    def noodle(self, pts, w, col=FUR, line=2.3):
        """A limb: fur tube along the points, inked on both sides (open ends tucked into the body / paw)."""
        curve = catmull(self.j(pts, 0.8), n=8)
        cr = self.cr
        cr.set_line_width(w * S); cr.set_source_rgb(*col)
        cr.move_to(*self.px(curve[0]))
        for p in curve[1:]:
            cr.line_to(*self.px(p))
        cr.stroke()
        for side in (1, -1):
            edge = []
            for i, p in enumerate(curve):
                a, b = curve[max(0, i - 1)], curve[min(len(curve) - 1, i + 1)]
                dx, dy = b[0] - a[0], b[1] - a[1]
                d = math.hypot(dx, dy) or 1
                edge.append((p[0] - dy / d * side * w / 2, p[1] + dx / d * side * w / 2))
            self.brush(edge, line, taper=True)

    def blob(self, pts, line=2.6, heavy=0.55, col=FUR):
        curve = catmull(self.j(pts, 1.0), closed=True, n=10)
        self.fill(curve, col)
        self.brush(curve, line, taper=False, closed=True, heavy=heavy)

    def paw(self, p, ang, r=7.5):
        """Little hand: round paw with two finger creases, turned by ang (degrees)."""
        a = math.radians(ang)
        pts = ellipse_pts(0, 0, r, r * 0.85, 18)
        rot = lambda q: (p[0] + q[0] * math.cos(a) - q[1] * math.sin(a), p[1] + q[0] * math.sin(a) + q[1] * math.cos(a))
        self.blob([rot(q) for q in pts], line=2.0, heavy=None)
        for fx in (-2.5, 2.5):
            self.brush([rot((fx, r * 0.2)), rot((fx * 1.1, r * 0.85))], 1.4)

    def foot(self, p, toward, rx=13, ry=6):
        pts = ellipse_pts(p[0] + toward * rx * 0.55, p[1], rx, ry, 18)
        self.blob(pts, line=2.0, heavy=None)

    def lines(self, segs, w=1.8, col=INK):
        for a, b in segs:
            self.brush([a, b], w, taper=True, col=col)

    def save(self, path):
        self.surf.write_to_png(path)


# ── Jake's parts ──
FACE_X, FACE_Y, FACE_SC = 8, -42, 1.34   # anchor → face pivot offset and face size on the standing bean
BOX = nums("box"); PIV = nums("pivot")
EYE_L, EYE_R = nums("eyeL"), nums("eyeR")
MUZZLE = bez_sample(var("muzzle")); MOUTH = bez_sample(var("mouth"))
NOSE = tuple(float(v) for v in re.search(r"ellipse\(([\d.]+), ([\d.]+), ([\d.]+), ([\d.]+)\)", var("nose")).groups())


def bean_pts(sx=1.0, sy=1.0, rot=0.0, cx=0.0, cy=0.0, lean=0.0):
    """Jake's body around the anchor: a soft bean, a bit fuller low down. lean bends the top sideways."""
    base = [(0, -122), (50, -116), (70, -74), (72, 0), (74, 70), (62, 108), (16, 124), (-24, 122), (-62, 108),
            (-74, 72), (-72, 0), (-70, -74), (-50, -116)]
    a = math.radians(rot)
    out = []
    for x, y in base:
        x += lean * max(0, -y) / 122
        x, y = x * sx, y * sy
        out.append((cx + x * math.cos(a) - y * math.sin(a), cy + x * math.sin(a) + y * math.cos(a)))
    return out


def face(d, ox, oy, sc=FACE_SC, wink=0.0, squash=1.0):
    """The lock-picture face, placed so its box sits with the pivot at (ox, oy) — same spot as in JakeWipe."""
    def T(p):
        return (ox + (p[0] - PIV["x"]) * sc, oy + (p[1] - PIV["y"]) * sc * squash)
    for e, is_r in ((EYE_L, False), (EYE_R, True)):
        rr = e["r"] * sc
        sh = ellipse_pts(*T((e["cx"] + e["sx"], e["cy"] + e["sy"])), (rr + 1.5), (rr + 1.5) * squash, 28)
        d.fill(d.j(sh, 0.5), INK)
        if is_r and wink > 0.5:
            c = T((e["cx"], e["cy"]))
            d.brush([(c[0] - rr, c[1] - 2), (c[0], c[1] + rr * 0.45), (c[0] + rr, c[1] - 2)], 3.4)
            continue
        ry = rr * squash * (1 - 0.85 * wink if is_r else 1)
        wh = ellipse_pts(*T((e["cx"], e["cy"])), rr, ry, 28)
        d.fill(wh, WHITE); d.brush(d.j(wh + wh[:1], 0.5), 2.3, taper=False)
    m = d.j([T(p) for p in MUZZLE], 0.7)
    d.fill(m, FUR); d.brush(m, 2.5, taper=False, heavy=0.35)
    d.brush(d.j([T(p) for p in MOUTH], 0.4), 2.2)
    d.fill(d.j(ellipse_pts(*T((NOSE[0], NOSE[1])), NOSE[2] * sc, NOSE[3] * sc * squash, 22), 0.4), INK)
    # brow crease on the left side of the head, like the show
    d.brush(d.j([T((-6, 42)), T((-12, 56)), T((-8, 68))], 0.5), 2.0)


# ── poses ──
# Anchor (0, 0) = middle of Jake's bean when he stands; y grows down; units like JakeShapes (face box is 140 wide).


def stand(d, breath=0.0, wink=0.0):
    tail(d, [(-68, 80), (-92, 86), (-102, 102), (-98, 112)])
    for s in (-1, 1):
        d.noodle([(s * 30, 104), (s * 34, 150), (s * 32, 196)], 13)
        d.foot((s * 32, 199), s)
    d.blob(bean_pts(1, 1 + breath))
    face(d, FACE_X, FACE_Y - breath * 60, wink=wink)
    d.noodle([(-66, -6), (-80, 34), (-74, 66), (-50, 72), (-28, 64)], 12)
    d.noodle([(68, -4), (82, 36), (76, 68), (52, 74), (30, 66)], 12)
    d.paw((-26, 64), -20); d.paw((28, 66), 20)


def tail(d, pts):
    d.noodle(pts, 11)


def fall(d, k):
    """Falling, arms thrown up, legs kicking; k = 0..1 through the flail, new arm angle each drawing."""
    sy = 1.06 + 0.04 * math.sin(k * 7)
    lean = 8 * math.sin(k * 5)
    tail(d, [(-58, 80), (-78, 70 - 10 * k), (-92, 58), (-96, 44)])
    d.noodle([(-26, 104), (-46, 140 + 6 * math.sin(k * 9)), (-58, 176)], 13); d.foot((-58, 179), -1)
    d.noodle([(26, 104), (44, 132), (70, 150 + 8 * math.cos(k * 8))], 13); d.foot((70, 153), 1)
    d.blob(bean_pts(0.96, sy, lean=lean))
    face(d, FACE_X + lean * 0.6, FACE_Y - 6, squash=1.04)
    wave = 14 * math.sin(k * 9)
    d.noodle([(-56, -14), (-80, -50), (-86 + wave * 0.4, -96), (-74 + wave, -134)], 11); d.paw((-74 + wave, -138), 160)
    d.noodle([(58, -12), (82, -46), (92 - wave * 0.4, -92), (84 - wave, -130)], 11); d.paw((84 - wave, -134), -160)
    # speed lines above him
    d.lines([((x, -170 - 30 * ((i * 37 + int(k * 9)) % 3)), (x, -206 - 30 * ((i * 37 + int(k * 9)) % 3))) for i, x in enumerate((-50, -10, 34, 70))], 1.6)


def smear(d):
    """Last frame before the floor: stretched long and thin."""
    tail(d, [(-50, 120), (-66, 100), (-72, 80)])
    for s in (-1, 1):
        d.noodle([(s * 22, 150), (s * 26, 200), (s * 24, 246)], 11); d.foot((s * 24, 249), s)
    d.blob(bean_pts(0.78, 1.42))
    face(d, FACE_X * 0.8, FACE_Y * 1.42 - 6, sc=0.92, squash=1.18)
    d.noodle([(-46, -40), (-56, -110), (-48, -186)], 10); d.paw((-48, -190), 175)
    d.noodle([(48, -38), (58, -108), (52, -184)], 10); d.paw((52, -188), -175)
    d.lines([((x, -230), (x, -300)) for x in (-60, -20, 30, 66)], 1.6)


def splat(d, k):
    """Flat on the floor; k = 0 impact (dust burst) .. 1 settled."""
    cy = 92                                                     # pancake sits low, on the floor line
    for s in (-1, 1):
        d.noodle([(s * 40, cy + 18), (s * 96, cy + 30), (s * 150, cy + 38), (s * 176, cy + 34)], 13); d.foot((s * 178, cy + 34), s)
    tail(d, [(-90, cy + 10), (-120, cy - 6), (-130, cy - 24)])
    d.blob(bean_pts(1.62, 0.42, cy=cy + 4))
    face(d, FACE_X * 1.4, cy - 30, sc=1.0, squash=0.55)
    d.noodle([(-80, cy - 4), (-130, cy - 2), (-178, cy + 4)], 11); d.paw((-182, cy + 4), 90)
    d.noodle([(80, cy - 4), (130, cy - 2), (178, cy + 6)], 11); d.paw((182, cy + 6), -90)
    if k < 0.5:   # impact: dust puffs and burst lines
        for s in (-1, 1):
            for i in range(3):
                d.blob(ellipse_pts(s * (200 + i * 26), cy + 36 - i * 10, 14 - i * 3, 9 - i * 2, 14), line=1.8, heavy=None, col=(0.98, 0.93, 0.8))
            d.lines([((s * 120, cy - 40), (s * 160, cy - 80)), ((s * 60, cy - 50), (s * 74, cy - 96)), ((0, cy - 56), (0, cy - 104))], 2.0)


def getup(d, k):
    """From pancake to standing, overshooting tall (k 0..1)."""
    sx = 1.62 + (0.88 - 1.62) * k
    sy = 0.42 + (1.12 - 0.42) * k
    cy = 92 * (1 - k) - 10 * k
    for s in (-1, 1):
        d.noodle([(s * 30, cy + 110 * sy), (s * (60 - 30 * k), cy + 120 * sy + 20), (s * (100 - 70 * k), cy + 124 * sy + 30)], 13)
        d.foot((s * (100 - 70 * k), cy + 124 * sy + 33), s)
    d.blob(bean_pts(sx, sy, cy=cy))
    face(d, FACE_X, cy - 64 * sy, squash=0.6 + 0.4 * k)
    for s in (-1, 1):
        sh = (s * 70 * sx, cy - 8)
        el = (s * (70 * sx + 26), cy + 26 - 30 * k)
        pw = (s * (70 * sx + 10 - 20 * k), cy - 22 - 40 * k)
        d.noodle([sh, el, pw], 12); d.paw(pw, -s * 140)


def run(d, i, n=6):
    """Gallop on four legs, facing right: long low body, head upright at the front. i = drawing in the cycle."""
    ph = 2 * math.pi * i / n
    bob = -8 * abs(math.sin(ph))
    cy = 70 + bob
    stretch = 1 + 0.08 * math.cos(ph)
    # far legs (behind the body), then body, then near legs
    def leg(hx, hy, ph2, front):
        sw = math.sin(ph2); lift = max(0, math.cos(ph2))
        knee = (hx + 26 * sw, hy + 40 - 12 * lift)
        paw_p = (hx + 52 * sw * (1.2 if front else 1), hy + 78 - 26 * lift)
        d.noodle([(hx, hy), knee, paw_p], 12)
        d.foot((paw_p[0], paw_p[1] + 3), 1, rx=11, ry=5)
    leg(-70, cy + 20, ph + 0.8, False); leg(66, cy + 20, ph + math.pi + 0.8, True)
    tail(d, [(-118 * stretch, cy - 4), (-142, cy - 26 + 6 * math.sin(ph)), (-150, cy - 50)])
    d.blob(bean_pts(1.0, 1.0, rot=90, cx=0, cy=cy, lean=0) if False else
           [(cy_x, cy_y) for cy_x, cy_y in [(x * stretch, y * 0.62 + cy) for x, y in
            [(-122, 0), (-114, -40), (-70, -58), (0, -60), (70, -58), (112, -44), (126, -6), (122, 30), (100, 54), (40, 62),
             (-30, 62), (-96, 54), (-120, 30)]]])
    leg(-50, cy + 26, ph, False); leg(84, cy + 26, ph + math.pi, True)
    # head: the bean's front end rises into a round head; face upright on it
    hx, hy = 96 * stretch, cy - 50 + bob * 0.3
    d.blob([(hx + x, hy + y) for x, y in ellipse_pts(0, 0, 62, 56, 14)], heavy=0.2)
    face(d, hx + 6, hy + 14, sc=0.98)


def wink_frame(d, w):
    stand(d, wink=w)


# ── the sequences (12 fps): name → list of drawings, each a function of the Draw ──
def sequences():
    seq = {}
    seq["stand"] = [lambda d: stand(d)]
    seq["fall"] = [lambda d, k=k: fall(d, k / 5) for k in range(6)] + [smear]
    seq["splat"] = [lambda d: splat(d, 0), lambda d: splat(d, 0), lambda d: splat(d, 1), lambda d: splat(d, 1),
                    lambda d: splat(d, 1), lambda d: splat(d, 1)]
    seq["getup"] = [lambda d, k=k: getup(d, k / 3) for k in range(4)]
    seq["run"] = [lambda d, i=i: run(d, i) for i in range(6)]
    return seq


def trim(f):
    """Crop the PNG to its drawing (+ margin). Returns [x, y, w, h] of the crop on the full canvas."""
    im = cairo.ImageSurface.create_from_png(f)
    w, h, st = im.get_width(), im.get_height(), im.get_stride()
    data = im.get_data()
    xs, ys = [], []
    for y in range(0, h, 2):
        row = data[y * st:(y + 1) * st]
        for x in range(0, w, 2):
            if row[x * 4 + 3]:
                xs.append(x); ys.append(y)
    m = 6
    x0, y0 = max(0, min(xs) - m), max(0, min(ys) - m)
    x1, y1 = min(w, max(xs) + m + 2), min(h, max(ys) + m + 2)
    out = cairo.ImageSurface(cairo.FORMAT_ARGB32, x1 - x0, y1 - y0)
    cr = cairo.Context(out); cr.set_source_surface(im, -x0, -y0); cr.paint()
    out.write_to_png(f)
    return [x0, y0, x1 - x0, y1 - y0]


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    out = args[0] if args else os.path.join(HERE, "..", "assets", "jake")
    sheet = sys.argv[sys.argv.index("--sheet") + 1] if "--sheet" in sys.argv else None
    os.makedirs(out, exist_ok=True)
    manifest = {"w": W, "h": H, "scale": S, "ax": AX, "ay": AY, "seq": {}}
    files = []
    for name, frames in sequences().items():
        manifest["seq"][name] = len(frames)
        for i, fn in enumerate(frames):
            d = Draw(seed=(sum(map(ord, name)) * 131 + i * 17) & 0xFFFF)
            fn(d)
            f = os.path.join(out, "%s_%02d.png" % (name, i))
            d.save(f); files.append(f)
            box = trim(f)
            manifest["seq"].setdefault(name + "_frames", []).append(box)
    manifest["face"] = {"x": FACE_X, "y": FACE_Y, "sc": FACE_SC}
    manifest["bean"] = {"x0": -74, "x1": 74, "y0": -122, "y1": 124}     # bean_pts() bounds, units around the anchor
    # JakeWipe.qml imports this (frame crops, canvas, face spot) — written as a JS library so QML can import it
    open(os.path.join(out, "frames.js"), "w").write(".pragma library\n// made by tools/jake-frames.py — don't edit\nvar M = "
                                                    + json.dumps(manifest) + "\n")
    if sheet:
        cols = 6; rows = (len(files) + cols - 1) // cols
        th, tw = H // 2, W // 2
        sh = cairo.ImageSurface(cairo.FORMAT_RGB24, cols * tw, rows * th)
        cr = cairo.Context(sh); cr.set_source_rgb(0.18, 0.2, 0.26); cr.paint()
        for i, f in enumerate(files):
            im = cairo.ImageSurface.create_from_png(f)
            nm = os.path.basename(f)[:-4]; sq, k = nm.rsplit("_", 1)
            bx = manifest["seq"][sq + "_frames"][int(k)]
            cr.save(); cr.translate((i % cols) * tw, (i // cols) * th); cr.scale(0.5, 0.5)
            cr.set_source_rgb(0.24, 0.27, 0.33); cr.rectangle(4, 4, W - 8, H - 8); cr.fill()
            cr.set_source_surface(im, bx[0], bx[1]); cr.paint(); cr.restore()
            cr.set_source_rgb(1, 0.3, 0.3); cr.move_to((i % cols) * tw + 8, (i // cols) * th + 18); cr.set_font_size(14)
            cr.show_text(os.path.basename(f)[:-4]);
        sh.write_to_png(sheet)
    print(len(files), "frames →", out)


if __name__ == "__main__":
    main()
