// AngleGradientRect —— 支持 CSS 角度的线性渐变圆角矩形
//
// QML 的 Gradient 只有「水平/垂直」方向，而官方 CSS 里全是带角度的渐变：
//     linear-gradient(242.83deg, #FC3D49 16.96%, #FC3D49 34.33%, #FB3B5B 83.04%)
//     linear-gradient(270deg,   #FC3D49 0%,     #FC3D49 26%,    #FB3B5B 99%)
// 这里按 CSS 规范把角度换算成起止端点。
//
// Gradient 的 GradientStop 必须静态声明，所以固定提供 4 个 stop（够用：
// 官方最复杂的一条是 3 个 stop）。用 set2()/set3() 便捷赋值。
//
// 用法：
//     AngleGradientRect { cssAngle: 242.83;  }
//     + Component.onCompleted: set3(0.1696, "#FC3D49", 0.3433, "#FC3D49", 0.8304, "#FB3B5B")
import QtQuick 2.15
import QtGraphicalEffects 1.0

Item {
    id: root

    property real cssAngle: 180          // CSS deg：0=向上，顺时针
    property real radius: 0
    property real topLeftRadius: radius
    property real topRightRadius: radius
    property real bottomLeftRadius: radius
    property real bottomRightRadius: radius

    // ── 最多 4 个色标 ─────────────────────────────────
    property real p0: 0; property color c0: "transparent"
    property real p1: 1; property color c1: "transparent"
    property real p2: 1; property color c2: "transparent"
    property real p3: 1; property color c3: "transparent"

    function set2(posA, colA, posB, colB) {
        p0 = posA; c0 = colA;
        p1 = posB; c1 = colB;
        p2 = 1;    c2 = colB;
        p3 = 1;    c3 = colB;
    }
    function set3(posA, colA, posB, colB, posC, colC) {
        p0 = posA; c0 = colA;
        p1 = posB; c1 = colB;
        p2 = posC; c2 = colC;
        p3 = 1;    c3 = colC;
    }

    readonly property bool _uniform:
        Math.abs(topLeftRadius - topRightRadius) < 0.01 &&
        Math.abs(topRightRadius - bottomRightRadius) < 0.01 &&
        Math.abs(bottomRightRadius - bottomLeftRadius) < 0.01

    // 渐变源（不可见，只提供 alpha 剪影 = 圆角形状）
    Item {
        id: src
        anchors.fill: parent
        visible: false

        Rectangle {
            anchors.fill: parent
            visible: root._uniform
            color: "black"
            radius: root.radius
            antialiasing: true
        }
        Rectangle {
            anchors.fill: parent
            visible: !root._uniform
            color: "black"
            radius: Math.max(root.topLeftRadius, root.topRightRadius,
                             root.bottomLeftRadius, root.bottomRightRadius)
            antialiasing: true
        }
    }

    // CSS 角度 → 起止端点（屏幕坐标 y 向下）
    // CSS: 0deg 指向上，角度顺时针增大。方向向量 = (sin a, -cos a)
    readonly property var _ep: {
        var a = cssAngle * Math.PI / 180;
        var dx = Math.sin(a), dy = -Math.cos(a);
        var w = width, h = height;
        var L = Math.abs(w * dx) + Math.abs(h * dy);   // 渐变线长度
        return {
            x1: w / 2 - dx * L / 2,
            y1: h / 2 - dy * L / 2,
            x2: w / 2 + dx * L / 2,
            y2: h / 2 + dy * L / 2
        };
    }

    LinearGradient {
        anchors.fill: parent
        source: src
        start: Qt.point(root._ep.x1, root._ep.y1)
        end: Qt.point(root._ep.x2, root._ep.y2)
        cached: false        // 源尺寸/角度变化时必须重算，不能 cache

        gradient: Gradient {
            GradientStop { position: root.p0; color: root.c0 }
            GradientStop { position: root.p1; color: root.c1 }
            GradientStop { position: root.p2; color: root.c2 }
            GradientStop { position: root.p3; color: root.c3 }
        }
    }
}
