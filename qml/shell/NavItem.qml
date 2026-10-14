// NavItem —— 左侧栏导航项
//
// 规格来自官方源码 packages/pc/src/components/left/components/nav-item.jsx：
//   ItemContainer { height:36px; padding:8px; display:flex; align-items:center;
//                   border-radius:8px }
//     &:hover / &.selected-hover → background: colorBlack11
//     &.selected → background: linear-gradient(270deg, #FC3D49 0%, #FC3D49 26%, #FB3B5B 99%)
//   IconWrapper { width:20px; height:20px; margin-right:8px }
//     图标色：选中 colorSidebar8(白) / 常态 colorBlack5
//   .title { font-size:14px; line-height:18px }
//     文字色：选中 colorSidebar8(白) / 常态 colorBlack3
//
// 注意这里**不是** 12px 字号 —— 之前写成了 12px，实测官方导航标题是 14px
// （"推荐"宽 28 = 2×14），歌单项才是 12px，两者不一样。
import QtQuick 2.15
import TightNCM 1.0
import "../widgets"

Item {
    id: root

    property string iconName: ""
    property string text: ""
    property bool selected: false
    property bool showDot: false        // 「关注」「我的播客」后面的小圆点

    signal clicked()

    width: Metrics.navItemWidth
    height: Metrics.navItemHeight

    readonly property bool hovered: hh.hovered

    // ── 背景 ────────────────────────────────────────
    // 选中态是 270deg 线性渐变：CSS 里 270deg 指向左侧，
    // 所以第一个色标(0%)落在**右边**。cssAngle 直接用 270。
    RoundRect {
        anchors.fill: parent
        radius: Metrics.navItemRadius
        visible: !root.selected
        color: root.hovered ? Theme.colorBlack11 : "transparent"
        Behavior on color { ColorAnimation { duration: 120 } }
    }
    AngleGradientRect {
        anchors.fill: parent
        visible: root.selected
        radius: Metrics.navItemRadius
        cssAngle: 270
        Component.onCompleted: set3(0.00, Theme.colorSecondary1_2,
                                    0.26, Theme.colorSecondary1_2,
                                    0.99, Theme.colorSecondary1_1)
    }

    // ── 图标 + 文字 ─────────────────────────────────
    Row {
        anchors.verticalCenter: parent.verticalCenter
        x: Metrics.navItemPadding
        spacing: Metrics.navItemIconGap

        Icon {
            id: ic
            name: root.iconName
            size: Metrics.navItemIconSize
            color: root.selected ? Theme.colorSidebar8 : Theme.colorBlack5
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        Text {
            id: label
            text: root.text
            anchors.verticalCenter: parent.verticalCenter
            font.pixelSize: Metrics.navItemFontSize
            font.family: "Microsoft YaHei"
            color: root.selected ? Theme.colorSidebar8 : Theme.colorBlack3
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        // 小红点：紧跟在文字右边（官方 Ext 在 title 之后，间距 4px），不是贴右边缘
        Rectangle {
            visible: root.showDot
            width: 5; height: 5; radius: 2.5
            color: Theme.colorSecondary2_1
            anchors.verticalCenter: parent.verticalCenter
            antialiasing: true
        }
    }

    HoverHandler { id: hh }
    TapHandler { onTapped: root.clicked() }
}
