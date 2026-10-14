// CommentsPanel —— 右侧滑出的评论区
import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls 2.15
import TightNCM 1.0
import "../widgets"

Item {
    id: root

    property bool open: false
    property var hotComments: []
    property var comments: []
    property int total: 0
    property bool loading: false
    property string songName: ""
    property bool hasMore: false
    // cid → bool。点赞后服务端不回传整页，靠这张表让按钮立刻变红
    property var likedMap: ({})

    signal closeRequested()
    signal likeRequested(var comment)
    signal loadMoreRequested()

    readonly property int panelWidth: 420

    // 官方是「x 分钟前 / x 小时前 / YYYY-MM-DD HH:mm」三档
    function fmtTime(ms) {
        if (!ms) return ""
        var now = new Date().getTime()
        var diff = Math.floor((now - ms) / 1000)
        if (diff < 60) return "刚刚"
        if (diff < 3600) return Math.floor(diff / 60) + " 分钟前"
        if (diff < 86400) return Math.floor(diff / 3600) + " 小时前"
        var d = new Date(ms)
        if (d.getFullYear() === new Date().getFullYear())
            return (d.getMonth() + 1) + "月" + d.getDate() + "日"
        return d.getFullYear() + "年" + (d.getMonth() + 1) + "月" + d.getDate() + "日"
    }

    // 遮罩
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.18)
        opacity: root.open ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 180 } }
        MouseArea {
            anchors.fill: parent
            onClicked: root.closeRequested()
        }
    }

    Item {
        id: panel
        width: root.panelWidth
        height: parent.height
        x: root.open ? parent.width - width : parent.width
        Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

        Rectangle {
            anchors.fill: parent
            color: Theme.pageBackground
            Rectangle {
                anchors.left: parent.left
                width: 1
                height: parent.height
                color: Theme.divider
            }
        }

        Column {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 0

            Row {
                width: parent.width
                height: 32

                Text {
                    text: "评论"
                    font.pixelSize: Metrics.fontLarge
                    font.weight: Font.DemiBold
                    color: Theme.colorBlack1
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    topPadding: 3
                    leftPadding: 6
                    text: root.total > 0 ? Api.fmtCount(root.total) : ""
                    font.pixelSize: Metrics.fontSmall
                    color: Theme.colorBlack7
                    anchors.verticalCenter: parent.verticalCenter
                }

                Item { width: parent.width - 220; height: 1 }

                Icon {
                    name: "refresh"
                    size: 16
                    color: rfHover.hovered ? Theme.colorBlack1 : Theme.colorBlack5
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on color { ColorAnimation { duration: 110 } }
                    HoverHandler { id: rfHover }
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                    }
                }
                Item { width: 12; height: 1 }
                Icon {
                    name: "close"
                    size: 16
                    color: clHover.hovered ? Theme.colorBlack1 : Theme.colorBlack5
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on color { ColorAnimation { duration: 110 } }
                    HoverHandler { id: clHover }
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.closeRequested()
                    }
                }
            }

            Text {
                width: parent.width
                topPadding: 2
                text: root.songName
                font.pixelSize: Metrics.fontSmall
                color: Theme.colorBlack5
                elide: Text.ElideRight
            }

            Item { width: 1; height: 12 }

            ListView {
                id: list
                width: parent.width
                height: parent.height - 60
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                reuseItems: true
                model: root.hotComments.concat(root.comments)
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                delegate: Item {
                    id: dlg
                    required property int index
                    required property var modelData
                    width: list.width
                    height: body.implicitHeight + 24

                    readonly property bool isLiked: root.likedMap[modelData.id] !== undefined
                                                   ? root.likedMap[modelData.id]
                                                   : (modelData.liked === true)

                    // 热评 / 最新评论 的分隔标题（model 是 hot 拼 normal）
                    Text {
                        visible: (root.hotComments.length > 0 && index === 0)
                                 || index === root.hotComments.length
                        text: index === 0 ? "精彩评论" : "最新评论"
                        font.pixelSize: Metrics.fontSmall
                        font.weight: Font.DemiBold
                        color: Theme.colorBlack5
                        anchors.top: parent.top
                        anchors.topMargin: -2
                    }

                    Row {
                        id: body
                        width: parent.width
                        spacing: 10
                        anchors.top: parent.top
                        anchors.topMargin: (root.hotComments.length > 0 && index === 0)
                                           || index === root.hotComments.length ? 24 : 8

                        RoundRect {
                            width: 34; height: 34
                            radius: 17
                            color: Theme.colorBlack12
                            clip: true
                            Image {
                                anchors.fill: parent
                                source: modelData.avatar || ""
                                sourceSize.width: Math.max(1, Math.round(width * Screen.devicePixelRatio))
                                sourceSize.height: Math.max(1, Math.round(height * Screen.devicePixelRatio))
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                visible: status === Image.Ready
                            }
                        }

                        Column {
                            width: parent.width - 44
                            spacing: 4

                            Row {
                                spacing: 6
                                Text {
                                    text: modelData.userName || ""
                                    font.pixelSize: Metrics.fontSmall
                                    color: Theme.colorBlack5
                                }
                                Text {
                                    visible: text !== ""
                                    text: modelData.location || ""
                                    font.pixelSize: Metrics.fontSmall
                                    color: Theme.colorBlack8
                                }
                            }

                            // 被回复的那条：官方画成灰底引用块「@xxx：内容」
                            Row {
                                width: parent.width
                                spacing: 4
                                visible: !!modelData.replyTo
                                Rectangle {
                                    width: parent.width
                                    height: replyCol.implicitHeight + 12
                                    radius: 4
                                    color: Theme.colorBlack12
                                    Column {
                                        id: replyCol
                                        x: 8
                                        y: 6
                                        width: parent.width - 16
                                        spacing: 2
                                        Text {
                                            width: parent.width
                                            text: "@" + (modelData.replyTo || "")
                                            font.pixelSize: Metrics.fontTiny
                                            color: Theme.colorBlack4   // 官方 @用户名是深灰偏蓝，这里没有这个 token，用黑 4 档
                                            elide: Text.ElideRight
                                        }
                                        Text {
                                            width: parent.width
                                            text: modelData.replyContent || ""
                                            font.pixelSize: Metrics.fontTiny
                                            color: Theme.colorBlack5
                                            wrapMode: Text.Wrap
                                            maximumLineCount: 2
                                            elide: Text.ElideRight
                                        }
                                    }
                                }
                            }

                            Text {
                                width: parent.width
                                text: modelData.content || ""
                                font.pixelSize: Metrics.fontNormal
                                color: Theme.colorBlack1
                                wrapMode: Text.Wrap
                            }

                            Row {
                                width: parent.width
                                spacing: 6

                                Text {
                                    text: root.fmtTime(modelData.time)
                                    font.pixelSize: Metrics.fontTiny
                                    color: Theme.colorBlack8
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Item { width: parent.width - 120; height: 1 }

                                // 点赞：官方是「心/赞 + 数字」，点一下变红
                                Row {
                                    spacing: 4
                                    anchors.verticalCenter: parent.verticalCenter
                                    Icon {
                                        name: "like"
                                        size: 13
                                        color: dlg.isLiked ? Theme.brand : Theme.colorBlack7
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Text {
                                        text: modelData.likedCount > 0
                                              ? Api.fmtCount(modelData.likedCount) : "赞"
                                        font.pixelSize: Metrics.fontTiny
                                        color: dlg.isLiked ? Theme.brand : Theme.colorBlack7
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        anchors.margins: -6
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.likeRequested(modelData)
                                    }
                                }
                            }
                        }
                    }
                }

                footer: Item {
                    width: list.width
                    height: 64

                    Text {
                        anchors.centerIn: parent
                        visible: root.hotComments.length + root.comments.length === 0
                        text: root.loading ? "加载中…" : "还没有评论"
                        font.pixelSize: Metrics.fontSmall
                        color: Theme.colorBlack7
                    }

                    // 翻页：官方是滚到底自动加载，这里加个显式按钮更可控
                    Item {
                        anchors.centerIn: parent
                        width: 120
                        height: 28
                        visible: root.hasMore && !root.loading
                                 && (root.hotComments.length + root.comments.length) > 0

                        RoundRect {
                            anchors.fill: parent
                            radius: 14
                            color: moreHover.hovered ? Theme.colorBlack11 : "transparent"
                            borderColor: Theme.divider
                            borderWidth: 1
                        }
                        Text {
                            anchors.centerIn: parent
                            text: "加载更多评论"
                            font.pixelSize: Metrics.fontSmall
                            color: Theme.colorBlack3
                        }
                        HoverHandler { id: moreHover }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.loadMoreRequested()
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: root.loading && (root.hotComments.length + root.comments.length) > 0
                        text: "加载中…"
                        font.pixelSize: Metrics.fontSmall
                        color: Theme.colorBlack7
                    }
                }
            }
        }
    }
}
