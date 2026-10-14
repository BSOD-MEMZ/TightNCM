// ShadowBox —— 带 CSS box-shadow 语义的圆角面板
//
// 设计目标：可以直接把官方 CSS 的 shadow 字符串粘进来。
//     ShadowBox { css: "0 6px 16px rgba(0,0,0,0.04)" }
//     ShadowBox { css: "0 2.3px 17.25px 0 rgba(0,0,0,0.1)" }
//     ShadowBox { css: "inset 0 0 0 1px rgba(40,50,72,0.06)" }
//
// CSS → Qt 映射（QtGraphicalEffects.DropShadow）：
//     offsetX      → horizontalOffset
//     offsetY      → verticalOffset
//     blur-radius  → radius          （两者都是「≈ 2σ」，所以数值可以近似直取）
//     spread       → spread          （CSS 是 px 扩张；Qt 是 0..1 的比例，这里换算）
//     color        → color
//
// inset 阴影：Qt 没有对应能力，但本项目里 inset 全部是
//     `inset 0 0 0 Npx <color>`，语义等价于 N px 的内描边，所以直接画 border。
import QtQuick 2.15
import QtGraphicalEffects 1.0
import TightNCM 1.0

Item {
    id: root

    // 直接把 CSS 的 box-shadow 值粘进来
    property string css: "none"

    // 面板本体
    property color color: Theme.panel
    property color borderColor: "transparent"
    property real borderWidth: 0
    property real radius: 0
    property real topLeftRadius: radius
    property real topRightRadius: radius
    property real bottomLeftRadius: radius
    property real bottomRightRadius: radius

    // 阴影总开关：默认跟随 Metrics.enableBoxShadow（当前是 false）。
    // 原因：Qt 里 box-shadow 要靠 QtGraphicalEffects.DropShadow，每次多一遍 FBO，
    // 而且 `blur-radius ↔ radius` 还没标定到像素级。需要时把 Metrics 里那个开关
    // 改成 true 就能全部打开，或者单独给某个实例设 shadowEnabled: true 覆盖。
    property bool shadowEnabled: Metrics.enableBoxShadow

    // 可选的显式阴影源（比如想给一个复杂 Item 投影）
    property Item shadowSource: null

    default property alias content: contentLayer.data

    // ── CSS 解析 ───────────────────────────────────────────
    // 注意：QML 没有「把 CSS 颜色字符串解析成 color」的函数（Qt.color 不存在），
    // 所以这里把颜色原样存成字符串，交给 DropShadow.color / RoundRect.borderColor
    // 这种 color 类型属性自动转换。
    function parseCss(str) {
        var out = { ok: false, inset: false, x: 0, y: 0, blur: 0, spread: 0, color: "transparent", raw: str };
        if (!str || str === "none" || str === "unset" || str === "initial") return out;

        var s = String(str).trim();

        // inset 关键字
        if (/^inset\b/i.test(s)) { out.inset = true; s = s.replace(/^inset\b/i, "").trim(); }
        // 结尾的 !important
        s = s.replace(/!important\s*$/i, "").trim();

        // 颜色：rgba(...) / rgb(...) / #hex
        var m = s.match(/rgba?\([^)]*\)/i);
        if (m) {
            out.color = m[0];
            s = s.replace(m[0], " ");
        } else {
            m = s.match(/#[0-9a-fA-F]{3,8}\b/);
            if (m) {
                out.color = m[0];
                s = s.replace(m[0], " ");
            }
        }

        // 剩下的是数字：x y blur spread
        var nums = s.match(/-?\d*\.?\d+/g);
        if (nums) {
            nums = nums.map(Number);
            out.x      = nums[0] || 0;
            out.y      = nums.length > 1 ? nums[1] : 0;
            out.blur   = nums.length > 2 ? nums[2] : 0;
            out.spread = nums.length > 3 ? nums[3] : 0;
        }

        out.ok = true;
        return out;
    }

    readonly property var _s: parseCss(css)

    // 计算 spread 的 0..1 比例（Qt 按尺寸比例扩张）
    readonly property real _qtSpread: {
        if (!_s.ok || !_s.spread) return 0;
        var ref = Math.min(width, height) / 2;
        return ref > 0 ? Math.min(1, _s.spread / ref) : 0;
    }
    // QtGraphicalEffects 的采样数：1 + radius*2 是标准值，大半径降采样保性能
    readonly property int _samples: Math.max(1, Math.min(31, 1 + Math.round((_s.blur || 0) * 2)))

    // ── 阴影源（不可见，只提供剪影） ────────────────────────
    RoundRect {
        id: caster
        anchors.fill: parent
        visible: false
        color: "black"          // 只用 alpha，真实颜色由 DropShadow.color 覆盖
        radius: root.radius
        topLeftRadius: root.topLeftRadius
        topRightRadius: root.topRightRadius
        bottomLeftRadius: root.bottomLeftRadius
        bottomRightRadius: root.bottomRightRadius
    }

    // ── 阴影（画在面板之下） ───────────────────────────────
    DropShadow {
        id: shadow
        anchors.fill: parent
        // 让阴影可以溢出到宿主边界之外
        width: parent.width + _samples * 2
        height: parent.height + _samples * 2
        x: -_samples
        y: -_samples
        visible: root.shadowEnabled && root._s.ok && !root._s.inset
        source: root.shadowSource || caster
        horizontalOffset: root._s.x
        verticalOffset: root._s.y
        radius: root._s.blur || 0
        samples: root._samples
        spread: root._qtSpread
        color: root._s.color
        cached: false
        transparentBorder: true
    }

    // ── 面板本体（画在阴影之上，遮住内部那半个阴影） ────────
    RoundRect {
        id: panel
        anchors.fill: parent
        color: root.color
        radius: root.radius
        topLeftRadius: root.topLeftRadius
        topRightRadius: root.topRightRadius
        bottomLeftRadius: root.bottomLeftRadius
        bottomRightRadius: root.bottomRightRadius

        // inset 阴影 → 内描边
        borderColor: root._s.ok && root._s.inset ? root._s.color : root.borderColor
        borderWidth: root._s.ok && root._s.inset ? Math.max(1, root._s.spread) : root.borderWidth
    }

    // ── 内容 ─────────────────────────────────────────────
    Item {
        id: contentLayer
        anchors.fill: parent
    }
}
