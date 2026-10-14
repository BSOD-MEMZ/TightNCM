// SettingsPage —— 设置页（1:1 还原官方 pages/setting 的版式）
//
// 官方结构：左侧分栏（账号 / 播放 / 下载 / 音乐桌面）+ 右侧一串 BaseItem 行。
// 我们没有「音乐桌面」，所以分栏是：账号 / 播放 / 下载 / 关于。
// 每一行的规格来自官方 BaseItem（见 widgets/SettingRow.qml 顶部的 CSS 字面值）。
//
// 下面四个开关是**真生效**的（用户指定）：
//   记住上次播放进度 → Store.resumeLastProgress，启动时恢复上次那首和位置
//   启动时自动播放   → Store.autoplayOnStart，恢复后是否直接开播
//   音乐淡入淡出     → Store.fadeInOut，转发给 Player.fadeEnabled
//   切歌通知         → Store.notifyOnTrackChange，后台切歌时发系统通知
//
// 四栏用「4 个 VStack + visible 切换」而不是逐个给行设高度：
// col 本身是 VStack，它排位时会跳过不可见的子项，所以隐藏栏自然不占高度。
import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls 2.15
import TightNCM 1.0
import "../widgets"

Item {
    id: root

    property bool loggedIn: false
    property string nickname: ""
    property string avatar: ""
    property string userId: ""
    property int vipType: 0

    signal logoutRequested()

    readonly property var sections: ["账号", "播放", "下载", "关于"]
    property int currentSection: 1     // 官方默认落在「播放」

    // ── 左侧分栏 ────────────────────────────────────
    Item {
        id: menu
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.leftMargin: Metrics.pBodyPadding
        anchors.topMargin: Metrics.pageTopPad
        width: Metrics.sMenuWidth

        VStack {
            width: menu.width
            spacing: 4

            Repeater {
                model: root.sections
                delegate: Item {
                    required property int index
                    required property var modelData
                    width: menu.width
                    height: 36
                    readonly property bool active: root.currentSection === index

                    RoundRect {
                        anchors.fill: parent
                        radius: Metrics.navItemRadius
                        visible: !parent.active
                        color: secHover.hovered ? Theme.colorBlack11 : "transparent"
                    }
                    AngleGradientRect {
                        anchors.fill: parent
                        visible: parent.active
                        radius: Metrics.navItemRadius
                        cssAngle: 270
                        Component.onCompleted: set3(0.00, Theme.colorSecondary1_2,
                                                    0.26, Theme.colorSecondary1_2,
                                                    0.99, Theme.colorSecondary1_1)
                    }
                    Text {
                        x: Metrics.navItemPadding
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData
                        font.pixelSize: Metrics.navItemFontSize
                        color: parent.active ? Theme.colorSidebar8 : Theme.colorBlack3
                    }
                    HoverHandler { id: secHover }
                    TapHandler { onTapped: root.currentSection = index }
                }
            }
        }
    }

    // ── 右侧内容 ────────────────────────────────────
    Flickable {
        id: pane
        anchors.left: menu.right
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.leftMargin: 40
        anchors.rightMargin: Metrics.pBodyPadding
        anchors.topMargin: Metrics.pageTopPad
        contentWidth: width
        contentHeight: col.height + 40
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        VStack {
            id: col
            width: pane.width
            spacing: 0

            /* ═════════════ 账号 ═════════════ */
            VStack {
                width: col.width
                spacing: 0
                visible: root.currentSection === 0

                SettingRow {
                    label: "账号"
                    Item {
                        width: parent.width
                        height: 64
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 14
                            RoundRect {
                                width: 56; height: 56; radius: 28
                                color: Theme.colorBlack12
                                clip: true
                                anchors.verticalCenter: parent.verticalCenter
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
                            VStack {
                                width: 340
                                spacing: 4
                                anchors.verticalCenter: parent.verticalCenter
                                Text {
                                    text: root.loggedIn ? root.nickname : "未登录"
                                    font.pixelSize: Metrics.fontLarge
                                    font.weight: Font.DemiBold
                                    color: Theme.colorBlack1
                                }
                                Text {
                                    text: root.loggedIn
                                          ? ("UID " + root.userId + (root.vipType > 0 ? "　VIP" : ""))
                                          : "登录后可以同步歌单、喜欢和播放记录"
                                    font.pixelSize: Metrics.fontSmall
                                    color: Theme.colorBlack6
                                }
                            }
                        }
                    }
                }

                SettingRow {
                    label: "登录状态"
                    showDivider: false
                    Row {
                        height: 32
                        spacing: 12
                        anchors.verticalCenter: parent.verticalCenter
                        Item {
                            width: 96; height: 32
                            visible: root.loggedIn
                            anchors.verticalCenter: parent.verticalCenter
                            RoundRect {
                                anchors.fill: parent
                                radius: 8
                                color: logoutHover.hovered ? Theme.colorBlack10 : Theme.colorBlack11
                            }
                            Text {
                                anchors.centerIn: parent
                                text: "退出登录"
                                font.pixelSize: Metrics.sRowTextSize
                                color: Theme.colorBlack2
                            }
                            HoverHandler { id: logoutHover }
                            TapHandler { onTapped: root.logoutRequested() }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !root.loggedIn
                            text: "点右上角头像可以登录"
                            font.pixelSize: Metrics.sRowTextSize
                            color: Theme.colorBlack6
                        }
                    }
                }
            }

            /* ═════════════ 播放 ═════════════ */
            VStack {
                width: col.width
                spacing: 0
                visible: root.currentSection === 1

                SettingRow {
                    label: "播放"
                    VStack {
                        width: parent.width
                        spacing: 14
                        SettingSwitch {
                            text: "程序启动时记住上一次播放进度"
                            checked: Store.resumeLastProgress
                            onToggled: function (v) { Store.resumeLastProgress = v }
                        }
                        SettingSwitch {
                            text: "程序启动时自动播放"
                            tip: "需要同时开启上面那条"
                            checked: Store.autoplayOnStart
                            onToggled: function (v) { Store.autoplayOnStart = v }
                        }
                        SettingSwitch {
                            text: "开启音乐淡入淡出"
                            checked: Store.fadeInOut
                            onToggled: function (v) { Store.fadeInOut = v }
                        }
                        SettingSwitch {
                            text: "在后台时歌曲切换发送通知"
                            checked: Store.notifyOnTrackChange
                            onToggled: function (v) { Store.notifyOnTrackChange = v }
                        }
                    }
                }

                SettingRow {
                    label: "播放列表同步"
                    showDivider: false
                    Text {
                        text: "客户端内的播放队列不会回写云端歌单；歌单改动请在手机端或网页端操作。"
                        font.pixelSize: Metrics.sRowTextSize
                        color: Theme.colorBlack6
                        wrapMode: Text.Wrap
                        width: parent.width - 40
                    }
                }
            }

            /* ═════════════ 下载 ═════════════ */
            VStack {
                width: col.width
                spacing: 0
                visible: root.currentSection === 2

                SettingRow {
                    label: "下载目录"
                    Text {
                        text: Store.downloadDir !== "" ? Store.downloadDir : "默认：音乐 / TightNCM"
                        font.pixelSize: Metrics.sRowTextSize
                        color: Theme.colorBlack2
                        elide: Text.ElideMiddle
                        width: parent.width - 40
                    }
                }
                SettingRow {
                    label: "同时下载数"
                    SettingSegmented {
                        options: ["1", "3", "5", "10"]
                        currentIndex: {
                            var n = Store.downloadThreads
                            return n <= 1 ? 0 : n <= 3 ? 1 : n <= 5 ? 2 : 3
                        }
                        onActivated: function (i) { Store.downloadThreads = [1, 3, 5, 10][i] }
                    }
                }
                SettingRow {
                    label: "下载音质"
                    SettingSegmented {
                        options: ["标准", "较高", "无损"]
                        currentIndex: Store.downloadQuality
                        onActivated: function (i) { Store.downloadQuality = i }
                    }
                }
                SettingRow {
                    label: "说明"
                    showDivider: false
                    Text {
                        text: "本地下载还没做（见 AGENTS.md 的「已知未完成」）。这一栏先把偏好存下来，功能落地后直接生效。"
                        font.pixelSize: Metrics.sRowTextSize
                        color: Theme.colorBlack6
                        wrapMode: Text.Wrap
                        width: parent.width - 40
                    }
                }
            }

            /* ═════════════ 关于 ═════════════ */
            VStack {
                width: col.width
                spacing: 0
                visible: root.currentSection === 3

                SettingRow {
                    label: "版本"
                    VStack {
                        width: parent.width
                        spacing: 6
                        Text {
                            text: "TightNCM　1.0"
                            font.pixelSize: Metrics.sRowTextSize
                            color: Theme.colorBlack2
                        }
                        Text {
                            text: "Qt 5.15.2 + QML，从零实现；界面按官方 web 播放器的实测规格 1:1 复刻。"
                            font.pixelSize: Metrics.sRowTextSize
                            color: Theme.colorBlack6
                        }
                    }
                }
                SettingRow {
                    label: "开源许可"
                    Text {
                        text: "Qt 5.15.2 (LGPLv3)　·　界面规格与图标版权归网易云音乐所有，本项目仅供学习"
                        font.pixelSize: Metrics.sRowTextSize
                        color: Theme.colorBlack6
                        wrapMode: Text.Wrap
                        width: parent.width - 40
                    }
                }
                SettingRow {
                    label: "隐私"
                    showDivider: false
                    Text {
                        text: "不做任何埋点上报。登录凭证（MUSIC_U）只存在本机注册表里，不上传。"
                        font.pixelSize: Metrics.sRowTextSize
                        color: Theme.colorBlack6
                        wrapMode: Text.Wrap
                        width: parent.width - 40
                    }
                }
            }
        }
    }
}
