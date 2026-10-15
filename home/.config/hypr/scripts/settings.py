#!/usr/bin/env python3
# All-in-one Settings: one window with a sidebar. Each section embeds the panel from the
# dedicated app (Screens, Network, Keyboard, Screen Time) plus a native System page.
# The embedding reuses the existing apps unchanged (via run_gui(embed_app=...) / Popup).
import importlib.util, os, subprocess
import gi
gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")
from gi.repository import Gtk, Adw, Gdk, GLib

SCRIPTS = os.path.dirname(os.path.abspath(__file__))
APP_ID = "dev.gamer.Settings"


def load_mod(fn, name):
    spec = importlib.util.spec_from_file_location(name, os.path.join(SCRIPTS, fn))
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


def run(*cmd, stdin=None):
    try:
        return subprocess.run(cmd, input=stdin, capture_output=True, text=True, timeout=8).stdout.strip()
    except Exception:
        return ""


def have(cmd):
    return bool(run("sh", "-c", f"command -v {cmd}"))


CSS = """
.sidebar-area { background: alpha(currentColor, 0.035); }
row.nav { padding: 0; }
.nav-box { padding: 9px 12px; }
.nav-label { font-weight: 600; }
.section-pad { padding: 4px; }
"""

SECTIONS = [
    ("screens",    "Screens",     "video-display-symbolic"),
    ("network",    "Network",     "network-wireless-symbolic"),
    ("shortcuts",  "Keyboard",    "input-keyboard-symbolic"),
    ("screentime", "Screen Time", "alarm-symbolic"),
    ("system",     "System",      "emblem-system-symbolic"),
]


class Window(Adw.ApplicationWindow):
    def __init__(self, app):
        super().__init__(application=app, title="Settings", default_width=1020, default_height=780)
        self.app = app
        self.subwins = []          # keep embedded sub-app windows alive (they hold the logic)
        self.built = set()
        self.holders = {}
        self.toasts = Adw.ToastOverlay()

        # --- layout: header + [sidebar | content stack] ---
        tv = Adw.ToolbarView()
        tv.add_top_bar(Adw.HeaderBar())
        body = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)

        sidebar = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        sidebar.add_css_class("sidebar-area")
        sidebar.set_size_request(210, -1)
        self.listbox = Gtk.ListBox()
        self.listbox.add_css_class("navigation-sidebar")
        self.listbox.connect("row-selected", self.on_row)
        for name, title, icon in SECTIONS:
            row = Gtk.ListBoxRow()
            row.name = name
            row.add_css_class("nav")
            box = Gtk.Box(spacing=12)
            box.add_css_class("nav-box")
            img = Gtk.Image.new_from_icon_name(icon)
            lbl = Gtk.Label(label=title, xalign=0)
            lbl.add_css_class("nav-label")
            box.append(img); box.append(lbl)
            row.set_child(box)
            self.listbox.append(row)
        sidebar.append(self.listbox)

        self.stack = Gtk.Stack(transition_type=Gtk.StackTransitionType.CROSSFADE, transition_duration=120)
        self.stack.set_hexpand(True)
        for name, title, icon in SECTIONS:
            holder = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
            holder.set_hexpand(True); holder.set_vexpand(True)
            self.stack.add_named(holder, name)
            self.holders[name] = holder

        body.append(sidebar)
        body.append(Gtk.Separator(orientation=Gtk.Orientation.VERTICAL))
        body.append(self.stack)
        tv.set_content(body)
        self.toasts.set_child(tv)
        self.set_content(self.toasts)

        self.listbox.select_row(self.listbox.get_row_at_index(0))

        keys = Gtk.EventControllerKey()
        keys.connect("key-pressed", lambda _c, kv, *_: (kv == Gdk.KEY_Escape and self.close()) or False)
        self.add_controller(keys)

    def toast(self, text):
        self.toasts.add_toast(Adw.Toast(title=text, timeout=4))

    def on_row(self, _lb, row):
        if not row:
            return
        self.ensure_built(row.name)
        self.stack.set_visible_child_name(row.name)

    def ensure_built(self, name):
        if name in self.built:
            return
        self.built.add(name)
        holder = self.holders[name]
        spinner = Gtk.Spinner(spinning=True, halign=Gtk.Align.CENTER, valign=Gtk.Align.CENTER, vexpand=True)
        holder.append(spinner)

        def build():
            try:
                content = getattr(self, f"build_{name}")()
            except Exception as e:
                content = Adw.StatusPage(icon_name="dialog-error-symbolic",
                                         title="Couldn't load this section", description=str(e))
            holder.remove(spinner)
            content.set_hexpand(True); content.set_vexpand(True)
            holder.append(content)
            return False
        GLib.timeout_add(30, build)   # let the spinner paint first

    # ---- embed an existing app's panel by lifting its content widget ----
    def embed(self, window):
        self.subwins.append(window)            # keep it alive (holds applier + handlers)
        content = window.get_content()
        try:
            window.set_content(Gtk.Box())      # detach content from its own (hidden) window
        except Exception:
            content.unparent()
        return content

    def build_screens(self):
        ss = load_mod("screen-settings.py", "ss_embed")
        prov = Gtk.CssProvider(); prov.load_from_string(ss.CSS)
        Gtk.StyleContext.add_provider_for_display(Gdk.Display.get_default(), prov,
                                                  Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
        content = self.embed(ss.Popup(self.app))
        scroll = Gtk.ScrolledWindow(child=content, hexpand=True, vexpand=True)
        return scroll

    def build_network(self):
        net = load_mod("netsettings.py", "net_embed")
        return self.embed(net.run_gui(embed_app=self.app))

    def build_shortcuts(self):
        kb = load_mod("keybinds.py", "kb_embed")
        return self.embed(kb.run_gui(embed_app=self.app))

    def build_screentime(self):
        st = load_mod("screentime.py", "st_embed")
        return self.embed(st.run_gui(embed_app=self.app))

    # ---- native System page ----
    def build_system(self):
        page = Adw.PreferencesPage(vexpand=True)

        # Appearance
        g = Adw.PreferencesGroup(title="Appearance")
        dark = Adw.SwitchRow(title="Dark mode",
                             active="dark" in run("noctalia", "msg", "theme-mode-get").lower() or True)
        dark.connect("notify::active", lambda r, _p:
                     run("noctalia", "msg", "theme-mode-set", "dark" if r.get_active() else "light"))
        g.add(dark)
        page.add(g)

        # Performance (ASUS)
        if have("asusctl"):
            g = Adw.PreferencesGroup(title="Performance",
                                     description="Quiet saves battery and runs cool; Performance is fastest and loudest.")
            profs = [p for p in run("asusctl", "profile", "list").splitlines() if p.strip()] or \
                    ["Quiet", "Balanced", "Performance"]
            row = Adw.ComboRow(title="Power profile", model=Gtk.StringList.new(profs))
            cur = run("asusctl", "profile", "get")
            sel = next((i for i, p in enumerate(profs) if p in cur), 0)
            row.set_selected(sel)
            row._profs = profs
            row.connect("notify::selected", lambda r, _p:
                        (run("asusctl", "profile", "set", r._profs[r.get_selected()]),
                         self.toast(f"Power profile: {r._profs[r.get_selected()]}")))
            g.add(row)
            page.add(g)

        # Connectivity
        g = Adw.PreferencesGroup(title="Connectivity")
        bt = Adw.SwitchRow(title="Bluetooth", active="on" in run("noctalia", "msg", "bluetooth-status").lower())
        bt.connect("notify::active", lambda r, _p:
                   run("noctalia", "msg", "bluetooth-enable" if r.get_active() else "bluetooth-disable"))
        g.add(bt)
        btpanel = Adw.ButtonRow(title="Open Bluetooth panel")
        btpanel.connect("activated", lambda *_: run("noctalia", "msg", "panel-toggle", "control-center", "bluetooth"))
        g.add(btpanel)
        g.add(self._goto_row("Wi-Fi, DNS, IP, devices…", "network"))
        page.add(g)

        # Security & sharing
        g = Adw.PreferencesGroup(title="Security &amp; sharing")
        fw = run("sh", "-c", "systemctl is-active firewalld 2>/dev/null")
        fwrow = Adw.ActionRow(title="Firewall",
                              subtitle="On — incoming blocked" if fw == "active" else "Off / not installed")
        fwrow.add_prefix(Gtk.Image.new_from_icon_name(
            "security-high-symbolic" if fw == "active" else "security-low-symbolic"))
        g.add(fwrow)
        share = Adw.ButtonRow(title="File sharing (open ports for 15 min)")
        share.connect("activated", lambda *_: subprocess.Popen([os.path.join(SCRIPTS, "share-firewall.sh")]))
        g.add(share)
        g.add(self._goto_row("Remote access (SSH), devices on network…", "network"))
        page.add(g)

        # About
        g = Adw.PreferencesGroup(title="About this PC")
        info = [("Device", "ASUS ROG Zephyrus G14"),
                ("OS", run("sh", "-c", ". /etc/os-release; echo $PRETTY_NAME")),
                ("Kernel", run("uname", "-r")),
                ("Processor", run("sh", "-c", "grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | xargs")),
                ("Memory", run("sh", "-c", "free -h | awk '/Mem:/{print $2}'")),
                ("Desktop", "Hyprland + Noctalia")]
        for k, v in info:
            r = Adw.ActionRow(title=k, subtitle=v or "—")
            r.set_subtitle_selectable(True)
            g.add(r)
        page.add(g)

        scroll = Gtk.ScrolledWindow(child=page, hexpand=True, vexpand=True)
        return scroll

    def _goto_row(self, title, section):
        r = Adw.ButtonRow(title=title)
        r.connect("activated", lambda *_: self.listbox.select_row(
            self.listbox.get_row_at_index([s[0] for s in SECTIONS].index(section))))
        return r


class App(Adw.Application):
    def __init__(self):
        super().__init__(application_id=APP_ID)

    def do_activate(self):
        if self.get_active_window():
            self.get_active_window().present(); return
        prov = Gtk.CssProvider(); prov.load_from_string(CSS)
        Gtk.StyleContext.add_provider_for_display(Gdk.Display.get_default(), prov,
                                                  Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
        Window(self).present()


if __name__ == "__main__":
    Adw.StyleManager.get_default().set_color_scheme(Adw.ColorScheme.PREFER_DARK)
    App().run()
