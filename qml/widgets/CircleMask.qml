// CircleMask —— 把方形图片视觉上裁成圆形（在圆外盖一层背景色）
//
// 试过但**在这个工程里不可用**的方案（都实测过，不是猜）：
//   1) RoundRect + clip：QQuickItem::clip 只裁矩形边界，不懂圆角路径 → 封面是方块
//   2) QtGraphicalEffects.OpacityMask：着色器效果，默认软件光栅后端下整块不绘制
//   3) QtQuick.Shapes 的「外框 + 内圆」双路径（OddEven 和 Winding 都试了）：不填洞
//   4) QML Canvas（drawImage 版本 & 纯 fill 版本，Cooperative 和 Immediate 都试了）：
//      在软件后端下压根不渲染
// 最后回到「用 Shape 画四个角块」—— 每个角块是一条 Line + 一条 **PathCubic 近似的
// 四分之一圆**（和 widgets/RoundRect.qml 里已经验证可用的画法完全同源），
// 四个角块互不相干，不存在子路径填充规则的问题。
//
// 只能用在「圆外是纯色」的场景。图片要自己铺在遮罩下面。
import QtQuick 2.15
import QtQuick.Shapes 1.15

Item {
    id: root

    // 圆外的填充色（= 遮罩下面图层的颜色）
    property color coverColor: "#2B2727"

    readonly property real _r: Math.min(width, height) / 2
    // 四分之一圆的贝塞尔控制点系数（圆角矩形同款）
    readonly property real _k: 0.4477152 * _r

    Shape {
        anchors.fill: parent
        antialiasing: true

        // ── 左上角 ──
        ShapePath {
            fillColor: root.coverColor
            strokeColor: "transparent"
            strokeWidth: 0
            startX: 0
            startY: 0
            PathLine { x: root._r; y: 0 }
            PathCubic {
                x: 0; y: root._r
                control1X: root._r - root._k; control1Y: 0
                control2X: 0;                 control2Y: root._r - root._k
            }
            PathLine { x: 0; y: 0 }
        }

        // ── 右上角 ──
        ShapePath {
            fillColor: root.coverColor
            strokeColor: "transparent"
            strokeWidth: 0
            startX: root.width
            startY: 0
            PathLine { x: root.width; y: root._r }
            PathCubic {
                x: root.width - root._r; y: 0
                control1X: root.width;                    control1Y: root._r - root._k
                control2X: root.width - root._r + root._k; control2Y: 0
            }
            PathLine { x: root.width; y: 0 }
        }

        // ── 右下角 ──
        ShapePath {
            fillColor: root.coverColor
            strokeColor: "transparent"
            strokeWidth: 0
            startX: root.width
            startY: root.height
            PathLine { x: root.width - root._r; y: root.height }
            PathCubic {
                x: root.width; y: root.height - root._r
                control1X: root.width - root._r + root._k; control1Y: root.height
                control2X: root.width;                     control2Y: root.height - root._r + root._k
            }
            PathLine { x: root.width; y: root.height }
        }

        // ── 左下角 ──
        ShapePath {
            fillColor: root.coverColor
            strokeColor: "transparent"
            strokeWidth: 0
            startX: 0
            startY: root.height
            PathLine { x: 0; y: root.height - root._r }
            PathCubic {
                x: root._r; y: root.height
                control1X: 0;                  control1Y: root.height - root._r + root._k
                control2X: root._r - root._k;  control2Y: root.height
            }
            PathLine { x: 0; y: root.height }
        }
    }
}
