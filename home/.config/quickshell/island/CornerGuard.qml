import QtQuick

// Crash guard (Qt 6.12): a right-click on a window's very first pixel (0,0) while that window has no focused item made Qt
// build a context-menu event from activeFocusItem->mapToScene() on a null item → Quickshell segfault. Taking the right
// press there stops Qt from making that event. One goes in every Island window; 1 px, nothing else changes.
MouseArea { width: 1; height: 1; z: 1e6; acceptedButtons: Qt.RightButton }
