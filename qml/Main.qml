// Main —— 应用外壳
//
// 骨架（实测）：
//   左侧栏   204 × 全高，bg rgba(40,50,72,0.03)
//   顶栏      高 72，padding 0 40，官方 class 含 draggable（窗口拖拽区）
//   内容区    x=204, y=72，独立滚动
//   播放栏    高 80，border-top 0.5px，padding 0 30
//   四角各 8px 的窗口缩放热区
//
// 数据与播放由 C++ 侧注入的三个全局对象提供：
//   Api     —— NcmApi（明文 /api/ + MUSIC_U cookie 鉴权）
//   Player  —— AudioPlayer（QMediaPlayer 封装）
//   Store   —— AppStore（音量 / 播放模式 / 喜欢集合 / 播放历史，QSettings 持久化）
import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls 2.15
import TightNCM 1.0

import "shell"
import "widgets"
import "pages"

Window {
    id: win

    width: 1280
    height: 800
    minimumWidth: 1000
    minimumHeight: 640
    visible: true
    title: "TightNCM"

    x: TNCScreenshotMode ? -4000 : Math.round((Screen.width - width) / 2)
    y: TNCScreenshotMode ? -4000 : Math.round((Screen.height - height) / 2)
    color: Theme.pageBackground

    flags: Qt.Window | Qt.FramelessWindowHint

    // ══════════════════════════════════════════════════
    //  页面与导航
    // ══════════════════════════════════════════════════
    property string pageKey: "home"
    property var history: []            // 页面历史快照，供返回键用

    // 侧栏选中态：把页面 key 映射到侧栏行号（0..4 主导航，5..8 我的音乐）
    // 直接用 pageKey 判断会漏掉「精选/播客/漫游/最近播放」等页，红色药丸就不亮了。
    readonly property int navIndexForPage: {
        switch (pageKey) {
        case "home":     return 0
        case "featured": return 1
        case "podcast":  return 2
        case "fm":       return 3
        case "like":     return 5
        case "recent":   return 6
        case "favourite":return 8
        default:         return -1
        }
    }

    property var currentPlaylist: null  // 歌单详情（含 songs）
    property var currentAlbum: null     // 专辑详情（含 songs）
    property var artistData: null
    property var artistSongs: []
    property var artistAlbums: []
    property var stubConfig: null

    // 个人主页（uid 由 openUser 决定，所以同一个页面能看自己也能看别人）
    property var userProfile: null
    property var userCreated: []
    property var userCollected: []
    property var userRecord: []
    property int  userLevel: 0
    property bool userIsSelf: true
    property var  userUid: 0
    property bool pendingUserPage: false   // 请求打开主页时 profile 尚未就绪

    property var createdPlaylists: []
    property var collectedPlaylists: []
    property var recommendPlaylists: []
    property var recommendSongs: []     // 新歌速递（全网，不个性化）
    property var dailySongs: []         // ★ 每日推荐（跟随账号口味，/api/v1/discovery/recommend/songs）

    property var toplists: []
    property var featuredPlaylists: []
    property string featuredCategory: "全部"
    property var podcastRadios: []

    property var fmSongs: []

    // 搜索
    property string searchKeyword: ""
    property var searchSongs: []
    property var searchArtists: []
    property var searchAlbums: []
    property var searchPlaylists: []
    property int searchTotal: 0
    property bool searchLoading: false

    // 页面级加载态
    property bool pageLoading: false

    // ══════════════════════════════════════════════════
    //  播放
    // ══════════════════════════════════════════════════
    property var playingList: []
    property int playingIndex: -1
    property var pendingSongId: -1
    // "list" = 普通列表；"fm" = 私人 FM（播完自动续下一批）
    property string playingSource: "list"

    // 当前曲目。必须是 readonly property 而不是 function()——
    // QML 不追踪函数内部读了哪些属性，写成函数的话绑定不会刷新。
    readonly property var currentSong: (playingIndex >= 0 && playingIndex < playingList.length)
                                       ? playingList[playingIndex] : null
    readonly property var playingSongId: currentSong ? currentSong.id : -1

    // 歌词
    property var lyricLines: []

    // 播放模式：order 顺序 / loop 列表循环 / singleloop 单曲循环 / shuffle 随机
    property string playMode: Store.playMode

    // ══════════════════════════════════════════════════
    //  侧边面板
    // ══════════════════════════════════════════════════
    property bool showQueue: false
    property bool showLyric: false
    property bool showComments: false
    property bool showNowPlaying: false    // 播放详情（点播放栏封面）

    property var commentHot: []
    property var commentList: []
    property int commentTotal: 0
    property bool commentLoading: false
    property var commentSong: null
    property int commentOffset: 0
    property bool commentHasMore: false
    // 点赞是「逐条」状态，服务端不会整页回传。用 cid → bool 的字典本地兜住，
    // 面板里读这个字典渲染，重开评论时清空。
    property var commentLiked: ({})

    // 登录
    property bool showLogin: false
    property string loginMessage: ""
    property bool loginFailed: false

    // 轻提示
    property string toast: ""
    function showToast(msg) {
        toast = msg
        toastTimer.restart()
    }
    Timer { id: toastTimer; interval: 3200; onTriggered: win.toast = "" }

    // ══════════════════════════════════════════════════
    //  导航
    // ══════════════════════════════════════════════════
    function snapshot() {
        return {
            key: pageKey === "stub" ? "home" : pageKey,
            playlist: currentPlaylist,
            album: currentAlbum,
            artist: artistData,
            stub: stubConfig
        }
    }
    function pushHistory() {
        history = history.concat([snapshot()])
        if (history.length > 40)
            history = history.slice(history.length - 40)
    }
    function goBack() {
        if (history.length === 0) {
            pageKey = "home"
            return
        }
        var s = history[history.length - 1]
        history = history.slice(0, history.length - 1)
        currentPlaylist = s.playlist
        currentAlbum = s.album
        artistData = s.artist
        stubConfig = s.stub
        pageKey = s.key
    }

    function openPlaylist(pl) {
        if (!pl || !pl.id) return
        pushHistory()
        currentPlaylist = pl
        pageKey = "playlist"
        pageLoading = true
        Api.loadPlaylistDetail(pl.id)
    }

    function openAlbum(album) {
        if (!album || !album.id) return
        pushHistory()
        currentAlbum = album
        pageKey = "album"
        pageLoading = true
        Api.loadAlbumDetail(album.id)
    }

    function openArtist(artist) {
        if (!artist || !artist.id) return
        pushHistory()
        artistData = { id: artist.id, name: artist.name, alias: artist.alias || "",
                       cover: artist.cover || "", briefDesc: "", musicSize: 0, albumSize: 0 }
        artistSongs = []
        artistAlbums = []
        pageKey = "artist"
        pageLoading = true
        Api.loadArtistDetail(artist.id, 100)
    }

    function openToplist(item) {
        openPlaylist({ id: item.id, name: item.name, cover: item.cover,
                       description: item.description || "",
                       author: "", playCount: 0 })
    }

    function openStub(title, subtitle, icon, planned) {
        pushHistory()
        stubConfig = { title: title, subtitle: subtitle, icon: icon, planned: planned }
        pageKey = "stub"
    }

    function findPlaylist(name) {
        var all = createdPlaylists.concat(collectedPlaylists)
        for (var i = 0; i < all.length; ++i) {
            if (all[i].name === name) { openPlaylist(all[i]); return }
        }
        showToast("还没加载到这个歌单（先登录，或去「推荐」逛逛）")
    }

    function openLikedMusic() {
        if (Api.likedPlaylistId > 0) {
            openPlaylist({ id: Api.likedPlaylistId, name: "我喜欢的音乐", cover: "" })
        } else {
            findPlaylist("我喜欢的音乐")
        }
    }

    // ══════════════════════════════════════════════════
    //  播放控制
    // ══════════════════════════════════════════════════
    function playAt(list, index, source) {
        if (!list || index < 0 || index >= list.length) return
        var song = list[index]
        if (!song || !song.id) return
        playingList = list
        playingIndex = index
        playingSource = source || "list"
        pendingSongId = song.id
        Store.addRecent(song)
        lyricLines = []
        Api.loadLyric(song.id)
        Api.loadSongUrl(song.id, 320000)

        // 设置页「在后台时歌曲切换发送通知」：只在窗口不是前台时打扰用户
        if (Store.notifyOnTrackChange && !win.active)
            Notifier.notify(song.name || "", song.artist || "")
    }

    function playAll(list) {
        if (!list || list.length === 0) {
            showToast("列表是空的")
            return
        }
        playAt(list, 0)
    }

    function randomIndex(avoid) {
        if (playingList.length <= 1) return 0
        var i = avoid
        for (var n = 0; n < 12 && i === avoid; ++n)
            i = Math.floor(Math.random() * playingList.length)
        return i === avoid ? (avoid + 1) % playingList.length : i
    }

    function playNext(auto) {
        if (playingList.length === 0) return

        if (playMode === "singleloop") {
            Player.restart()
            return
        }
        if (playingSource === "fm" && playingIndex >= playingList.length - 1) {
            Api.loadPersonalFm()          // FM 播完自动续一批
            return
        }
        if (playMode === "shuffle") {
            playAt(playingList, randomIndex(playingIndex), playingSource)
            return
        }
        if (playingIndex < playingList.length - 1) {
            playAt(playingList, playingIndex + 1, playingSource)
            return
        }
        if (playMode === "loop" && playingList.length > 0)
            playAt(playingList, 0, playingSource)
        else if (auto)
            Player.stop()                  // order 模式播完停在最后一首
    }

    function playPrev() {
        if (playingList.length === 0) return
        if (playMode === "singleloop") { Player.restart(); return }
        if (playMode === "shuffle") { playAt(playingList, randomIndex(playingIndex), playingSource); return }
        if (playingIndex > 0)
            playAt(playingList, playingIndex - 1, playingSource)
        else if (playMode === "loop")
            playAt(playingList, playingList.length - 1, playingSource)
    }

    function cyclePlayMode() {
        var order = ["order", "loop", "singleloop", "shuffle"]
        var i = order.indexOf(playMode)
        var next = order[(i + 1) % order.length]
        Store.setPlayMode(next)
        showToast({ order: "顺序播放", loop: "列表循环",
                    singleloop: "单曲循环", shuffle: "随机播放" }[next])
    }

    // ══════════════════════════════════════════════════
    //  喜欢
    // ══════════════════════════════════════════════════
    function toggleLike(song) {
        if (!song || !song.id) return
        if (!Api.loggedIn) {
            showToast("登录后才能收藏")
            return
        }
        var target = !Store.isLiked(song.id)
        Store.setLiked(song.id, target)     // 先本地生效，请求失败会回滚
        Api.likeSong(song.id, target)
    }

    // ══════════════════════════════════════════════════
    //  个人主页
    // ══════════════════════════════════════════════════
    function openUser(uid) {
        if (!uid) {
            // profile 还没回来 —— 先切页面，等 onProfileChanged 再补数据
            pendingUserPage = true
            pageKey = "user"
            return
        }
        pendingUserPage = false
        pushHistory()
        userUid = uid
        userIsSelf = (uid === Api.userId)
        userProfile = null
        userCreated = []
        userCollected = []
        userRecord = []
        userLevel = 0
        pageKey = "user"
        Api.loadUserDetail(uid)
        Api.loadUserPlaylistsOf(uid)
        Api.loadUserRecord(uid, 0)
        if (userIsSelf) Api.loadUserLevel()   // 等级接口只给自己的
    }

    // ══════════════════════════════════════════════════
    //  评论
    // ══════════════════════════════════════════════════
    function openComments(song) {
        if (!song || !song.id) {
            showToast("先放一首歌再看评论")
            return
        }
        commentSong = song
        commentHot = []
        commentList = []
        commentTotal = 0
        commentOffset = 0
        commentHasMore = false
        commentLiked = ({})
        commentLoading = true
        showComments = true
        Api.loadComments(song.id, 0)
    }

    // 翻页：offset 往后推一页，结果**追加**到已有列表后面
    function loadMoreComments() {
        if (!commentSong || commentLoading || !commentHasMore)
            return
        commentLoading = true
        Api.loadComments(commentSong.id, commentOffset)
    }

    // 评论点赞。本地先翻转（请求失败会自动回滚成服务端那次的结果）
    function toggleCommentLike(c) {
        if (!c || !c.id)
            return
        var now = commentLiked[c.id] !== undefined ? commentLiked[c.id] : (c.liked === true)
        setCommentLiked(c.id, !now)
        Api.likeComment(c.threadId || "", c.id, !now)
    }

    function setCommentLiked(cid, liked) {
        var m = commentLiked
        m[cid] = liked
        commentLiked = m          // 重新赋值才会触发绑定刷新

        // 顺手把列表里那条的计数也改掉（+1 / -1），不然数字不动看着像没反应
        var bump = function (arr) {
            var out = []
            var changed = false
            for (var i = 0; i < arr.length; ++i) {
                var o = arr[i]
                if (o.id === cid) {
                    o = Object.assign({}, o)     // 别原地改数组里的对象，绑定抓不到
                    o.liked = liked
                    o.likedCount = Math.max(0, (o.likedCount || 0) + (liked ? 1 : -1))
                    changed = true
                }
                out.push(o)
            }
            return changed ? out : arr
        }
        commentHot = bump(commentHot)
        commentList = bump(commentList)
    }

    // ══════════════════════════════════════════════════
    //  Api 回调
    // ══════════════════════════════════════════════════
    Connections {
        target: Api

        function onUserPlaylistsReady(created, collected) {
            win.createdPlaylists = created
            win.collectedPlaylists = collected
        }

        function onRecommendPlaylistsReady(list) { win.recommendPlaylists = list }
        function onRecommendSongsReady(list)     { win.recommendSongs = list }
        function onDailySongsReady(list)         { win.dailySongs = list }

        function onPlaylistDetailReady(detail) {
            win.pageLoading = false
            win.currentPlaylist = detail
            win.pageKey = "playlist"
        }

        function onAlbumDetailReady(album) {
            win.pageLoading = false
            win.currentAlbum = album
            win.pageKey = "album"
        }

        function onArtistDetailReady(artist, hotSongs, albums) {
            // 这个信号发两次：先给歌手信息（songs 为空），再给歌曲+专辑
            if (artist && artist.id)
                win.artistData = artist
            if (hotSongs && hotSongs.length > 0) {
                win.artistSongs = hotSongs
                win.pageLoading = false
            }
            if (albums && albums.length > 0)
                win.artistAlbums = albums
        }

        function onToplistsReady(blocks) {
            win.pageLoading = false
            win.toplists = blocks
        }

        function onTopPlaylistsReady(list) {
            win.pageLoading = false
            win.featuredPlaylists = list
        }

        function onSubscribedRadiosReady(list) {
            win.pageLoading = false
            win.podcastRadios = list
        }

        function onPersonalFmReady(songs) {
            win.pageLoading = false
            if (!songs || songs.length === 0) {
                win.showToast("私人 FM 没取到歌（可能需要登录）")
                return
            }
            win.fmSongs = songs
            // 正在放 FM / 第一次进 FM 页 → 直接续上
            if (win.playingSource === "fm" || win.playingList.length === 0
                    || win.pageKey === "fm")
                win.playAt(songs, 0, "fm")
        }

        function onRadioDetailReady(radio, programs) {
            if (programs && programs.length > 0)
                win.playAll(programs)
        }

        function onCommentsReady(songId, hot, normal, total) {
            if (!win.commentSong || win.commentSong.id !== songId) return
            win.commentLoading = false
            // 首页：整页替换。翻页：只把新的一页追加到普通评论后面（热评不变）
            if (win.commentOffset === 0) {
                win.commentHot = hot
                win.commentList = normal
            } else {
                win.commentList = win.commentList.concat(normal)
            }
            win.commentOffset += normal.length
            win.commentTotal = total
            win.commentHasMore = win.commentList.length < total
        }

        function onCommentLikeChanged(cid, liked) {
            win.setCommentLiked(cid, liked)
        }

        // ── 个人主页 ────────────────────────────────
        function onUserDetailReady(user)       { win.userProfile = user }
        function onUserPublicPlaylistsReady(created, collected) {
            win.userCreated = created
            win.userCollected = collected
        }
        function onUserRecordReady(songs)      { win.userRecord = songs }
        function onUserLevelReady(level)       { win.userLevel = level ? (level.level || 0) : 0 }

        function onLikeChanged(id, liked) { Store.setLiked(id, liked) }
        // 服务端那份是权威的，整体替换本地集合（用并集会让换号后残留上一个账号的红心）
        function onLikelistReady(ids)     { Store.setLikedIds(ids) }

        // ── 账号切换 ────────────────────────────────
        // profile 一变就说明新账号的数据到了。登录层不能只靠「Api.loggedIn 是不是 true」
        // 判断成功 —— 换号时旧 profile 会短暂保持真，导致登录层立刻关闭并显示旧昵称。
        function onProfileChanged() {
            if (win.showLogin && win.loginMessage === "验证中…" && Api.loggedIn) {
                win.showLogin = false
                win.loginMessage = ""
                win.showToast("已登录：" + Api.nickname)
            }
            // 启动时 profile 还在路上（userId 仍是 0）就要求打开个人主页 —— 等它到了再补请求
            if (win.pendingUserPage && Api.userId > 0) {
                win.pendingUserPage = false
                win.openUser(Api.userId)
            }
        }
        function onLoggedInChanged() {
            if (!Api.loggedIn) {
                // 退出登录：把上一账号的派生数据全部清掉，别让侧栏继续挂着别人的歌单
                win.createdPlaylists = []
                win.collectedPlaylists = []
                win.currentPlaylist = null
                win.currentAlbum = null
                Store.clearLiked()
            }
        }

        function onSearchReady(songs, total) {
            win.searchSongs = songs
            win.searchTotal = total
            win.searchLoading = false
            win.pageKey = "search"
        }

        function onSearchAllReady(keyword, result) {
            if (keyword !== win.searchKeyword) return
            win.searchSongs = result.songs || []
            win.searchArtists = result.artists || []
            win.searchAlbums = result.albums || []
            win.searchPlaylists = result.playlists || []
            win.searchTotal = result.songCount || 0
            win.searchLoading = false
            win.pageKey = "search"
        }

        function onLyricReady(id, lines) {
            if (!win.currentSong || win.currentSong.id !== id) return
            win.lyricLines = lines
        }

        function onSongUrlReady(id, url, br) {
            // 只接受当前待播那首，避免快速连点导致错播
            if (id !== win.pendingSongId) return
            if (url === "") {
                win.showToast("拿不到播放地址：可能是 VIP / 付费歌曲，或 cookie 已失效")
                return
            }
            Player.playUrl(url)
            if (win.resumePending)
                resumeSeekTimer.restart()
        }

        function onAccountFailed() {
            if (win.showLogin) {
                win.loginFailed = true
                win.loginMessage = Api.lastError
            }
        }

        function onLastErrorChanged() {
            if (win.toast === "" && Api.lastError !== "")
                win.showToast(Api.lastError)
        }
    }

    // ══════════════════════════════════════════════════
    //  启动
    // ══════════════════════════════════════════════════
    // 离屏验证用：--page <key> 直接落到某一页（并触发它需要的数据）
    // 也支持 --page playlist:<id> / album:<id> / artist:<id> 指定具体资源，
    // 用来验证「超大歌单」这类只在特定数据下才暴露的问题。
    function applyStartPage(key) {
        const ci = key.indexOf(":")
        if (ci > 0) {
            const kind = key.slice(0, ci)
            const rid  = Number(key.slice(ci + 1))
            if (kind === "playlist" && rid > 0) { pageKey = "playlist"; Api.loadPlaylistDetail(rid); return }
            if (kind === "album"    && rid > 0) { pageKey = "album";    Api.loadAlbumDetail(rid);    return }
            if (kind === "artist"   && rid > 0) { pageKey = "artist";   Api.loadArtistDetail(rid, 100); return }
        }
        switch (key) {
        case "playlist": Api.loadPlaylistDetail(3778678);                  break
        case "album":    { pageKey = "album";    Api.loadAlbumDetail(32311) }  break
        case "artist":   { pageKey = "artist";   Api.loadArtistDetail(6452, 100) } break
        case "toplist":  { pageKey = "toplist";  Api.loadToplists() }       break
        case "featured": { pageKey = "featured"; Api.loadTopPlaylists("全部") } break
        case "podcast":  { pageKey = "podcast";  Api.loadSubscribedRadios() }  break
        case "fm":       { pageKey = "fm";       Api.loadPersonalFm() }     break
        case "recent":   { pageKey = "recent" }                            break
        case "settings": { pageKey = "settings" }                          break
        case "user": openUser(Api.userId); break
        // 调试用：直接展开「正在播放」页（它平时只能靠点播放栏封面打开）
        case "nowplaying": { pageKey = "home"; showNowPlaying = true } break
        case "search":   {
            pageKey = "search"
            searchKeyword = "yoasobi"
            searchLoading = true
            Api.searchAll("yoasobi", 30)
            break
        }
        }
    }

    Component.onCompleted: {
        Api.loadRecommendPlaylists(12)
        Api.loadRecommendSongs()
        Api.loadDailyRecommendSongs(20)   // 首页「根据你的口味生成」那块
        if (TNCPageDelay <= 0)
            applyStartPage(TNCStartPage)
    }

    // 调试用：--page-delay <ms> —— 先停在首页，延迟之后再切到 TNCStartPage。
    // 为什么需要它：--page 是在首帧**之前**就把 pageKey 定好，页面从头到尾都是可见的；
    // 而真实交互里是「先隐藏 → 后来才可见 + 数据后到」，这正是本工程列表/布局出问题的场景。
    // 两者行为不一样，所以复现问题必须走这条延迟路径。
    Timer {
        interval: Math.max(1, TNCPageDelay)
        running: TNCPageDelay > 0
        onTriggered: applyStartPage(TNCStartPage)
    }

    // ══════════════════════════════════════════════════
    //  设置项接线
    // ══════════════════════════════════════════════════
    // 淡入淡出开关直接打到播放器上
    Binding { target: Player; property: "fadeEnabled"; value: Store.fadeInOut }

    // 「记住上次播放进度」：启动后把上次那首放回播放位置。
    // 延迟一点是为了避开启动时的接口风暴（loadAccount / 推荐列表都在抢连接）。
    property bool resumePending: false
    property int  resumePosition: 0

    Timer {
        id: resumeTimer
        interval: 1500
        running: true
        onTriggered: {
            if (!Store.resumeLastProgress) return
            var lp = Store.lastPlayed
            if (!lp || !lp.id) return
            win.resumePending = true
            win.resumePosition = lp.position || 0
            win.playAt([lp], 0, "resume")
            if (win.resumePosition <= 0 && !Store.autoplayOnStart)
                win.resumePending = true     // 仍然要 pause 住，不自动播
        }
    }

    // 媒体加载完再 seek（setMedia 之后立刻 seek 会被丢掉）
    Timer {
        id: resumeSeekTimer
        interval: 600
        onTriggered: {
            if (win.resumePosition > 0)
                Player.seek(win.resumePosition)
            if (!Store.autoplayOnStart)
                Player.pause()
            win.resumePending = false
        }
    }

    // 播放中定期落一次进度，异常退出也不至于丢太多
    Timer {
        interval: 10000
        repeat: true
        running: Player.stateName === "playing"
        onTriggered: {
            if (Store.resumeLastProgress && win.currentSong)
                Store.saveLastPlayed(win.currentSong, Player.position)
        }
    }

    onClosing: {
        if (Store.resumeLastProgress && win.currentSong)
            Store.saveLastPlayed(win.currentSong, Player.position)
    }

    // ── 页面背景 ────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: Theme.pageBackground
    }

    // ══════════════════════════════════════════════════
    //  沉浸式背景
    // ══════════════════════════════════════════════════
    // 官方歌单/专辑页会用封面主色给整个窗口铺一层极淡的底色：
    //     linear-gradient(<主色 alpha .1> 0%, transparent 480px)
    // 主色从封面缩略图里取（见 widgets/CoverTint.qml）。
    property color coverTint: "transparent"
    readonly property string tintCoverSource: {
        if (pageKey === "playlist" && currentPlaylist) return currentPlaylist.cover || ""
        if (pageKey === "album" && currentAlbum)       return currentAlbum.cover || ""
        return ""
    }
    onTintCoverSourceChanged: if (tintCoverSource === "") coverTint = "transparent"

    CoverTint {
        id: tintProbe
        source: win.tintCoverSource
        onColorReady: function (c) { win.coverTint = c }
    }

    // ⚠️ 必须声明在「页面背景」那个 Rectangle **之后** ——
    // Qt Quick 同 z 按声明顺序叠放，写在前面会被不透明的页面底色整个盖掉。
    Rectangle {
        // 只铺上面 480px：官方渐变的可见部分就到 480，下面全透明。
        // 写成 anchors.fill 的话软件后端要缓存整窗一层（1280×800×4 ≈ 4MB），白占内存。
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: Math.min(win.height, 480)
        visible: win.coverTint.a > 0
        gradient: Gradient {
            GradientStop {
                position: 0.0
                color: Qt.rgba(win.coverTint.r, win.coverTint.g, win.coverTint.b, 0.10)
            }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }


    // ── 左侧栏 ──────────────────────────────────────
    SideBar {
        id: sidebar
        width: Metrics.sidebarWidth
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: playBar.top

        createdPlaylists: win.createdPlaylists
        collectedPlaylists: win.collectedPlaylists
        currentIndex: win.navIndexForPage

        onNavActivated: function (index, text) {
            switch (index) {
            case 0: win.pushHistory(); win.pageKey = "home"; break
            case 1:
                win.pushHistory()
                win.pageKey = "featured"
                win.pageLoading = true
                Api.loadTopPlaylists(win.featuredCategory)
                break
            case 2:
                win.pushHistory()
                win.pageKey = "podcast"
                win.pageLoading = true
                if (Api.loggedIn) Api.loadSubscribedRadios()
                break
            case 3:
                win.pushHistory()
                win.pageKey = "fm"
                if (win.fmSongs.length === 0) {
                    win.pageLoading = true
                    Api.loadPersonalFm()
                }
                break
            case 4:
                win.openStub("关注", "动态 / 关注的人", "sidebar_community",
                             ["关注动态流（/api/event/forward）",
                              "好友听歌动态",
                              "私信与通知（/api/msg/private/history）"])
                break
            case 5: win.openLikedMusic(); break
            case 6: win.pushHistory(); win.pageKey = "recent"; break
            case 7:
                win.pushHistory()
                win.pageKey = "podcast"
                win.pageLoading = true
                if (Api.loggedIn) Api.loadSubscribedRadios()
                break
            case 8: win.findPlaylist("我的收藏"); break
            }
        }

        onPlaylistActivated: function (pl) { win.openPlaylist(pl) }
    }

    // ── 右侧区域 ────────────────────────────────────
    Item {
        id: rightArea
        anchors.left: sidebar.right
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: playBar.top

        TopBar {
            id: topBar
            width: parent.width
            anchors.top: parent.top
            canGoBack: win.pageKey !== "home"
            userName: Api.loggedIn ? Api.nickname : "未登录"
            avatar: Api.avatarUrl
            vipLevel: Api.vipType
            maximized: win.visibility === Window.Maximized

            onBackClicked: win.goBack()
            onUserClicked: {
                if (!Api.loggedIn) { win.showLogin = true; win.loginMessage = ""; win.loginFailed = false }
                else win.openUser(Api.userId)
            }
            onSearchAccepted: function (t) {
                if (t.trim() === "") return
                win.pushHistory()
                win.searchKeyword = t
                win.searchLoading = true
                win.searchSongs = []
                win.searchArtists = []
                win.searchAlbums = []
                win.searchPlaylists = []
                win.searchTotal = 0
                win.pageKey = "search"
                Api.searchAll(t, 30)
            }
            onMinimizeClicked: win.showMinimized()
            onMaximizeClicked: {
                if (win.visibility === Window.Maximized) win.showNormal();
                else win.showMaximized();
            }
            onCloseClicked: win.close()
            onSettingClicked: {
                win.pushHistory()
                win.pageKey = "settings"
            }
            onMessageClicked: win.showToast("消息中心还没做")
        }

        PageHost {
            id: pageHost
            anchors.top: topBar.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom

            pageKey: win.pageKey
            playlistData: win.pageKey === "album" ? win.currentAlbum : win.currentPlaylist
            artistData: win.artistData
            artistSongs: win.artistSongs
            artistAlbums: win.artistAlbums
            toplists: win.toplists
            featuredPlaylists: win.featuredPlaylists
            featuredCategory: win.featuredCategory
            podcastRadios: win.podcastRadios
            fmSongs: win.fmSongs
            fmCurrent: win.currentSong
                       ? win.currentSong
                       : (win.fmSongs.length > 0 ? win.fmSongs[0] : null)
            recentSongs: Store.recentSongs
            recommendPlaylists: win.recommendPlaylists
            recommendSongs: win.recommendSongs
            dailySongs: win.dailySongs

            userProfile: win.userProfile
            userCreated: win.userCreated
            userCollected: win.userCollected
            userRecord: win.userRecord
            userLevel: win.userLevel
            userIsSelf: win.userIsSelf
            playingSongId: win.playingSongId
            playing: Player.stateName === "playing"
            loggedIn: Api.loggedIn
            loading: win.pageLoading
            stubConfig: win.stubConfig

            accountName: Api.nickname
            accountAvatar: Api.avatarUrl
            accountId: Api.userId > 0 ? String(Api.userId) : ""
            accountVip: Api.vipType
            onLogoutRequested: {
                Api.logout()
                win.createdPlaylists = []
                win.collectedPlaylists = []
                win.pageKey = "home"
                win.showToast("已退出登录")
            }

            searchKeyword: win.searchKeyword
            searchSongs: win.searchSongs
            searchArtists: win.searchArtists
            searchAlbums: win.searchAlbums
            searchPlaylists: win.searchPlaylists
            searchTotal: win.searchTotal
            searchLoading: win.searchLoading

            onPlayRequested: function (songs, index) { win.playAt(songs, index) }
            onPlayAllRequested: function (songs) { win.playAll(songs) }
            onLikeToggled: function (song) { win.toggleLike(song) }
            onPlaylistClicked: function (pl) { win.openPlaylist(pl) }
            onAlbumClicked: function (a) { win.openAlbum(a) }
            onArtistClicked: function (a) { win.openArtist(a) }
            onToplistClicked: function (item) { win.openToplist(item) }
            onRadioClicked: function (r) { Api.loadRadioDetail(r.id) }
            onCommentsRequested: function (song) { win.openComments(song) }
            onLoginRequested: { win.showLogin = true; win.loginMessage = ""; win.loginFailed = false }
            onRecentClearRequested: { Store.clearRecent(); win.showToast("已清空播放记录") }
            onMorePlaylistsRequested: {
                win.pushHistory()
                win.pageKey = "featured"
                win.pageLoading = true
                Api.loadTopPlaylists(win.featuredCategory)
            }
            onCategoryChanged: function (cat) {
                win.featuredCategory = cat
                win.pageLoading = true
                Api.loadTopPlaylists(cat)
            }
            onFmNextBatchRequested: {
                win.pageLoading = true
                Api.loadPersonalFm()
            }
            onFmDislikeRequested: function (song) {
                Store.setLiked(song.id, false)
                Api.loadPersonalFm()
            }
            onFmLikeRequested: function (song) { win.toggleLike(song) }
        }
    }

    // ── 播放栏 ──────────────────────────────────────
    PlayBar {
        id: playBar
        width: parent.width
        anchors.bottom: parent.bottom

        playing: Player.stateName === "playing"
        loading: Player.stateName === "loading"
        title: win.currentSong ? win.currentSong.name : ""
        artist: win.currentSong ? win.currentSong.artist : ""
        cover: win.currentSong ? win.currentSong.cover : ""
        quality: win.currentSong ? (win.currentSong.quality || "") : ""
        positionMs: Player.position
        durationMs: Player.duration
        volume: Player.volume
        playMode: win.playMode
        lyricVisible: win.showLyric
        liked: {
            if (!win.currentSong) return false
            Store.likeRevision            // 绑定依赖：喜欢集合变化时重算
            return Store.isLiked(win.currentSong.id) || win.currentSong.liked === true
        }

        onPlayPauseClicked: Player.togglePause()
        onPrevClicked: win.playPrev()
        onNextClicked: win.playNext(false)
        onModeClicked: win.cyclePlayMode()
        onVolumeEdited: function (v) { Player.setVolume(v); Store.setVolume(v) }
        onSeekRequested: function (ms) { Player.seek(ms) }
        onLikeToggled: win.toggleLike(win.currentSong)
        onPlaylistClicked: win.showQueue = !win.showQueue
        onLyricClicked: win.showLyric = !win.showLyric
        onCoverClicked: win.showNowPlaying = !win.showNowPlaying
    }

    Connections {
        target: Player
        function onMediaFinished() { win.playNext(true) }
        function onErrorTextChanged() {
            if (Player.errorText !== "") win.showToast(Player.errorText)
        }
    }

    // ══════════════════════════════════════════════════
    //  覆盖层 / 侧栏
    // ══════════════════════════════════════════════════

    // ──────────────────────────────────────────────────
    //  四个覆盖层改成 Loader 延迟创建
    //
    //  为什么：这四个面板（尤其歌词页和评论区）各自带 ListView 和一堆绑定，
    //  常驻着实测要 ~7MB，而绝大多数会话里根本不会打开。
    //  active 用**闩锁**语义（打开过一次就常驻不销毁），这样：
    //    * 关闭时还有退场动画（不会被直接销毁）
    //    * 面板内部状态（歌词滚动位置等）在开关之间保留
    //  只有「从没打开过」才真正省下那部分内存。
    //  入场动画：组件创建那一刻 open 已经是 true，动画会被跳过，
    //  所以内部先用 armed 顶一帧，下一轮事件循环再放开。
    // ──────────────────────────────────────────────────
    property bool lyricLoaded: false
    property bool queueLoaded: false
    property bool commentsLoaded: false
    property bool loginLoaded: false
    property bool nowPlayingLoaded: false
    onShowLyricChanged:    if (showLyric)    lyricLoaded = true
    onShowQueueChanged:    if (showQueue)    queueLoaded = true
    onShowCommentsChanged: if (showComments) commentsLoaded = true
    onShowLoginChanged:    if (showLogin)    loginLoaded = true
    onShowNowPlayingChanged: if (showNowPlaying) nowPlayingLoaded = true

    // 歌词页（盖住内容区，保留侧栏与播放栏）
    Loader {
        active: win.lyricLoaded
        anchors.left: sidebar.right
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: playBar.top
        // 打开时抬到顶栏之上，避免顶栏盖住它
        z: win.showLyric ? 5 : -1
        sourceComponent: Component {
            LyricPanel {
                property bool armed: false
                open: armed && win.showLyric
                lines: win.lyricLines
                positionMs: Player.position
                cover: win.currentSong ? win.currentSong.cover : ""
                title: win.currentSong ? win.currentSong.name : ""
                artist: win.currentSong ? win.currentSong.artist : ""
                onCloseRequested: win.showLyric = false
                onSeekRequested: function (ms) { Player.seek(ms) }
                Component.onCompleted: Qt.callLater(function () { armed = true })
            }
        }
    }

    // 播放详情（点播放栏封面打开）。盖住侧栏和顶栏，但保留底部播放栏。
    Loader {
        active: win.nowPlayingLoaded
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: playBar.top
        z: win.showNowPlaying ? 6 : -1
        sourceComponent: Component {
            NowPlayingPanel {
                property bool armed: false
                open: armed && win.showNowPlaying
                lines: win.lyricLines
                positionMs: Player.position
                cover: win.currentSong ? win.currentSong.cover : ""
                title: win.currentSong ? win.currentSong.name : ""
                artist: win.currentSong ? win.currentSong.artist : ""
                album: win.currentSong ? (win.currentSong.album || "") : ""
                playing: Player.stateName === "playing"
                commentCount: win.commentTotal
                onCloseRequested: win.showNowPlaying = false
                onCommentsRequested: {
                    if (win.currentSong) win.openComments(win.currentSong)
                }
                onSeekRequested: function (ms) { Player.seek(ms) }
                Component.onCompleted: Qt.callLater(function () { armed = true })
            }
        }
    }

    // 播放队列
    Loader {
        active: win.queueLoaded
        anchors.fill: parent
        sourceComponent: Component {
            PlayQueuePanel {
                property bool armed: false
                open: armed && win.showQueue
                songs: win.playingList
                currentIndex: win.playingIndex
                playing: Player.stateName === "playing"
                onCloseRequested: win.showQueue = false
                onSongClicked: function (i) { win.playAt(win.playingList, i, win.playingSource) }
                onClearRequested: {
                    win.playingList = []
                    win.playingIndex = -1
                    Player.stop()
                }
                Component.onCompleted: Qt.callLater(function () { armed = true })
            }
        }
    }

    // 评论区
    Loader {
        active: win.commentsLoaded
        anchors.fill: parent
        sourceComponent: Component {
            CommentsPanel {
                property bool armed: false
                open: armed && win.showComments
                hotComments: win.commentHot
                comments: win.commentList
                total: win.commentTotal
                loading: win.commentLoading
                hasMore: win.commentHasMore
                likedMap: win.commentLiked
                songName: win.commentSong ? win.commentSong.name : ""
                onCloseRequested: win.showComments = false
                onLikeRequested: function (c) { win.toggleCommentLike(c) }
                onLoadMoreRequested: win.loadMoreComments()
                Component.onCompleted: Qt.callLater(function () { armed = true })
            }
        }
    }

    // 登录层
    Loader {
        active: win.loginLoaded
        anchors.fill: parent
        sourceComponent: Component {
            LoginOverlay {
                visible: win.showLogin
                busy: win.loginMessage === "验证中…"
                message: win.loginMessage
                failed: win.loginFailed

                onSubmitted: function (musicU) {
                    win.loginFailed = false
                    win.loginMessage = "验证中…"
                    Api.setMusicU(musicU)
                    loginProbe.restart()
                }
                onCancelled: win.showLogin = false
            }
        }
    }

    // setMusicU 会立刻清空旧 profile 再发 loadAccount，
    // 所以「登录成功」靠 onProfileChanged 判定（见上面的 Connections），
    // 这个定时器只当超时兜底 —— 太短会把还在路上的请求误判成失败。
    Timer {
        id: loginProbe
        interval: 10000
        onTriggered: {
            if (Api.loggedIn) {
                win.showLogin = false
                win.loginMessage = ""
                win.showToast("已登录：" + Api.nickname)
            } else if (win.loginMessage === "验证中…") {
                win.loginFailed = true
                win.loginMessage = "验证失败：MUSIC_U 无效或已过期"
            }
        }
    }

    // ── 轻提示 ──────────────────────────────────────
    Item {
        visible: win.toast !== ""
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: playBar.top
        anchors.bottomMargin: 16
        width: toastText.width + 32
        height: 36
        z: 10

        RoundRect {
            anchors.fill: parent
            radius: 8
            color: Qt.rgba(0, 0, 0, 0.78)
        }
        Text {
            id: toastText
            anchors.centerIn: parent
            text: win.toast
            font.pixelSize: Metrics.fontSmall
            color: Theme.colorWhite1
        }
    }

    // ── 窗口拖拽 / 缩放（Qt 5.15 原生 startSystemMove / startSystemResize） ──
    MouseArea {
        anchors.left: sidebar.right
        anchors.right: parent.right
        anchors.top: parent.top
        height: Metrics.topBarHeight
        anchors.rightMargin: 320
        cursorShape: Qt.SizeAllCursor
        onPressed: win.startSystemMove()
        z: -2
    }

    Repeater {
        model: [
            { e: Qt.LeftEdge  | Qt.TopEdge,    ax: 0.0, ay: 0.0 },
            { e: Qt.RightEdge | Qt.TopEdge,    ax: 1.0, ay: 0.0 },
            { e: Qt.LeftEdge  | Qt.BottomEdge, ax: 0.0, ay: 1.0 },
            { e: Qt.RightEdge | Qt.BottomEdge, ax: 1.0, ay: 1.0 }
        ]
        delegate: MouseArea {
            required property var modelData
            width: Metrics.resizeHandle
            height: Metrics.resizeHandle
            x: modelData.ax * (win.width  - width)
            y: modelData.ay * (win.height - height)
            cursorShape: (modelData.ax === modelData.ay) ? Qt.SizeFDiagCursor : Qt.SizeBDiagCursor
            z: 20
            onPressed: win.startSystemResize(modelData.e)
        }
    }
}
