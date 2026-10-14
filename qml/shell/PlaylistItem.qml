// PlaylistItem —— 侧栏里的歌单行
//
// 官方实测（1280×800 登录态）：
//   PlayListItemContent  164 × 46        ← 行盒
//     .background        164 × 42        ← hover/选中药丸，上下各留 2px
//     .cover             32 × 32         ← 左边距 8，在药丸内垂直居中
//     text               字号 12 / 行高 16，左边距 48（= 8 + 32 + 8）
import QtQuick 2.15
import QtQuick.Window 2.15
import TightNCM 1.0
import "../widgets"

Item {
    id: root

    property string title: ""
    property string cover: ""        // 网络地址或 qrc 路径
    property bool selected: false

    signal clicked()

    width: Metrics.navItemWidth
    height: Metrics.playlistItemHeight

    readonly property bool hovered: hh.hovered

    // 药丸：42 高，垂直居中
    RoundRect {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: Metrics.playlistItemPillHeight
        radius: Metrics.navItemRadius
        color: root.selected ? Theme.colorBlack11
             : root.hovered  ? Theme.colorBlack12
             : "transparent"
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    Row {
        anchors.verticalCenter: parent.verticalCenter
        x: Metrics.navItemPadding
        spacing: Metrics.playlistTextGap

        // 封面缩略图
        RoundRect {
            width: Metrics.playlistCoverSize
            height: Metrics.playlistCoverSize
            radius: Metrics.playlistCoverRadius
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.colorBlack12
            clip: true

            Image {
                id: coverImg
                anchors.fill: parent
                source: root.cover
                sourceSize.width: Math.max(1, Math.round(width * Screen.devicePixelRatio))
                sourceSize.height: Math.max(1, Math.round(height * Screen.devicePixelRatio))
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: status === Image.Ready
            }
            // 无封面时用「歌单」图标占位
            Icon {
                anchors.centerIn: parent
                visible: coverImg.status !== Image.Ready
                name: "playlist"
                size: 16
                color: Theme.colorBlack7
            }
        }

        Text {
            width: root.width - Metrics.navItemPadding * 2
                   - Metrics.playlistCoverSize - Metrics.playlistTextGap
            text: root.title
            anchors.verticalCenter: parent.verticalCenter
            font.pixelSize: Metrics.playlistFontSize
            color: root.selected ? Theme.colorBlack1 : Theme.colorBlack3
            elide: Text.ElideRight
            maximumLineCount: 1
        }
    }

    HoverHandler { id: hh }
    TapHandler { onTapped: root.clicked() }
}
