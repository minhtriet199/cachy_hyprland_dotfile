#!/usr/bin/env python3
# Network Settings: an easier, more advanced front-end for NetworkManager (nmcli).
# Pick a saved network, then: status & internet test, DNS presets with a speed test,
# automatic or static IP, IPv6, Wi-Fi band, MAC privacy, metered, auto-connect, password, forget.
# Changes are written with `nmcli connection modify` and re-applied to the live connection.
import os, random, socket, struct, subprocess, threading, time

APP_ID = "dev.gamer.NetworkSettings"

DNS_PRESETS = [
    # id, label, ipv4, ipv6, note
    ("auto", "Automatic (from router)", [], [], "Whatever your router hands out"),
    ("google", "Google", ["8.8.8.8", "8.8.4.4"], ["2001:4860:4860::8888", "2001:4860:4860::8844"], "Fast, reliable"),
    ("cloudflare", "Cloudflare", ["1.1.1.1", "1.0.0.1"], ["2606:4700:4700::1111", "2606:4700:4700::1001"], "Fast, privacy-focused"),
    ("cloudflare-sec", "Cloudflare · block malware", ["1.1.1.2", "1.0.0.2"], ["2606:4700:4700::1112", "2606:4700:4700::1002"], "Blocks known malware sites"),
    ("cloudflare-family", "Cloudflare · family", ["1.1.1.3", "1.0.0.3"], ["2606:4700:4700::1113", "2606:4700:4700::1003"], "Blocks malware and adult sites"),
    ("quad9", "Quad9", ["9.9.9.9", "149.112.112.112"], ["2620:fe::fe", "2620:fe::9"], "Blocks malware, privacy-focused"),
    ("adguard", "AdGuard", ["94.140.14.14", "94.140.15.15"], ["2a10:50c0::ad1:ff", "2a10:50c0::ad2:ff"], "Blocks ads and trackers"),
    ("opendns", "OpenDNS", ["208.67.222.222", "208.67.220.220"], ["2620:119:35::35", "2620:119:53::53"], "Cisco"),
    ("custom", "Custom…", [], [], "Type your own servers"),
]
MAC_MODES = [("", "Default"), ("permanent", "Real address"), ("stable", "Private, fixed per network"),
             ("random", "Private, new every time")]
BANDS = [("", "Automatic"), ("a", "5 GHz only"), ("bg", "2.4 GHz only")]
METERED = [("unknown", "Automatic"), ("yes", "Metered (save data)"), ("no", "Not metered")]
IPV6 = [("auto", "Automatic"), ("disabled", "Off")]


# ---------------- nmcli helpers ----------------

def nm(*args, check=False):
    r = subprocess.run(["nmcli", *args], capture_output=True, text=True)
    if check and r.returncode:
        raise RuntimeError((r.stderr or r.stdout).strip())
    return r.stdout


def split_t(line):
    """Split one line of `nmcli -t` output on unescaped colons."""
    out, cur, esc = [], "", False
    for ch in line:
        if esc:
            cur += ch; esc = False
        elif ch == "\\":
            esc = True
        elif ch == ":":
            out.append(cur); cur = ""
        else:
            cur += ch
    out.append(cur)
    return out


def connections():
    res = []
    for line in nm("-t", "-f", "NAME,UUID,TYPE,DEVICE,ACTIVE", "connection", "show").splitlines():
        name, uuid, typ, dev, active = split_t(line)
        if typ in ("802-11-wireless", "802-3-ethernet"):
            res.append({"name": name, "uuid": uuid, "type": typ, "device": dev, "active": active == "yes"})
    res.sort(key=lambda c: (not c["active"], c["name"].lower()))
    return res


FIELDS = ["connection.id", "connection.autoconnect", "connection.autoconnect-priority", "connection.metered",
          "ipv4.method", "ipv4.addresses", "ipv4.gateway", "ipv4.dns", "ipv4.ignore-auto-dns",
          "ipv6.method", "ipv6.dns", "ipv6.ignore-auto-dns"]
WIFI_FIELDS = ["802-11-wireless.ssid", "802-11-wireless.band", "802-11-wireless.cloned-mac-address",
               "802-11-wireless-security.key-mgmt"]


def settings(uuid, wifi):
    fields = FIELDS + (WIFI_FIELDS if wifi else [])
    vals = nm("-g", ",".join(fields), "connection", "show", uuid).split("\n")
    return {f: (vals[i] if i < len(vals) else "") for i, f in enumerate(fields)}


def live(dev):
    if not dev:
        return {}
    d = {}
    for line in nm("-t", "-f", "GENERAL.HWADDR,GENERAL.STATE,IP4.ADDRESS,IP4.GATEWAY,IP4.DNS,IP6.ADDRESS,IP6.DNS",
                   "device", "show", dev).splitlines():
        k, _, v = line.partition(":")
        key = k.split("[")[0]
        d.setdefault(key, []).append(v.replace("\\:", ":"))
    for line in nm("-t", "-f", "ACTIVE,SSID,SIGNAL,FREQ,RATE,SECURITY", "device", "wifi", "list",
                   "ifname", dev, "--rescan", "no").splitlines():
        f = split_t(line)
        if f[0] == "yes":
            d["wifi"] = {"ssid": f[1], "signal": f[2], "freq": f[3], "rate": f[4], "security": f[5]}
    return d


def password(uuid):
    return nm("-s", "-g", "802-11-wireless-security.psk", "connection", "show", uuid).strip()


def ssh_state():
    installed = os.path.exists("/usr/bin/sshd")
    active = subprocess.run(["systemctl", "is-active", "sshd"], capture_output=True, text=True).stdout.strip() == "active"
    ready = os.path.exists("/usr/local/bin/ssh-toggle")  # the narrow privileged helper
    return installed, active, ready


# ---------------- tests ----------------

def dns_query_ms(server, name="www.google.com", timeout=1.5):
    """Time one DNS A query straight to `server` (UDP 53). None if it fails."""
    qid = random.randint(0, 0xFFFF)
    q = struct.pack(">HHHHHH", qid, 0x0100, 1, 0, 0, 0)
    q += b"".join(bytes([len(p)]) + p.encode() for p in name.split(".")) + b"\0" + struct.pack(">HH", 1, 1)
    fam = socket.AF_INET6 if ":" in server else socket.AF_INET
    try:
        with socket.socket(fam, socket.SOCK_DGRAM) as s:
            s.settimeout(timeout)
            t = time.perf_counter()
            s.sendto(q, (server, 53))
            data = s.recv(512)
            if data[:2] != q[:2]:
                return None
            return (time.perf_counter() - t) * 1000
    except OSError:
        return None


def best_of(server, n=3):
    times = [t for t in (dns_query_ms(server) for _ in range(n)) if t is not None]
    return min(times) if times else None


def ping_ms(host="1.1.1.1"):
    out = subprocess.run(["ping", "-c", "3", "-i", "0.3", "-W", "2", host], capture_output=True, text=True).stdout
    for line in out.splitlines():
        if "min/avg" in line:
            return float(line.split("=")[1].split("/")[1])
    return None


# ---------------- devices on the network ----------------

_oui = None


def vendor(mac):
    global _oui
    if _oui is None:
        _oui = {}
        try:
            for line in open("/usr/share/hwdata/oui.txt", errors="replace"):
                if "(hex)" in line:
                    pre, _, name = line.partition("(hex)")
                    _oui[pre.strip().replace("-", "").upper()] = name.strip()
        except OSError:
            pass
    m = mac.replace(":", "").upper()
    if len(m) >= 2 and int(m[1], 16) & 2:  # locally administered = randomized "private" address
        return "Private address (phone/laptop hiding its real MAC)"
    return _oui.get(m[:6], "Unknown maker")


def mdns_name(ip):
    try:
        out = subprocess.run(["avahi-resolve", "-a", ip], capture_output=True, text=True, timeout=2).stdout.split()
        return out[1].removesuffix(".local") if len(out) > 1 else ""
    except (subprocess.TimeoutExpired, OSError):
        return ""


def dns_name(ip):
    try:
        return socket.gethostbyaddr(ip)[0].split(".")[0]
    except OSError:
        return ""


def scan(cidr):
    """Find devices on the local subnet: poke every address so it answers ARP, then read the neighbour table."""
    import ipaddress
    net = ipaddress.ip_network(cidr, strict=False)
    hosts = list(net.hosts())[:1024]
    def poke(ip):
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as so:
                so.sendto(b"", (str(ip), 9))  # discard port: harmless, but forces an ARP lookup
        except OSError:
            pass
        subprocess.run(["ping", "-c", "1", "-W", "1", str(ip)], capture_output=True)
    threads = [threading.Thread(target=poke, args=(ip,)) for ip in hosts]
    for i in range(0, len(threads), 64):
        batch = threads[i:i + 64]
        for t in batch: t.start()
        for t in batch: t.join()
    time.sleep(0.5)
    found = {}
    for line in subprocess.run(["ip", "-4", "neigh"], capture_output=True, text=True).stdout.splitlines():
        f = line.split()
        if "lladdr" in f and f[-1] != "FAILED" and ipaddress.ip_address(f[0]) in net:
            found[f[0]] = f[f.index("lladdr") + 1].upper()
    devices = []
    vendor("00:00:00:00:00:00")  # load the maker database once, before the threads below share it
    def describe(ip, mac):
        devices.append({"ip": ip, "mac": mac, "vendor": vendor(mac), "name": mdns_name(ip) or dns_name(ip)})
    ts = [threading.Thread(target=describe, args=kv) for kv in found.items()]
    for t in ts: t.start()
    for t in ts: t.join()
    return sorted(devices, key=lambda d: tuple(int(x) for x in d["ip"].split(".")))


# ---------------- GUI ----------------

def run_gui():
    import gi
    gi.require_version("Gtk", "4.0")
    gi.require_version("Adw", "1")
    from gi.repository import Gtk, Adw, Gdk, GLib

    CSS = """
    .hero { padding: 16px 18px; border-radius: 14px; }
    .hero-name { font-size: 20px; font-weight: 800; }
    .hero-state { font-size: 12px; font-weight: 700; }
    .ok { color: @success_color; } .bad { color: @error_color; }
    .stat-value { font-weight: 700; font-feature-settings: "tnum"; }
    .stat-label { font-size: 11px; opacity: 0.6; }
    .mono { font-family: monospace; }
    .ms { font-weight: 700; font-feature-settings: "tnum"; }
    .fastest { color: @success_color; }
    """

    def bg(fn, done):
        """Run fn() off the UI thread, then done(result) on it."""
        def work():
            try:
                r = fn()
            except Exception as e:  # report instead of crashing the window
                r = e
            GLib.idle_add(lambda: (done(r), False)[1])
        threading.Thread(target=work, daemon=True).start()

    def combo(title, options, current, subtitle=None):
        row = Adw.ComboRow(title=title, model=Gtk.StringList.new([l for _, l in options]))
        if subtitle:
            row.set_subtitle(subtitle)
        keys = [k for k, _ in options]
        row.set_selected(keys.index(current) if current in keys else 0)
        row.keys = keys
        return row

    def stat(label, value):
        b = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=1, hexpand=True)
        v = Gtk.Label(label=value or "–", xalign=0, selectable=True, ellipsize=3)
        v.add_css_class("stat-value")
        l = Gtk.Label(label=label, xalign=0)
        l.add_css_class("stat-label")
        b.append(v); b.append(l)
        return b

    class Window(Adw.ApplicationWindow):
        def __init__(self, app):
            super().__init__(application=app, title="Network Settings", default_width=640, default_height=820)
            self.toasts = Adw.ToastOverlay()
            tv = Adw.ToolbarView()
            hb = Adw.HeaderBar()
            refresh = Gtk.Button(icon_name="view-refresh-symbolic", tooltip_text="Refresh")
            refresh.connect("clicked", lambda *_: self.load(self.conn["uuid"] if self.conn else None))
            hb.pack_start(refresh)
            self.apply_btn = Gtk.Button(label="Apply", sensitive=False)
            self.apply_btn.add_css_class("suggested-action")
            self.apply_btn.connect("clicked", lambda *_: self.apply())
            hb.pack_end(self.apply_btn)
            tv.add_top_bar(hb)
            self.holder = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
            tv.set_content(self.holder)
            self.toasts.set_child(tv)
            self.set_content(self.toasts)
            keys = Gtk.EventControllerKey()
            keys.connect("key-pressed", lambda _c, kv, *_: (kv == Gdk.KEY_Escape and self.close()) or False)
            self.add_controller(keys)
            self.conn = None
            self.load()

        def toast(self, text):
            self.toasts.add_toast(Adw.Toast(title=text, timeout=4))

        def changed(self, *_):
            if not getattr(self, "loading", False):
                self.apply_btn.set_sensitive(True)

        # ---------- build page ----------
        def load(self, uuid=None):
            self.conns = connections()
            if not self.conns:
                self.swap(Adw.StatusPage(icon_name="network-offline-symbolic", title="No saved networks"))
                return
            self.conn = next((c for c in self.conns if c["uuid"] == uuid), self.conns[0])
            wifi = self.conn["type"] == "802-11-wireless"
            self.s = settings(self.conn["uuid"], wifi)
            self.live = live(self.conn["device"]) if self.conn["active"] else {}
            self.loading = True
            self.swap(self.build(wifi))
            self.loading = False
            self.apply_btn.set_sensitive(False)

        def swap(self, widget):
            old = self.holder.get_first_child()
            if old:
                self.holder.remove(old)
            self.holder.append(widget)

        def build(self, wifi):
            page = Adw.PreferencesPage(vexpand=True)
            s, lv, c = self.s, self.live, self.conn

            # network picker
            g = Adw.PreferencesGroup()
            pick = Adw.ComboRow(title="Network", model=Gtk.StringList.new(
                [("● " if x["active"] else "") + x["name"] for x in self.conns]))
            pick.set_selected(self.conns.index(c))
            pick.connect("notify::selected", lambda r, _p: self.load(self.conns[r.get_selected()]["uuid"]))
            g.add(pick)
            page.add(g)

            # status card
            g = Adw.PreferencesGroup()
            card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
            card.add_css_class("card"); card.add_css_class("hero")
            top = Gtk.Box(spacing=10)
            icon = Gtk.Image.new_from_icon_name("network-wireless-signal-excellent-symbolic" if wifi
                                                else "network-wired-symbolic")
            icon.set_pixel_size(28)
            names = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, hexpand=True)
            n = Gtk.Label(label=c["name"], xalign=0, ellipsize=3)
            n.add_css_class("hero-name")
            st = Gtk.Label(label="Connected" if c["active"] else "Not connected", xalign=0)
            st.add_css_class("hero-state"); st.add_css_class("ok" if c["active"] else "bad")
            names.append(n); names.append(st)
            btn = Gtk.Button(label="Disconnect" if c["active"] else "Connect", valign=Gtk.Align.CENTER)
            if not c["active"]:
                btn.add_css_class("suggested-action")
            btn.connect("clicked", lambda *_: self.toggle_connection())
            top.append(icon); top.append(names); top.append(btn)
            card.append(top)
            if c["active"]:
                w = lv.get("wifi", {})
                grid = Gtk.Grid(column_spacing=16, row_spacing=10, column_homogeneous=True)
                freq = w.get("freq", "")
                band = ("5 GHz" if freq.startswith("5") else "6 GHz" if freq.startswith("6") else "2.4 GHz") if freq else ""
                items = [("IP address", (lv.get("IP4.ADDRESS") or [""])[0]),
                         ("Gateway (router)", (lv.get("IP4.GATEWAY") or [""])[0]),
                         ("DNS in use", ", ".join(x for x in lv.get("IP4.DNS", []) + lv.get("IP6.DNS", []) if x))]
                if wifi:
                    items = [("Signal", f'{w.get("signal", "?")}%'), ("Band", band),
                             ("Link speed", w.get("rate", ""))] + items
                items.append(("MAC address", (lv.get("GENERAL.HWADDR") or [""])[0]))
                for i, (label, value) in enumerate(items):
                    grid.attach(stat(label, value), i % 3, i // 3, 1, 1)
                card.append(grid)
                test = Gtk.Box(spacing=10)
                self.test_label = Gtk.Label(label="", xalign=0, hexpand=True, wrap=True)
                self.test_label.add_css_class("stat-label")
                tb = Gtk.Button(label="Test internet")
                tb.connect("clicked", lambda *_: self.test_internet())
                test.append(self.test_label); test.append(tb)
                card.append(test)
            g.add(card)
            page.add(g)

            # DNS
            g = Adw.PreferencesGroup(title="DNS", description="Which servers turn website names into addresses. "
                                     "A faster or filtering DNS can speed up browsing or block ads/malware.")
            v4 = [x for x in s["ipv4.dns"].split(",") if x]
            current = "auto" if s["ipv4.ignore-auto-dns"] != "yes" or not v4 else next(
                (p[0] for p in DNS_PRESETS if p[2] and p[2] == v4), "custom")
            self.dns_row = combo("DNS provider", [(p[0], p[1]) for p in DNS_PRESETS], current)
            g.add(self.dns_row)
            self.dns1 = Adw.EntryRow(title="Primary DNS", text=v4[0] if len(v4) > 0 else "")
            self.dns2 = Adw.EntryRow(title="Secondary DNS", text=v4[1] if len(v4) > 1 else "")
            self.dns6 = Adw.EntryRow(title="IPv6 DNS (optional, comma separated)", text=s["ipv6.dns"])
            for r in (self.dns1, self.dns2, self.dns6):
                r.add_css_class("mono")
                r.connect("changed", self.changed)
                g.add(r)
            self.dns_row.connect("notify::selected", lambda *_: (self.dns_mode(), self.changed()))
            speed = Adw.ExpanderRow(title="DNS speed test", subtitle="Find the fastest provider from here")
            self.speed_rows = {}
            for pid, label, ips, _, note in DNS_PRESETS:
                if not ips:
                    continue
                r = Adw.ActionRow(title=label, subtitle=f"{note} · {ips[0]}")
                ms = Gtk.Label(label="–")
                ms.add_css_class("ms")
                r.add_suffix(ms)
                use = Gtk.Button(label="Use", valign=Gtk.Align.CENTER)
                use.add_css_class("flat")
                use.connect("clicked", lambda _b, pid=pid: self.dns_row.set_selected(self.dns_row.keys.index(pid)))
                r.add_suffix(use)
                speed.add_row(r)
                self.speed_rows[pid] = ms
            run = Gtk.Button(label="Run test", valign=Gtk.Align.CENTER)
            run.connect("clicked", lambda *_: self.dns_speed())
            speed.add_suffix(run)
            g.add(speed)
            page.add(g)
            self.dns_mode()

            # IP
            g = Adw.PreferencesGroup(title="IP address")
            self.dhcp = Adw.SwitchRow(title="Automatic (DHCP)", subtitle="Get an address from the router",
                                      active=s["ipv4.method"] != "manual")
            g.add(self.dhcp)
            addr = s["ipv4.addresses"].split(",")[0] if s["ipv4.addresses"] else ""
            ip, _, prefix = addr.partition("/")
            if not ip and lv.get("IP4.ADDRESS"):  # prefill with the current address
                ip, _, prefix = lv["IP4.ADDRESS"][0].partition("/")
            self.ip = Adw.EntryRow(title="IP address", text=ip)
            self.prefix = Adw.EntryRow(title="Subnet prefix (24 = 255.255.255.0)", text=prefix or "24")
            self.gw = Adw.EntryRow(title="Gateway", text=s["ipv4.gateway"] or (lv.get("IP4.GATEWAY") or [""])[0])
            for r in (self.ip, self.prefix, self.gw):
                r.add_css_class("mono")
                r.connect("changed", self.changed)
                g.add(r)
            self.dhcp.connect("notify::active", lambda *_: (self.ip_mode(), self.changed()))
            self.ipv6 = combo("IPv6", IPV6, "disabled" if s["ipv6.method"] in ("disabled", "ignore") else "auto",
                              "Turn off if some sites are slow or fail to load")
            self.ipv6.connect("notify::selected", self.changed)
            g.add(self.ipv6)
            page.add(g)
            self.ip_mode()

            # Wi-Fi / connection options
            g = Adw.PreferencesGroup(title="Wi-Fi" if wifi else "Connection")
            if wifi:
                self.band = combo("Band", BANDS, s["802-11-wireless.band"],
                                  "5 GHz is faster, 2.4 GHz reaches further through walls")
                self.mac = combo("MAC address", MAC_MODES, s["802-11-wireless.cloned-mac-address"],
                                 "Private addresses stop networks from tracking this laptop")
                for r in (self.band, self.mac):
                    r.connect("notify::selected", self.changed)
                    g.add(r)
                if s["802-11-wireless-security.key-mgmt"]:
                    pw = Adw.PasswordEntryRow(title="Password (click the eye to show)", text=password(c["uuid"]))
                    pw.set_editable(False)
                    copy = Gtk.Button(icon_name="edit-copy-symbolic", valign=Gtk.Align.CENTER, tooltip_text="Copy password")
                    copy.add_css_class("flat")
                    copy.connect("clicked", lambda *_: (self.get_clipboard().set(password(c["uuid"])),
                                                        self.toast("Password copied")))
                    pw.add_suffix(copy)
                    g.add(pw)
            self.auto = Adw.SwitchRow(title="Connect automatically", active=s["connection.autoconnect"] == "yes")
            self.metered = combo("Metered connection", METERED, s["connection.metered"],
                                 "Apps hold back big downloads on metered networks")
            self.prio = Adw.SpinRow.new_with_range(-100, 100, 1)
            self.prio.set_title("Priority")
            self.prio.set_subtitle("Higher wins when several saved networks are in range")
            self.prio.set_value(int(s["connection.autoconnect-priority"] or 0))
            for r, sig in ((self.auto, "notify::active"), (self.metered, "notify::selected"), (self.prio, "notify::value")):
                r.connect(sig, self.changed)
                g.add(r)
            page.add(g)

            if c["active"] and lv.get("IP4.ADDRESS"):
                self.dev_group = Adw.PreferencesGroup(
                    title="Devices on this network",
                    description="Phones, TVs, laptops… currently connected. To see what they're browsing or to "
                                "kick one off, use the router's admin page — that traffic never passes this laptop.")
                router = (lv.get("IP4.GATEWAY") or [""])[0]
                if router:
                    open_router = Gtk.Button(label="Router page", valign=Gtk.Align.CENTER, tooltip_text=f"http://{router}")
                    open_router.connect("clicked", lambda *_: subprocess.Popen(["xdg-open", f"http://{router}"]))
                    self.dev_group.set_header_suffix(open_router)
                self.scan_row = Adw.ButtonRow(title="Scan for devices", start_icon_name="system-search-symbolic")
                self.scan_row.connect("activated", lambda *_: self.scan_devices())
                self.dev_group.add(self.scan_row)
                self.dev_rows = []
                page.add(self.dev_group)

            # Remote access (SSH): server + its firewall opening, flipped together
            installed, ssh_on, ssh_ready = ssh_state()
            if installed:
                g = Adw.PreferencesGroup(title="Remote access", description=
                    "Let another device (a PC or phone) log into this laptop over SSH. "
                    "Keep it off unless you're using it — especially on a shared network.")
                self.ssh_row = Adw.SwitchRow(title="SSH server", active=ssh_on)
                myip = (lv.get("IP4.ADDRESS") or [""])[0].split("/")[0]
                user = os.environ.get("USER") or ""
                if ssh_on:
                    self.ssh_row.set_subtitle(f"On · connect with   ssh {user}@{myip}" if myip else "On")
                else:
                    self.ssh_row.set_subtitle("Off · nobody can log in remotely")
                self.ssh_row.connect("notify::active", self.on_ssh)
                g.add(self.ssh_row)
                if not ssh_ready:
                    note = Adw.ActionRow(title="One-time setup needed to use this switch",
                                         subtitle="See the setup command I gave you, then reopen this window.")
                    note.add_prefix(Gtk.Image.new_from_icon_name("dialog-information-symbolic"))
                    g.add(note)
                page.add(g)

            g = Adw.PreferencesGroup()
            forget = Adw.ButtonRow(title="Forget this network")
            forget.add_css_class("destructive-action")
            forget.connect("activated", lambda *_: self.forget())
            g.add(forget)
            page.add(g)
            return page

        def dns_mode(self):
            pid = self.dns_row.keys[self.dns_row.get_selected()]
            p = next(x for x in DNS_PRESETS if x[0] == pid)
            custom = pid == "custom"
            for r in (self.dns1, self.dns2, self.dns6):
                r.set_visible(custom)
            self.dns_row.set_subtitle("" if custom else f'{p[4]}' + (f' · {", ".join(p[2])}' if p[2] else ""))

        def ip_mode(self):
            manual = not self.dhcp.get_active()
            for r in (self.ip, self.prefix, self.gw):
                r.set_visible(manual)

        # ---------- actions ----------
        def collect(self):
            wifi = self.conn["type"] == "802-11-wireless"
            args = []
            pid = self.dns_row.keys[self.dns_row.get_selected()]
            if pid == "auto":
                args += ["ipv4.dns", "", "ipv4.ignore-auto-dns", "no", "ipv6.dns", "", "ipv6.ignore-auto-dns", "no"]
            else:
                if pid == "custom":
                    v4 = [x.strip() for x in (self.dns1.get_text(), self.dns2.get_text()) if x.strip()]
                    v6 = [x.strip() for x in self.dns6.get_text().split(",") if x.strip()]
                    for a in v4 + v6:
                        socket.inet_pton(socket.AF_INET6 if ":" in a else socket.AF_INET, a)  # validates
                    if not v4:
                        raise ValueError("Enter at least a primary DNS server")
                else:
                    p = next(x for x in DNS_PRESETS if x[0] == pid)
                    v4, v6 = p[2], p[3]
                args += ["ipv4.dns", ",".join(v4), "ipv4.ignore-auto-dns", "yes",
                         "ipv6.dns", ",".join(v6), "ipv6.ignore-auto-dns", "yes" if v6 else "no"]
            if self.dhcp.get_active():
                args += ["ipv4.method", "auto", "ipv4.addresses", "", "ipv4.gateway", ""]
            else:
                ip, pre, gw = self.ip.get_text().strip(), self.prefix.get_text().strip(), self.gw.get_text().strip()
                socket.inet_pton(socket.AF_INET, ip)
                socket.inet_pton(socket.AF_INET, gw)
                if not pre.isdigit() or not 0 < int(pre) <= 32:
                    raise ValueError("Subnet prefix must be 1–32")
                args += ["ipv4.method", "manual", "ipv4.addresses", f"{ip}/{pre}", "ipv4.gateway", gw]
            args += ["ipv6.method", self.ipv6.keys[self.ipv6.get_selected()]]
            if wifi:
                args += ["802-11-wireless.band", self.band.keys[self.band.get_selected()],
                         "802-11-wireless.cloned-mac-address", self.mac.keys[self.mac.get_selected()]]
            args += ["connection.autoconnect", "yes" if self.auto.get_active() else "no",
                     "connection.metered", self.metered.keys[self.metered.get_selected()],
                     "connection.autoconnect-priority", str(int(self.prio.get_value()))]
            return args

        def apply(self):
            try:
                args = self.collect()
            except (ValueError, OSError) as e:
                self.toast(f"Check your entries: {e}")
                return
            c = self.conn
            self.apply_btn.set_sensitive(False)
            self.toast("Applying… the connection may blink for a moment")

            def work():
                nm("connection", "modify", c["uuid"], *args, check=True)
                if c["active"]:
                    # reapply keeps the link up when possible; band/MAC changes need a reconnect
                    r = subprocess.run(["nmcli", "device", "reapply", c["device"]], capture_output=True, text=True)
                    if r.returncode or any(a.startswith("802-11-wireless") for a in args[::2]):
                        nm("connection", "up", c["uuid"], check=True)
                return True

            def done(r):
                if isinstance(r, Exception):
                    self.toast(f"Couldn't apply: {r}")
                    self.apply_btn.set_sensitive(True)
                else:
                    self.toast("Saved and applied")
                    self.load(c["uuid"])
            bg(work, done)

        def on_ssh(self, row, _p):
            if getattr(self, "loading", False):
                return
            want = row.get_active()
            installed, now, ready = ssh_state()
            if want == now:
                return
            if not ready:
                self.loading = True; row.set_active(now); self.loading = False
                self.toast("Run the one-time SSH setup command first.")
                return
            row.set_sensitive(False)
            self.toast("Turning SSH on…" if want else "Turning SSH off…")
            bg(lambda: subprocess.run(["sudo", "-n", "/usr/local/bin/ssh-toggle", "on" if want else "off"],
                                      capture_output=True, text=True, check=True),
               lambda r: (self.toast(f"Couldn't change SSH: {getattr(r, 'stderr', r)}")
                          if isinstance(r, Exception) else None, self.load(self.conn["uuid"])))

        def toggle_connection(self):
            c = self.conn
            self.toast("Disconnecting…" if c["active"] else f"Connecting to {c['name']}…")
            bg(lambda: nm("connection", "down" if c["active"] else "up", c["uuid"], check=True),
               lambda r: (self.toast(f"Failed: {r}") if isinstance(r, Exception) else None, self.load(c["uuid"])))

        def forget(self):
            c = self.conn
            d = Adw.AlertDialog(heading=f"Forget “{c['name']}”?",
                                body="Its saved password and settings will be deleted. You can reconnect later "
                                     "by choosing it in the Wi-Fi panel and typing the password again.")
            d.add_response("cancel", "Cancel")
            d.add_response("forget", "Forget")
            d.set_response_appearance("forget", Adw.ResponseAppearance.DESTRUCTIVE)
            d.connect("response", lambda _d, r: r == "forget" and bg(
                lambda: nm("connection", "delete", c["uuid"], check=True),
                lambda res: (self.toast(f"Failed: {res}") if isinstance(res, Exception) else self.toast("Forgotten"),
                             self.load())))
            d.present(self)

        def scan_devices(self):
            lv = self.live
            cidr = lv["IP4.ADDRESS"][0]
            me = (lv.get("GENERAL.HWADDR") or [""])[0].upper()
            router = (lv.get("IP4.GATEWAY") or [""])[0]
            self.scan_row.set_title("Scanning… (about 10 seconds)")
            self.scan_row.set_sensitive(False)

            def done(devs):
                self.scan_row.set_sensitive(True)
                for r in self.dev_rows:
                    self.dev_group.remove(r)
                self.dev_rows = []
                if isinstance(devs, Exception):
                    self.scan_row.set_title("Scan for devices")
                    self.toast(f"Scan failed: {devs}")
                    return
                my_ip = cidr.split("/")[0]
                devs = [d for d in devs if d["ip"] != my_ip]
                devs.insert(0, {"ip": my_ip, "mac": me, "vendor": vendor(me) if me else "", "name": "This laptop"})
                self.scan_row.set_title(f"Scan again · {len(devs)} devices found")
                for d in devs:
                    is_router = d["ip"] == router
                    title = "Router" if is_router else d["name"] or d["vendor"]
                    sub = f'{d["ip"]} · {d["mac"]}' + (f' · {d["vendor"]}' if title != d["vendor"] else "")
                    r = Adw.ActionRow(title=GLib.markup_escape_text(title), subtitle=GLib.markup_escape_text(sub))
                    r.set_subtitle_selectable(True)
                    icon = ("network-wireless-symbolic" if is_router else "computer-laptop-symbolic"
                            if d["name"] == "This laptop" else "phone-symbolic" if "Private" in d["vendor"]
                            else "network-workgroup-symbolic")
                    r.add_prefix(Gtk.Image.new_from_icon_name(icon))
                    self.dev_group.add(r)
                    self.dev_rows.append(r)
            bg(lambda: scan(cidr), done)

        def test_internet(self):
            self.test_label.set_label("Testing…")

            def work():
                p = ping_ms()
                dns_servers = self.live.get("IP4.DNS", [])
                d = best_of(dns_servers[0]) if dns_servers else None
                return p, d

            def done(r):
                if isinstance(r, Exception):
                    self.test_label.set_label(f"Test failed: {r}")
                    return
                p, d = r
                parts = [f"Internet: {p:.0f} ms ping" if p else "Internet: no response",
                         f"DNS answers in {d:.0f} ms" if d else "DNS: no answer"]
                self.test_label.set_label(" · ".join(parts))
            bg(work, done)

        def dns_speed(self):
            for ms in self.speed_rows.values():
                ms.set_label("…")
                ms.remove_css_class("fastest")
            presets = [(p[0], p[2][0]) for p in DNS_PRESETS if p[2]]

            def work():
                res = {}
                threads = [threading.Thread(target=lambda pid=pid, ip=ip: res.__setitem__(pid, best_of(ip)))
                           for pid, ip in presets]
                for t in threads: t.start()
                for t in threads: t.join()
                return res

            def done(res):
                if isinstance(res, Exception):
                    self.toast(f"Speed test failed: {res}")
                    return
                ok = {k: v for k, v in res.items() if v is not None}
                best = min(ok, key=ok.get) if ok else None
                for pid, ms in self.speed_rows.items():
                    v = res.get(pid)
                    ms.set_label(f"{v:.0f} ms" if v is not None else "no reply")
                    if pid == best:
                        ms.add_css_class("fastest")
            bg(work, done)

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
    run_gui()
