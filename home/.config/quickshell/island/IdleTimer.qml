import QtQuick
import Quickshell.Wayland

// An idle timer that follows changes: Quickshell's IdleMonitor keeps the timeout it started with (the prefs / the
// charger are read a moment later, and Settings changes were ignored), so the monitor is rebuilt whenever minutes changes.
// minutes 0 = off. idle(): no key / mouse for that long · back(): the first key / mouse move after that.
Instantiator {
    id: it
    property real minutes: 0
    property bool respectInhibitors: true          // a playing video / game holds it off
    signal idle()
    signal back()
    model: minutes > 0 ? [minutes] : []
    delegate: IdleMonitor {
        required property real modelData
        timeout: modelData * 60; respectInhibitors: it.respectInhibitors
        onIsIdleChanged: isIdle ? it.idle() : it.back()
    }
}
