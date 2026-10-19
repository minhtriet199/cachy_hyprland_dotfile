#!/usr/bin/env python3
# Light / dark for the apps around Isla (Settings → Shell → Look → Mode). Isla itself follows Prefs.dark.
#   appearance.py dark|light
# Qt/KDE: Kvantum theme Isla ↔ IslaDark, kdeglobals colour scheme Isla ↔ IslaDark.
# GTK: gtk.css imports isla.css ↔ isla-dark.css (made from isla.css with the same colour map as Isla's dark mode),
#      gtk-theme adw-gtk3 ↔ adw-gtk3-dark, color-scheme prefer-light ↔ prefer-dark (browsers, portals follow it).
import colorsys, os, re, subprocess, sys

H = os.path.expanduser("~")
dark = len(sys.argv) > 1 and sys.argv[1] == "dark"


def dk(m):
    r, g, b = (int(m.group(0)[i:i + 2], 16) / 255 for i in (1, 3, 5))
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    if l > 0.7:   l, s = 0.09 + (1 - l) * 0.55, max(0.08, s * 0.3)
    elif l < 0.4: l, s = 0.93 - l * 0.35, s * 0.4
    r, g, b = colorsys.hls_to_rgb(h, l, s)
    return "#%02X%02X%02X" % (round(r * 255), round(g * 255), round(b * 255))


def setkey(path, section, key, value):
    text = open(path).read() if os.path.exists(path) else ""
    if re.search(r"(?m)^\[%s\]" % re.escape(section), text):
        block = re.search(r"(?ms)^\[%s\]\n(.*?)(?=^\[|\Z)" % re.escape(section), text)
        body = block.group(1)
        body = re.sub(r"(?m)^%s=.*$" % key, "%s=%s" % (key, value), body) if re.search(r"(?m)^%s=" % key, body) else "%s=%s\n" % (key, value) + body
        text = text[:block.start(1)] + body + text[block.end(1):]
    else:
        text = text.rstrip() + "\n\n[%s]\n%s=%s\n" % (section, key, value)
    open(path, "w").write(text)


# Qt / KDE
setkey(H + "/.config/Kvantum/kvantum.kvconfig", "General", "theme", "IslaDark" if dark else "Isla")
setkey(H + "/.config/kdeglobals", "General", "ColorScheme", "IslaDark" if dark else "Isla")

# GTK: build the dark css from the light one, then point gtk.css at the right file
for v in ("3.0", "4.0"):
    d = "%s/.config/gtk-%s" % (H, v)
    if not os.path.exists(d + "/isla.css"):
        continue
    light = open(d + "/isla.css").read()
    open(d + "/isla-dark.css", "w").write(re.sub(r"#[0-9A-Fa-f]{6}\b", dk, light).replace("Isla colours", "Isla dark colours", 1))
    css = d + "/gtk.css"
    s = open(css).read() if os.path.exists(css) else ""
    s = re.sub(r'@import url\("(isla|isla-dark|noctalia)\.css"\);', '@import url("%s");' % ("isla-dark.css" if dark else "isla.css"), s)
    if "@import" not in s:
        s = '@import url("%s");\n' % ("isla-dark.css" if dark else "isla.css") + s
    open(css, "w").write(s)
    ini = d + "/settings.ini"
    if os.path.exists(ini):
        setkey(ini, "Settings", "gtk-application-prefer-dark-theme", "1" if dark else "0")
subprocess.run(["gsettings", "set", "org.gnome.desktop.interface", "gtk-theme", "adw-gtk3-dark" if dark else "adw-gtk3"])
subprocess.run(["gsettings", "set", "org.gnome.desktop.interface", "color-scheme", "prefer-dark" if dark else "prefer-light"])
print("dark" if dark else "light")
