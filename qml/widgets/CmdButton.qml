// CmdButton —— 对齐官方 desktop-ui 的按钮
//
// 数值来自编译后 CSS 的字面值（见 research/extract-rules.mjs 的输出）：
//   size-s : height 20px, padding 0 8px,  radius 10px, font 12px
//   size-m : height 28px, padding 0 12px, radius 14px, font 14px
//   surfacePri : linear-gradient(242.83deg, #FC3D49 16.96%, #FC3D49 34.33%, #FB3B5B 83.04%)
//   hover  : filter brightness(0.9)
//   active : opacity + scale
import QtQuick 2.15
import TightNCM 1.0
import "../widgets"

Item {
    id: root

    // "surface-pri" | "surface-sec" | "outline-sec" | "outline-pri" | "text-pri" | "text-sec" | "text-normal"
    property string variant: "surface-pri"
    // "xs" | "s" | "m" | "l" | "custom"
    property string size: "m"

    property string text: ""
    property string iconName: ""
    property real iconSize: 16

    property color textColor: Theme.colorWhite1
    property color bgColor: "transparent"
    property color borderColor: "transparent"
    property real borderWidth: 0
    property real radiusOverride: -1

    // 自定义尺寸（size === "custom" 时生效）
    property real customHeight: 40
    property real customPadding: 16
    property real customRadius: 10
    property real customFontSize: Metrics.fontMedium

    readonly property bool hovered: hoverHandler.hovered
    readonly property bool pressed: pressHandler.pressed

    signal clicked()

    // ── 尺寸表 ────────────────────────────────────────────
    readonly property var _sizeTable: ({
        xs: { h: 20, pad: 8,  r: 10, fs: 12 },
        s:  { h: 20, pad: 8,  r: 10, fs: 12 },
        m:  { h: 28, pad: 12, r: 14, fs: 14 },
        l:  { h: 40, pad: 20, r: 20, fs: 14 },
    })
    readonly property var _sz: size === "custom"
        ? { h: customHeight, pad: customPadding, r: customRadius, fs: customFontSize }
        : (_sizeTable[size] || _sizeTable.m)

    implicitHeight: _sz.h
    implicitWidth: contentRow.implicitWidth + _sz.pad * 2
    width: implicitWidth
    height: implicitHeight

    // 主按钮渐变：CSS 是 242.83deg，纯 CSS 角度 → QML 端点换算见文档
    RoundRect {
        id: bg
        anchors.fill: parent
        color: root.bgColor
        radius: radiusOverride >= 0 ? radiusOverride : _sz.r
        borderColor: root.borderColor
        borderWidth: root.borderWidth

        // 主按钮底色（渐变在下面单独铺）
        visible: root.variant !== "surface-pri"

        // hover 用 brightness(0.9) 近似：叠一层 10% 的黑
        Rectangle {
            anchors.fill: parent
            radius: bg.radius
            color: "black"
            opacity: root.hovered ? 0.1 : 0
            visible: root.variant === "surface-pri" || root.variant === "surface-sec"
        }
    }

    // surface-pri 渐变底
    // 官方 CSS: linear-gradient(242.83deg, #FC3D49 16.96%, #FC3D49 34.33%, #FB3B5B 83.04%)
    AngleGradientRect {
        id: gradBg
        anchors.fill: parent
        visible: root.variant === "surface-pri"
        radius: radiusOverride >= 0 ? radiusOverride : _sz.r
        cssAngle: 242.83
        Component.onCompleted: set3(0.1696, Theme.colorSecondary1_2,
                                    0.3433, Theme.colorSecondary1_2,
                                    0.8304, Theme.colorSecondary1_1)

        // hover: filter brightness(0.9)
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "black"
            opacity: root.hovered ? 0.1 : 0
        }
    }

    // ── 内容 ─────────────────────────────────────────────
    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: 6

        Icon {
            visible: root.iconName !== ""
            name: root.iconName
            size: root.iconSize
            color: root.textColor
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            visible: root.text !== ""
            text: root.text
            color: root.textColor
            font.pixelSize: root._sz.fs
            font.family: "Microsoft YaHei"
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    // ── 交互 ─────────────────────────────────────────────
    HoverHandler { id: hoverHandler }
    TapHandler {
        id: pressHandler
        onTapped: root.clicked()
    }

    // active 态：opacity + 轻微缩放
    opacity: pressed ? 0.9 : 1
    scale: pressed ? 0.98 : 1
    Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
    Behavior on opacity { NumberAnimation { duration: 90 } }
}
