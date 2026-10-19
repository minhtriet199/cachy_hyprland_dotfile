import QtQuick
import "Mat.js" as M

// A flat piece of the 3D phone (back plate, side wall): drawn through a small layer with a clear border,
// so its edges stay smooth under the perspective transform (a plain Rectangle gets stair-step edges there).
// Set the Rectangle through `plate` (plate.width, plate.radius, plate.gradient…); children go on the plate.
Item {
    id: p
    property var m                                   // the piece's full 3D matrix (Mat.js array)
    property real tex: 1.5                           // texture sharpness (plain colours: edges only)
    property alias plate: r
    default property alias content: r.data
    readonly property real pad: 3
    width: r.width + 2 * pad; height: r.height + 2 * pad
    transform: Matrix4x4 { matrix: M.toQt(M.chain(p.m, M.T(-p.pad, -p.pad))) }
    layer.enabled: true; layer.smooth: true
    layer.textureSize: Qt.size(width * tex, height * tex)
    Rectangle { id: r; x: p.pad; y: p.pad }
}
