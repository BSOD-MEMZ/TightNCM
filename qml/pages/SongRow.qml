// SongRow —— 歌曲表格的一行
// 规格（官方 CSS 字面值）：
//   .tbody .tr      { height: 64px }
//   .StyledTitleCell .cover { width/height 48px; border-radius: 8px }
//   .title          { font-size: 16px; color: colorBlack1 }，alias 用 colorBlack5
//   td              { padding: 0 8px }，第一列 padding-left 16px
import QtQuick 2.15
import QtQuick.Window 2.15
import TightNCM 1.0
import "../widgets"

Item {
    id: root

    property var song: null
    // 由表格统一下发的列宽（和表头用同一份，保证对齐）
    property var colWidths: [45, 180, 115, 60, 64]
    property int rowIndex: 0
    property bool isPlaying: false
    property bool selected: false

    signal playRequested(int index)
    signal likeToggled(int index)

    height: Metrics.tRowHeight
    readonly property bool hovered: hh.hovered
    readonly property bool dimmed: song && song.fee === 1 && !root.hovered

    // 喜欢状态：本地集合优先，接口给的 starred 兜底。
    // `Store.likeRevision` 是绑定依赖 —— 它变了这条绑定才会重算（QSet 本身 QML 看不见）。
    readonly property bool liked: {
        if (!root.song) return false
        Store.likeRevision
        if (Store.isLiked(root.song.id)) return true
        return root.song.liked === true
    }

    // ── 整行背景 ────────────────────────────────────
    // 官方 hover/selected：background colorFunction2（纯白）+ 阴影 + radius 10。
    // 页面底色是 rgb(247,249,252)，所以白卡本身就浮起来了（阴影全局关着）。
    Rectangle {
        anchors.fill: parent
        radius: Metrics.tRowRadius
        color: root.selected ? Theme.colorFunction2
             : root.hovered  ? Theme.colorFunction2
             : "transparent"
        Behavior on color { ColorAnimation { duration: 100 } }
    }

    Row {
        anchors.fill: parent

        // ── 序号 / 悬停播放键 ───────────────────────
        Item {
            width: root.colWidths[0]
            height: parent.height

            Text {
                anchors.centerIn: parent
                visible: !root.hovered && !root.isPlaying
                text: root.song ? (root.song.index < 10 ? "0" : "") + root.song.index : ""
                font.pixelSize: Metrics.fontMedium
                color: Theme.colorBlack7
            }

            // 正在播放 → 出声波图标
            Icon {
                anchors.centerIn: parent
                visible: root.isPlaying
                name: "playing"
                size: 16
                color: Theme.brand
            }

            // 悬停 → 红色圆形播放键
            Item {
                anchors.centerIn: parent
                width: 28; height: 28
                visible: root.hovered && !root.isPlaying

                AngleGradientRect {
                    anchors.fill: parent
                    cssAngle: 270
                    radius: width / 2
                    Component.onCompleted: set2(0.0, Theme.colorSecondary1_1, 0.74, Theme.colorSecondary1_2)
                }
                Icon {
                    anchors.centerIn: parent
                    name: "play"
                    size: 14
                    color: Theme.colorWhite1
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.playRequested(root.song ? root.song.index - 1 : 0)
                }
            }
        }

        // ── 标题：封面 + 标题/副标题 ────────────────
        Item {
            width: root.colWidths[1]
            height: parent.height

            Row {
                id: titleRow
                anchors.verticalCenter: parent.verticalCenter
                x: Metrics.tCellPaddingX
                // 必须给显式宽度：否则 Row 的 width 由 childrenRect 决定，
                // 内部的 Column 再拿 parent.width 就成了循环依赖，算出来是 0。
                width: parent.width - Metrics.tCellPaddingX * 2
                spacing: 10
                clip: true

                // 封面 48×48 r8
                RoundRect {
                    width: Metrics.tCoverSize
                    height: Metrics.tCoverSize
                    radius: Metrics.tCoverRadius
                    color: Theme.colorBlack12
                    clip: true
                    anchors.verticalCenter: parent.verticalCenter

                    Image {
                        id: rowCover
                        anchors.fill: parent
                        source: root.song ? (root.song.cover || "") : ""
                        sourceSize.width: Math.max(1, Math.round(width * Screen.devicePixelRatio))
                        sourceSize.height: Math.max(1, Math.round(height * Screen.devicePixelRatio))
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        visible: status === Image.Ready
                    }
                    Icon {
                        anchors.centerIn: parent
                        visible: rowCover.status !== Image.Ready
                        name: "music"
                        size: 18
                        color: Theme.colorBlack8
                    }
                }

                // 文字区
                Column {
                    width: titleRow.width - Metrics.tCoverSize - titleRow.spacing
                    spacing: 2
                    anchors.verticalCenter: parent.verticalCenter

                    // 第一行：标题 +（别名）
                    Row {
                        width: parent.width
                        spacing: 0

                        Text {
                            // 字段名是 name（网易接口）而不是 title
                            text: root.song ? (root.song.name || "") : ""
                            font.pixelSize: Metrics.tTitleFontSize
                            font.weight: Font.Medium
                            color: root.isPlaying ? Theme.brand
                                 : root.dimmed    ? Theme.colorBlack8
                                 : Theme.colorBlack1
                            elide: Text.ElideRight
                            width: Math.min(implicitWidth, parent.width - aliasText.width - qualityTag.width)
                        }
                        Text {
                            id: aliasText
                            text: root.song && root.song.alias ? "（" + root.song.alias + "）" : ""
                            font.pixelSize: Metrics.tTitleFontSize
                            color: Theme.colorBlack5
                            visible: text !== ""
                        }
                    }

                    // 第二行：音质徽章 + 歌手  （官方 .sub-title：font-size 13, colorBlack6, 子项间距 4）
                    Row {
                        width: parent.width
                        spacing: 4

                        // 音质徽章（sq / hq / sky / hires / jymaster）
                        Item {
                            id: qualityTag
                            width: root.song && root.song.quality ? 31 : 0
                            height: 14
                            visible: width > 0
                            anchors.verticalCenter: parent.verticalCenter
                            Icon {
                                anchors.fill: parent
                                name: (root.song && root.song.quality) ? root.song.quality : ""
                                size: 14
                            }
                        }

                        Text {
                            text: root.song ? root.song.artist : ""
                            font.pixelSize: Metrics.tSubFontSize
                            color: Theme.colorBlack6
                            elide: Text.ElideRight
                            width: parent.width - qualityTag.width - 4
                        }
                    }
                }
            }
        }

        // ── 专辑 ────────────────────────────────────
        Item {
            width: root.colWidths[2]
            height: parent.height
            Text {
                anchors.verticalCenter: parent.verticalCenter
                x: Metrics.tCellPaddingX
                width: parent.width - Metrics.tCellPaddingX * 2
                text: root.song ? root.song.album : ""
                font.pixelSize: Metrics.fontSmall
                color: Theme.colorBlack5
                elide: Text.ElideRight
            }
        }

        // ── 喜欢 / 悬停操作组 ───────────────────────
        Item {
            width: root.colWidths[3]
            height: parent.height

            // 常态：红心
            Icon {
                anchors.centerIn: parent
                visible: !root.hovered
                name: root.liked ? "likenumber_red" : "like"
                size: 18
                color: root.liked ? Theme.brand : Theme.colorBlack7
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.likeToggled(root.song ? root.song.index - 1 : 0)
                }
            }

            // 悬停：收藏 / 评论 / 更多
            Row {
                anchors.centerIn: parent
                visible: root.hovered
                spacing: 10
                Repeater {
                    model: ["collect", "comment", "morefunctions"]
                    delegate: Icon {
                        required property string modelData
                        name: modelData
                        size: 16
                        color: Theme.colorBlack5
                        anchors.verticalCenter: parent.verticalCenter
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor }
                    }
                }
            }
        }

        // ── 时长 ────────────────────────────────────
        Item {
            width: root.colWidths[4]
            height: parent.height

            Text {
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                anchors.rightMargin: Metrics.tCellPaddingX
                text: root.song ? root.fmt(root.song.duration) : ""
                font.pixelSize: Metrics.fontSmall
                color: Theme.colorBlack7
            }
        }
    }

    function fmt(sec) {
        var m = Math.floor(sec / 60)
        var s = sec % 60
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s
    }

    HoverHandler { id: hh }
}
