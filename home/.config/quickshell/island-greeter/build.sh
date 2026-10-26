#!/bin/sh
# Put the greeter together in one folder: the greeter's own files + copies (never links) of the Island files it reuses.
# Usage: build.sh <out dir>
set -eu
here="$(cd "$(dirname "$0")" && pwd)"
island="${ISLAND_DIR:-$HOME/.config/quickshell/island}"
out="$1"
mkdir -p "$out/fonts"
for f in LockScreen.qml PhoneBody.qml Theme.qml UiCandy.qml UiText.qml UiStrokeText.qml UiDots.qml UiTag.qml UiDashed.qml Glyph.qml Glyphs.js BarBattery.qml IrisWipe.qml SceneWipe.qml JakeWipe.qml JakeLimb.qml JakeShapes.js WipeIcon.qml; do
    cp "$island/$f" "$out/$f"
done
cp "$island"/fonts/*.ttf "$out/fonts/"
cp "$here/shell.qml" "$here/Prefs.qml" "$here/Svc.qml" "$here/greeter.lua" "$out/"
install -m 755 "$here/run-greeter" "$here/island-greeter-session" "$here/island-session" "$here/paint-vt" "$out/"
