// PlaylistHeader —— 歌单详情页头部
//
// 规格来自 登录态实测（1280×800 与 1440×900 两次一致）：
//   StyledCommon  244,90  996×222   display:flex; padding: 0 0 28px
//     .cover      244,98  194×194   border-radius 12（相对内容框再下移 8px）
//       .bg       绝对定位 top:-8 left:12 right:12 bottom:32，radius 8，colorBlack11
//     .info       478,90  762×194   margin-left 40
//       .title    y=90   高 33.5    font-size 24 / line-height 32 / weight 600
//       .description  margin-top 8  font-size 13 / line-height 21
//       .more     y=133.5 高 24    margin: 10px 0 12px；子项间距 12
//         头像 24×24，与昵称间距 10；昵称 12px colorBlack5；时间 12px colorBlack8
//       .btns     y=244  高 40    margin-top: auto；子项间距 12
//         播放全部 94×40；右侧圆形「…」40×40
//
// 注意：页头总高是 **222**（= 194 + 28），不是 封面+8+28。
// 之前把封面写成 216 并让高度跟着封面走，导致整个页头高出 30px、
// 把下面的 Tabs 和表格整体往下顶。
import QtQuick 2.15
import QtQuick.Window 2.15
import TightNCM 1.0
import "../widgets"

Item {
    id: root

    property string title: ""
    property string description: ""
    property string author: ""
    property string authorAvatar: ""
    property string createTime: ""
    property int playCount: 0
    property string cover: ""

    signal playAllClicked()
    signal moreClicked()
    signal authorClicked()

    readonly property int coverSize: Metrics.pPlaylistCoverSize
    height: Metrics.pHeaderHeight

    // ⚠️ 不用 Row：官方只有**封面**相对内容框下移 8px，右侧 info 是贴顶的（title 的
    // 顶边 = 页头内容框顶边）。Row 会把 topMargin 同时施加到所有子项，info 就低了 8px。
    // ── 封面（含背后的堆叠卡） ──────────────────────
    Item {
        id: coverBox
        // 只能用 y —— anchors.top 会覆盖 y，封面就不会下移那 8px 了
        y: Metrics.pHeaderCoverTop
        width: root.coverSize
        height: root.coverSize

        // .bg —— 封面后面那层浅色卡，做出「一叠」的层次
        RoundRect {
            x: 12
            y: -8
            width: parent.width - 24
            height: parent.height - 24
            radius: 8
            color: Theme.colorBlack11
            z: 0
        }

        RoundRect {
            anchors.fill: parent
            radius: Metrics.pPlaylistCoverRadius
            color: Theme.colorBlack12
            clip: true
            z: 1

            Image {
                anchors.fill: parent
                source: root.cover
                sourceSize.width: Math.max(1, Math.round(width * Screen.devicePixelRatio))
                sourceSize.height: Math.max(1, Math.round(height * Screen.devicePixelRatio))
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: status === Image.Ready
            }
            Icon {
                anchors.centerIn: parent
                visible: root.cover === ""
                name: "playlist"
                size: 48
                color: Theme.colorBlack8
            }

            // 播放量角标：top 12 right 10，icon 12，文字 15 bold 字距 -3
            Row {
                visible: root.playCount > 0
                spacing: 2
                x: parent.width - width - 10
                y: 12
                z: 2

                Icon {
                    name: "view_counts"
                    size: 12
                    color: Theme.colorWhite1
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: root.playCount >= 10000
                          ? (root.playCount / 10000).toFixed(1) + "万"
                          : String(root.playCount)
                    font.pixelSize: 15
                    font.weight: Font.Bold
                    font.letterSpacing: -0.3
                    color: Theme.colorWhite1
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // 顶部压暗，保证白色角标可读（官方 .with-mask）
            Rectangle {
                anchors.fill: parent
                z: 1
                visible: root.playCount > 0
                gradient: Gradient {
                    GradientStop { position: 0.00; color: Qt.rgba(0, 0, 0, 0.30) }
                    GradientStop { position: 0.40; color: Qt.rgba(0, 0, 0, 0.0) }
                }
            }
        }
    }

    // ── 右侧信息 ────────────────────────────────
    // 高 194：标题贴顶、按钮贴底（等价于 .btns { margin-top: auto }）
    Item {
        id: info
        width: root.width - root.coverSize - Metrics.pInfoMarginLeft
        height: root.coverSize
        anchors.top: parent.top
        anchors.left: coverBox.right
        anchors.leftMargin: Metrics.pInfoMarginLeft

        Text {
            id: titleText
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            text: root.title
            font.pixelSize: Metrics.pHeaderTitleSize
            font.weight: Font.DemiBold
            color: Theme.colorBlack1
            // 必须用 FixedHeight：ProportionalHeight 乘的是字体的**自然行高**
            // （微软雅黑约 1.33em），24px 字号会算成 42.6px，而 CSS 要的是刚好 32px。
            lineHeight: Metrics.pHeaderTitleLine
            lineHeightMode: Text.FixedHeight
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }

        Text {
            id: descText
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: titleText.bottom
            anchors.topMargin: 8
            visible: root.description !== ""
            text: root.description
            font.pixelSize: Metrics.fontNormal
            color: Theme.colorBlack5
            lineHeight: 21
            lineHeightMode: Text.FixedHeight
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }

        // 作者 + 创建时间
        Row {
            id: moreRow
            anchors.left: parent.left
            anchors.top: (descText.visible ? descText.bottom : titleText.bottom)
            anchors.topMargin: Metrics.pMoreMarginTop
            spacing: Metrics.pMoreGap

            Row {
                spacing: Metrics.pAuthorGap
                anchors.verticalCenter: parent.verticalCenter

                RoundRect {
                    width: Metrics.pAuthorAvatarSize
                    height: Metrics.pAuthorAvatarSize
                    radius: width / 2
                    color: Theme.colorBlack12
                    clip: true
                    anchors.verticalCenter: parent.verticalCenter
                    Image {
                        anchors.fill: parent
                        source: root.authorAvatar
                sourceSize.width: Math.max(1, Math.round(width * Screen.devicePixelRatio))
                        sourceSize.height: Math.max(1, Math.round(height * Screen.devicePixelRatio))
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        visible: status === Image.Ready
                    }
                }
                Text {
                    text: root.author
                    font.pixelSize: Metrics.pAuthorFontSize
                    font.weight: Font.Medium
                    color: Theme.colorBlack5
                    anchors.verticalCenter: parent.verticalCenter
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.authorClicked()
                    }
                }
            }
            Text {
                text: root.createTime
                font.pixelSize: Metrics.pAuthorFontSize
                color: Theme.colorBlack8
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // 底部按钮（等价于 margin-top:auto）
        Row {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            spacing: Metrics.pBtnGap

            // 播放全部：94×40 r8 字号 13
            Item {
                width: Metrics.pPlayAllWidth
                height: Metrics.pPlayAllHeight

                AngleGradientRect {
                    anchors.fill: parent
                    radius: Metrics.pPlayAllRadius
                    cssAngle: 242.83
                    Component.onCompleted: set3(0.1696, Theme.colorSecondary1_2,
                                                0.3433, Theme.colorSecondary1_2,
                                                0.8304, Theme.colorSecondary1_1)
                    opacity: playAllHover.hovered ? 0.9 : 1.0
                    Behavior on opacity { NumberAnimation { duration: 120 } }
                }
                Row {
                    anchors.centerIn: parent
                    spacing: 4
                    Icon {
                        name: "play"
                        size: 16
                        color: Theme.colorWhite1
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "播放全部"
                        font.pixelSize: Metrics.pPlayAllFontSize
                        color: Theme.colorWhite1
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.playAllClicked()
                }
                HoverHandler { id: playAllHover }
            }

            // 更多：surface-sec 圆形
            Item {
                width: Metrics.pSecBtnSize
                height: Metrics.pSecBtnSize
                RoundRect {
                    anchors.fill: parent
                    radius: width / 2
                    color: moreHover.hovered ? Theme.colorBlack10 : Theme.colorBlack11
                    Behavior on color { ColorAnimation { duration: 120 } }
                }
                Icon {
                    anchors.centerIn: parent
                    name: "morefunctions"
                    size: 18
                    color: Theme.colorBlack3
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.moreClicked()
                }
                HoverHandler { id: moreHover }
            }
        }
    }
}
