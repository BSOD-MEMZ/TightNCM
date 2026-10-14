// NcmApi —— 网易云接口客户端
//
// ⚠️ 关键结论（已实测，见 research/api-endpoints.txt）：
// 新版 web 播放器用的是**明文 `/api/` 端点 + Cookie 鉴权**，不做加密。
// 依据：bundle 里 web 版的 native 加密垫片是直通的 ——
//     vendors~app.js:  serialData(e){ return e }              // 原样返回
//                      deSerialData(e){ return e }
//                      encryptId(e){ return e }
// 而加密请求还要求 clientSign（浏览器拿不到），会直接跳过加密分支。
// 所以**不需要实现 weapi 的 AES+RSA，也不需要 eapi 的 AES-ECB**。
//
// 端点基址：
//   https://interface.music.163.com   绝大部分 /api/
//   https://music.163.com             私人 FM（/api/v1/radio/get）**只在主站**（interface 上 404）
// 鉴权：Cookie: MUSIC_U=xxx
// 依赖：Qt5Network + OpenSSL 1.1.1（assets/runtime/ 下那两个 DLL，缺了 supportsSsl 会是 0）
#pragma once

#include <QObject>
#include <QNetworkAccessManager>
#include <QVariantMap>
#include <QVariantList>
#include <QSharedPointer>

class QNetworkReply;

struct PlaylistFetch;   // 拉取歌单时的分批累积状态（定义在 NcmApi.cpp）

class NcmApi : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool    loggedIn  READ loggedIn  NOTIFY loggedInChanged)
    Q_PROPERTY(QString nickname  READ nickname  NOTIFY profileChanged)
    Q_PROPERTY(QString avatarUrl READ avatarUrl NOTIFY profileChanged)
    Q_PROPERTY(qint64  userId    READ userId    NOTIFY profileChanged)
    Q_PROPERTY(int     vipType   READ vipType   NOTIFY profileChanged)
    Q_PROPERTY(qint64  likedPlaylistId READ likedPlaylistId NOTIFY profileChanged)
    Q_PROPERTY(QString lastError READ lastError NOTIFY lastErrorChanged)

public:
    explicit NcmApi(QObject *parent = nullptr);

    bool    loggedIn()  const { return !m_profile.isEmpty(); }
    QString nickname()  const { return m_profile.value(QStringLiteral("nickname")).toString(); }
    QString avatarUrl() const { return m_profile.value(QStringLiteral("avatarUrl")).toString(); }
    qint64  userId()    const { return m_profile.value(QStringLiteral("userId")).toLongLong(); }
    int     vipType()   const { return m_profile.value(QStringLiteral("vipType")).toInt(); }
    // 「我喜欢的音乐」是官方给每个用户预置的特殊歌单（创建列表第一个），id 从登录态里拿
    qint64  likedPlaylistId() const { return m_likedPlaylistId; }
    QString lastError() const { return m_lastError; }

    // ── 会话 ──────────────────────────────────────────
    Q_INVOKABLE void    setMusicU(const QString &value);   // 手工注入 MUSIC_U
    Q_INVOKABLE QString musicU() const { return m_musicU; }
    Q_INVOKABLE void    loadAccount();                     // 校验登录态
    Q_INVOKABLE void    logout();

    // ── 歌单 ──────────────────────────────────────────
    Q_INVOKABLE void loadUserPlaylists();                  // 我的歌单
    Q_INVOKABLE void loadPlaylistDetail(qint64 id);
    Q_INVOKABLE void loadRecommendPlaylists(int limit = 12);
    Q_INVOKABLE void loadRecommendSongs();                 // 新歌速递 /api/personalized/newsong
    // ★「跟随兴趣」的每日推荐：/api/v1/discovery/recommend/songs
    // 和 personalized/newsong（全网新歌、**不**个性化）不是一回事 —— 首页要的是这个。
    Q_INVOKABLE void loadDailyRecommendSongs(int limit = 20);
    Q_INVOKABLE void loadTopPlaylists(const QString &cat = QStringLiteral("全部"),
                                      int limit = 30);     // 歌单广场 /api/playlist/list/get

    // ── 榜单 ──────────────────────────────────────────
    Q_INVOKABLE void loadToplists();                       // /api/toplist/detail/v2

    // ── 个人主页（自己 / 别人） ───────────────────────
    // 这几个都是「按 uid 取」，所以既能做自己的主页也能做别人（歌手、评论点进去）的主页。
    Q_INVOKABLE void loadUserDetail(qint64 uid);            // /api/v1/user/detail/<uid>
    Q_INVOKABLE void loadUserPlaylistsOf(qint64 uid, int limit = 30);  // /api/user/playlist?uid=
    Q_INVOKABLE void loadUserRecord(qint64 uid, int type = 0);         // 听歌排行 0=所有 1=周
    Q_INVOKABLE void loadUserLevel();                       // /api/user/level（自己的等级）

    // ── 歌手 / 专辑 ───────────────────────────────────
    // 注意：/api/v1/artist/songs 的 order 参数是**必需**的，不带会返回 400 参数错误
    Q_INVOKABLE void loadArtistDetail(qint64 id, int songLimit = 50);
    Q_INVOKABLE void loadAlbumDetail(qint64 id);

    // ── 私人 FM ───────────────────────────────────────
    Q_INVOKABLE void loadPersonalFm(int count = 3);

    // ── 播客 / 电台 ───────────────────────────────────
    Q_INVOKABLE void loadSubscribedRadios(int limit = 60);
    Q_INVOKABLE void loadRadioDetail(qint64 id, int limit = 60);

    // ── 评论 ──────────────────────────────────────────
    Q_INVOKABLE void loadComments(qint64 songId, int offset = 0, int limit = 20);
    // 评论点赞。threadId 形如 R_SO_4_<歌曲id>（在评论 JSON 里带回来），
    // t=1 点赞 / t=0 取消。别把歌曲 id 当 threadId 传，服务端会回 400 参数错误。
    Q_INVOKABLE void likeComment(const QString &threadId, qint64 cid, bool like);

    // ── 喜欢 ──────────────────────────────────────────
    Q_INVOKABLE void likeSong(qint64 id, bool like);
    Q_INVOKABLE void loadLikelist();                       // 同步服务端的「喜欢」集合

    // ── 搜索 ──────────────────────────────────────────
    // type: 1 单曲 / 100 歌手 / 10 专辑 / 1000 歌单 / 1004 MV
    Q_INVOKABLE void search(const QString &keyword, int type = 1, int limit = 30, int offset = 0);
    // 一次把 单曲/歌手/专辑/歌单 都搜出来（搜索页要分 tab）
    Q_INVOKABLE void searchAll(const QString &keyword, int limitEach = 30);

    // ── 播放地址 / 歌词 ───────────────────────────────
    Q_INVOKABLE void loadSongUrl(qint64 id, int maxBr = 320000);
    Q_INVOKABLE void loadLyric(qint64 id);

    // ── 无状态工具（QML 也用得上） ────────────────────
    // 注意：不能写成 static —— QML 无法通过实例调用静态 Q_INVOKABLE
    Q_INVOKABLE QString fmtCount(qint64 n) const;          // 128000 → 12.8万

signals:
    void loggedInChanged();
    void profileChanged();
    void lastErrorChanged();

    void userPlaylistsReady(const QVariantList &created, const QVariantList &collected);
    void playlistDetailReady(const QVariantMap &detail);
    void recommendPlaylistsReady(const QVariantList &list);
    void recommendSongsReady(const QVariantList &list);
    void dailySongsReady(const QVariantList &list);
    void userDetailReady(const QVariantMap &user);
    void userPublicPlaylistsReady(const QVariantList &created, const QVariantList &collected);
    void userRecordReady(const QVariantList &songs);
    void userLevelReady(const QVariantMap &level);
    void topPlaylistsReady(const QVariantList &list);

    void toplistsReady(const QVariantList &blocks);        // [{name, code, list:[...]}]
    void artistDetailReady(const QVariantMap &artist, const QVariantList &hotSongs,
                           const QVariantList &albums);
    void albumDetailReady(const QVariantMap &album);
    void personalFmReady(const QVariantList &songs);

    void subscribedRadiosReady(const QVariantList &list);
    void radioDetailReady(const QVariantMap &radio, const QVariantList &programs);

    void commentsReady(qint64 songId, const QVariantList &hot,
                       const QVariantList &normal, int total);
    void commentLikeChanged(qint64 cid, bool liked);

    void likeChanged(qint64 id, bool liked);
    void likelistReady(const QVariantList &ids);

    void searchReady(const QVariantList &songs, int total);
    void searchAllReady(const QString &keyword, const QVariantMap &result);

    void songUrlReady(qint64 id, const QString &url, int br);
    void lyricReady(qint64 id, const QVariantList &lines);  // [{t:ms, text, tr}]
    void accountFailed();

private:
    QNetworkReply *get(const QString &path, const QVariantMap &params = {},
                       const QString &base = QString());
    QNetworkReply *post(const QString &path, const QVariantMap &params = {},
                        const QString &base = QString());
    void           applyHeaders(QNetworkRequest &req) const;
    void           publishPlaylist(const QSharedPointer<PlaylistFetch> &st);
    void           fail(const QString &what, const QString &msg);
    void           setProfile(const QVariantMap &p);

    // 把各种形状的歌曲 JSON 归一化
    static QVariantMap normalizeSong(const QVariantMap &raw);
    static QVariantMap normalizePlaylist(const QVariantMap &raw);

    QNetworkAccessManager m_nam;
    QString    m_musicU;
    QString    m_deviceId;
    QVariantMap m_profile;
    qint64     m_likedPlaylistId = 0;
    QString    m_lastError;
};
