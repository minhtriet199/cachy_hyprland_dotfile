#!/usr/bin/env python3
# Screen Settings: Windows-style display settings for every screen.
# Pick a screen in the arrangement at the top, then set brightness, HDR (only if the screen's EDID
# supports it), resolution, refresh rate and scale. Resolution/refresh/scale changes ask
# "Keep these display settings?" and revert after 15 s, like Windows.
# Esc = close (or revert a pending change), click away = close.
import json, os, subprocess, threading, time
import gi
gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")
from gi.repository import Gtk, Adw, GLib, Gdk

CTL = os.path.join(os.path.dirname(os.path.abspath(__file__)), "screenctl.py")
APP_ID = "dev.gamer.ScreenSettings"
NITS_MIN = 80
REVERT_SECS = 15
SCALE_STEPS = (1, 1.25, 1.5, 1.75, 2, 2.5, 3)
RES_NAMES = {(7680, 4320): "8K", (5120, 2880): "5K", (5120, 1440): "Super ultrawide",
             (3840, 2160): "4K", (3840, 2400): "4K+", (3440, 1440): "Ultrawide 2K",
             (2560, 1600): "2.5K", (2560, 1440): "2K", (2560, 1080): "Ultrawide 1080p",
             (1920, 1200): "1200p", (1920, 1080): "1080p", (1600, 900): "900p", (1366, 768): "768p",
             (1280, 800): "800p", (1280, 720): "720p"}

CSS = """
window.screenset { border-radius: 18px; }
.outer { padding: 18px 18px 16px 18px; }
.app-title { font-weight: 800; font-size: 16px; }
.hint { font-size: 11px; opacity: 0.5; }
.arrangement { border-radius: 14px; background: alpha(currentColor, 0.05); padding: 14px; }
.mon { border-radius: 10px; padding: 0; background: alpha(currentColor, 0.10);
       border: 2px solid transparent; transition: all 150ms; }
.mon:hover { background: alpha(currentColor, 0.16); }
.mon.selected { background: alpha(@accent_bg_color, 0.25); border-color: @accent_bg_color; }
.mon-num { font-size: 22px; font-weight: 800; }
.mon.selected .mon-num { color: @accent_color; }
.mon-name { font-size: 11px; font-weight: 600; opacity: 0.75; }
.screen-title { font-weight: 700; font-size: 14px; }
.pill-label { font-size: 10px; font-weight: 700; padding: 1px 8px; border-radius: 99px;
              background: alpha(currentColor, 0.10); }
.bright-row { padding: 10px 12px 10px 14px; }
.big { font-size: 26px; font-weight: 800; color: @accent_color; }
.big-unit { font-size: 14px; font-weight: 700; opacity: 0.6; margin-bottom: 4px; }
.sub { font-size: 11px; opacity: 0.6; }
scale.bright trough { min-height: 8px; border-radius: 99px; }
scale.bright highlight { border-radius: 99px; background: @accent_bg_color; }
scale.bright slider { min-width: 20px; min-height: 20px; background: @accent_bg_color;
                      box-shadow: 0 0 0 4px alpha(@accent_bg_color, 0.25); }
spinbutton.pct { font-weight: 700; }
.keep-bar { border-radius: 12px; padding: 10px 12px; background: alpha(@accent_bg_color, 0.15); }
.keep-title { font-weight: 700; }
"""


def ctl(*args):
    return subprocess.run(["python3", CTL, *map(str, args)], capture_output=True, text=True).stdout


def list_screens():
    try:
        return json.loads(ctl("list"))
    except Exception:
        return []


def fmt_hz(hz):
    return f"{int(hz)} Hz" if hz == int(hz) else f"{hz:.2f} Hz"


def valid_scales(w, h):
    """Scales Hyprland accepts for this resolution (logical size must be whole pixels),
    nearest to the usual Windows steps."""
    out = []
    for target in SCALE_STEPS:
        t = round(target * 120)
        for d in range(0, 25):
            hit = next((k for k in (t - d, t + d) if k > 0 and (w * 120) % k == 0 and (h * 120) % k == 0), None)
            if hit:
                sc = round(hit / 120, 6)
                if sc not in out:
                    out.append(sc)
                break
    return out


def screen_icon(s):
    return "computer-laptop-symbolic" if s.get("internal") else "video-display-symbolic"


class Applier:
    """Runs screenctl calls on a worker thread; for brightness only the latest value per screen is applied."""

    def __init__(self):
        self.pending = {}
        self.busy = False
        self.cv = threading.Condition()
        threading.Thread(target=self.run, daemon=True).start()

    def request(self, key, args, done=None):
        with self.cv:
            self.pending[key] = (args, done)
            self.cv.notify()

    def run(self):
        while True:
            with self.cv:
                while not self.pending:
                    self.cv.wait()
                key = next(iter(self.pending))
                args, done = self.pending.pop(key)
                self.busy = True
            out = ctl(*args)
            with self.cv:
                self.busy = False
            if done:
                GLib.idle_add(done, out)

    def flush(self):
        for _ in range(50):  # let the last change land before exiting
            with self.cv:
                if not self.pending and not self.busy:
                    return
            time.sleep(0.1)


class ScreenPage(Gtk.Box):
    """Settings for one screen."""

    def __init__(self, win, s, num):
        super().__init__(orientation=Gtk.Orientation.VERTICAL, spacing=14)
        self.win, self.s, self.out = win, s, s["output"]
        self.hdr = s["hdr"]
        self.debounce = 0
        self.syncing = False

        # title line
        head = Gtk.Box(spacing=8)
        icon = Gtk.Image.new_from_icon_name(screen_icon(s))
        title = Gtk.Label(label=f'{num}. {s["model"]}', xalign=0)
        title.add_css_class("screen-title")
        title.set_tooltip_text(s["name"])
        pill = Gtk.Label(label=self.out)
        pill.add_css_class("pill-label")
        head.append(icon); head.append(title); head.append(pill)
        self.append(head)

        # --- Brightness & color ---
        color = Adw.PreferencesGroup(title="Brightness &amp; color")
        bright = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        bright.add_css_class("bright-row")
        top = Gtk.Box(spacing=4)
        lbl = Gtk.Label(label="Brightness", xalign=0, hexpand=True, valign=Gtk.Align.END)
        self.big = Gtk.Label()
        self.big.add_css_class("big")
        unit = Gtk.Label(label="%", valign=Gtk.Align.END)
        unit.add_css_class("big-unit")
        top.append(lbl); top.append(self.big); top.append(unit)
        bright.append(top)
        row = Gtk.Box(spacing=10)
        row.append(Gtk.Image.new_from_icon_name("display-brightness-low-symbolic"))
        self.scale = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 0, 100, 1)
        self.scale.add_css_class("bright")
        self.scale.set_hexpand(True)
        self.scale.set_draw_value(False)
        self.spin = Gtk.SpinButton.new_with_range(0, 100, 1)
        self.spin.add_css_class("pct")
        self.spin.set_width_chars(3)
        self.spin.set_valign(Gtk.Align.CENTER)
        row.append(self.scale); row.append(self.spin)
        bright.append(row)
        self.sub = Gtk.Label(xalign=0, wrap=True)
        self.sub.add_css_class("sub")
        bright.append(self.sub)
        color.add(Adw.PreferencesRow(activatable=False, child=bright))

        self.hdr_row = Adw.SwitchRow(title="HDR", active=self.hdr)
        if s["hdr_supported"]:
            self.hdr_row.set_subtitle(f'Brighter, more vivid picture · up to {s["nits_max"]} nits')
        else:
            self.hdr_row.set_subtitle("Not supported by this screen")
            self.hdr_row.set_sensitive(False)
        self.hdr_row.connect("notify::active", self.on_hdr)
        color.add(self.hdr_row)
        self.append(color)

        # --- Scale & layout ---
        layout = Adw.PreferencesGroup(title="Scale &amp; layout")
        self.res_row = Adw.ComboRow(title="Display resolution")
        self.hz_row = Adw.ComboRow(title="Refresh rate")
        self.scale_row = Adw.ComboRow(title="Scale", subtitle="Size of text, apps and other items")
        self.rot_row = Adw.ComboRow(title="Orientation", model=Gtk.StringList.new(
            ["Landscape", "Portrait (90°)", "Landscape (flipped)", "Portrait (270°)"]))
        self.rot_row.set_selected(s["transform"])
        for r in (self.res_row, self.hz_row, self.scale_row, self.rot_row):
            layout.add(r)
        self.append(layout)
        self.fill_modes(s["width"], s["height"], s["refresh"], s["scale"])
        self.res_row.connect("notify::selected", self.on_res)
        self.hz_row.connect("notify::selected", self.on_mode_change)
        self.scale_row.connect("notify::selected", self.on_mode_change)
        self.rot_row.connect("notify::selected", self.on_rotate)

        self.show_value(s["pct"])
        self.scale.connect("value-changed", lambda w: self.set_value(int(w.get_value())))
        self.spin.connect("value-changed", lambda w: self.set_value(int(w.get_value())))
        self.spin.connect("activate", lambda *_: win.close())

    # ----- brightness -----
    def show_value(self, v):
        self.syncing = True
        self.scale.set_value(v)
        self.spin.set_value(v)
        self.syncing = False
        self.big.set_label(str(v))
        if self.s["internal"]:
            self.sub.set_label("Laptop backlight")
        elif self.hdr:
            nits = NITS_MIN + v * (self.s["nits_max"] - NITS_MIN) // 100
            self.sub.set_label(f"{nits} nits · the monitor locks its own brightness in HDR, so this sets desktop white")
        elif self.s["ddc"]:
            self.sub.set_label("Monitor backlight over DDC/CI")
        else:
            self.sub.set_label("No DDC/CI: turn it on in the monitor's menu")

    def set_value(self, v):
        if self.syncing:
            return
        self.show_value(v)
        if self.debounce:
            GLib.source_remove(self.debounce)
        # HDR brightness reloads Hyprland, so wait a bit longer before applying
        delay = 60 if self.s["internal"] else 400 if self.hdr else 120
        self.debounce = GLib.timeout_add(delay, self.apply)

    def apply(self):
        self.debounce = 0
        self.win.applier.request(self.out, ("set", self.out, int(self.scale.get_value())))
        return False

    def commit(self):
        self.spin.update()  # commit a typed but not yet parsed number
        if self.debounce:
            GLib.source_remove(self.debounce)
            self.apply()

    # ----- HDR -----
    def on_hdr(self, row, _p):
        on = row.get_active()
        if on == self.hdr:
            return
        self.hdr = on
        self.set_sensitive(False)
        self.win.hold_focus(5)  # the screen reconfigures; don't treat that as "clicked away"

        def done(_out):
            self.refresh_from_backend()
            self.set_sensitive(True)
            return False
        self.win.applier.request(("hdr", self.out), ("hdr", self.out, "on" if on else "off"), done)

    def refresh_from_backend(self):
        for s in list_screens():
            if s["output"] == self.out:
                self.s = s
                self.hdr = s["hdr"]
                self.show_value(s["pct"])

    # ----- resolution / refresh / scale -----
    def fill_modes(self, w, h, hz, scale):
        self.syncing = True
        native = tuple(self.s["native"] or ())
        self.res_list = [(m["w"], m["h"]) for m in self.s["modes"]]
        if (w, h) not in self.res_list:
            self.res_list.insert(0, (w, h))
        labels = []
        for rw, rh in self.res_list:
            name = RES_NAMES.get((rw, rh))
            labels.append(f"{rw} × {rh}" + (f" ({name})" if name else ""))
        if native:
            name = RES_NAMES.get(native)
            self.res_row.set_subtitle(f"Recommended: {native[0]} × {native[1]}" + (f" ({name})" if name else ""))
        self.res_row.set_model(Gtk.StringList.new(labels))
        self.res_row.set_selected(self.res_list.index((w, h)))
        self.fill_rates(w, h, hz)
        self.fill_scales(w, h, scale)
        self.syncing = False

    def fill_rates(self, w, h, hz):
        rates = next((m["rates"] for m in self.s["modes"] if (m["w"], m["h"]) == (w, h)), [hz])
        self.rates = rates
        self.hz_row.set_model(Gtk.StringList.new([fmt_hz(r) for r in rates]))
        self.hz_row.set_selected(min(range(len(rates)), key=lambda i: abs(rates[i] - hz)))

    def fill_scales(self, w, h, scale):
        self.scales = valid_scales(w, h)
        # the current scale may be one Hyprland picked itself; keep it in the list if it's valid here
        cur = round(scale, 6)
        if cur not in self.scales and (w * 120) % round(cur * 120) == 0 and (h * 120) % round(cur * 120) == 0:
            self.scales.append(cur)
            self.scales.sort()
        self.scale_row.set_model(Gtk.StringList.new([f"{round(sc * 100)}%" for sc in self.scales]))
        self.scale_row.set_selected(min(range(len(self.scales)), key=lambda i: abs(self.scales[i] - scale)))

    def current_mode(self):
        w, h = self.res_list[self.res_row.get_selected()]
        return w, h, self.rates[self.hz_row.get_selected()], self.scales[self.scale_row.get_selected()]

    def on_res(self, *_):
        if self.syncing:
            return
        w, h = self.res_list[self.res_row.get_selected()]
        self.syncing = True
        self.fill_rates(w, h, self.s["refresh"])
        self.fill_scales(w, h, self.s["scale"])
        self.syncing = False
        self.on_mode_change()

    def on_mode_change(self, *_):
        if self.syncing:
            return
        self.win.apply_mode(self, *self.current_mode())

    def show_mode(self, w, h, hz, sc):
        self.syncing = True
        self.res_row.set_selected(self.res_list.index((w, h)) if (w, h) in self.res_list else 0)
        self.fill_rates(w, h, hz)
        self.fill_scales(w, h, sc)
        self.syncing = False

    def on_rotate(self, *_):
        if self.syncing:
            return
        self.win.apply_rotation(self, self.rot_row.get_selected())

    def show_rotation(self, transform):
        self.syncing = True
        self.rot_row.set_selected(transform)
        self.syncing = False


class Arrangement(Gtk.Box):
    """Screens drawn to scale in their real layout, like Windows. Click one to select it."""
    W, H = 420, 110

    def __init__(self, screens, on_pick, on_move):
        super().__init__()
        self.add_css_class("arrangement")
        self.fixed = Gtk.Fixed(halign=Gtk.Align.CENTER, hexpand=True)
        self.append(self.fixed)
        self.buttons = []
        self.on_pick = on_pick
        self.on_move = on_move
        self.layout(screens)

    def layout(self, screens):
        for b in self.buttons:
            self.fixed.remove(b)
        self.buttons = []
        rects = []
        for s in screens:
            w, h = s["width"] / s["scale"], s["height"] / s["scale"]
            if s["transform"] % 2:
                w, h = h, w
            rects.append((s["x"], s["y"], w, h))
        minx, miny = min(r[0] for r in rects), min(r[1] for r in rects)
        maxx, maxy = max(r[0] + r[2] for r in rects), max(r[1] + r[3] for r in rects)
        k = min(self.W / (maxx - minx), self.H / (maxy - miny))
        gap = 6
        for i, (s, (x, y, w, h)) in enumerate(zip(screens, rects)):
            box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, valign=Gtk.Align.CENTER)
            num = Gtk.Label(label=str(i + 1))
            num.add_css_class("mon-num")
            name = Gtk.Label(label=s["model"], ellipsize=3)
            name.add_css_class("mon-name")
            box.append(num); box.append(name)
            b = Gtk.Button(child=box)
            b.add_css_class("mon")
            b.set_tooltip_text(f'{s["name"]} ({s["output"]})')
            b.set_size_request(max(int(w * k) - gap, 40), max(int(h * k) - gap, 30))
            b.connect("clicked", lambda _b, i=i: self.on_pick(i))
            bx, by = (x - minx) * k + gap / 2, (y - miny) * k + gap / 2
            self.fixed.put(b, bx, by)
            self.buttons.append(b)
            if len(screens) > 1:
                drag = Gtk.GestureDrag()
                drag.connect("drag-begin", lambda g, sx, sy, i=i: self._drag_begin(i))
                drag.connect("drag-update", lambda g, ox, oy, i=i: self._drag_move(i, ox, oy))
                drag.connect("drag-end", lambda g, ox, oy, i=i: self._drag_end(i, ox, oy))
                b.add_controller(drag)
        self._screens = screens
        self._origin = (minx, miny)
        self._k = k

    def select(self, i):
        for j, b in enumerate(self.buttons):
            (b.add_css_class if j == i else b.remove_css_class)("selected")

    def _base(self, i):
        s = self._screens[i]; minx, miny = self._origin; gap = 6
        return (s["x"] - minx) * self._k + gap / 2, (s["y"] - miny) * self._k + gap / 2

    def _drag_begin(self, i):
        self.on_pick(i)
        self._bx, self._by = self._base(i)

    def _drag_move(self, i, ox, oy):
        self.fixed.move(self.buttons[i], self._bx + ox, self._by + oy)

    def _logical(self, s):
        w, h = s["width"] / s["scale"], s["height"] / s["scale"]
        return (h, w) if s["transform"] % 2 else (w, h)

    def _drag_end(self, i, ox, oy):
        if len(self._screens) != 2:          # snap back; multi-monitor drag not supported
            self.fixed.move(self.buttons[i], self._bx, self._by); return
        other = 1 - i
        a, b = self._screens[other], self._screens[i]   # a = anchor, b = dragged
        aw, ah = self._logical(a); bw, bh = self._logical(b)
        if abs(ox) >= abs(oy):                # side by side
            if ox >= 0:  posA, posB = (0, 0), (int(aw), 0)      # b to the right
            else:        posA, posB = (int(bw), 0), (0, 0)      # b to the left
        else:                                 # stacked
            if oy >= 0:  posA, posB = (0, 0), (0, int(ah))      # b below
            else:        posA, posB = (0, int(bh)), (0, 0)      # b above
        pos = {a["output"]: f"{posA[0]}x{posA[1]}", b["output"]: f"{posB[0]}x{posB[1]}"}
        self.on_move(pos)


class Popup(Adw.ApplicationWindow):
    def __init__(self, app):
        super().__init__(application=app, title="Screen Settings")
        self.add_css_class("screenset")
        self.set_default_size(500, -1)
        self.set_resizable(False)
        self.applier = Applier()
        self.was_active = False
        self.hold_until = time.monotonic() + 1  # ignore focus flicker on open
        self.pending = None  # [page, old mode, seconds left, timer] while "keep changes?" is shown

        outer = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=14)
        outer.add_css_class("outer")
        head = Gtk.Box(spacing=10)
        icon = Gtk.Image.new_from_icon_name("preferences-desktop-display-symbolic")
        icon.set_pixel_size(20)
        title = Gtk.Label(label="Screen Settings", xalign=0, hexpand=True)
        title.add_css_class("app-title")
        hint = Gtk.Label(label="Esc close")
        hint.add_css_class("hint")
        head.append(icon); head.append(title); head.append(hint)
        outer.append(head)
        self.set_content(outer)

        self.screens = list_screens()
        self.pages = []
        if not self.screens:
            outer.append(Adw.StatusPage(icon_name="video-display-symbolic", title="No screens found"))
        else:
            self.arrangement = Arrangement(self.screens, self.pick, self.on_move)
            outer.append(self.arrangement)
            if len(self.screens) > 1:
                self.mode_btns = {}
                seg = Gtk.Box(halign=Gtk.Align.CENTER)
                seg.add_css_class("linked")
                def add_mode(key, label):
                    b = Gtk.ToggleButton(label=label, focus_on_click=False)
                    if self.mode_btns:
                        b.set_group(next(iter(self.mode_btns.values())))
                    b.connect("toggled", lambda btn, k=key: btn.get_active() and self.on_mode_btn(k))
                    seg.append(b); self.mode_btns[key] = b
                add_mode(("extend",), "Extend")
                add_mode(("duplicate",), "Duplicate")
                for i, sc in enumerate(self.screens):
                    add_mode(("only", sc["output"]), f"Only {i + 1}")
                outer.append(seg)
                self.sync_mode_buttons()

            # "keep these display settings?" bar
            self.keep_label = Gtk.Label(xalign=0)
            self.keep_label.add_css_class("sub")
            keep_title = Gtk.Label(label="Keep these display settings?", xalign=0)
            keep_title.add_css_class("keep-title")
            texts = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, hexpand=True)
            texts.append(keep_title); texts.append(self.keep_label)
            revert = Gtk.Button(label="Revert", valign=Gtk.Align.CENTER)
            keep = Gtk.Button(label="Keep changes", valign=Gtk.Align.CENTER)
            keep.add_css_class("suggested-action")
            revert.connect("clicked", lambda *_: self.revert_mode())
            keep.connect("clicked", lambda *_: self.keep_mode())
            bar = Gtk.Box(spacing=8)
            bar.add_css_class("keep-bar")
            bar.append(texts); bar.append(revert); bar.append(keep)
            self.keep_revealer = Gtk.Revealer(child=bar, reveal_child=False,
                                              transition_type=Gtk.RevealerTransitionType.SLIDE_DOWN)
            outer.append(self.keep_revealer)

            self.stack = Gtk.Stack(transition_type=Gtk.StackTransitionType.CROSSFADE,
                                   transition_duration=150, vhomogeneous=False, interpolate_size=True)
            self.pages = [ScreenPage(self, s, i + 1) for i, s in enumerate(self.screens)]
            for p in self.pages:
                self.stack.add_child(p)
            outer.append(self.stack)
            # start on the focused screen
            self.pick(next((i for i, s in enumerate(self.screens) if s["focused"]), 0))

        keys = Gtk.EventControllerKey()
        keys.set_propagation_phase(Gtk.PropagationPhase.CAPTURE)
        keys.connect("key-pressed", self.on_key)
        self.add_controller(keys)
        self.connect("notify::is-active", self.on_active)
        self.connect("close-request", self.on_close)

    def pick(self, i):
        self.arrangement.select(i)
        self.stack.set_visible_child(self.pages[i])

    # ----- changes with a 15-second keep-or-revert, like Windows -----
    def begin_change(self, key, revert_fn):
        if self.pending:
            if self.pending[3] == key:        # same control still pending: keep its first revert
                self.hold_focus(REVERT_SECS + 5)
                return
            self.keep_mode()                  # a different change was pending: treat it as kept
        self.pending = [revert_fn, REVERT_SECS, 0, key]
        self.hold_focus(REVERT_SECS + 5)

    def send(self, key, args, then=None, lock=None):
        if lock:
            lock.set_sensitive(False)
        def done(_out):
            if lock:
                lock.set_sensitive(True)
            self.relayout()
            if then:
                then()
            return False
        self.applier.request(key, args, done)

    def apply_mode(self, page, w, h, hz, sc):
        s0 = page.s
        old = (s0["width"], s0["height"], s0["refresh"], s0["scale"])
        self.begin_change(("mode", page.out), lambda: (page.show_mode(*old),
            self.send(("mode", page.out), ("mode", page.out, f"{old[0]}x{old[1]}@{old[2]}", old[3]))))
        self.send(("mode", page.out), ("mode", page.out, f"{w}x{h}@{hz}", sc),
                  then=self.start_countdown, lock=page)

    def apply_rotation(self, page, transform):
        old = page.s["transform"]
        self.begin_change(("rotate", page.out), lambda: (page.show_rotation(old),
            self.send(("rotate", page.out), ("rotate", page.out, old * 90))))
        self.send(("rotate", page.out), ("rotate", page.out, transform * 90),
                  then=self.start_countdown, lock=page)

    def apply_arrange(self, mode, out=None):
        prev = self.current_arrange()
        self.begin_change("arrange", lambda: self.send("arrange", ("arrange",) + prev,
                                                       then=self.sync_mode_buttons))
        self.send("arrange", ("arrange", mode) + ((out,) if out else ()), then=self.start_countdown)

    def apply_layout(self, positions):
        prev = {sc["output"]: f'{sc["x"]}x{sc["y"]}' for sc in self.screens}
        flat = lambda d: tuple(v for out, p in d.items() for v in (out, p))
        self.begin_change("layout", lambda: self.send("layout", ("layout",) + flat(prev)))
        self.send("layout", ("layout",) + flat(positions), then=self.start_countdown)

    def on_move(self, positions):
        self.apply_layout(positions)

    def on_mode_btn(self, key):
        if getattr(self, "_sync_modes", False):
            return
        self.apply_arrange(*key)

    def current_arrange(self):
        offs = [sc for sc in self.screens if sc["off"]]
        if offs and len(self.screens) - len(offs) >= 1 and len(offs) == len(self.screens) - 1:
            on = next(sc for sc in self.screens if not sc["off"])
            return ("only", on["output"])
        if any(sc["mirror"] for sc in self.screens):
            return ("duplicate",)
        return ("extend",)

    def sync_mode_buttons(self):
        if not hasattr(self, "mode_btns"):
            return
        cur = self.current_arrange()
        self._sync_modes = True
        for key, b in self.mode_btns.items():
            b.set_active(key == cur)
        self._sync_modes = False

    def start_countdown(self):
        if not self.pending:
            return
        if self.pending[2]:
            GLib.source_remove(self.pending[2])
        self.pending[1] = REVERT_SECS
        self.keep_revealer.set_reveal_child(True)
        self.tick()
        self.pending[2] = GLib.timeout_add_seconds(1, self.tick)

    def tick(self):
        if not self.pending:
            return False
        if self.pending[1] <= 0:
            self.pending[2] = 0
            self.revert_mode()
            return False
        self.keep_label.set_label(f"Reverting to the previous settings in {self.pending[1]} s")
        self.pending[1] -= 1
        return True

    def keep_mode(self):
        if self.pending and self.pending[2]:
            GLib.source_remove(self.pending[2])
        self.pending = None
        self.keep_revealer.set_reveal_child(False)
        self.hold_focus(1)

    def revert_mode(self):
        if not self.pending:
            return
        revert_fn, _, timer, _ = self.pending
        if timer:
            GLib.source_remove(timer)
        self.pending = None
        self.keep_revealer.set_reveal_child(False)
        self.hold_focus(5)
        revert_fn()

    def relayout(self):
        # sizes/positions changed: redraw the arrangement and refresh each page's info
        fresh = {s["output"]: s for s in list_screens()}
        for p in self.pages:
            if p.out in fresh:
                p.s = fresh[p.out]
        self.screens = [p.s for p in self.pages]
        self.arrangement.layout(self.screens)
        self.arrangement.select(self.pages.index(self.stack.get_visible_child()))
        self.sync_mode_buttons()

    # ----- window behaviour -----
    def hold_focus(self, secs):
        self.hold_until = max(self.hold_until, time.monotonic() + secs)

    def on_close(self, *_):
        if self.pending:  # closed without confirming: go back, like Windows
            self.revert_mode()
        for p in self.pages:
            p.commit()
        self.set_visible(False)
        self.applier.flush()
        return False

    def on_key(self, _c, keyval, _code, _state):
        if keyval == Gdk.KEY_Escape:
            if self.pending:
                self.revert_mode()
            else:
                self.close()
            return True
        return False

    def on_active(self, *_):
        # click away closes, like a popup (not while a change is waiting for "keep")
        if self.is_active():
            self.was_active = True
        elif self.was_active and time.monotonic() > self.hold_until and not self.pending:
            # focus can flicker while the window maps; only close if it stays away
            GLib.timeout_add(200, lambda: (self.is_active() or self.pending or self.close(), False)[1])


class App(Adw.Application):
    def __init__(self):
        super().__init__(application_id=APP_ID)

    def do_activate(self):
        win = self.get_active_window()
        if win:  # launched again while open: close it (toggle)
            win.close(); return
        prov = Gtk.CssProvider()
        prov.load_from_string(CSS)
        Gtk.StyleContext.add_provider_for_display(Gdk.Display.get_default(), prov,
                                                  Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
        Popup(self).present()


if __name__ == "__main__":
    Adw.StyleManager.get_default().set_color_scheme(Adw.ColorScheme.PREFER_DARK)
    App().run()
