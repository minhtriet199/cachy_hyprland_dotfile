#!/usr/bin/env python3
# Keyboard Shortcuts: edit Hyprland keybinds in a window instead of in binds.lua.
# Source of truth: ~/.config/hypr/keybinds.json. Saving regenerates config/binds.lua,
# reloads Hyprland and rolls back automatically if the new config has errors.
#   keybinds.py             open the editor
#   keybinds.py generate    rebuild binds.lua from keybinds.json (and reload)
import json, os, shutil, subprocess, sys, time, uuid

HYPR = os.path.expanduser("~/.config/hypr")
DATA = os.path.join(HYPR, "keybinds.json")
LUA = os.path.join(HYPR, "config", "binds.lua")
APP_ID = "dev.gamer.KeyboardShortcuts"
UWSM = "uwsm app -- "

CATEGORIES = ["Windows", "Focus & move", "Workspaces", "Apps", "Media & hardware", "Screen",
              "Utilities", "Mouse"]

# action id -> (label, kind, choices) ; kind: None | "text" | "app" | "choice"
DIRS = [("up", "Up"), ("down", "Down"), ("left", "Left"), ("right", "Right")]
MONS = [("+1", "Next screen"), ("-1", "Previous screen")]
DIGIT_MODES = [("go", "Show workspace N on this screen"), ("move", "Move window to workspace N (follow)"),
               ("focus", "Go to workspace N (absolute)"), ("move_to", "Move window to workspace N on this screen"),
               ("move_silent", "Move window to workspace N (stay)")]
ACTIONS = {
    "app":           ("Open an app", "app", None),
    "exec":          ("Run a command", "text", None),
    "close":         ("Close window", None, None),
    "float":         ("Toggle floating", None, None),
    "fullscreen":    ("Fullscreen", None, None),
    "maximize":      ("Maximize", None, None),
    "togglesplit":   ("Toggle split direction", None, None),
    "opaque":        ("Toggle window opacity", None, None),
    "cycle":         ("Next window", None, None),
    "focus_dir":     ("Move focus", "choice", DIRS),
    "focus_monitor": ("Focus screen", "choice", MONS),
    "focus_ws":      ("Go to workspace", "text", None),
    "move_dir":      ("Move window", "choice", DIRS),
    "move_monitor":  ("Move window to screen", "choice", MONS),
    "move_ws":       ("Move window to workspace", "text", None),
    "ws_digits":     ("Workspace number keys 1–9", "choice", DIGIT_MODES),
    "drag":          ("Drag window with mouse", None, None),
    "resize":        ("Resize window with mouse", None, None),
    "zoom":          ("Screen zoom", "choice", [("in", "Zoom in"), ("out", "Zoom out")]),
}
ARG_HINT = {"exec": "Command", "focus_ws": "Workspace (number, m+1, m-1, emptym…)",
            "move_ws": "Workspace (number, m+1, m-1…)"}

KEY_NAMES = {"mouse:272": "Left click", "mouse:273": "Right click", "mouse:274": "Middle click",
             "mouse_up": "Scroll up", "mouse_down": "Scroll down", "code:82": "Keypad −",
             "code:86": "Keypad +", "Return": "Enter", "Escape": "Esc", "period": ".", "comma": ",",
             "Minus": "−", "minus": "−", "Plus": "+", "plus": "+", "Print": "PrtSc", "SUPER": "Super",
             "SHIFT": "Shift", "CONTROL": "Ctrl", "CTRL": "Ctrl", "ALT": "Alt", "Space": "Space",
             "XF86AudioRaiseVolume": "Volume up", "XF86AudioLowerVolume": "Volume down",
             "XF86AudioMute": "Mute", "XF86AudioMicMute": "Mic mute", "XF86AudioPlay": "Play",
             "XF86AudioPause": "Pause", "XF86AudioNext": "Next track", "XF86AudioPrev": "Previous track",
             "XF86MonBrightnessUp": "Brightness up", "XF86MonBrightnessDown": "Brightness down",
             "XF86Calculator": "Calculator key", "XF86Launch4": "Fn+F5 (Armoury key)"}
for _d in range(10):
    KEY_NAMES[f"code:{19 if _d == 0 else 9 + _d}"] = str(_d)


# ---------------- data ----------------

def key_parts(b):
    parts = [p.strip() for p in b["keys"].split(" + ")]
    if b["action"] == "ws_digits":
        parts.append("1…9")
    return parts


def pretty(part):
    return KEY_NAMES.get(part, part)


def norm(keys):
    parts = [p.strip().upper() for p in keys.split(" + ")]
    return " + ".join(sorted(p.replace("CTRL", "CONTROL") for p in parts))


def load():
    with open(DATA) as f:
        return json.load(f)


def save(binds):
    tmp = DATA + ".tmp"
    with open(tmp, "w") as f:
        json.dump(binds, f, indent=1, ensure_ascii=False)
    os.replace(tmp, DATA)


def summary(b):
    label, kind, choices = ACTIONS.get(b["action"], (b["action"], None, None))
    arg = b.get("arg", "")
    if kind == "choice":
        return dict(choices).get(arg, arg)
    if kind == "app":
        return f"Open {app_name(arg)}"
    if kind == "text":
        return f"{label}: {arg}" if b["action"] != "exec" else arg
    return label


_app_names = None


def app_name(app_id):
    global _app_names
    if _app_names is None:
        _app_names = {}
        try:
            import gi
            gi.require_version("Gio", "2.0")
            from gi.repository import Gio
            for a in Gio.AppInfo.get_all():
                if a.get_id():
                    _app_names[a.get_id()] = a.get_display_name()
        except Exception:
            pass
    return _app_names.get(app_id, app_id.removesuffix(".desktop"))


# ---------------- Lua generation ----------------

def lstr(s):
    return json.dumps(s, ensure_ascii=False)


def dispatcher(b):
    a, arg = b["action"], b.get("arg", "")
    ws = lambda v: v if str(v).lstrip("-").isdigit() else lstr(v)
    return {
        "app":           lambda: f"hl.dsp.exec_cmd({lstr(UWSM + arg)})",
        "exec":          lambda: f"hl.dsp.exec_cmd({lstr(arg)})",
        "close":         lambda: "hl.dsp.window.close()",
        "float":         lambda: 'hl.dsp.window.float({ action = "toggle" })',
        "fullscreen":    lambda: "hl.dsp.window.fullscreen()",
        "maximize":      lambda: "hl.dsp.window.fullscreen({ mode = 1 })",
        "togglesplit":   lambda: 'hl.dsp.layout("togglesplit")',
        "opaque":        lambda: 'hl.dsp.window.set_prop({ prop = "opaque", value = "toggle" })',
        "cycle":         lambda: "hl.dsp.window.cycle_next()",
        "focus_dir":     lambda: f"hl.dsp.focus({{ direction = {lstr(arg)} }})",
        "focus_monitor": lambda: f"hl.dsp.focus({{ monitor = {lstr(arg)} }})",
        "focus_ws":      lambda: f"hl.dsp.focus({{ workspace = {ws(arg)} }})",
        "move_dir":      lambda: f"hl.dsp.window.move({{ direction = {lstr(arg[0])} }})",
        "move_monitor":  lambda: f"hl.dsp.window.move({{ monitor = {lstr(arg)} }})",
        "move_ws":       lambda: f"hl.dsp.window.move({{ workspace = {ws(arg)} }})",
        "drag":          lambda: "hl.dsp.window.drag()",
        "resize":        lambda: "hl.dsp.window.resize()",
        "zoom":          lambda: f"function() zoomfunction({'0.3' if arg == 'in' else '-0.3'}) end",
    }[a]()


def opts(b, extra=None):
    o = []
    if b.get("locked"):
        o.append("locked = true")
    if b.get("repeating"):
        o.append("repeating = true")
    if b.get("desc"):
        o.append(f"description = {lstr(extra or b['desc'])}")
    return ", { " + ", ".join(o) + " }" if o else ""


HEADER = '''-- GENERATED by scripts/keybinds.py from ~/.config/hypr/keybinds.json.
-- Edit shortcuts in the "Keyboard Shortcuts" app; changes made here are overwritten.

-- Number-row keys by physical keycode (works on AZERTY too). Digit d -> 1..9 => 10..18, 0 => 19
local function digitCode(d)
    return "code:" .. (d == 0 and 19 or (9 + d))
end

local function zoomfunction(value)
    local z = hl.get_config("cursor:zoom_factor") + value
    hl.config({ cursor = { zoom_factor = math.max(1.0, math.min(3.0, z)) } })
end

-- Empty submap the Keyboard Shortcuts app switches to while recording a shortcut, so
-- existing binds don't fire. Emergency exit: Super+Ctrl+Alt+Escape.
hl.define_submap("keycapture", function()
    hl.bind("SUPER + CONTROL + ALT + Escape", hl.dsp.submap("reset"))
end)
'''


def generate(binds):
    out = [HEADER]
    for cat in CATEGORIES + sorted({b["category"] for b in binds} - set(CATEGORIES)):
        group = [b for b in binds if b["category"] == cat and not b.get("disabled")]
        if not group:
            continue
        out.append(f"\n-- {cat}")
        for b in group:
            keys = b["keys"]
            if b["action"] == "ws_digits":
                mode = b.get("arg", "go")
                pre = lstr(keys + " + ")
                if mode in ("go", "move"):
                    out.append(f"for i = 1, 9 do  -- {b.get('desc', '')}\n"
                               f"    hl.bind({pre} .. digitCode(i), hl.dsp.exec_cmd(\"~/.config/hypr/scripts/ws.sh {mode} \" .. i){opts(b)})\nend")
                else:
                    disp = {"focus": "hl.dsp.focus({ workspace = i })",
                            "move_to": 'hl.dsp.window.move({ workspace = "m~" .. i })',
                            "move_silent": 'hl.dsp.window.move({ workspace = "m~" .. i, follow = false })'}[mode]
                    out.append(f"for i = 1, NUM_WPM do  -- {b.get('desc', '')}\n"
                               f"    hl.bind({pre} .. digitCode(i % 10), {disp}{opts(b)})\nend")
            else:
                out.append(f"hl.bind({lstr(keys)}, {dispatcher(b)}{opts(b)})")
    return "\n".join(out) + "\n"


def config_errors():
    out = subprocess.run(["hyprctl", "configerrors"], capture_output=True, text=True).stdout.strip()
    return "" if out in ("", "no errors") else out


def apply(binds):
    """Write binds.lua, reload, roll back on errors. Returns '' or the error text."""
    old_lua = open(LUA).read() if os.path.exists(LUA) else None
    before = config_errors()
    with open(LUA, "w") as f:
        f.write(generate(binds))
    subprocess.run(["hyprctl", "reload"], capture_output=True)
    time.sleep(0.3)
    err = config_errors()
    if err and err != before:
        if old_lua is not None:
            with open(LUA, "w") as f:
                f.write(old_lua)
            subprocess.run(["hyprctl", "reload"], capture_output=True)
        return err
    save(binds)
    return ""


def submap(name):
    subprocess.run(["hyprctl", "dispatch", f'hl.dsp.submap("{name}")'], capture_output=True)


# ---------------- GUI ----------------

def run_gui(embed_app=None):
    import gi
    gi.require_version("Gtk", "4.0")
    gi.require_version("Adw", "1")
    from gi.repository import Gtk, Adw, Gdk, GLib, Gio

    CSS = """
    .keycap { font-family: monospace; font-weight: 700; font-size: 12px; padding: 2px 8px;
              border-radius: 6px; background: alpha(currentColor, 0.10);
              box-shadow: inset 0 -2px alpha(currentColor, 0.15); }
    .keyplus { opacity: 0.45; font-weight: 700; }
    .conflict { color: @warning_color; }
    .rec { padding: 6px 14px; }
    .rec.recording { background: alpha(@accent_bg_color, 0.25); color: @accent_color; }
    .count { opacity: 0.55; font-size: 12px; }
    """

    MODS = {Gdk.ModifierType.SUPER_MASK: "SUPER", Gdk.ModifierType.CONTROL_MASK: "CONTROL",
            Gdk.ModifierType.ALT_MASK: "ALT", Gdk.ModifierType.SHIFT_MASK: "SHIFT"}
    MOD_KEYS = {"Shift_L", "Shift_R", "Control_L", "Control_R", "Alt_L", "Alt_R", "Super_L", "Super_R",
                "Meta_L", "Meta_R", "ISO_Level3_Shift", "Hyper_L", "Hyper_R"}

    def keycaps(parts):
        box = Gtk.Box(spacing=4, valign=Gtk.Align.CENTER)
        for i, p in enumerate(parts):
            if i:
                plus = Gtk.Label(label="+")
                plus.add_css_class("keyplus")
                box.append(plus)
            cap = Gtk.Label(label=pretty(p))
            cap.add_css_class("keycap")
            box.append(cap)
        return box

    class Editor(Adw.Dialog):
        def __init__(self, win, bind, on_save):
            super().__init__(title="Edit shortcut" if bind else "Add shortcut", content_width=520)
            self.win, self.on_save = win, on_save
            self.b = dict(bind) if bind else {"keys": "", "action": "app", "arg": "", "category": "Apps",
                                              "desc": "", "locked": False, "repeating": False}
            self.recording = False

            tv = Adw.ToolbarView()
            hb = Adw.HeaderBar(show_end_title_buttons=False, show_start_title_buttons=False)
            cancel = Gtk.Button(label="Cancel")
            cancel.connect("clicked", lambda *_: self.close())
            self.save_btn = Gtk.Button(label="Save")
            self.save_btn.add_css_class("suggested-action")
            self.save_btn.connect("clicked", self.do_save)
            hb.pack_start(cancel); hb.pack_end(self.save_btn)
            tv.add_top_bar(hb)

            page = Adw.PreferencesPage()
            g1 = Adw.PreferencesGroup()
            self.name_row = Adw.EntryRow(title="Name", text=self.b.get("desc", ""))
            g1.add(self.name_row)

            # shortcut recorder
            self.key_row = Adw.ActionRow(title="Shortcut", subtitle="Click, then press the keys")
            self.rec_btn = Gtk.Button(valign=Gtk.Align.CENTER)
            self.rec_btn.add_css_class("rec")
            self.rec_btn.connect("clicked", lambda *_: self.start_record())
            self.key_row.add_suffix(self.rec_btn)
            g1.add(self.key_row)
            self.keys_text = Adw.EntryRow(title="Or type it (e.g. SUPER + SHIFT + W, SUPER + mouse:272)",
                                          text=self.b.get("keys", ""))
            self.keys_text.connect("changed", lambda r: self.set_keys(r.get_text(), from_text=True))
            g1.add(self.keys_text)
            self.conflict = Gtk.Label(xalign=0, wrap=True, margin_top=6)
            self.conflict.add_css_class("conflict")
            g1.add(self.conflict)
            page.add(g1)

            g2 = Adw.PreferencesGroup(title="What it does")
            self.action_ids = list(ACTIONS)
            self.action_row = Adw.ComboRow(title="Action",
                                           model=Gtk.StringList.new([ACTIONS[a][0] for a in self.action_ids]))
            self.action_row.set_selected(self.action_ids.index(self.b["action"]) if self.b["action"] in ACTIONS else 0)
            self.action_row.connect("notify::selected", lambda *_: self.update_arg())
            g2.add(self.action_row)
            self.arg_text = Adw.EntryRow(title="Command")
            self.arg_choice = Adw.ComboRow(title="Option")
            self.apps = sorted(((a.get_display_name(), a.get_id()) for a in Gio.AppInfo.get_all()
                                if a.should_show() and a.get_id()), key=lambda t: t[0].lower())
            self.arg_app = Adw.ComboRow(title="App", enable_search=True,
                                        model=Gtk.StringList.new([n for n, _ in self.apps]))
            self.arg_app.set_expression(Gtk.PropertyExpression.new(Gtk.StringObject, None, "string"))
            for w in (self.arg_text, self.arg_choice, self.arg_app):
                g2.add(w)
            page.add(g2)

            g3 = Adw.PreferencesGroup(title="Options")
            self.cat_row = Adw.ComboRow(title="Category", model=Gtk.StringList.new(CATEGORIES))
            self.cat_row.set_selected(CATEGORIES.index(self.b["category"]) if self.b["category"] in CATEGORIES else 0)
            self.repeat_row = Adw.SwitchRow(title="Repeat while held", active=self.b.get("repeating", False))
            self.locked_row = Adw.SwitchRow(title="Also works on the lock screen", active=self.b.get("locked", False))
            for w in (self.cat_row, self.repeat_row, self.locked_row):
                g3.add(w)
            page.add(g3)

            tv.set_content(page)
            self.set_child(tv)

            keys = Gtk.EventControllerKey()
            keys.set_propagation_phase(Gtk.PropagationPhase.CAPTURE)
            keys.connect("key-pressed", self.on_key)
            self.add_controller(keys)
            self.connect("closed", lambda *_: self.stop_record())

            self.update_arg(initial=True)
            self.set_keys(self.b.get("keys", ""))

        # --- keys ---
        def set_keys(self, keys, from_text=False):
            self.b["keys"] = keys.strip()
            parts = key_parts(self.b) if self.b["keys"] else []
            self.rec_btn.set_child(keycaps(parts) if parts else Gtk.Label(label="Record shortcut"))
            if not from_text and self.keys_text.get_text() != self.b["keys"]:
                self.keys_text.set_text(self.b["keys"])
            other = self.win.conflicts(self.b)
            self.conflict.set_label(f"⚠ Already used by: {', '.join(other)}. Both will run." if other else "")
            self.conflict.set_visible(bool(other))

        def start_record(self):
            self.recording = True
            submap("keycapture")  # so existing binds like Super+W don't fire while recording
            self.rec_btn.add_css_class("recording")
            self.rec_btn.set_child(Gtk.Label(label="Press keys…  (Esc to cancel)"))
            self.rec_btn.grab_focus()
            GLib.timeout_add_seconds(10, self.stop_record_timeout)

        def stop_record_timeout(self):
            if self.recording:
                self.stop_record()
                self.set_keys(self.b["keys"])
            return False

        def stop_record(self):
            if self.recording:
                self.recording = False
                submap("reset")
                self.rec_btn.remove_css_class("recording")

        def on_key(self, ctrl, keyval, keycode, state):
            if not self.recording:
                return False
            name = Gdk.keyval_name(keyval) or ""
            if name in MOD_KEYS:
                return True
            if name == "Escape" and not (state & Gdk.ModifierType.MODIFIER_MASK & ~Gdk.ModifierType.LOCK_MASK):
                self.stop_record(); self.set_keys(self.b["keys"]); return True
            mods = [m for mask, m in MODS.items() if state & mask]
            # base key without Shift/AltGr levels
            ok, base, *_ = ctrl.get_widget().get_display().translate_key(keycode, 0, ctrl.get_group())
            if ok:
                name = Gdk.keyval_name(base) or name
            if 10 <= keycode <= 19:  # number row by physical key (AZERTY safe)
                key = f"code:{keycode}"
            elif len(name) == 1:
                key = name.upper()
            else:
                key = name
            order = ["SUPER", "CONTROL", "ALT", "SHIFT"]
            mods.sort(key=order.index)
            self.stop_record()
            if self.b["action"] == "ws_digits":
                self.set_keys(" + ".join(mods))  # number keys are added automatically
            else:
                self.set_keys(" + ".join(mods + [key]))
            return True

        # --- action argument ---
        def update_arg(self, initial=False):
            a = self.action_ids[self.action_row.get_selected()]
            kind, choices = ACTIONS[a][1], ACTIONS[a][2]
            self.arg_text.set_visible(kind == "text")
            self.arg_choice.set_visible(kind == "choice")
            self.arg_app.set_visible(kind == "app")
            arg = self.b.get("arg", "") if (initial or a == self.b["action"]) else ""
            if kind == "text":
                self.arg_text.set_title(ARG_HINT.get(a, "Value"))
                self.arg_text.set_text(arg)
            elif kind == "choice":
                self.choice_vals = [c for c, _ in choices]
                self.arg_choice.set_model(Gtk.StringList.new([l for _, l in choices]))
                self.arg_choice.set_selected(self.choice_vals.index(arg) if arg in self.choice_vals else 0)
            elif kind == "app":
                ids = [i for _, i in self.apps]
                self.arg_app.set_selected(ids.index(arg) if arg in ids else 0)
            if a == "ws_digits":
                self.key_row.set_subtitle("Modifiers only: number keys 1–9 are added automatically")
            else:
                self.key_row.set_subtitle("Click, then press the keys")
            if not initial:
                self.b["action"] = a
                self.set_keys(self.b["keys"])

        def do_save(self, *_):
            a = self.action_ids[self.action_row.get_selected()]
            kind = ACTIONS[a][1]
            b = self.b
            b["action"] = a
            if kind == "text":
                b["arg"] = self.arg_text.get_text().strip()
            elif kind == "choice":
                b["arg"] = self.choice_vals[self.arg_choice.get_selected()]
            elif kind == "app":
                b["arg"] = self.apps[self.arg_app.get_selected()][1] if self.apps else ""
            else:
                b["arg"] = ""
            b["desc"] = self.name_row.get_text().strip() or summary(b)
            b["category"] = CATEGORIES[self.cat_row.get_selected()]
            b["repeating"] = self.repeat_row.get_active()
            b["locked"] = self.locked_row.get_active()
            if not b["keys"] or (kind == "text" and not b["arg"]):
                self.win.toast("Add a shortcut and what it should do first")
                return
            b.setdefault("id", uuid.uuid4().hex[:8])
            other = self.win.conflicts(b)
            if other:
                keys = " + ".join(pretty(p) for p in key_parts(b))
                d = Adw.AlertDialog(heading="That combination is already used",
                    body=f"{keys} is already assigned to: {', '.join(other)}.\n\n"
                         "If you save, both actions run when you press it. Save anyway?")
                d.add_response("cancel", "Pick different keys")
                d.add_response("save", "Save anyway")
                d.set_response_appearance("save", Adw.ResponseAppearance.DESTRUCTIVE)
                d.set_default_response("cancel")
                d.connect("response", lambda _d, r: r == "save" and (self.on_save(b), self.close()))
                d.present(self)
                return
            self.on_save(b)
            self.close()

    class Window(Adw.ApplicationWindow):
        def __init__(self, app):
            super().__init__(application=app, title="Keyboard Shortcuts", default_width=760, default_height=760)
            self.binds = load()
            for _b in self.binds:
                _b.setdefault("id", uuid.uuid4().hex[:8])
            self.toasts = Adw.ToastOverlay()
            tv = Adw.ToolbarView()
            hb = Adw.HeaderBar()
            add = Gtk.Button(icon_name="list-add-symbolic", tooltip_text="Add shortcut")
            add.add_css_class("suggested-action")
            add.connect("clicked", lambda *_: self.edit(None))
            hb.pack_start(add)
            self.search = Gtk.SearchEntry(placeholder_text="Search shortcuts, keys or commands", hexpand=True)
            self.search.connect("search-changed", lambda *_: self.rebuild())
            clamp_s = Adw.Clamp(maximum_size=420, child=self.search)
            hb.set_title_widget(clamp_s)
            tv.add_top_bar(hb)
            self.scroller_holder = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
            tv.set_content(self.scroller_holder)
            self.toasts.set_child(tv)
            self.set_content(self.toasts)

            keys = Gtk.EventControllerKey()
            keys.connect("key-pressed", self.on_key)
            self.add_controller(keys)
            self.rebuild()
            self.search.grab_focus()

        def on_key(self, _c, keyval, _code, state):
            if keyval == Gdk.KEY_Escape and not self.search.get_text():
                self.close(); return True
            if keyval == Gdk.KEY_n and state & Gdk.ModifierType.CONTROL_MASK:
                self.edit(None); return True
            return False

        def toast(self, text, undo=None):
            t = Adw.Toast(title=text, timeout=4)
            if undo:
                t.set_button_label("Undo")
                t.connect("button-clicked", lambda *_: undo())
            self.toasts.add_toast(t)

        def conflicts(self, b):
            if not b.get("keys"):
                return []
            mine = norm(b["keys"]) + ("#digits" if b["action"] == "ws_digits" else "")
            return [o.get("desc", o["keys"]) for o in self.binds if o is not b and o.get("id") != b.get("id")
                    and norm(o["keys"]) + ("#digits" if o["action"] == "ws_digits" else "") == mine]

        def rebuild(self):
            child = self.scroller_holder.get_first_child()
            if child:
                self.scroller_holder.remove(child)
            page = Adw.PreferencesPage(vexpand=True)
            q = self.search.get_text().strip().lower()
            shown = 0
            for cat in CATEGORIES:
                items = [b for b in self.binds if b["category"] == cat]
                if q:
                    items = [b for b in items if q in (b.get("desc", "") + " " + " ".join(map(pretty, key_parts(b)))
                                                       + " " + b["keys"] + " " + summary(b)).lower()]
                if not items:
                    continue
                g = Adw.PreferencesGroup(title=GLib.markup_escape_text(cat))
                cnt = Gtk.Label(label=str(len(items)))
                cnt.add_css_class("count")
                g.set_header_suffix(cnt)
                for b in items:
                    g.add(self.row(b))
                    shown += 1
                page.add(g)
            if not shown:
                g = Adw.PreferencesGroup()
                g.add(Adw.StatusPage(icon_name="system-search-symbolic", title="No shortcuts found"))
                page.add(g)
            self.scroller_holder.append(page)

        def row(self, b):
            title, sub = b.get("desc") or summary(b), summary(b)
            r = Adw.ActionRow(title=GLib.markup_escape_text(title),
                              subtitle=GLib.markup_escape_text(sub if sub != title else ""), activatable=True)
            r.set_subtitle_lines(1)
            other = self.conflicts(b)
            if other:
                warn = Gtk.Image.new_from_icon_name("dialog-warning-symbolic")
                warn.add_css_class("conflict")
                warn.set_tooltip_text("Same keys as: " + ", ".join(other))
                r.add_suffix(warn)
            r.add_suffix(keycaps(key_parts(b)))
            edit = Gtk.Button(icon_name="document-edit-symbolic", valign=Gtk.Align.CENTER, tooltip_text="Edit")
            edit.add_css_class("flat")
            edit.connect("clicked", lambda *_: self.edit(b))
            delete = Gtk.Button(icon_name="user-trash-symbolic", valign=Gtk.Align.CENTER, tooltip_text="Delete")
            delete.add_css_class("flat")
            delete.connect("clicked", lambda *_: self.delete(b))
            r.add_suffix(edit); r.add_suffix(delete)
            r.connect("activated", lambda *_: self.edit(b))
            return r

        def edit(self, b):
            def saved(nb):
                new = [x for x in self.binds]
                if b is None:
                    new.append(nb)
                else:
                    new[new.index(b)] = nb
                self.commit(new, "Shortcut saved")
            Editor(self, b, saved).present(self)

        def delete(self, b):
            old = list(self.binds)
            self.commit([x for x in self.binds if x is not b], f"Deleted “{b.get('desc') or summary(b)}”",
                        undo=lambda: self.commit(old, "Restored"))

        def commit(self, new, msg, undo=None):
            err = apply(new)
            if err:
                self.toast("Hyprland rejected that, nothing changed: " + err.splitlines()[0][:120])
                return
            self.binds = load()
            self.rebuild()
            self.toast(msg, undo)

    class App(Adw.Application):
        def __init__(self):
            super().__init__(application_id=APP_ID)

        def do_activate(self):
            win = self.get_active_window()
            if win:
                win.present(); return
            prov = Gtk.CssProvider()
            prov.load_from_string(CSS)
            Gtk.StyleContext.add_provider_for_display(Gdk.Display.get_default(), prov,
                                                      Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
            Window(self).present()

    if embed_app is not None:                 # embed this app's panel inside another window
        prov = Gtk.CssProvider(); prov.load_from_string(CSS)
        Gtk.StyleContext.add_provider_for_display(Gdk.Display.get_default(), prov,
                                                  Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
        return Window(embed_app)
    try:
        App().run()
    finally:
        submap("reset")  # never leave Hyprland stuck in the recording submap


if __name__ == "__main__":
    if sys.argv[1:] == ["generate"]:
        err = apply(load())
        sys.exit(err or 0)
    run_gui()
