// RoundRect —— 支持四角独立圆角的矩形
//
// 为什么不用 Rectangle：Qt 5.15 的 Rectangle 只有统一的 radius，
// 而官方界面里有 53 处需要「单侧圆角」（如 `0 80px 80px 0`）。
// Qt 6.7 才给 Rectangle 补了分角圆角，我们用 5.15。
//
// 性能设计：实测官方 855 处 border-radius 里 824 处是统一值，
// 所以这里做双路径——四角相同时退化成原生 Rectangle（零开销），
// 只有真需要分角时才走 Shape。
//
// 圆角用三次贝塞尔画（不用 PathAngleArc）：PathAngleArc 的引入版本有歧义，
// 而贝塞尔在全部 Qt5 版本上都可用，视觉等价。
import QtQuick 2.15
import QtQuick.Shapes 1.15

Item {
    id: root

    property color color: "transparent"
    property color borderColor: "transparent"
    property real borderWidth: 0

    // 四角默认都跟随 radius；单独设置某一角即可覆盖它。
    // （注意：不能把 radius 写成 `alias topLeftRadius` —— 那样只改左上角，
    //   其余三角还是 0，会被判成"非统一圆角"而错走 Shape 慢路径。）
    property real radius: 0
    property real topLeftRadius: radius
    property real topRightRadius: radius
    property real bottomLeftRadius: radius
    property real bottomRightRadius: radius

    readonly property bool _uniform:
        Math.abs(topLeftRadius - topRightRadius) < 0.01 &&
        Math.abs(topRightRadius - bottomRightRadius) < 0.01 &&
        Math.abs(bottomRightRadius - bottomLeftRadius) < 0.01

    // 圆角不能超过半宽/半高
    readonly property real _lim: Math.min(width, height) / 2
    readonly property real _tl: Math.max(0, Math.min(topLeftRadius,     _lim))
    readonly property real _tr: Math.max(0, Math.min(topRightRadius,    _lim))
    readonly property real _br: Math.max(0, Math.min(bottomRightRadius, _lim))
    readonly property real _bl: Math.max(0, Math.min(bottomLeftRadius,  _lim))

    // ── 快路径：统一圆角 → 原生 Rectangle ──────────────────
    Rectangle {
        id: fastPath
        anchors.fill: parent
        visible: root._uniform
        color: root.color
        radius: root._tl
        border.color: root.borderColor
        border.width: root.borderWidth
        antialiasing: true
    }

    // ── 慢路径：四角不同 → Shape 路径 ─────────────────────
    Shape {
        id: slowPath
        anchors.fill: parent
        visible: !root._uniform
        antialiasing: true

        // 三次贝塞尔逼近圆弧的魔数
        readonly property real k: 0.5522847498307936

        ShapePath {
            fillColor: root.color
            strokeColor: root.borderColor
            strokeWidth: root.borderWidth
            capStyle: ShapePath.FlatCap
            joinStyle: ShapePath.MiterJoin

            // 起点：左上角之后
            startX: root._tl
            startY: 0

            // ── 上边 → 右上角 ──
            PathLine { x: root.width - root._tr; y: 0 }
            PathCubic {
                // 从 (w - tr, 0) 弧到 (w, tr)
                control1X: root.width - root._tr + slowPath.k * root._tr
                control1Y: 0
                control2X: root.width
                control2Y: root._tr - slowPath.k * root._tr
                x: root.width
                y: root._tr
            }

            // ── 右边 → 右下角 ──
            PathLine { x: root.width; y: root.height - root._br }
            PathCubic {
                control1X: root.width
                control1Y: root.height - root._br + slowPath.k * root._br
                control2X: root.width - root._br + slowPath.k * root._br
                control2Y: root.height
                x: root.width - root._br
                y: root.height
            }

            // ── 下边 → 左下角 ──
            PathLine { x: root._bl; y: root.height }
            PathCubic {
                control1X: root._bl - slowPath.k * root._bl
                control1Y: root.height
                control2X: 0
                control2Y: root.height - root._bl + slowPath.k * root._bl
                x: 0
                y: root.height - root._bl
            }

            // ── 左边 → 左上角 ──
            PathLine { x: 0; y: root._tl }
            PathCubic {
                control1X: 0
                control1Y: root._tl - slowPath.k * root._tl
                control2X: root._tl - slowPath.k * root._tl
                control2Y: 0
                x: root._tl
                y: 0
            }
        }
    }
}
