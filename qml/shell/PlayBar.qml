// PlayBar —— 底部播放栏
// 规格来自还原源码 packages/pc/src/components/PlayBar/style.ts：
//     PlayBarHeight = 80
//     border-top: 0.5px solid colorBlack10
//     background: colorFunction17
//     padding: 0 30px
//     .left   子元素间距 10px
//     .middle width 376px，居中，.btns padding-top 12px
//     .side   宽 262px
//     播放键：linear-gradient(270deg, #FC3D49 0%, #FC3D49 26%, #FB3B5B 99%) + 圆形 + hover scale(1.05)
import QtQuick 2.15
import QtQuick.Window 2.15
import TightNCM 1.0
import "../widgets"

Item {
    id: root

    // ── 播放状态 ────────────────────────────────────
    property bool playing: false
    property string title: ""
    property string artist: ""
    property string cover: ""
    property bool liked: false
    property string quality: ""       // sq / hq / hires / jymaster / sky，空则不显示
    property int positionMs: 0
    property int durationMs: 0
    // 进度比例（由 positionMs / durationMs 推出，外部不用管）
    readonly property real position: durationMs > 0
        ? Math.max(0, Math.min(1, positionMs / durationMs)) : 0
    // "order" | "loop" | "singleloop" | "shuffle"
    property string playMode: "loop"
    property int volume: 70          // 0..100
    property bool lyricVisible: false
    property bool loading: false

    implicitHeight: Metrics.playBarHeight

    signal playPauseClicked()
    signal prevClicked()
    signal nextClicked()
    signal modeClicked()
    signal coverClicked()      // 点左侧封面 → 打开「正在播放」全屏页（官方同款）
    // 注意：不能叫 volumeChanged —— property int volume 会自动生成这个信号，会撞名
    signal volumeEdited(int v)
    signal playlistClicked()
    signal lyricClicked()
    signal likeToggled()
    signal seekRequested(int ms)

    function fmt(ms) {
        if (!ms || ms < 0) return "00:00";
        var s = Math.floor(ms / 1000);
        var m = Math.floor(s / 60);
        s = s % 60;
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
    }

    readonly property var modeIcon: {
        switch (playMode) {
        case "order":      return "order";
        case "singleloop": return "singleloop";
        case "shuffle":    return "shuffle";
        default:           return "loop";
        }
    }
    readonly property var volumeIcon: {
        if (volume <= 0) return "Volume0";
        if (volume < 34) return "Volume1";
        if (volume < 67) return "Volume2";
        return "Volume3";
    }

    // ── 背景 ────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: Theme.barBackground        // colorFunction17 = rgba(250,250,250,1)
    }
    // border-top: 0.5px solid colorBlack10
    Rectangle {
        anchors.top: parent.top
        width: parent.width
        height: 1
        color: Theme.divider
    }

    // ── 左：歌曲信息 ────────────────────────────────
    Row {
        id: leftArea
        anchors.left: parent.left
        anchors.leftMargin: Metrics.barPadding
        anchors.verticalCenter: parent.verticalCenter
        spacing: Metrics.playBarLeftGap
        height: Metrics.playBarHeight

        // 封面
        RoundRect {
            width: 48; height: 48; radius: 8
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.colorBlack11
            clip: true
            Image {
                anchors.fill: parent
                source: root.cover
                sourceSize.width: Math.max(1, Math.round(width * Screen.devicePixelRatio))
                sourceSize.height: Math.max(1, Math.round(height * Screen.devicePixelRatio))
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: status === Image.Ready
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.coverClicked()
            }
        }

        // 标题 / 歌手
        Column {
            width: 180
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
                width: parent.width
                text: root.title || "未在播放"
                font.pixelSize: Metrics.fontMedium
                font.weight: Font.Medium
                color: Theme.textPrimary
                elide: Text.ElideRight
                maximumLineCount: 1
            }
            Text {
                width: parent.width
                text: root.artist
                font.pixelSize: Metrics.fontSmall
                color: Theme.textTertiary
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }

        // 红心
        Icon {
            name: root.liked ? "likenumber_red" : "like"
            size: 20
            color: root.liked ? Theme.brand : Theme.textTertiary
            anchors.verticalCenter: parent.verticalCenter
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.likeToggled()
            }
        }
        // 收藏到歌单
        Icon {
            name: "add_to_playlist" ; size: 20 ; color: Theme.textTertiary
            anchors.verticalCenter: parent.verticalCenter
            visible: false
        }
        // 下载
        Icon {
            name: "download" ; size: 20 ; color: Theme.textTertiary
            anchors.verticalCenter: parent.verticalCenter
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor }
        }
        // 评论
        Icon {
            name: "comment" ; size: 20 ; color: Theme.textTertiary
            anchors.verticalCenter: parent.verticalCenter
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor }
        }
        // 更多
        Icon {
            name: "morefunctions" ; size: 20 ; color: Theme.textTertiary
            anchors.verticalCenter: parent.verticalCenter
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor }
        }
    }

    // ── 中：播放控制（宽 376，居中） ────────────────
    Column {
        id: middleArea
        width: Metrics.playBarMiddleWidth
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        // 按钮排 + 进度条
        Item {
            width: parent.width
            height: 44

            Row {
                id: btns
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 2
                spacing: 18

                Icon {
                    name: root.modeIcon ; size: 18 ; color: Theme.textTertiary
                    anchors.verticalCenter: parent.verticalCenter
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.modeClicked() }
                }
                Icon {
                    name: "pre" ; size: 20 ; color: Theme.textTertiary
                    anchors.verticalCenter: parent.verticalCenter
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.prevClicked() }
                }

                // 播放 / 暂停：圆形渐变
                Item {
                    id: playBtn
                    width: 40; height: 40
                    anchors.verticalCenter: parent.verticalCenter

                    AngleGradientRect {
                        id: playGrad
                        anchors.fill: parent
                        cssAngle: 270
                        radius: width / 2
                        Component.onCompleted: set2(0.0, Theme.colorSecondary1_1, 0.74, Theme.colorSecondary1_2)
                    }

                    Icon {
                        anchors.centerIn: parent
                        // play2/pause2 自带外圈，这里的红色圆是按钮本身，所以用纯图形版 play/pause
                        name: root.playing ? "pause" : "play"
                        size: 20
                        color: Theme.colorWhite1
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.playPauseClicked()
                    }

                    // hover: transform: scale(1.05)
                    scale: playHover.hovered ? 1.05 : 1
                    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }
                    HoverHandler { id: playHover }
                }

                Icon {
                    // 官方 next 与 pre 是镜像关系；ncm_next.svg 是从别的上下文里挖出来的（viewBox 被裁成 14.88x16.23，
                    // 画出来是个实心大三角）。next_song 才是 24x24 那套里 pre 的镜像版。
                    name: "next_song" ; size: 20 ; color: Theme.textTertiary
                    anchors.verticalCenter: parent.verticalCenter
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.nextClicked() }
                }
                Icon {
                    name: "lyric" ; size: 18
                    color: root.lyricVisible ? Theme.colorBlack3 : Theme.textTertiary
                    anchors.verticalCenter: parent.verticalCenter
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.lyricClicked() }
                }
            }
        }

        // 进度：时间 + 条
        Row {
            width: parent.width
            spacing: 8

            Text {
                text: root.fmt(root.positionMs)
                font.pixelSize: Metrics.fontTiny
                color: Theme.colorBlack7
                anchors.verticalCenter: parent.verticalCenter
            }

            Item {
                id: track
                width: parent.width - 88
                height: 14
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width; height: 2; radius: 1
                    color: Theme.colorBlack9
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width * Math.max(0, Math.min(1, root.position))
                    height: 2; radius: 1
                    color: Theme.brand
                }
                Rectangle {
                    visible: trackHover.hovered
                    x: parent.width * Math.max(0, Math.min(1, root.position)) - 4
                    anchors.verticalCenter: parent.verticalCenter
                    width: 8; height: 8; radius: 4
                    color: Theme.brand
                }
                HoverHandler { id: trackHover }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.durationMs > 0)
                            root.seekRequested(Math.round(root.durationMs * Math.max(0, Math.min(1, mouse.x / width))))
                    }
                }
            }

            Text {
                text: root.fmt(root.durationMs)
                font.pixelSize: Metrics.fontTiny
                color: Theme.colorBlack7
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    // ── 右：音质 / 音量 / 播放列表（宽 262） ────────
    Row {
        id: rightArea
        anchors.right: parent.right
        anchors.rightMargin: Metrics.barPadding
        anchors.verticalCenter: parent.verticalCenter
        width: Metrics.playBarSideWidth
        layoutDirection: Qt.RightToLeft
        spacing: 16

        Icon {
            name: "playlist" ; size: 20 ; color: Theme.textTertiary
            anchors.verticalCenter: parent.verticalCenter
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.playlistClicked() }
        }

        // 音量
        Row {
            spacing: 6
            anchors.verticalCenter: parent.verticalCenter
            Icon {
                name: root.volumeIcon ; size: 20 ; color: Theme.textTertiary
                anchors.verticalCenter: parent.verticalCenter
            }
            Item {
                width: 80; height: 14
                anchors.verticalCenter: parent.verticalCenter
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width; height: 2; radius: 1
                    color: Theme.colorBlack9
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width * root.volume / 100
                    height: 2; radius: 1
                    color: Theme.colorBlack5
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.volumeEdited(Math.round(100 * mouse.x / width))
                }
            }
        }

        // 音质徽章（没取到就不显示）
        Item {
            width: root.quality !== "" ? 26 : 0
            height: 16
            visible: root.quality !== ""
            anchors.verticalCenter: parent.verticalCenter
            Icon { anchors.fill: parent; name: root.quality; size: 16 }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor }
        }
    }
}
