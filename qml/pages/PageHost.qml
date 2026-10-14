// PageHost —— 内容区路由
// 页面都常驻（用 visible 切换），避免 Loader 反复销毁重建导致状态丢失。
import QtQuick 2.15
import TightNCM 1.0

Item {
    id: root

    // home | playlist | album | artist | toplist | featured | podcast | fm | recent | search | stub
    property string pageKey: "home"

    // 数据
    property var playlistData: null
    property var artistData: null
    property var artistSongs: []
    property var artistAlbums: []
    property var toplists: []
    property var featuredPlaylists: []
    property string featuredCategory: "全部"
    property var podcastRadios: []
    property var fmSongs: []
    property var fmCurrent: null
    property var recentSongs: []
    property var recommendPlaylists: []
    property var recommendSongs: []
    property var dailySongs: []

    // 个人主页（看自己 / 看别人，同一组接口）
    property var userProfile: null
    property var userCreated: []
    property var userCollected: []
    property var userRecord: []
    property int  userLevel: 0
    property bool userIsSelf: true
    property var playingSongId: -1
    property bool playing: false
    property bool loggedIn: false

    // 搜索
    property string searchKeyword: ""
    property var searchSongs: []
    property var searchArtists: []
    property var searchAlbums: []
    property var searchPlaylists: []
    property int searchTotal: 0
    property bool searchLoading: false

    // 通用
    property var stubConfig: null

    // 设置页要展示的账号信息
    property string accountName: ""
    property string accountAvatar: ""
    property string accountId: ""
    property int    accountVip: 0

    signal logoutRequested()
    property bool loading: false

    // ── 上行信号（全部带数据本体，Main 不用猜是哪个列表） ──
    signal playRequested(var songs, int index)
    signal likeToggled(var song)
    signal playAllRequested(var songs)
    signal playlistClicked(var playlist)
    signal albumClicked(var album)
    signal artistClicked(var artist)
    signal radioClicked(var radio)
    signal toplistClicked(var item)
    signal categoryChanged(string cat)
    signal searchSongsMoreRequested(string keyword)
    signal fmNextBatchRequested()
    signal fmDislikeRequested(var song)
    signal fmLikeRequested(var song)
    signal recentClearRequested()
    signal loginRequested()
    signal commentsRequested(var song)
    signal morePlaylistsRequested()

    HomePage {
        anchors.fill: parent
        visible: root.pageKey === "home"
        recommendPlaylists: root.recommendPlaylists
        recommendSongs: root.recommendSongs
        dailySongs: root.dailySongs
        playingSongId: root.playingSongId
        onPlaylistClicked: function (p) { root.playlistClicked(p) }
        // 首页第二块是「每日推荐」（跟随口味），点的是 dailySongs 不是新歌速递
        onSongClicked: function (i) { root.playRequested(root.dailySongs, i) }
        onMorePlaylistsClicked: root.morePlaylistsRequested()
        onPlayDailyClicked: root.playAllRequested(root.dailySongs)
    }

    PlaylistDetailPage {
        anchors.fill: parent
        visible: root.pageKey === "playlist"
        title: root.playlistData ? root.playlistData.name : ""
        description: root.playlistData ? root.playlistData.description || "" : ""
        author: root.playlistData ? root.playlistData.author || "" : ""
        authorAvatar: root.playlistData ? root.playlistData.authorAvatar || "" : ""
        createTime: root.playlistData ? root.playlistData.createTime || "" : ""
        playCount: root.playlistData ? root.playlistData.playCount || 0 : 0
        cover: root.playlistData ? root.playlistData.cover || "" : ""
        songs: root.playlistData && root.playlistData.songs ? root.playlistData.songs : []
        commentCount: root.playlistData ? root.playlistData.commentCount || 0 : 0
        playingSongId: root.playingSongId

        onPlayRequested: function (i) {
            if (root.playlistData && root.playlistData.songs) root.playRequested(root.playlistData.songs, i)
        }
        onLikeToggled: function (i) {
            if (root.playlistData && root.playlistData.songs) root.likeToggled(root.playlistData.songs[i])
        }
        onPlayAllClicked: if (root.playlistData && root.playlistData.songs) root.playAllRequested(root.playlistData.songs)
        onCommentTabRequested: {
            var s = root.playlistData && root.playlistData.songs ? root.playlistData.songs[0] : null
            root.commentsRequested(s)
        }
    }

    // 专辑：复用歌单详情页的版式（封面 + 信息 + 曲目表），去掉标签栏
    PlaylistDetailPage {
        anchors.fill: parent
        visible: root.pageKey === "album"
        showTabs: false
        title: root.playlistData ? root.playlistData.name : ""
        description: root.playlistData ? root.playlistData.description || "" : ""
        author: root.playlistData ? root.playlistData.author || "" : ""
        createTime: root.playlistData ? root.playlistData.publishTime || "" : ""
        cover: root.playlistData ? root.playlistData.cover || "" : ""
        songs: root.playlistData && root.playlistData.songs ? root.playlistData.songs : []
        playingSongId: root.playingSongId
        emptyText: "这张专辑没有曲目"

        onPlayRequested: function (i) {
            if (root.playlistData && root.playlistData.songs) root.playRequested(root.playlistData.songs, i)
        }
        onLikeToggled: function (i) {
            if (root.playlistData && root.playlistData.songs) root.likeToggled(root.playlistData.songs[i])
        }
        onPlayAllClicked: if (root.playlistData && root.playlistData.songs) root.playAllRequested(root.playlistData.songs)
    }

    ArtistPage {
        anchors.fill: parent
        visible: root.pageKey === "artist"
        artist: root.artistData
        hotSongs: root.artistSongs
        albums: root.artistAlbums
        playingSongId: root.playingSongId

        onPlayRequested: function (i) { root.playRequested(root.artistSongs, i) }
        onLikeToggled: function (i) { root.likeToggled(root.artistSongs[i]) }
        onAlbumClicked: function (a) { root.albumClicked(a) }
    }

    UserProfilePage {
        anchors.fill: parent
        visible: root.pageKey === "user"
        user: root.userProfile
        createdPlaylists: root.userCreated
        collectedPlaylists: root.userCollected
        record: root.userRecord
        level: root.userLevel
        isSelf: root.userIsSelf
        onPlaylistClicked: function (p) { root.playlistClicked(p) }
        onSongClicked: function (songs, i) { root.playRequested(songs, i) }
    }

    ToplistPage {
        anchors.fill: parent
        visible: root.pageKey === "toplist"
        blocks: root.toplists
        loading: root.loading
        onToplistClicked: function (item) { root.toplistClicked(item) }
    }

    FeaturedPage {
        anchors.fill: parent
        visible: root.pageKey === "featured"
        playlists: root.featuredPlaylists
        category: root.featuredCategory
        loading: root.loading
        onPlaylistClicked: function (p) { root.playlistClicked(p) }
        onCategorySelected: function (c) { root.categoryChanged(c) }
    }

    PodcastPage {
        anchors.fill: parent
        visible: root.pageKey === "podcast"
        radios: root.podcastRadios
        loading: root.loading
        loggedIn: root.loggedIn
        onRadioClicked: function (r) { root.radioClicked(r) }
        onLoginRequested: root.loginRequested()
    }

    FmPage {
        anchors.fill: parent
        visible: root.pageKey === "fm"
        songs: root.fmSongs
        currentSong: root.fmCurrent
        playing: root.playing
        loading: root.loading
        onPlayRequested: function (i) { root.playRequested(root.fmSongs, 0) }
        onNextBatchRequested: root.fmNextBatchRequested()
        onDislikeRequested: function (s) { root.fmDislikeRequested(s) }
        onLikeRequested: function (s) { root.fmLikeRequested(s) }
    }

    RecentPage {
        anchors.fill: parent
        visible: root.pageKey === "recent"
        songs: root.recentSongs
        playingSongId: root.playingSongId
        onPlayRequested: function (i) { root.playRequested(root.recentSongs, i) }
        onLikeToggled: function (i) { root.likeToggled(root.recentSongs[i]) }
        onClearRequested: root.recentClearRequested()
    }

    SearchPage {
        anchors.fill: parent
        visible: root.pageKey === "search"
        keyword: root.searchKeyword
        songs: root.searchSongs
        artists: root.searchArtists
        albums: root.searchAlbums
        playlists: root.searchPlaylists
        total: root.searchTotal
        loading: root.searchLoading
        playingSongId: root.playingSongId

        onPlayRequested: function (i) { root.playRequested(root.searchSongs, i) }
        onLikeToggled: function (i) { root.likeToggled(root.searchSongs[i]) }
        onArtistClicked: function (a) { root.artistClicked(a) }
        onAlbumClicked: function (a) { root.albumClicked(a) }
        onPlaylistClicked: function (p) { root.playlistClicked(p) }
    }

    SettingsPage {
        anchors.fill: parent
        visible: root.pageKey === "settings"
        loggedIn: root.loggedIn
        nickname: root.accountName
        avatar: root.accountAvatar
        userId: root.accountId
        vipType: root.accountVip
        onLogoutRequested: root.logoutRequested()
    }

    StubPage {
        anchors.fill: parent
        visible: root.pageKey === "stub"
        title: root.stubConfig ? root.stubConfig.title || "" : ""
        subtitle: root.stubConfig ? root.stubConfig.subtitle || "" : ""
        iconName: root.stubConfig ? root.stubConfig.icon || "playlist" : "playlist"
        planned: root.stubConfig ? root.stubConfig.planned || [] : []
    }
}
