#!/bin/sh
# Put the greeter together in one folder: the greeter's own files + copies (never links) of the Isla files it reuses.
# Usage: build.sh <out dir>
set -eu
here="$(cd "$(dirname "$0")" && pwd)"
isla="${ISLA_DIR:-$HOME/.config/quickshell/isla}"
out="$1"
mkdir -p "$out/fonts"
for f in LockScreen.qml Theme.qml UiCandy.qml UiText.qml UiStrokeText.qml UiDots.qml UiTag.qml UiDashed.qml Glyph.qml Glyphs.js BarBattery.qml IrisWipe.qml WipeIcon.qml; do
    cp "$isla/$f" "$out/$f"
done
cp "$isla"/fonts/*.ttf "$out/fonts/"
cp "$here/shell.qml" "$here/Prefs.qml" "$here/Svc.qml" "$here/greeter.lua" "$out/"
install -m 755 "$here/run-greeter" "$here/isla-greeter-session" "$out/"
