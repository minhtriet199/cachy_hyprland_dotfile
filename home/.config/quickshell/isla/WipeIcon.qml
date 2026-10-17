import QtQuick
import QtQuick.Shapes

// The icon in the middle of the circle-iris scene change. name: leaf · star · bell · apple · flower · heart · shell · none
Item {
    id: wi
    property string name: "leaf"
    readonly property color ink: "#2C4A54"
    width: 150; height: 150
    // leaf
    Shape { visible: wi.name === "leaf"; width: 24; height: 24; scale: wi.width / 24; transformOrigin: Item.TopLeft; preferredRendererType: Shape.CurveRenderer
        ShapePath { fillColor: "#3E7A4D"; strokeColor: "transparent"; PathSvg { path: "M12.6 2.8c5.2 1.8 8.6 6.4 7.6 11.6-.9 4.6-5.1 7.4-9.6 7.1-1.2-4.6-.6-10.2 2-18.7z" } }
        ShapePath { fillColor: "#7CC47F"; strokeColor: "#2C5F3C"; strokeWidth: 1.1; joinStyle: ShapePath.RoundJoin; PathSvg { path: "M12 2.2c5.2 1.8 8.6 6.4 7.6 11.6-.9 4.6-5.1 7.4-9.6 7.1-1.2-4.6-.6-10.2 2-18.7z" } }
        ShapePath { fillColor: "transparent"; strokeColor: "#2C5F3C"; strokeWidth: 1.1; capStyle: ShapePath.RoundCap; PathSvg { path: "M10 20.9c.4-5.4 1.8-10.4 4.6-14.6M9.6 21.6l-1.4 1.6" } }
        ShapePath { fillColor: "transparent"; strokeColor: "#BFE6C2"; strokeWidth: 1; capStyle: ShapePath.RoundCap; PathSvg { path: "M13.6 5.4c2.4 1.4 3.9 3.3 4.3 5.6" } }
    }
    // star (Nook Miles / wishing star)
    Shape { visible: wi.name === "star"; width: 24; height: 24; scale: wi.width / 24; transformOrigin: Item.TopLeft; preferredRendererType: Shape.CurveRenderer
        ShapePath { fillColor: "#FFD45C"; strokeColor: wi.ink; strokeWidth: 1.1; joinStyle: ShapePath.RoundJoin
            PathSvg { path: "M12 2.5l2.9 5.9 6.5.9-4.7 4.6 1.1 6.5L12 17.3l-5.8 3.1 1.1-6.5-4.7-4.6 6.5-.9z" } }
        ShapePath { fillColor: "transparent"; strokeColor: "#FFF3C4"; strokeWidth: .9; capStyle: ShapePath.RoundCap; PathSvg { path: "M10.2 8.6l1.2-2.4" } }
    }
    // bell bag (Bells)
    Shape { visible: wi.name === "bell"; width: 24; height: 24; scale: wi.width / 24; transformOrigin: Item.TopLeft; preferredRendererType: Shape.CurveRenderer
        ShapePath { fillColor: "#F2C14E"; strokeColor: wi.ink; strokeWidth: 1.1; joinStyle: ShapePath.RoundJoin
            PathSvg { path: "M9.5 6.5c-3.6 2-6 5.6-6 9 0 3.4 3.8 5.5 8.5 5.5s8.5-2.1 8.5-5.5c0-3.4-2.4-7-6-9z" } }
        ShapePath { fillColor: "#E3A93A"; strokeColor: wi.ink; strokeWidth: 1.1; joinStyle: ShapePath.RoundJoin; PathSvg { path: "M8.5 3.5h7l-1.5 3h-4z" } }
        ShapePath { fillColor: "transparent"; strokeColor: wi.ink; strokeWidth: 1.2; capStyle: ShapePath.RoundCap; PathSvg { path: "M12 11v6M10 12.5c0-1 4-1 4 0s-4 1.5-4 2.6 4 1 4 0" } }
    }
    // apple (native fruit)
    Shape { visible: wi.name === "apple"; width: 24; height: 24; scale: wi.width / 24; transformOrigin: Item.TopLeft; preferredRendererType: Shape.CurveRenderer
        ShapePath { fillColor: "#EE6F8F"; strokeColor: wi.ink; strokeWidth: 1.1; joinStyle: ShapePath.RoundJoin
            PathSvg { path: "M12 7.5c-2-1.5-7.5-1.3-7.5 4.8 0 5 3.4 8.7 5.5 8.7 1 0 1.3-.5 2-.5s1 .5 2 .5c2.1 0 5.5-3.7 5.5-8.7 0-6.1-5.5-6.3-7.5-4.8z" } }
        ShapePath { fillColor: "#7CC47F"; strokeColor: wi.ink; strokeWidth: 1; joinStyle: ShapePath.RoundJoin; PathSvg { path: "M12.4 6.8c.4-2.4 2.3-3.8 4.6-3.8-.3 2.3-2.2 3.8-4.6 3.8z" } }
        ShapePath { fillColor: "transparent"; strokeColor: "#FAD0DB"; strokeWidth: 1; capStyle: ShapePath.RoundCap; PathSvg { path: "M7.2 10.5c.5-1 1.3-1.6 2.3-1.8" } }
    }
    // flower (cosmos)
    Shape { visible: wi.name === "flower"; width: 24; height: 24; scale: wi.width / 24; transformOrigin: Item.TopLeft; preferredRendererType: Shape.CurveRenderer
        ShapePath { fillColor: "#F6BFD0"; strokeColor: wi.ink; strokeWidth: 1; joinStyle: ShapePath.RoundJoin
            PathSvg { path: "M12 3a3 3 0 0 1 3 3.4 3 3 0 0 1 4.5 3.3 3 3 0 0 1-1.7 5.2 3 3 0 0 1-4.2 3.5 3 3 0 0 1-3.2 0 3 3 0 0 1-4.2-3.5 3 3 0 0 1-1.7-5.2A3 3 0 0 1 9 6.4 3 3 0 0 1 12 3z" } }
        ShapePath { fillColor: "#FFD45C"; strokeColor: wi.ink; strokeWidth: 1; PathSvg { path: "M9.6 11.6a2.4 2.4 0 1 0 4.8 0a2.4 2.4 0 1 0-4.8 0" } }
    }
    // heart
    Shape { visible: wi.name === "heart"; width: 24; height: 24; scale: wi.width / 24; transformOrigin: Item.TopLeft; preferredRendererType: Shape.CurveRenderer
        ShapePath { fillColor: "#EE7D9C"; strokeColor: wi.ink; strokeWidth: 1.1; joinStyle: ShapePath.RoundJoin
            PathSvg { path: "M12 20.5S3 15 3 9.2C3 6.3 5.2 4 8 4c1.7 0 3.1.9 4 2.2C12.9 4.9 14.3 4 16 4c2.8 0 5 2.3 5 5.2 0 5.8-9 11.3-9 11.3z" } }
        ShapePath { fillColor: "transparent"; strokeColor: "#FAD0DB"; strokeWidth: 1; capStyle: ShapePath.RoundCap; PathSvg { path: "M6 8.2c.3-1.2 1.1-1.9 2.2-2" } }
    }
    // shell (beach)
    Shape { visible: wi.name === "shell"; width: 24; height: 24; scale: wi.width / 24; transformOrigin: Item.TopLeft; preferredRendererType: Shape.CurveRenderer
        ShapePath { fillColor: "#FBD5C2"; strokeColor: wi.ink; strokeWidth: 1.1; joinStyle: ShapePath.RoundJoin
            PathSvg { path: "M12 4c5 0 9 4.4 8.4 9.4-.3 2.4-2 4.6-4.4 5.6H8c-2.4-1-4.1-3.2-4.4-5.6C3 8.4 7 4 12 4zM9.5 19l1 2h3l1-2" } }
        ShapePath { fillColor: "transparent"; strokeColor: wi.ink; strokeWidth: 1; capStyle: ShapePath.RoundCap; PathSvg { path: "M12 5v13.5M8.2 6.2l2 12.3M15.8 6.2l-2 12.3M5 10.5l4 8M19 10.5l-4 8" } }
    }
}
