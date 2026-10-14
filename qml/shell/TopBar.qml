// TopBar —— 顶栏
//
// 官方 Header/index.jsx 的 HeaderRow 是一个 grid，列定义**字面值**：
//     grid-template-columns: 28px 8px 258px 8px 36px 20px auto 20px min-content
//       ①28 后退键（28×36，radius 8，1px 边框 colorSidebar5，箭头 11px）
//       ②8  间隔
//       ③258 搜索框
//       ④8  间隔
//       ⑤36 听歌识曲（web 端隐藏，这里也留空）
//       ⑥20 间隔
//       ⑦auto 弹性空白
//       ⑧20 间隔
//       ⑨min-content 右侧图标组
// 容器：height 72，padding 0 40px（CONTENT_AREA_PADDING）
// 图标色：常 colorSidebar3(0.6) → hover colorSidebar1(1)
// 右侧图标组：MiniModeIconBar > *:not(:last-child) { margin-right: 10px }
import QtQuick 2.15
import QtQuick.Window 2.15
import TightNCM 1.0
import "../widgets"

Item {
    id: root

    property bool canGoBack: false
    property string userName: ""
    property string avatar: ""
    property int vipLevel: 0
    property bool messageUnread: false

    // 无边框窗口必须自带窗控，否则用户只能 Alt+F4。
    // 官方 web 版没有这组按钮（由宿主 Orpheus 画），我们自绘就得补上。
    property bool showWindowControls: true
    property bool maximized: false

    signal backClicked()
    signal searchAccepted(string text)
    signal messageClicked()
    signal settingClicked()
    signal userClicked()
    signal minimizeClicked()
    signal maximizeClicked()
    signal closeClicked()

    implicitHeight: Metrics.topBarHeight

    // ── ①后退键 28×36 ────────────────────────────────
    Item {
        id: backBtn
        x: Metrics.contentPadding
        anchors.verticalCenter: parent.verticalCenter
        width: Metrics.headerBackWidth
        height: Metrics.headerBackHeight

        RoundRect {
            anchors.fill: parent
            radius: Metrics.headerBackRadius
            color: backHover.hovered && root.canGoBack ? Theme.colorSidebar5 : "transparent"
            borderColor: Theme.colorSidebar5
            borderWidth: 1
            opacity: root.canGoBack ? 1.0 : 0.3
            Behavior on color { ColorAnimation { duration: 120 } }
        }
        Icon {
            anchors.centerIn: parent
            name: "backward"
            size: 11
            color: Theme.colorSidebar2
        }
        HoverHandler { id: backHover }
        MouseArea {
            anchors.fill: parent
            cursorShape: root.canGoBack ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: root.backClicked()
        }
    }

    // ── ③搜索框 ─────────────────────────────────────
    SearchBox {
        id: search
        anchors.verticalCenter: parent.verticalCenter
        x: backBtn.x + backBtn.width + Metrics.headerSearchGap
        onAccepted: root.searchAccepted(text)
    }

    // ── ⑨右侧图标组 ─────────────────────────────────
    Row {
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: Metrics.contentPadding
        spacing: Metrics.headerIconGap

        // 用户区：头像 28 → 昵称 → 黑胶 VIP 徽章 → 下拉箭头
        // 官方 .Bar_b2jgnke > *:not(:last-child) { margin-right: 4px }
        Row {
            spacing: Metrics.headerUserGap
            anchors.verticalCenter: parent.verticalCenter

            Item {
                width: Metrics.headerAvatarSize
                height: Metrics.headerAvatarSize
                anchors.verticalCenter: parent.verticalCenter

                RoundRect {
                    anchors.fill: parent
                    radius: width / 2
                    color: Theme.colorBlack11
                    clip: true
                    Image {
                        anchors.fill: parent
                        source: root.avatar
                        sourceSize.width: Math.max(1, Math.round(width * Screen.devicePixelRatio))
                        sourceSize.height: Math.max(1, Math.round(height * Screen.devicePixelRatio))
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        visible: status === Image.Ready
                    }
                }
            }

            // 官方 .Name_n1q7o360：font-size 13 / weight 500 / line-height 16
            //                      常态 colorSidebar2，hover colorSidebar1
            Text {
                text: root.userName
                anchors.verticalCenter: parent.verticalCenter
                font.pixelSize: Metrics.headerNameSize
                font.weight: Metrics.headerNameWeight
                font.family: "Microsoft YaHei"
                color: nameHover.hovered ? Theme.colorSidebar1 : Theme.colorSidebar2
                elide: Text.ElideRight
                width: Math.min(implicitWidth, 100)
                HoverHandler { id: nameHover }
            }

            // 黑胶 VIP 徽章（48×16）。**不是**单色图标 —— 见 VipBadge.qml
            VipBadge {
                level: root.vipLevel
                anchors.verticalCenter: parent.verticalCenter
            }

            // 下拉箭头：官方 cmd-icon-unfold，20×20 的图标盒（字形 12.2）
            Item {
                width: Metrics.headerDropdownSize
                height: Metrics.headerDropdownSize
                anchors.verticalCenter: parent.verticalCenter

                Icon {
                    anchors.centerIn: parent
                    name: "dropdown"
                    size: 20
                    color: dropHover.hovered ? Theme.colorSidebar1 : Theme.colorSidebar3
                }
                HoverHandler { id: dropHover }
            }
        }

        // 官方这里没有分隔线（HeaderRow grid 第 8 列是 20px 的 draggable 占位），
        // 所以用户区和图标组之间只留 headerIconGap 的间距。

        // 消息
        Item {
            width: Metrics.headerIconSize
            height: Metrics.headerIconSize
            anchors.verticalCenter: parent.verticalCenter
            Icon {
                anchors.fill: parent
                name: "message"
                size: Metrics.headerIconSize
                color: msgHover.hovered ? Theme.colorSidebar1 : Theme.colorSidebar3
            }
            Rectangle {
                visible: root.messageUnread
                width: 5; height: 5; radius: 2.5
                color: Theme.colorSecondary2_1
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.rightMargin: 1
                anchors.topMargin: 1
            }
            HoverHandler { id: msgHover }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.messageClicked()
            }
        }

        // 设置
        Icon {
            name: "setting"
            size: Metrics.headerIconSize
            color: setHover.hovered ? Theme.colorSidebar1 : Theme.colorSidebar3
            anchors.verticalCenter: parent.verticalCenter
            HoverHandler { id: setHover }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.settingClicked()
            }
        }

        // 竖分隔线
        Rectangle {
            visible: root.showWindowControls
            width: 1
            height: 16
            color: Theme.colorSidebar5
            anchors.verticalCenter: parent.verticalCenter
        }

        // ── 窗控：最小化 / 最大化-还原 / 关闭 ─────────────
        Row {
            visible: root.showWindowControls
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Repeater {
                model: [
                    { ic: "minimize", hoverBg: Theme.colorBlack11, hoverFg: Theme.colorBlack1, act: "min" },
                    { ic: root.maximized ? "restore" : "maximize", hoverBg: Theme.colorBlack11, hoverFg: Theme.colorBlack1, act: "max" },
                    { ic: "close", hoverBg: Theme.brand, hoverFg: Theme.colorWhite1, act: "close" }
                ]
                delegate: Item {
                    required property var modelData
                    width: 32
                    height: 32

                    readonly property bool hovered: wcHover.hovered

                    RoundRect {
                        anchors.fill: parent
                        radius: 8
                        color: parent.hovered ? modelData.hoverBg : "transparent"
                        Behavior on color { ColorAnimation { duration: 110 } }
                    }
                    Icon {
                        anchors.centerIn: parent
                        name: modelData.ic
                        size: 16
                        color: parent.hovered ? modelData.hoverFg : Theme.colorSidebar3
                        Behavior on color { ColorAnimation { duration: 110 } }
                    }

                    HoverHandler { id: wcHover }
                    TapHandler {
                        onTapped: {
                            if (modelData.act === "min")      root.minimizeClicked();
                            else if (modelData.act === "max") root.maximizeClicked();
                            else                              root.closeClicked();
                        }
                    }
                }
            }
        }
    }

    // 用户区整体可点
    MouseArea {
        anchors.right: parent.right
        anchors.rightMargin: Metrics.contentPadding
        anchors.verticalCenter: parent.verticalCenter
        width: 220
        height: 32
        cursorShape: Qt.PointingHandCursor
        onClicked: root.userClicked()
        z: -1
    }
}
