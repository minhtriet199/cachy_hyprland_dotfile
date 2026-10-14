#!/usr/bin/env python3
# Screen Time, up to a month. Noctalia only shows up to 14 days, so this keeps its own copy.
#   screentime.py archive   copy Noctalia's per-day data into the archive, keep KEEP_DAYS days
#                           (run every 10 min by the screentime-archive.timer user unit)
#   screentime.py           open the month view
# Archive: ~/.local/state/screen-time/archive.json, same shape as Noctalia's screen_time.json:
#   {"2026-10-15": {"apps": {app: seconds}, "hourly": [24 x seconds], "app_hourly": {...}}}
import datetime as dt, json, os, re, sys

SRC = os.path.expanduser("~/.local/state/noctalia/screen_time.json")
ARCHIVE = os.path.expanduser("~/.local/state/screen-time/archive.json")
KEEP_DAYS = 31
APP_ID = "dev.gamer.ScreenTime"


def read(path):
    try:
        with open(path) as f:
            return json.load(f)
    except (OSError, ValueError):
        return {}


def day_total(d):
    return sum(d.get("hourly", [])) or sum(d.get("apps", {}).values())


def archive():
    arc, src = read(ARCHIVE), read(SRC)
    for day, data in src.items():
        # Noctalia's copy is the live one; but never let a reset (smaller/empty day) wipe what we saved
        if day not in arc or day_total(data) >= day_total(arc[day]):
            arc[day] = data
    cutoff = (dt.date.today() - dt.timedelta(days=KEEP_DAYS - 1)).isoformat()
    arc = {k: v for k, v in sorted(arc.items()) if k >= cutoff}
    os.makedirs(os.path.dirname(ARCHIVE), exist_ok=True)
    tmp = ARCHIVE + ".tmp"
    with open(tmp, "w") as f:
        json.dump(arc, f)
    os.replace(tmp, ARCHIVE)
    return arc


def steam_games():
    """Steam app id -> game name, from the appmanifests in every Steam library."""
    import glob, re
    roots = {os.path.expanduser("~/.local/share/Steam")}
    try:
        vdf = open(os.path.expanduser("~/.local/share/Steam/steamapps/libraryfolders.vdf")).read()
        roots |= set(re.findall(r'"path"\s+"([^"]+)"', vdf))
    except OSError:
        pass
    names = {}
    for root in roots:
        for mf in glob.glob(os.path.join(root, "steamapps", "appmanifest_*.acf")):
            try:
                txt = open(mf, errors="replace").read()
            except OSError:
                continue
            aid, name = re.search(r'"appid"\s+"(\d+)"', txt), re.search(r'"name"\s+"([^"]+)"', txt)
            if aid and name:
                names[aid.group(1)] = name.group(1)
    return names


def fmt(secs):
    h, m = divmod(int(secs) // 60, 60)
    return f"{h}h {m:02d}m" if h else f"{m}m"


def run_gui():
    import gi
    gi.require_version("Gtk", "4.0")
    gi.require_version("Adw", "1")
    from gi.repository import Gtk, Adw, Gdk, Gio

    CSS = """
    .tile { padding: 12px 14px; border-radius: 12px; }
    .tile-value { font-size: 24px; font-weight: 800; }
    .tile-label { font-size: 11px; opacity: 0.65; font-weight: 600; }
    .section { font-weight: 700; font-size: 14px; }
    .muted { opacity: 0.6; font-size: 12px; }
    .app-time { font-weight: 700; font-feature-settings: "tnum"; }
    """

    class Chart(Gtk.DrawingArea):
        """Daily totals for the last KEEP_DAYS days. One series, so one hue (accent) and no legend."""

        def __init__(self, days, on_pick):
            super().__init__(content_height=190, hexpand=True, has_tooltip=True)
            self.days, self.on_pick, self.selected, self.hover = days, on_pick, len(days) - 1, None
            self.highlight = {len(days) - 1}
            self.set_draw_func(self.draw)
            self.connect("query-tooltip", self.tooltip)
            click = Gtk.GestureClick()
            click.connect("pressed", lambda _g, _n, x, _y: self.pick_at(x))
            self.add_controller(click)
            motion = Gtk.EventControllerMotion()
            motion.connect("motion", lambda _c, x, _y: self.set_hover(self.index_at(x)))
            motion.connect("leave", lambda *_: self.set_hover(None))
            self.add_controller(motion)
            self.pad_l, self.pad_b, self.pad_t = 40, 22, 8

        def geom(self):
            w = self.get_width() - self.pad_l
            return w / max(len(self.days), 1)

        def index_at(self, x):
            i = int((x - self.pad_l) // self.geom())
            return i if 0 <= i < len(self.days) else None

        def pick_at(self, x):
            i = self.index_at(x)
            if i is not None:
                self.selected = i
                self.queue_draw()
                self.on_pick(i)

        def set_hover(self, i):
            if i != self.hover:
                self.hover = i
                self.queue_draw()

        def tooltip(self, _w, x, _y, _kb, tip):
            i = self.index_at(x)
            if i is None:
                return False
            day, secs = self.days[i]
            tip.set_text(f"{day.strftime('%a %d %b')}: {fmt(secs) if secs else 'no data'}")
            return True

        def draw(self, _a, cr, width, height):
            fg = self.get_color()
            accent = Adw.StyleManager.get_default().get_accent_color_rgba()
            top = max([s for _, s in self.days] + [3600])
            step = 3600 * (1 if top <= 4 * 3600 else 2 if top <= 8 * 3600 else 4)
            ymax = ((int(top) // step) + 1) * step
            plot_h = height - self.pad_b - self.pad_t
            y = lambda v: self.pad_t + plot_h * (1 - v / ymax)

            # recessive grid + hour labels
            cr.set_line_width(1)
            cr.select_font_face("sans")
            cr.set_font_size(10)
            for v in range(0, ymax + 1, step):
                cr.set_source_rgba(fg.red, fg.green, fg.blue, 0.10)
                cr.move_to(self.pad_l, round(y(v)) + 0.5)
                cr.line_to(width, round(y(v)) + 0.5)
                cr.stroke()
                cr.set_source_rgba(fg.red, fg.green, fg.blue, 0.55)
                cr.move_to(4, y(v) + 4)
                cr.show_text(f"{v // 3600}h")

            bw = self.geom()
            gap = max(2, bw * 0.25)
            for i, (day, secs) in enumerate(self.days):
                x0 = self.pad_l + i * bw + gap / 2
                w = bw - gap
                if secs:
                    alpha = 1.0 if i in self.highlight else 0.75 if i == self.hover else 0.4
                    cr.set_source_rgba(accent.red, accent.green, accent.blue, alpha)
                    yt, yb, r = y(secs), y(0), min(4, w / 2)
                    r = min(r, (yb - yt) / 2)
                    # 4px rounded data end, square at the baseline
                    cr.new_path()
                    cr.move_to(x0, yb)
                    cr.line_to(x0, yt + r)
                    cr.arc(x0 + r, yt + r, r, 3.14159, 1.5 * 3.14159)
                    cr.arc(x0 + w - r, yt + r, r, 1.5 * 3.14159, 0)
                    cr.line_to(x0 + w, yb)
                    cr.close_path()
                    cr.fill()
                # day labels: every Monday + the selected day
                if day.weekday() == 0 or i == len(self.days) - 1 or (len(self.highlight) == 1 and i in self.highlight):
                    cr.set_source_rgba(fg.red, fg.green, fg.blue, 0.9 if i in self.highlight else 0.55)
                    label = str(day.day)
                    ext = cr.text_extents(label)
                    cr.move_to(x0 + w / 2 - ext.width / 2, height - 6)
                    cr.show_text(label)

    class Window(Adw.ApplicationWindow):
        def __init__(self, app):
            super().__init__(application=app, title="Screen Time", default_width=720, default_height=780)
            arc = archive()  # refresh now so today is current
            today = dt.date.today()
            self.data = arc
            self.days = []
            for k in range(KEEP_DAYS - 1, -1, -1):
                d = today - dt.timedelta(days=k)
                self.days.append((d, day_total(arc.get(d.isoformat(), {}))))
            self.names = {}
            for a in Gio.AppInfo.get_all():
                if a.get_id():
                    self.names[a.get_id().removesuffix(".desktop").lower()] = (a.get_display_name(), a.get_icon())
                    wm = a.get_startup_wm_class() if hasattr(a, "get_startup_wm_class") else None
                    if wm:  # apps tracked by window class, e.g. dev.gamer.ScreenTime
                        self.names.setdefault(wm.lower(), (a.get_display_name(), a.get_icon()))
                    # Steam game shortcuts run steam://rungameid/<id>; games show up as steam_app_<id>
                    if m := re.search(r"rungameid/(\d+)", a.get_commandline() or ""):
                        self.names[f"steam_app_{m.group(1)}"] = (a.get_display_name(), a.get_icon())
            for aid, name in steam_games().items():
                icon = Gio.ThemedIcon.new(f"steam_icon_{aid}")
                self.names.setdefault(f"steam_app_{aid}", (name, icon if Gtk.IconTheme.get_for_display(
                    Gdk.Display.get_default()).has_gicon(icon) else Gio.ThemedIcon.new("steam")))

            tv = Adw.ToolbarView()
            tv.add_top_bar(Adw.HeaderBar())
            box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=16, margin_start=20, margin_end=20,
                          margin_bottom=20, margin_top=6)

            used = [s for _, s in self.days if s]
            tiles = Gtk.Box(spacing=10, homogeneous=True)
            for value, label in ((fmt(self.days[-1][1]), "Today"),
                                 (fmt(sum(used) / len(used)) if used else "–", "Daily average"),
                                 (fmt(sum(used)), f"Last {KEEP_DAYS} days"),
                                 (str(len(used)), "Days recorded")):
                t = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
                t.add_css_class("card"); t.add_css_class("tile")
                v = Gtk.Label(label=value, xalign=0); v.add_css_class("tile-value")
                l = Gtk.Label(label=label, xalign=0); l.add_css_class("tile-label")
                t.append(v); t.append(l)
                tiles.append(t)
            box.append(tiles)

            head = Gtk.Box()
            title = Gtk.Label(label="Daily screen time", xalign=0, hexpand=True)
            title.add_css_class("section")
            hint = Gtk.Label(label="Click a day for its apps")
            hint.add_css_class("muted")
            head.append(title); head.append(hint)
            box.append(head)
            self.chart = Chart(self.days, self.show_day)
            box.append(self.chart)

            self.apps_title = Gtk.Label(xalign=0)
            self.apps_title.add_css_class("section")
            # range picker: Today / This week / This month / Last 31 days
            n = len(self.days)
            monday = today - dt.timedelta(days=today.weekday())
            self.ranges = {
                "today": ("Today", [n - 1]),
                "week": ("This week", [i for i, (d, _) in enumerate(self.days) if d >= monday]),
                "month": ("This month", [i for i, (d, _) in enumerate(self.days) if d >= today.replace(day=1)]),
                "all": (f"Last {KEEP_DAYS} days", list(range(n))),
            }
            seg = Gtk.Box()
            seg.add_css_class("linked")
            self.range_btns = {}
            for key, (label, _) in self.ranges.items():
                b = Gtk.ToggleButton(label=label)
                if self.range_btns:
                    b.set_group(next(iter(self.range_btns.values())))
                b.connect("toggled", lambda btn, k=key: btn.get_active() and self.show_range(k))
                seg.append(b)
                self.range_btns[key] = b
            ah = Gtk.Box()
            self.apps_title.set_hexpand(True)
            ah.append(self.apps_title); ah.append(seg)
            box.append(ah)
            self.apps = Gtk.ListBox(selection_mode=Gtk.SelectionMode.NONE)
            self.apps.add_css_class("boxed-list")
            box.append(self.apps)

            scroll = Gtk.ScrolledWindow(child=box, vexpand=True)
            tv.set_content(scroll)
            self.set_content(tv)
            self.range_btns["today"].set_active(True)

            keys = Gtk.EventControllerKey()
            keys.connect("key-pressed", lambda _c, kv, *_: (kv == Gdk.KEY_Escape and self.close()) or False)
            self.add_controller(keys)

        def app_label(self, app):
            hit = self.names.get(app.lower())
            if not hit:
                hit = next((v for k, v in self.names.items() if k.endswith("." + app.lower()) or k == app.lower()), None)
            return hit or (app, None)

        def show_day(self, i):
            # clicked a bar in the chart: that one day
            for btn in self.range_btns.values():
                btn.set_active(False)
            day = self.days[i][0]
            label = "today" if i == len(self.days) - 1 else day.strftime("%A %d %B")
            self.show(([i]), f"Most used · {label}")

        def show_range(self, key):
            label, idx = self.ranges[key]
            total = sum(self.days[i][1] for i in idx)
            self.show(idx, f"Most used · {label.lower()} · {fmt(total)}")

        def show(self, idx, title):
            self.chart.highlight = set(idx)
            self.chart.queue_draw()
            self.apps_title.set_label(title)
            totals = {}
            for i in idx:
                for app, sec in self.data.get(self.days[i][0].isoformat(), {}).get("apps", {}).items():
                    totals[app] = totals.get(app, 0) + sec
            while (row := self.apps.get_first_child()):
                self.apps.remove(row)
            items = sorted(totals.items(), key=lambda kv: -kv[1])
            if not items:
                self.apps.append(Adw.ActionRow(title="No screen time recorded"))
                return
            top = items[0][1]
            for app, secs in items[:15]:
                name, icon = self.app_label(app)
                row = Adw.ActionRow(title=GLib_escape(name))
                img = Gtk.Image.new_from_gicon(icon) if icon else Gtk.Image.new_from_icon_name("application-x-executable")
                img.set_pixel_size(28)
                row.add_prefix(img)
                bar = Gtk.LevelBar(min_value=0, max_value=top, value=secs, valign=Gtk.Align.CENTER, width_request=160)
                row.add_suffix(bar)
                t = Gtk.Label(label=fmt(secs), width_chars=8, xalign=1)
                t.add_css_class("app-time")
                row.add_suffix(t)
                self.apps.append(row)

    from gi.repository import GLib
    GLib_escape = GLib.markup_escape_text

    class App(Adw.Application):
        def __init__(self):
            super().__init__(application_id=APP_ID)

        def do_activate(self):
            if self.get_active_window():
                self.get_active_window().present(); return
            prov = Gtk.CssProvider()
            prov.load_from_string(CSS)
            Gtk.StyleContext.add_provider_for_display(Gdk.Display.get_default(), prov,
                                                      Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
            Window(self).present()

    Adw.StyleManager.get_default().set_color_scheme(Adw.ColorScheme.PREFER_DARK)
    App().run()


if __name__ == "__main__":
    if sys.argv[1:] == ["archive"]:
        archive()
    else:
        run_gui()
