// FmPage —— 漫游（私人 FM）
// 数据：https://music.163.com/api/v1/radio/get（注意只在主站，interface 上是 404）
// 一个 FM「批次」拿 3 首，播完/换一批时再取。
import QtQuick 2.15
import QtQuick.Window 2.15
import TightNCM 1.0
import "../widgets"

Item {
    id: root

    property var songs: []
    property var currentSong: null
    property bool playing: false
    property bool loading: false

    signal playRequested(int index)
    signal nextBatchRequested()
    signal dislikeRequested(var song)
    signal likeRequested(var song)

    // 用 VStack 而不是 Column：本工程里 positioner 会漏排后加进来的子项
    // （实测标题行与歌手行会一起停在 y=0，两行叠在一起）
    VStack {
        anchors.centerIn: parent
        width: Math.min(420, parent.width - 80)
        spacing: 0

        // ── 封面 ──────────────────────────────────
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 280; height: 280

            RoundRect {
                anchors.fill: parent
                radius: 16
                color: Theme.colorBlack12
                clip: true

                Image {
                    id: fmCover
                    anchors.fill: parent
                    source: root.currentSong ? (root.currentSong.cover || "") : ""
                    sourceSize.width: Math.max(1, Math.round(width * Screen.devicePixelRatio))
                    sourceSize.height: Math.max(1, Math.round(height * Screen.devicePixelRatio))
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: status === Image.Ready
                }
                Icon {
                    anchors.centerIn: parent
                    visible: fmCover.status !== Image.Ready
                    name: "sidebar_fm"
                    size: 64
                    color: Theme.colorBlack8
                }
            }
        }

        Item { width: 1; height: 24 }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.currentSong ? root.currentSong.name
                 : (root.loading ? "正在为你挑选…" : "点击下方开始漫游")
            font.pixelSize: 20
            font.weight: Font.DemiBold
            color: Theme.colorBlack1
            elide: Text.ElideRight
        }

        Item { width: 1; height: 6 }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.currentSong ? root.currentSong.artist : "私人 FM · 根据你的口味生成"
            font.pixelSize: Metrics.fontNormal
            color: Theme.colorBlack5
            elide: Text.ElideRight
        }

        Item { width: 1; height: 28 }

        // ── 操作 ──────────────────────────────────
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 24

            // 不喜欢 → 换一批
            Item {
                width: 52; height: 52
                anchors.verticalCenter: parent.verticalCenter
                RoundRect {
                    anchors.fill: parent
                    radius: width / 2
                    color: dislikeHover.hovered ? Theme.colorBlack10 : Theme.colorBlack11
                    Behavior on color { ColorAnimation { duration: 110 } }
                }
                Icon {
                    anchors.centerIn: parent
                    name: "dislike"
                    size: 22
                    color: Theme.colorBlack5
                }
                HoverHandler { id: dislikeHover }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.currentSong) root.dislikeRequested(root.currentSong)
                        else root.nextBatchRequested()
                    }
                }
            }

            // 播放 / 暂停
            Item {
                width: 64; height: 64
                anchors.verticalCenter: parent.verticalCenter

                AngleGradientRect {
                    anchors.fill: parent
                    cssAngle: 270
                    radius: width / 2
                    Component.onCompleted: set2(0.0, Theme.colorSecondary1_1,
                                                 0.74, Theme.colorSecondary1_2)
                }
                Icon {
                    anchors.centerIn: parent
                    name: root.playing ? "pause" : "play"
                    size: 26
                    color: Theme.colorWhite1
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.playRequested(0)
                }
            }

            // 喜欢
            Item {
                width: 52; height: 52
                anchors.verticalCenter: parent.verticalCenter
                RoundRect {
                    anchors.fill: parent
                    radius: width / 2
                    color: likeHover.hovered ? Theme.colorBlack10 : Theme.colorBlack11
                    Behavior on color { ColorAnimation { duration: 110 } }
                }
                Icon {
                    anchors.centerIn: parent
                    name: root.currentSong && root.currentSong.liked
                          ? "likenumber_red" : "like"
                    size: 22
                    color: root.currentSong && root.currentSong.liked
                           ? Theme.brand : Theme.colorBlack5
                }
                HoverHandler { id: likeHover }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (root.currentSong) root.likeRequested(root.currentSong)
                }
            }
        }

        Item { width: 1; height: 28 }

        // 换一批
        CmdButton {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.songs.length > 0
            text: "换一批"
            iconName: "refresh"
            variant: "outline-sec"
            textColor: Theme.colorBlack3
            borderColor: Theme.colorBlack10
            borderWidth: 1
            size: "l"
            customHeight: 32
            customPadding: 16
            customRadius: 16
            customFontSize: Metrics.fontSmall
            onClicked: root.nextBatchRequested()
        }
    }
}
