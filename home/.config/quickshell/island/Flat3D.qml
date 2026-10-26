import QtQuick
import "Mat.js" as M

// A flat piece of the 3D phone (back plate, side wall, the screen face), drawn through one smoothed layer with a
// clear border all round, so its outline stays smooth under the perspective matrix (a plain Rectangle or a layer
// that ends right at the edge gets stair-step edges there). Put the piece inside; it is sized by its children.
Item {
    id: p
    property var m                                   // the piece's full 3D matrix (Mat.js array)
    property real tex: 1.5                           // texture sharpness (plain colours only need smooth edges)
    property bool smoothed: true                     // false = drawn straight (only for a flat, untilted piece: no stair-steps then)
    default property alias content: holder.data
    readonly property real pad: 3
    width: holder.width + 2 * pad; height: holder.height + 2 * pad
    transform: Matrix4x4 { matrix: M.toQt(M.chain(p.m, M.T(-p.pad, -p.pad))) }
    layer.enabled: smoothed; layer.smooth: true
    layer.textureSize: Qt.size(width * tex, height * tex)
    Item { id: holder; x: p.pad; y: p.pad; width: childrenRect.width; height: childrenRect.height }
}
