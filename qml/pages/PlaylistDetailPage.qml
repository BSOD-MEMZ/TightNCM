// PlaylistDetailPage —— 歌单详情页
// 也用于「我喜欢的音乐」「最近播放」「专辑」等一切「头部 + 歌曲表格」的页面。
//
// 结构（对齐官方 packages/pc/src/pages/playlist）：
//   SongList
//     headerComponent: PlaylistHeader(封面 216 + 信息) → CmdTabs → 表头(40)
//     delegate: SongRow(64)
//   两侧留白 40px（官方 --spyptxt-0: 40px）
import QtQuick 2.15
import TightNCM 1.0
import "../widgets"

Item {
    id: root

    // 页面数据
    property string title: "歌单"
    property string description: ""
    property string author: ""
    property string authorAvatar: ""
    property string createTime: ""
    property int playCount: 0
    property string cover: ""
    property var songs: []
    property string emptyText: "这里还没有歌"
    property bool showTabs: true
    property int commentCount: 0
    property int subscriberCount: 0
    property bool showPlayAll: true

    // 播放态（由外部按歌曲 id 驱动）
    property var playingSongId: -1

    signal playRequested(int index)
    signal likeToggled(int index)
    signal playAllClicked()
    signal commentTabRequested()

    SongList {
        anchors.fill: parent
        songs: root.songs
        playingSongId: root.playingSongId
        emptyText: root.emptyText
        onPlayRequested: function (i) { root.playRequested(i) }
        onLikeToggled: function (i) { root.likeToggled(i) }

        headerSource: Component {
            Column {
                width: parent ? parent.width : 0

                PlaylistHeader {
                    width: parent.width
                    visible: root.showPlayAll
                    title: root.title
                    description: root.description
                    author: root.author
                    authorAvatar: root.authorAvatar
                    createTime: root.createTime
                    playCount: root.playCount
                    cover: root.cover
                    onPlayAllClicked: root.playAllClicked()
                }

                // 专辑页没有播放全部按钮，用一块简洁标题代替
                Column {
                    width: parent.width
                    visible: !root.showPlayAll
                    topPadding: 12
                    bottomPadding: 24

                    Text {
                        width: parent.width
                        text: root.title
                        font.pixelSize: 24
                        font.weight: Font.DemiBold
                        color: Theme.colorBlack1
                        wrapMode: Text.Wrap
                    }
                    Text {
                        topPadding: 6
                        width: parent.width
                        text: (root.author ? root.author + " · " : "") + root.createTime
                        font.pixelSize: Metrics.fontNormal
                        color: Theme.colorBlack5
                    }
                }

                CmdTabs {
                    width: parent.width
                    visible: root.showTabs
                    items: [
                        { text: "歌曲", count: root.songs.length },
                        { text: "评论", count: root.commentCount },
                        { text: "收藏者", count: root.subscriberCount }
                    ]
                    currentIndex: 0
                    extraText: "搜索"
                    extraIcon: "search"
                    onTabClicked: function (i) { if (i === 1) root.commentTabRequested() }
                }
            }
        }
    }
}
