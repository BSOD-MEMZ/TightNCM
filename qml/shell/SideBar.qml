// SideBar —— 左侧导航栏
//
// 规格全部来自官方源码 + 登录态实测（1280×800）：
//   容器   0,0  204×800，background rgba(40,50,72,0.03)（colorSidebar7）
//   logo 区 0,0  204×72（BackContainer）—— 固定不滚动
//     红圆标 28×28；字标 99×18；间距 10（整块水平居中）
//   滚动区 0,72  202×728
//     padding: 18px 0 0 24px   （官方 .draggable）
//     导航项 164×36，项距 4（NavItemContainer > *:not(:last-child) margin-bottom 4）
//     分组 padding 14px 0；.first-group 为 0 0 14px
//     分组底分隔线：颜色 colorBlack11，左右各内缩 9px
//     歌单分组头 164×32；歌单项 164×46
//
// ⚠️ 用 VStack 而不是 Column：
// 歌单是登录后才异步回来的，Column 这种 positioner 在本工程「常驻页面 + visible 切换 +
// 数据后到」的结构里不会给后加的子项排位，整列会叠在 y=0。VStack 靠属性依赖重排。
import QtQuick 2.15
import QtQuick.Controls 2.15
import TightNCM 1.0
import "../widgets"

Item {
    id: root

    // 图标名对应官方 cmd-icon-<name>（assets/icons-svg/ncm_*.svg）
    readonly property var primaryNav: [
        { ic: "sidebar_home",       tx: "推荐",         dot: false },
        { ic: "sidebar_featured",   tx: "精选",         dot: false },
        { ic: "sidebar_podcast",    tx: "播客",         dot: false },
        { ic: "sidebar_fm",         tx: "漫游",         dot: false },
        { ic: "sidebar_community",  tx: "关注",         dot: true  }
    ]
    readonly property var libraryNav: [
        { ic: "sidebar_like",       tx: "我喜欢的音乐", dot: false },
        { ic: "sidebar_history",    tx: "最近播放",     dot: false },
        { ic: "sidebar_my_podcast", tx: "我的播客",     dot: true  },
        { ic: "sidebar_favourite",  tx: "我的收藏",     dot: false }
    ]

    property int currentIndex: 0
    property var createdPlaylists: []
    property var collectedPlaylists: []
    property bool createdExpanded: true
    property bool collectedExpanded: true

    signal navActivated(int index, string text)
    signal playlistActivated(var playlist)

    // 底色
    Rectangle {
        anchors.fill: parent
        color: Theme.colorSidebar7
    }

    // ── Logo 区（固定，不随导航滚动） ────────────────
    Item {
        id: logoRow
        width: parent.width
        height: Metrics.logoRowHeight

        Row {
            anchors.centerIn: parent
            spacing: Metrics.logoGap

            Icon {
                name: "logo"
                size: Metrics.logoIconSize
                color: Theme.brand
                anchors.verticalCenter: parent.verticalCenter
            }
            Icon {
                name: "title"
                width: Metrics.logoTitleWidth
                height: Metrics.logoTitleHeight
                color: Theme.colorBlack1
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    // ── 可滚动导航 ──────────────────────────────────
    Flickable {
        id: flick
        anchors.top: logoRow.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        contentWidth: width
        contentHeight: navStack.y + navStack.height + 24
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        VStack {
            id: navStack
            x: 0
            y: Metrics.sidebarTopPad
            width: flick.width
            spacing: 0

            // ── 主导航（first-group：无上 padding，下 14） ──
            Repeater {
                model: root.primaryNav
                delegate: Item {
                    required property int index
                    required property var modelData
                    width: navStack.width
                    height: Metrics.navItemHeight + Metrics.navItemGap
                    NavItem {
                        x: Metrics.sidebarHMargin
                        iconName: modelData.ic
                        text: modelData.tx
                        showDot: modelData.dot
                        selected: root.currentIndex === index
                        onClicked: root.navActivated(index, modelData.tx)
                    }
                }
            }

            Item { width: 1; height: Metrics.navGroupFirstPadB - Metrics.navItemGap }
            Rectangle {
                x: Metrics.sidebarHMargin + Metrics.navDividerInset
                width: Metrics.navItemWidth - Metrics.navDividerInset * 2
                height: 1
                color: Theme.colorBlack11
            }

            // ── 我的音乐（padding-top 14） ──
            Item { width: 1; height: Metrics.navGroupPadY - 1 }
            Repeater {
                model: root.libraryNav
                delegate: Item {
                    required property int index
                    required property var modelData
                    width: navStack.width
                    height: Metrics.navItemHeight + Metrics.navItemGap
                    NavItem {
                        x: Metrics.sidebarHMargin
                        iconName: modelData.ic
                        text: modelData.tx
                        showDot: modelData.dot
                        selected: root.currentIndex === root.primaryNav.length + index
                        onClicked: root.navActivated(root.primaryNav.length + index, modelData.tx)

                        // 「我喜欢的音乐」右侧有颗心跳图标（官方 sidebar_heartbeat）
                        Icon {
                            name: "sidebar_heartbeat"
                            size: 18
                            visible: modelData.ic === "sidebar_like"
                            color: Theme.colorBlack5
                            anchors.right: parent.right
                            anchors.rightMargin: Metrics.navItemPadding
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }

            // ── 创建的歌单 ──
            Item { width: 1; height: Metrics.navGroupPadY - Metrics.navItemGap }
            Rectangle {
                x: Metrics.sidebarHMargin + Metrics.navDividerInset
                width: Metrics.navItemWidth - Metrics.navDividerInset * 2
                height: 1
                color: Theme.colorBlack11
            }
            Item { width: 1; height: Metrics.navGroupPadY - 1 }

            SectionHeader {
                width: Metrics.navItemWidth
                x: Metrics.sidebarHMargin
                title: "创建的歌单"
                count: root.createdPlaylists.length
                expanded: root.createdExpanded
                onToggled: root.createdExpanded = !root.createdExpanded
            }
            Repeater {
                model: root.createdExpanded ? root.createdPlaylists : []
                delegate: PlaylistItem {
                    required property var modelData
                    x: Metrics.sidebarHMargin
                    title: modelData.name
                    cover: modelData.cover || ""
                    onClicked: root.playlistActivated(modelData)
                }
            }

            // ── 收藏的歌单 ──
            Item { width: 1; height: Metrics.navGroupPadY }
            Rectangle {
                x: Metrics.sidebarHMargin + Metrics.navDividerInset
                width: Metrics.navItemWidth - Metrics.navDividerInset * 2
                height: 1
                color: Theme.colorBlack11
            }
            Item { width: 1; height: Metrics.navGroupPadY - 1 }

            SectionHeader {
                width: Metrics.navItemWidth
                x: Metrics.sidebarHMargin
                title: "收藏的歌单"
                count: root.collectedPlaylists.length
                expanded: root.collectedExpanded
                showAdd: false
                onToggled: root.collectedExpanded = !root.collectedExpanded
            }
            Repeater {
                model: root.collectedExpanded ? root.collectedPlaylists : []
                delegate: PlaylistItem {
                    required property var modelData
                    x: Metrics.sidebarHMargin
                    title: modelData.name
                    cover: modelData.cover || ""
                    onClicked: root.playlistActivated(modelData)
                }
            }
        }
    }
}
