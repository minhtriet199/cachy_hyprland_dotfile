import QtQuick

// Status bar at the top of every phone screen, like a real phone:
// left  — time, then little bubbles for apps with notifications · date under it
// right — quiet (DND), Bluetooth, Wi-Fi, sound, battery icon + % · one small line under it (Wi-Fi name, speeds…)
Item {
    id: st
    property var svc
    property real timePx: 19
    property string right2: ""
    width: parent ? parent.width : 324
    height: 39
    readonly property var notifApps: {
        if (!svc) return [];
        const seen = [];
        for (const n of svc.notifications) if (!seen.some(x => x.app === n.app)) seen.push({ app: n.app, tint: n.tint });
        return seen;
    }

    // left
    Row {
        x: 6; spacing: 6
        UiText { text: st.svc ? st.svc.timeText : ""; px: st.timePx; w: 700; height: st.timePx * 1.05 }
        Row {
            anchors.verticalCenter: parent.verticalCenter; spacing: 3
            Repeater {
                model: st.notifApps.slice(0, 3)
                delegate: Rectangle {
                    required property var modelData
                    width: 16; height: 16; radius: 8; color: modelData.tint; border.width: 1.5; border.color: Theme.inkPhone
                    UiText { anchors.centerIn: parent; text: modelData.app.charAt(0).toUpperCase(); px: 9; w: 700; color: "#FFFFFF" }
                }
            }
            UiText { visible: st.notifApps.length > 3; text: "+" + (st.notifApps.length - 3); fam: "n"; px: 10; w: 900; color: Theme.textSoft; anchors.verticalCenter: parent.verticalCenter }
        }
    }
    UiText { x: 6; y: st.timePx * 1.05; text: st.svc ? st.svc.phoneDate : ""; fam: "n"; px: 11; w: 800; color: Theme.textSoft }

    // right
    Row {
        id: icons
        anchors.right: parent.right; anchors.rightMargin: 6; y: 1; spacing: 5
        readonly property color ic: Theme.textDeep
        Glyph { visible: !!st.svc && st.svc.dnd; name: "bellOff"; size: 14; stroke: 2.4; color: icons.ic; anchors.verticalCenter: parent.verticalCenter }
        Glyph { visible: !!st.svc && st.svc.btState !== "off"; name: st.svc && st.svc.btState === "connected" ? "btConnected" : "bluetooth"; size: 14; stroke: 2.4; color: icons.ic; anchors.verticalCenter: parent.verticalCenter }
        Item {
            width: 14; height: 14; anchors.verticalCenter: parent.verticalCenter
            readonly property string w: st.svc ? (st.svc.wifiIcon === "connecting" ? "none" : st.svc.wifiIcon) : "wifiOff"
            Glyph { visible: parent.w === "wifi1" || parent.w === "wifi2"; anchors.fill: parent; name: "wifiArcs"; size: 14; stroke: 2.4; color: icons.ic; opacity: 0.28 }
            Glyph { anchors.fill: parent; name: parent.w === "none" ? "wifiArcs" : parent.w; size: 14; stroke: 2.4; color: icons.ic; opacity: parent.w === "none" ? 0.4 : 1 }
        }
        Glyph { name: st.svc ? st.svc.volIcon : "volume"; size: 14; stroke: 2.4; color: icons.ic; anchors.verticalCenter: parent.verticalCenter }
        BarBattery { size: 17; level: st.svc ? st.svc.battery.percent / 100 : 0; charging: !!st.svc && st.svc.battery.charging; color: icons.ic; anchors.verticalCenter: parent.verticalCenter }
        UiText { text: st.svc ? st.svc.battery.percent + "%" : ""; px: 12; w: 700; color: icons.ic; anchors.verticalCenter: parent.verticalCenter }
    }
    UiText { visible: st.right2 !== ""; anchors.right: parent.right; anchors.rightMargin: 6; y: 20; text: st.right2; fam: "n"; px: 10.5; w: 800; color: Theme.textSoft
        width: Math.min(implicitWidth, st.width * 0.55); horizontalAlignment: Text.AlignRight }
}
