// PlaylistCard —— 歌单 / 专辑 / 歌手 通用卡片
//
// 规格（官方卡片）：
//   封面 168×168，radius 10（歌手用圆形）
//   播放量角标：右上 10,10；图标 12；文字 13
//   标题 12px 两行，颜色 colorBlack1
//   歌手/作者行 12px colorBlack5
//   hover 时封面中心出 44px 半透明黑色圆 + 播放三角
import QtQuick 2.15
import QtQuick.Window 2.15
import TightNCM 1.0
import "../widgets"

Item {
    id: root

    property string title: ""
    property string cover: ""
    property string subtitle: ""        // 歌手名 / 作者 / 发行时间
    property int    playCount: 0
    property bool   round: false        // 歌手头像用圆形
    property string fallbackIcon: "playlist"   // 没封面时显示的图标
    property string badge: ""           // 右上角小标（如「独家」）
    property real   cardSize: 168
    property real   radius: 10   // 官方 .cmd-card / .CardWrapper border-radius: 10px（实测词表里出现 26 次）
    property bool   showPlayButton: true     // hover 播放键（歌手卡不需要）

    signal clicked()
    signal playClicked()

    width: cardSize
    height: cardSize + 8 + 20 + (subtitle !== "" ? 18 : 0) + 4

    readonly property bool hovered: hh.hovered

    // ── 封面 ────────────────────────────────────────
    RoundRect {
        id: coverBox
        width: root.cardSize
        height: root.cardSize
        radius: root.round ? width / 2 : root.radius
        color: Theme.colorBlack12
        clip: true

        Image {
            id: img
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
            visible: img.status !== Image.Ready
            name: root.fallbackIcon
            size: 40
            color: Theme.colorBlack8
        }

        // 播放量角标（歌手卡不给）
        Row {
            visible: root.playCount > 0
            spacing: 2
            x: parent.width - width - 10
            y: 10
            z: 2
            Icon {
                name: "view_counts"; size: 12; color: Theme.colorWhite1
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: Api.fmtCount(root.playCount)
                font.pixelSize: 13
                color: Theme.colorWhite1
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // 顶部压暗，让白色角标可读
        Rectangle {
            anchors.fill: parent
            z: 1
            visible: root.playCount > 0
            radius: coverBox.radius
            gradient: Gradient {
                GradientStop { position: 0.00; color: Qt.rgba(0, 0, 0, 0.28) }
                GradientStop { position: 0.45; color: Qt.rgba(0, 0, 0, 0.0) }
            }
        }

        // hover 播放键
        Item {
            anchors.centerIn: parent
            width: 44; height: 44
            visible: root.hovered && root.showPlayButton
            z: 3
            RoundRect {
                anchors.fill: parent
                radius: width / 2
                color: Qt.rgba(0, 0, 0, 0.38)
            }
            Icon {
                anchors.centerIn: parent
                name: "play"
                size: 20
                color: Theme.colorWhite1
            }
        }

        // 角标
        Item {
            visible: root.badge !== ""
            z: 3
            x: 8
            y: 8
            width: badgeText.width + 12
            height: 20
            RoundRect {
                anchors.fill: parent
                radius: 4
                color: Theme.brand
            }
            Text {
                id: badgeText
                anchors.centerIn: parent
                text: root.badge
                font.pixelSize: 11
                color: Theme.colorWhite1
            }
        }
    }

    // ── 标题 ────────────────────────────────────────
    Text {
        id: titleText
        anchors.top: coverBox.bottom
        anchors.topMargin: 8
        width: root.width
        text: root.title
        font.pixelSize: Metrics.fontSmall
        color: root.hovered ? Theme.brand : Theme.colorBlack1
        wrapMode: Text.Wrap
        maximumLineCount: 2
        elide: Text.ElideRight
        Behavior on color { ColorAnimation { duration: 110 } }
    }

    Text {
        anchors.top: titleText.bottom
        anchors.topMargin: 2
        width: root.width
        visible: root.subtitle !== ""
        text: root.subtitle
        font.pixelSize: Metrics.fontSmall
        color: Theme.colorBlack5
        elide: Text.ElideRight
        maximumLineCount: 1
    }

    HoverHandler { id: hh }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
