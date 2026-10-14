// SearchPage —— 搜索结果页
// 四个 tab：单曲 / 歌手 / 专辑 / 歌单。数据来自 /api/cloudsearch/pc（一次请求四类）。
import QtQuick 2.15
import TightNCM 1.0
import "../widgets"

Item {
    id: root

    property string keyword: ""
    property var songs: []
    property var artists: []
    property var albums: []
    property var playlists: []
    property int total: 0
    property bool loading: false
    property var playingSongId: -1
    property int tab: 0            // 0 单曲 / 1 歌手 / 2 专辑 / 3 歌单
    property string initialTab: ""

    signal playRequested(int index)
    signal likeToggled(int index)
    signal artistClicked(var item)
    signal albumClicked(var item)
    signal playlistClicked(var item)

    readonly property var tabs: [
        { text: "单曲", count: root.songs.length },
        { text: "歌手", count: root.artists.length },
        { text: "专辑", count: root.albums.length },
        { text: "歌单", count: root.playlists.length }
    ]

    // 两个视图共用同一个页头（Component 是工厂，可以实例化多份）
    Component {
        id: searchHeader

        Column {
            width: parent ? parent.width : 0
            topPadding: 12

            // ⚠️ 这两个 Text 必须给显式 height。
            // Loader 首次实例化页头时 item 的 parent 还是 null，`width: parent.width`
            // 会先按 0 量一遍 —— 宽度依赖型的 Text 此时 implicitHeight 被算成 0，
            // 之后 positioner 不再重算：这一行既不占位、y 又停在 0，看起来就是
            // 页头文字叠在列表上、后面所有内容整体上移。
            // 用 TextMetrics 拿真实行高写死，绕开这个坑。
            TextMetrics { id: titleMetrics; font: titleText.font; text: titleText.text }
            TextMetrics { id: subMetrics;   font: subText.font;   text: subText.text }

            Text {
                id: titleText
                width: parent.width
                height: titleMetrics.height
                text: root.keyword !== "" ? ("搜索「" + root.keyword + "」") : "搜索"
                font.pixelSize: 24
                font.weight: Font.DemiBold
                color: Theme.colorBlack1
                elide: Text.ElideRight
            }
            Text {
                id: subText
                width: parent.width
                topPadding: 6
                height: subMetrics.height + 6
                text: root.loading ? "搜索中…"
                     : (root.total > 0 ? ("找到 " + root.total + " 首单曲") : "没有结果")
                font.pixelSize: Metrics.fontSmall
                color: Theme.colorBlack5
            }

            Item { width: 1; height: 16 }

            CmdTabs {
                width: parent.width
                items: root.tabs
                currentIndex: root.tab
                onTabClicked: function (i) { root.tab = i }
            }
            Item { width: 1; height: 4 }
        }
    }

    // ── 单曲 ─────────────────────────────────────────
    SongList {
        anchors.fill: parent
        visible: root.tab === 0
        songs: root.songs
        playingSongId: root.playingSongId
        emptyText: root.loading ? "" : "没有找到相关单曲"
        headerSource: searchHeader
        onPlayRequested: function (i) { root.playRequested(i) }
        onLikeToggled: function (i) { root.likeToggled(i) }
    }

    // ── 歌手 / 专辑 / 歌单 ───────────────────────────
    ScrollColumn {
        anchors.fill: parent
        visible: root.tab !== 0
        topPad: 0

        Loader {
            width: parent.width
            // 用 implicitHeight：height 会被 Loader 反向写回，绑定 height 会成环
            height: item ? item.implicitHeight : 0
            sourceComponent: searchHeader
        }

        Item { width: 1; height: 12 }

        CardGrid {
            visible: root.tab === 1
            items: root.artists
            cardSize: 140
            round: true
            fallbackIcon: "user_music_pkg"
            subtitleField: "alias"
            countField: ""
            onCardClicked: function (item) { root.artistClicked(item) }
        }

        CardGrid {
            visible: root.tab === 2
            items: root.albums
            cardSize: 140
            subtitleField: "author"
            countField: ""
            onCardClicked: function (item) { root.albumClicked(item) }
        }

        CardGrid {
            visible: root.tab === 3
            items: root.playlists
            cardSize: 140
            subtitleField: "author"
            onCardClicked: function (item) { root.playlistClicked(item) }
        }

        Item {
            width: 1
            height: 80
            visible: !root.loading
                     && ((root.tab === 1 && root.artists.length === 0)
                      || (root.tab === 2 && root.albums.length === 0)
                      || (root.tab === 3 && root.playlists.length === 0))
            Text {
                anchors.top: parent.top
                anchors.topMargin: 20
                text: "这一类没有结果"
                font.pixelSize: Metrics.fontMedium
                color: Theme.colorBlack7
            }
        }
    }

    onInitialTabChanged: {
        if (initialTab === "artist") tab = 1
        else if (initialTab === "album") tab = 2
        else if (initialTab === "playlist") tab = 3
        else tab = 0
    }
}
