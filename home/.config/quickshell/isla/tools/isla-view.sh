#!/bin/sh
# Open a picture in Isla View (view.qml, an instant-camera photo). One viewer: a second open switches its picture.
f=$(readlink -f "${1:-}")
cfg="$HOME/.config/quickshell/isla/view.qml"
qs -p "$cfg" ipc call view open "$f" >/dev/null 2>&1 && exit 0
ISLA_VIEW="$f" exec qs -n -p "$cfg"
