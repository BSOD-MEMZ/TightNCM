// ArtistPage —— 歌手页
// 数据：/api/v1/artist/<id>（信息） + /api/v1/artist/songs?id=&order=hot（热门歌曲）
// 专辑列表没有可用端点（/api/artist/albums 返回 400），由 C++ 侧从歌曲里按 albumId 去重推出来。
import QtQuick 2.15
import QtQuick.Window 2.15
import TightNCM 1.0
import "../widgets"

Item {
    id: root

    property var artist: null
    property var hotSongs: []
    property var albums: []
    property var playingSongId: -1
    property int tab: 0

    signal playRequested(int index)
    signal likeToggled(int index)
    signal albumClicked(var item)

    Component {
        id: artistHeader

        Column {
            width: parent ? parent.width : 0
            topPadding: 12

            Row {
                width: parent.width
                spacing: 32

                // 圆形头像 180
                RoundRect {
                    width: 180; height: 180
                    radius: width / 2
                    color: Theme.colorBlack12
                    clip: true

                    Image {
                        id: face
                        anchors.fill: parent
                        source: root.artist ? (root.artist.cover || "") : ""
                        sourceSize.width: Math.max(1, Math.round(width * Screen.devicePixelRatio))
                        sourceSize.height: Math.max(1, Math.round(height * Screen.devicePixelRatio))
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        visible: status === Image.Ready
                    }
                    Icon {
                        anchors.centerIn: parent
                        visible: face.status !== Image.Ready
                        name: "user_music_pkg"
                        size: 48
                        color: Theme.colorBlack8
                    }
                }

                // 用 VStack 而不是 Column：本工程里 positioner 会漏排后加进来的子项
                VStack {
                    width: parent.width - 180 - 32
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Text {
                        width: parent.width
                        text: root.artist ? root.artist.name : ""
                        font.pixelSize: 28
                        font.weight: Font.DemiBold
                        color: Theme.colorBlack1
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        visible: text !== ""
                        text: root.artist && root.artist.alias ? root.artist.alias : ""
                        font.pixelSize: Metrics.fontMedium
                        color: Theme.colorBlack5
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: root.artist
                              ? (root.artist.musicSize + " 首歌 · " + root.artist.albumSize + " 张专辑")
                              : ""
                        font.pixelSize: Metrics.fontSmall
                        color: Theme.colorBlack7
                    }
                    Text {
                        width: parent.width
                        visible: text !== ""
                        text: root.artist ? (root.artist.briefDesc || "") : ""
                        font.pixelSize: Metrics.fontSmall
                        color: Theme.colorBlack5
                        lineHeight: 20
                        lineHeightMode: Text.FixedHeight
                        wrapMode: Text.Wrap
                        maximumLineCount: 3
                        elide: Text.ElideRight
                        topPadding: 6
                    }
                }
            }

            Item { width: 1; height: 20 }

            CmdTabs {
                width: parent.width
                items: [
                    { text: "热门歌曲", count: root.hotSongs.length },
                    { text: "专辑", count: root.albums.length }
                ]
                currentIndex: root.tab
                onTabClicked: function (i) { root.tab = i }
            }
            Item { width: 1; height: 4 }
        }
    }

    SongList {
        anchors.fill: parent
        visible: root.tab === 0
        songs: root.hotSongs
        playingSongId: root.playingSongId
        emptyText: "还没取到热门歌曲"
        headerSource: artistHeader
        onPlayRequested: function (i) { root.playRequested(i) }
        onLikeToggled: function (i) { root.likeToggled(i) }
    }

    ScrollColumn {
        anchors.fill: parent
        visible: root.tab === 1
        topPad: 0

        Loader {
            width: parent.width
            // 用 implicitHeight：height 会被 Loader 反向写回，绑定 height 会成环
            height: item ? item.implicitHeight : 0
            sourceComponent: artistHeader
        }

        Item { width: 1; height: 12 }

        CardGrid {
            items: root.albums
            cardSize: 168
            subtitleField: "author"
            countField: ""
            onCardClicked: function (item) { root.albumClicked(item) }
        }

        Item {
            width: 1
            height: 80
            visible: root.albums.length === 0
            Text {
                anchors.top: parent.top
                anchors.topMargin: 20
                text: "这张歌手名下没取到专辑"
                font.pixelSize: Metrics.fontMedium
                color: Theme.colorBlack7
            }
        }
    }
}
