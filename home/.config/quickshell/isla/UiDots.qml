import QtQuick

// Dotted paper pattern (phone screens). Drawn at 2.5× and scaled down, clipped to a rounded box.
Item {
    id: root
    property color dot: Theme.screenDot
    property real step: 24
    property real r: 2.6
    property real radius: 0
    property real res: 2.5
    Canvas {
        id: c
        width: root.width * root.res; height: root.height * root.res
        scale: 1 / root.res; transformOrigin: Item.TopLeft
        onWidthChanged: requestPaint(); onHeightChanged: requestPaint()
        onPaint: {
            const g = getContext("2d"); g.reset(); g.scale(root.res, root.res);
            const w = root.width, h = root.height, rr = Math.min(root.radius, w / 2, h / 2);
            if (rr > 0) {
                g.beginPath(); g.moveTo(rr, 0); g.lineTo(w - rr, 0); g.arcTo(w, 0, w, rr, rr); g.lineTo(w, h - rr); g.arcTo(w, h, w - rr, h, rr);
                g.lineTo(rr, h); g.arcTo(0, h, 0, h - rr, rr); g.lineTo(0, rr); g.arcTo(0, 0, rr, 0, rr); g.closePath(); g.clip();
            }
            g.fillStyle = root.dot;
            for (let y = root.step / 2; y < h + root.step; y += root.step)
                for (let x = root.step / 2; x < w + root.step; x += root.step) { g.beginPath(); g.arc(x, y, root.r, 0, Math.PI * 2); g.fill() }
        }
    }
}
