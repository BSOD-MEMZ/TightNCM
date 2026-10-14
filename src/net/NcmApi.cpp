#include "NcmApi.h"

#include <QNetworkRequest>
#include <QNetworkReply>
#include <QUrlQuery>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QSettings>
#include <QRandomGenerator>
#include <QDateTime>
#include <QRegularExpression>
#include <QSharedPointer>
#include <QSet>
#include <algorithm>

namespace {
const QString kBase      = QStringLiteral("https://interface.music.163.com");
// 私人 FM（/api/v1/radio/get）只在主站有，interface 上返回 404
const QString kBaseMusic = QStringLiteral("https://music.163.com");
const QString kUserAg = QStringLiteral(
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36");

// 音质档位 → 官方图标名（assets/icons-svg/ncm_<name>.svg）
QString qualityFromLevel(const QString &level)
{
    if (level == QLatin1String("hires") || level == QLatin1String("jymaster"))
        return QStringLiteral("hires");
    if (level == QLatin1String("lossless"))
        return QStringLiteral("sq");
    if (level == QLatin1String("exhigh") || level == QLatin1String("higher"))
        return QStringLiteral("hq");
    return QString();
}

// JSON 数组参数：把 [1,2,3] 序列化成 "[1,2,3]"
QString jsonIds(const QList<qint64> &ids)
{
    QStringList parts;
    for (qint64 id : ids)
        parts << QString::number(id);
    return QLatin1Char('[') + parts.join(QLatin1Char(',')) + QLatin1Char(']');
}

// privileges[] → { 歌曲 id : 音质图标名 }
QHash<qint64, QString> qualityFromPrivileges(const QJsonArray &arr)
{
    QHash<qint64, QString> out;
    for (const QJsonValue &v : arr) {
        const QJsonObject p = v.toObject();
        out.insert(p.value(QStringLiteral("id")).toVariant().toLongLong(),
                   qualityFromLevel(p.value(QStringLiteral("maxBrLevel")).toString()));
    }
    return out;
}

}   // namespace

// 「正在拉一个歌单」的中间状态。分批补全歌曲时要跨多个请求累积，所以用共享对象。
struct PlaylistFetch {
    QVariantMap detail;
    QList<qint64> ids;                 // trackIds 的原始顺序（完整曲目表）
    QHash<qint64, QVariantMap> byId;   // 已经拿到的歌曲
    QHash<qint64, QString> quality;    // 音质徽章
    int pending = 0;                   // 还没回来的补全请求数
};

namespace {

// 给图片 URL 加尺寸参数。
// 不加的话网易 CDN 会返回原图 —— 封面动辄 1MB，一页 12 张就是十几 MB，
// 界面会长时间空着。官方也是这么做的（?param=96y96 能把 1.1MB 压到 22KB）。
QString withSize(const QString &url, int size)
{
    if (url.isEmpty() || url.startsWith(QLatin1String("data:")))
        return url;
    return url + QStringLiteral("?param=%1y%1").arg(size);
}

// ── 歌词解析 ────────────────────────────────────────────
// 新版 web 播放器返回的 lrc.lyric **不是 LRC 文本，而是 JSONL**：
//     {"t":0,"c":[{"tx":"作词: "},{"tx":"张国祥",...}]}
//     {"t":1000,"c":[{"tx":"作曲: "},...]}
// 每行一个 JSON 对象，t 是毫秒时间戳，c 是片段数组（拼 tx 就是整行文本）。
// 老接口/部分歌曲仍是标准 LRC，所以两种都要认。
void parseLyricBody(const QString &raw, QVariantList *out, QHash<qint64, QString> *trMap)
{
    const QString body = raw.trimmed();
    if (body.isEmpty())
        return;

    if (body.startsWith(QLatin1Char('{'))) {
        const QStringList lines = body.split(QLatin1Char('\n'), Qt::SkipEmptyParts);
        for (const QString &line : lines) {
            const QJsonObject o = QJsonDocument::fromJson(line.trimmed().toUtf8()).object();
            if (o.isEmpty())
                continue;
            const qint64 ts = o.value(QStringLiteral("t")).toVariant().toLongLong();
            QString text;
            for (const QJsonValue &c : o.value(QStringLiteral("c")).toArray())
                text += c.toObject().value(QStringLiteral("tx")).toString();
            if (text.isEmpty())
                continue;
            if (trMap) {
                (*trMap)[ts] = text;
                continue;
            }
            QVariantMap m;
            m[QStringLiteral("t")]    = ts;
            m[QStringLiteral("text")] = text;
            m[QStringLiteral("tr")]   = QString();
            *out << m;
        }
        return;
    }

    // 标准 LRC：[mm:ss.xx] / [mm:ss:xx]
    static const QRegularExpression re(
        QStringLiteral("\\[(\\d{1,3}):(\\d{1,2})(?:[.:](\\d{1,3}))?\\]"));
    const QStringList lines = body.split(QLatin1Char('\n'), Qt::SkipEmptyParts);
    for (const QString &line : lines) {
        auto it = re.globalMatch(line);
        QString text = line;
        QList<qint64> stamps;
        // 一行可能挂多个时间戳（重复副歌），逐个抠出来
        while (it.hasNext()) {
            const QRegularExpressionMatch m = it.next();
            const qint64 mm = m.captured(1).toLongLong();
            const qint64 ss = m.captured(2).toLongLong();
            QString frac = m.captured(3);
            qint64 ms = 0;
            if (!frac.isEmpty()) {
                if (frac.size() == 1)      ms = frac.toLongLong() * 100;
                else if (frac.size() == 2) ms = frac.toLongLong() * 10;
                else                       ms = frac.left(3).toLongLong();
            }
            stamps << (mm * 60000 + ss * 1000 + ms);
        }
        if (stamps.isEmpty())
            continue;
        text.remove(re);
        text = text.trimmed();
        if (text.isEmpty())
            continue;
        for (qint64 ts : stamps) {
            if (trMap) {
                (*trMap)[ts] = text;
                continue;
            }
            QVariantMap m;
            m[QStringLiteral("t")]    = ts;
            m[QStringLiteral("text")] = text;
            m[QStringLiteral("tr")]   = QString();
            *out << m;
        }
    }
}

QVariantList parseLyric(const QString &raw, const QString &trRaw)
{
    QVariantList out;
    QHash<qint64, QString> tr;
    parseLyricBody(raw, &out, nullptr);
    if (!trRaw.trimmed().isEmpty())
        parseLyricBody(trRaw, nullptr, &tr);

    if (!tr.isEmpty()) {
        for (QVariant &v : out) {
            QVariantMap m = v.toMap();
            const QString t = tr.value(m.value(QStringLiteral("t")).toLongLong());
            if (!t.isEmpty())
                m[QStringLiteral("tr")] = t;
            v = m;
        }
    }
    std::sort(out.begin(), out.end(), [](const QVariant &a, const QVariant &b) {
        return a.toMap().value(QStringLiteral("t")).toLongLong()
             < b.toMap().value(QStringLiteral("t")).toLongLong();
    });
    return out;
}
} // namespace

NcmApi::NcmApi(QObject *parent)
    : QObject(parent)
{
    QSettings s;
    m_musicU = s.value(QStringLiteral("session/MUSIC_U")).toString();

    m_deviceId = s.value(QStringLiteral("device/id")).toString();
    if (m_deviceId.isEmpty()) {
        // 16 位十六进制，模拟官方 getDeviceId
        m_deviceId = QString::number(QRandomGenerator::global()->generate64(), 16).right(16);
        s.setValue(QStringLiteral("device/id"), m_deviceId);
    }
}

// ─────────────────────────────────────────────────────────
//  请求底层
// ─────────────────────────────────────────────────────────

void NcmApi::applyHeaders(QNetworkRequest &req) const
{
    req.setHeader(QNetworkRequest::UserAgentHeader, kUserAg);
    req.setRawHeader("Referer", "https://music.163.com/");
    req.setRawHeader("Origin",  "https://music.163.com");
    req.setRawHeader("Accept",  "application/json, text/plain, */*");
    // 官方 web 客户端会带这几个头（见 vendors~app.js 的 formatParamKey 调用处）
    req.setRawHeader("os",       "pc");
    req.setRawHeader("appver",   "3.1.0");
    req.setRawHeader("osver",    "10.0.19045");
    req.setRawHeader("deviceId", m_deviceId.toUtf8());
    req.setRawHeader("requestId", "0");
    if (!m_musicU.isEmpty())
        req.setRawHeader("Cookie", ("MUSIC_U=" + m_musicU).toUtf8());
}

QNetworkReply *NcmApi::get(const QString &path, const QVariantMap &params,
                           const QString &base)
{
    QUrl url((base.isEmpty() ? kBase : base) + path);
    QUrlQuery q;
    for (auto it = params.constBegin(); it != params.constEnd(); ++it)
        q.addQueryItem(it.key(), it.value().toString());
    url.setQuery(q);

    QNetworkRequest req(url);
    applyHeaders(req);
    return m_nam.get(req);
}

QNetworkReply *NcmApi::post(const QString &path, const QVariantMap &params,
                            const QString &base)
{
    QUrlQuery q;
    for (auto it = params.constBegin(); it != params.constEnd(); ++it)
        q.addQueryItem(it.key(), it.value().toString());

    QNetworkRequest req(QUrl((base.isEmpty() ? kBase : base) + path));
    applyHeaders(req);
    req.setHeader(QNetworkRequest::ContentTypeHeader,
                  QStringLiteral("application/x-www-form-urlencoded"));
    return m_nam.post(req, q.toString(QUrl::FullyEncoded).toUtf8());
}

void NcmApi::fail(const QString &what, const QString &msg)
{
    m_lastError = what + QStringLiteral(": ") + msg;
    qWarning("[NcmApi] %s", qPrintable(m_lastError));
    emit lastErrorChanged();
}

QString NcmApi::fmtCount(qint64 n) const
{
    if (n >= 100000000)
        return QString::number(n / 100000000.0, 'f', 1) + QStringLiteral("亿");
    if (n >= 10000)
        return QString::number(n / 10000.0, 'f', 1) + QStringLiteral("万");
    return QString::number(n);
}

void NcmApi::setProfile(const QVariantMap &p)
{
    const bool was = loggedIn();
    m_profile = p;
    // 头像显示尺寸 28px，别拉原图
    if (m_profile.contains(QStringLiteral("avatarUrl")))
        m_profile[QStringLiteral("avatarUrl")] =
            withSize(m_profile.value(QStringLiteral("avatarUrl")).toString(), 64);
    if (!m_profile.contains(QStringLiteral("nickname"))) {
        if (m_profile.contains(QStringLiteral("userName")))   // account 里是 userName
            m_profile[QStringLiteral("nickname")] =
                m_profile.value(QStringLiteral("userName"));
    }
    emit profileChanged();
    if (was != loggedIn())
        emit loggedInChanged();
}

// ─────────────────────────────────────────────────────────
//  归一化
// ─────────────────────────────────────────────────────────

QVariantMap NcmApi::normalizeSong(const QVariantMap &raw)
{
    QVariantMap o;

    // personalized/newsong 把歌塞在 song 字段里
    const QVariantMap src = raw.contains(QStringLiteral("song"))
                                ? raw.value(QStringLiteral("song")).toMap()
                                : raw;

    o[QStringLiteral("id")]   = src.value(QStringLiteral("id")).toLongLong();
    o[QStringLiteral("name")] = src.value(QStringLiteral("name")).toString();
    if (o[QStringLiteral("name")].toString().isEmpty())
        o[QStringLiteral("name")] = raw.value(QStringLiteral("name")).toString();

    // 歌手：ar（新）/ artists（旧）
    QStringList artists;
    const QVariantList ar = src.value(QStringLiteral("ar")).toList().isEmpty()
                                ? src.value(QStringLiteral("artists")).toList()
                                : src.value(QStringLiteral("ar")).toList();
    for (const QVariant &v : ar)
        artists << v.toMap().value(QStringLiteral("name")).toString();
    o[QStringLiteral("artist")] = artists.join(QStringLiteral(" / "));
    // 点歌手名要跳转，所以留一份原始的 id 列表
    QVariantList artistIds;
    for (const QVariant &v : ar) {
        QVariantMap a;
        a[QStringLiteral("id")]   = v.toMap().value(QStringLiteral("id")).toLongLong();
        a[QStringLiteral("name")] = v.toMap().value(QStringLiteral("name")).toString();
        artistIds << a;
    }
    o[QStringLiteral("artists")] = artistIds;

    // 专辑：al（新）/ album（旧）
    const QVariantMap al = src.value(QStringLiteral("al")).toMap().isEmpty()
                               ? src.value(QStringLiteral("album")).toMap()
                               : src.value(QStringLiteral("al")).toMap();
    o[QStringLiteral("album")]    = al.value(QStringLiteral("name")).toString();
    o[QStringLiteral("albumId")]  = al.value(QStringLiteral("id")).toLongLong();
    o[QStringLiteral("cover")]    = al.value(QStringLiteral("picUrl")).toString();
    if (o[QStringLiteral("cover")].toString().isEmpty())
        o[QStringLiteral("cover")] = raw.value(QStringLiteral("picUrl")).toString();
    // 列表封面 48px，给 96 就够（省流量）
    o[QStringLiteral("cover")] = withSize(o[QStringLiteral("cover")].toString(), 96);

    // 时长：dt（毫秒）/ duration（毫秒）
    qint64 ms = src.value(QStringLiteral("dt")).toLongLong();
    if (ms <= 0)
        ms = src.value(QStringLiteral("duration")).toLongLong();
    o[QStringLiteral("duration")] = int(ms / 1000);

    o[QStringLiteral("fee")] = src.value(QStringLiteral("fee"), 0).toInt();
    o[QStringLiteral("mvId")] = src.value(QStringLiteral("mv")).toLongLong();
    // 私人 FM 的返回里带 starred，直接就是「是否已喜欢」
    if (src.contains(QStringLiteral("starred")))
        o[QStringLiteral("liked")] = src.value(QStringLiteral("starred")).toBool();

    // 别名字段（有的接口给 alia / alias）
    const QVariantList alia = src.value(QStringLiteral("alia")).toList().isEmpty()
                                  ? src.value(QStringLiteral("alias")).toList()
                                  : src.value(QStringLiteral("alia")).toList();
    o[QStringLiteral("alias")] = alia.isEmpty() ? QString() : alia.first().toString();

    // 音质徽章：搜索/详情结果里带 hr / sq / h 三个档
    QString q;
    if (!src.value(QStringLiteral("hr")).toMap().isEmpty())
        q = QStringLiteral("hires");
    else if (!src.value(QStringLiteral("sq")).toMap().isEmpty())
        q = QStringLiteral("sq");
    else if (!src.value(QStringLiteral("h")).toMap().isEmpty())
        q = QStringLiteral("hq");
    o[QStringLiteral("quality")] = q;

    return o;
}

QVariantMap NcmApi::normalizePlaylist(const QVariantMap &raw)
{
    QVariantMap o;
    o[QStringLiteral("id")]    = raw.value(QStringLiteral("id")).toLongLong();
    o[QStringLiteral("name")]  = raw.value(QStringLiteral("name")).toString();
    o[QStringLiteral("trackCount")] = raw.value(QStringLiteral("trackCount"),
                                                raw.value(QStringLiteral("songCount"))).toInt();
    o[QStringLiteral("playCount")]  = raw.value(QStringLiteral("playCount")).toLongLong();
    o[QStringLiteral("description")] = raw.value(QStringLiteral("description")).toString();
    o[QStringLiteral("subscribed")] =
        raw.value(QStringLiteral("subscribed"), false).toBool();
    // 「我喜欢的音乐」靠这个字段认：specialType == 5
    o[QStringLiteral("specialType")] =
        raw.value(QStringLiteral("specialType"), 0).toInt();

    QString cover = raw.value(QStringLiteral("coverImgUrl")).toString();
    if (cover.isEmpty())
        cover = raw.value(QStringLiteral("picUrl")).toString();
    if (cover.isEmpty())
        cover = raw.value(QStringLiteral("img1v1Url")).toString();
    // 封面显示尺寸是 216（列表卡片 168），给 440 够 2x 屏且体积很小
    o[QStringLiteral("cover")] = withSize(cover, 440);
    // 网格卡片只需要 336
    o[QStringLiteral("coverSmall")] = withSize(cover, 336);

    // 创建者
    const QVariantMap creator = raw.value(QStringLiteral("creator")).toMap();
    o[QStringLiteral("author")] = creator.value(QStringLiteral("nickname")).toString();
    o[QStringLiteral("authorAvatar")] =
        withSize(creator.value(QStringLiteral("avatarUrl")).toString(), 48);
    o[QStringLiteral("authorId")] = creator.value(QStringLiteral("userId")).toLongLong();
    // 电台的「创建者」字段是 dj
    if (o.value(QStringLiteral("author")).toString().isEmpty()) {
        const QVariantMap dj = raw.value(QStringLiteral("dj")).toMap();
        o[QStringLiteral("author")] = dj.value(QStringLiteral("nickname")).toString();
        o[QStringLiteral("authorAvatar")] =
            withSize(dj.value(QStringLiteral("avatarUrl")).toString(), 48);
        o[QStringLiteral("authorId")] = dj.value(QStringLiteral("userId")).toLongLong();
    }

    const qint64 ct = raw.value(QStringLiteral("createTime")).toLongLong();
    o[QStringLiteral("createTime")] = ct > 0
        ? QDateTime::fromMSecsSinceEpoch(ct).toString(QStringLiteral("yyyy-MM-dd 创建"))
        : QString();

    return o;
}

// ─────────────────────────────────────────────────────────
//  会话
// ─────────────────────────────────────────────────────────

void NcmApi::setMusicU(const QString &value)
{
    const QString next = value.trimmed();

    // ⚠️ 换号（或换 token）时必须**立刻**把上一账号的派生状态清空。
    // 否则在 loadAccount 回来的这几百毫秒里：loggedIn() 还是 true、userId() 还是旧 uid、
    // likedPlaylistId 还是旧账号的「我喜欢的音乐」——
    // 表现就是「我登录了 A 账号，点进去却是 B 账号的歌单」，而且登录层会以为
    // 已经登录成功（因为 loggedIn 一直是 true）直接关掉。
    if (next != m_musicU) {
        const bool wasLogged = loggedIn();
        m_likedPlaylistId = 0;
        m_profile.clear();
        emit profileChanged();
        if (wasLogged)
            emit loggedInChanged();
    }

    m_musicU = next;
    QSettings().setValue(QStringLiteral("session/MUSIC_U"), m_musicU);

    if (m_musicU.isEmpty())
        emit loggedInChanged();
    else
        loadAccount();
}

void NcmApi::logout()
{
    setMusicU(QString());
}

void NcmApi::loadAccount()
{
    QNetworkReply *r = get(QStringLiteral("/api/nuser/account/get"));
    connect(r, &QNetworkReply::finished, this, [this, r]() {
        r->deleteLater();
        if (r->error() != QNetworkReply::NoError) {
            fail(QStringLiteral("账号"), r->errorString());
            emit accountFailed();
            return;
        }
        const QJsonObject o = QJsonDocument::fromJson(r->readAll()).object();
        const QJsonObject prof = o.value(QStringLiteral("profile")).toObject();
        if (prof.isEmpty()) {
            fail(QStringLiteral("账号"), QStringLiteral("未登录或 cookie 已失效"));
            setProfile({});
            emit accountFailed();
            return;
        }
        QVariantMap p = prof.toVariantMap();
        p[QStringLiteral("userId")] = o.value(QStringLiteral("account"))
                                          .toObject().value(QStringLiteral("id")).toVariant();
        setProfile(p);
        loadUserPlaylists();
        loadLikelist();
    });
}

// ─────────────────────────────────────────────────────────
//  歌单
// ─────────────────────────────────────────────────────────

void NcmApi::loadUserPlaylists()
{
    if (userId() <= 0)
        return;

    QVariantMap params;
    params[QStringLiteral("uid")]    = QString::number(userId());
    params[QStringLiteral("limit")]  = QStringLiteral("1000");
    params[QStringLiteral("offset")] = QStringLiteral("0");

    QNetworkReply *r = get(QStringLiteral("/api/user/playlist"), params);
    connect(r, &QNetworkReply::finished, this, [this, r]() {
        r->deleteLater();
        if (r->error() != QNetworkReply::NoError) {
            fail(QStringLiteral("我的歌单"), r->errorString());
            return;
        }
        const QJsonObject o = QJsonDocument::fromJson(r->readAll()).object();
        const QJsonArray arr = o.value(QStringLiteral("playlist")).toArray();

        QVariantList created, collected;
        for (const QJsonValue &v : arr) {
            const QVariantMap p = normalizePlaylist(v.toObject().toVariantMap());
            const bool mine = p.value(QStringLiteral("authorId")).toLongLong() == userId();

            // ⚠️ 「我喜欢的音乐」不能只看 specialType == 5 ——
            // 每个用户都有一条自己的「XX喜欢的音乐」（specialType 都是 5），
            // 我**收藏**了别人分享的「喜欢的音乐」歌单时，它也在这个列表里。
            // 之前只判断 specialType，结果：
            //   1) 把别人的「XX喜欢的音乐」prepend 进「创建的歌单」
            //   2) 用别人的 id 覆盖 m_likedPlaylistId
            // 表现就是「我登录了 A 账号，点『我喜欢的音乐』进去却是 B 账号的歌单」。
            if (p.value(QStringLiteral("specialType")).toInt() == 5 && mine) {
                m_likedPlaylistId = p.value(QStringLiteral("id")).toLongLong();
                created.prepend(p);
            } else if (mine) {
                created << p;
            } else {
                collected << p;
            }
        }
        if (m_likedPlaylistId)
            emit profileChanged();
        emit userPlaylistsReady(created, collected);
    });
}

void NcmApi::publishPlaylist(const QSharedPointer<PlaylistFetch> &st)
{
    // 按 trackIds 的原始顺序组装 —— 顺序就是歌单顺序，缺的（还没补回来的）先跳过
    QVariantList songs;
    int idx = 1;
    for (qint64 sid : st->ids) {
        auto it = st->byId.constFind(sid);
        if (it == st->byId.constEnd())
            continue;
        QVariantMap s = it.value();
        s[QStringLiteral("index")] = idx++;
        const QString q = st->quality.value(sid);
        if (!q.isEmpty())
            s[QStringLiteral("quality")] = q;
        songs << s;
    }
    QVariantMap d = st->detail;
    d[QStringLiteral("songs")]     = songs;
    d[QStringLiteral("songTotal")] = st->ids.size();   // 真·总数，UI 可以边下边显示
    emit playlistDetailReady(d);
}

void NcmApi::loadPlaylistDetail(qint64 id)
{
    QVariantMap params;
    params[QStringLiteral("id")] = QString::number(id);
    params[QStringLiteral("n")]  = QStringLiteral("100000");
    params[QStringLiteral("s")]  = QStringLiteral("8");

    QNetworkReply *r = get(QStringLiteral("/api/v6/playlist/detail"), params);
    connect(r, &QNetworkReply::finished, this, [this, r]() {
        r->deleteLater();
        if (r->error() != QNetworkReply::NoError) {
            fail(QStringLiteral("歌单详情"), r->errorString());
            return;
        }
        const QJsonObject o = QJsonDocument::fromJson(r->readAll()).object();
        const QJsonObject pl = o.value(QStringLiteral("playlist")).toObject();
        if (pl.isEmpty()) {
            fail(QStringLiteral("歌单详情"), QStringLiteral("返回为空"));
            return;
        }

        // ⚠️ 这个接口的 `tracks` / `privileges` **会被截断**，不能当完整曲目表用。
        // 实测（2026-10-14）：
        //     741 首的歌单 → tracks 741（正常）
        //     900 首的歌单 → tracks **只有 20**，privileges 也只有 20
        //     803 首的歌单 → tracks **只有 20**
        // 表现就是「打开歌单只显示前几首」。
        // 只有 `trackIds` 是完整的（900 首都回来了），所以一律以它为准：
        // tracks 里已有的先拿来用，缺的用 /api/v3/song/detail 分批补齐
        // （这个接口 songs 和 privileges 一起给）。
        const QJsonArray trackIds = pl.value(QStringLiteral("trackIds")).toArray();

        auto st = QSharedPointer<PlaylistFetch>::create();
        st->detail  = normalizePlaylist(pl.toVariantMap());
        st->quality = qualityFromPrivileges(o.value(QStringLiteral("privileges")).toArray());

        for (const QJsonValue &v : pl.value(QStringLiteral("tracks")).toArray()) {
            QVariantMap s = normalizeSong(v.toObject().toVariantMap());
            const qint64 sid = s.value(QStringLiteral("id")).toLongLong();
            if (sid > 0)
                st->byId.insert(sid, s);
        }

        // trackIds 为空（老接口形态）时退回 tracks 的顺序
        if (trackIds.isEmpty()) {
            for (const QJsonValue &v : pl.value(QStringLiteral("tracks")).toArray())
                st->ids << v.toObject().value(QStringLiteral("id")).toVariant().toLongLong();
        } else {
            for (const QJsonValue &v : trackIds)
                st->ids << v.toObject().value(QStringLiteral("id")).toVariant().toLongLong();
        }

        // 先把已经拿到的发出去，页面立刻有内容
        publishPlaylist(st);

        if (st->byId.size() >= st->ids.size())
            return;                       // tracks 是完整的，不用补

        // 缺的用 /api/v3/song/detail 分批补。一次 200 个 id
        // （URL 长度可控；900 首也就 5 个请求）
        const int kBatch = 200;
        for (int start = 0; start < st->ids.size(); start += kBatch) {
            QJsonArray c;
            for (int i = start; i < start + kBatch && i < st->ids.size(); ++i) {
                QJsonObject e;
                e[QStringLiteral("id")] = double(st->ids.at(i));
                c.append(e);
            }
            if (c.isEmpty())
                continue;

            QVariantMap p2;
            p2[QStringLiteral("c")] = QString::fromUtf8(
                QJsonDocument(c).toJson(QJsonDocument::Compact));

            ++st->pending;
            QNetworkReply *r2 = get(QStringLiteral("/api/v3/song/detail"), p2);
            connect(r2, &QNetworkReply::finished, this, [this, r2, st]() {
                r2->deleteLater();
                --st->pending;
                if (r2->error() == QNetworkReply::NoError) {
                    const QJsonObject oo = QJsonDocument::fromJson(r2->readAll()).object();
                    for (const QJsonValue &v : oo.value(QStringLiteral("songs")).toArray()) {
                        QVariantMap s = normalizeSong(v.toObject().toVariantMap());
                        const qint64 sid = s.value(QStringLiteral("id")).toLongLong();
                        if (sid > 0)
                            st->byId.insert(sid, s);
                    }
                    const QHash<qint64, QString> q =
                        qualityFromPrivileges(oo.value(QStringLiteral("privileges")).toArray());
                    for (auto it = q.constBegin(); it != q.constEnd(); ++it)
                        st->quality.insert(it.key(), it.value());
                }
                publishPlaylist(st);   // 每批回来都重发一次，边下边长
            });
        }
    });
}

void NcmApi::loadRecommendPlaylists(int limit)
{
    QVariantMap params;
    params[QStringLiteral("limit")] = QString::number(limit);

    QNetworkReply *r = get(QStringLiteral("/api/personalized/playlist"), params);
    connect(r, &QNetworkReply::finished, this, [this, r]() {
        r->deleteLater();
        if (r->error() != QNetworkReply::NoError) {
            fail(QStringLiteral("推荐歌单"), r->errorString());
            return;
        }
        const QJsonObject o = QJsonDocument::fromJson(r->readAll()).object();
        QVariantList list;
        for (const QJsonValue &v : o.value(QStringLiteral("result")).toArray())
            list << normalizePlaylist(v.toObject().toVariantMap());
        emit recommendPlaylistsReady(list);
    });
}

void NcmApi::loadRecommendSongs()
{
    QNetworkReply *r = get(QStringLiteral("/api/personalized/newsong"),
                           { { QStringLiteral("limit"), QStringLiteral("30") } });
    connect(r, &QNetworkReply::finished, this, [this, r]() {
        r->deleteLater();
        if (r->error() != QNetworkReply::NoError) {
            fail(QStringLiteral("推荐歌曲"), r->errorString());
            return;
        }
        const QJsonObject o = QJsonDocument::fromJson(r->readAll()).object();
        QVariantList list;
        int idx = 1;
        for (const QJsonValue &v : o.value(QStringLiteral("result")).toArray()) {
            QVariantMap s = normalizeSong(v.toObject().toVariantMap());
            s[QStringLiteral("index")] = idx++;
            list << s;
        }
        emit recommendSongsReady(list);
    });
}

// ★ 每日推荐（跟随兴趣）。区别于 loadRecommendSongs：
//   /api/personalized/newsong      → 全网新歌速递，跟账号口味**无关**
//   /api/v1/discovery/recommend/songs → 按这个账号的听歌口味算出来的 20 首，每天换
// 实测（dCbAxH）：返回「ルマ / かいりきベア」这类日系曲，口味特征很明显；
// newsong 返回的则是全网新歌。首页那块「根据你的口味生成」必须用这个。
// ⚠️ 这个端点只在主站有，interface 上会 404，所以显式传 kBaseMusic。
void NcmApi::loadDailyRecommendSongs(int limit)
{
    QVariantMap params;
    params[QStringLiteral("limit")] = QString::number(limit);

    QNetworkReply *r = get(QStringLiteral("/api/v1/discovery/recommend/songs"),
                           params, kBaseMusic);
    connect(r, &QNetworkReply::finished, this, [this, r]() {
        r->deleteLater();
        if (r->error() != QNetworkReply::NoError) {
            fail(QStringLiteral("每日推荐"), r->errorString());
            return;
        }
        const QJsonObject o = QJsonDocument::fromJson(r->readAll()).object();
        if (o.value(QStringLiteral("code")).toInt() != 200) {
            fail(QStringLiteral("每日推荐"),
                 QStringLiteral("code=%1").arg(o.value(QStringLiteral("code")).toInt()));
            return;
        }
        QVariantList list;
        int idx = 1;
        for (const QJsonValue &v : o.value(QStringLiteral("recommend")).toArray()) {
            QVariantMap s = normalizeSong(v.toObject().toVariantMap());
            s[QStringLiteral("index")] = idx++;
            list << s;
        }
        emit dailySongsReady(list);
    });
}

// ── 个人主页 ───────────────────────────────────────────
// /api/v1/user/detail/<uid>：**路径参数**，不是 ?uid=（那个是 404「接口未找到」）
void NcmApi::loadUserDetail(qint64 uid)
{
    if (uid <= 0)
        uid = userId();
    if (uid <= 0)
        return;

    QNetworkReply *r = get(QStringLiteral("/api/v1/user/detail/%1").arg(uid), {}, kBaseMusic);
    connect(r, &QNetworkReply::finished, this, [this, r]() {
        r->deleteLater();
        if (r->error() != QNetworkReply::NoError) {
            fail(QStringLiteral("用户资料"), r->errorString());
            return;
        }
        const QJsonObject o = QJsonDocument::fromJson(r->readAll()).object();
        const QJsonObject p = o.value(QStringLiteral("profile")).toObject();

        QVariantMap u;
        u[QStringLiteral("id")]          = p.value(QStringLiteral("userId")).toVariant();
        u[QStringLiteral("nickname")]    = p.value(QStringLiteral("nickname")).toString();
        u[QStringLiteral("avatar")]      = p.value(QStringLiteral("avatarUrl")).toString();
        u[QStringLiteral("background")]  = p.value(QStringLiteral("backgroundUrl")).toString();
        u[QStringLiteral("signature")]   = p.value(QStringLiteral("signature")).toString();
        u[QStringLiteral("gender")]      = p.value(QStringLiteral("gender")).toInt();
        u[QStringLiteral("city")]        = p.value(QStringLiteral("city")).toVariant();
        u[QStringLiteral("province")]    = p.value(QStringLiteral("province")).toVariant();
        u[QStringLiteral("birthday")]    = p.value(QStringLiteral("birthday")).toVariant();
        u[QStringLiteral("follows")]     = p.value(QStringLiteral("follows")).toVariant();
        u[QStringLiteral("followeds")]   = p.value(QStringLiteral("followeds")).toVariant();
        u[QStringLiteral("eventCount")]  = p.value(QStringLiteral("eventCount")).toVariant();
        u[QStringLiteral("playlistCount")] = p.value(QStringLiteral("playlistCount")).toVariant();
        u[QStringLiteral("vipType")]     = p.value(QStringLiteral("vipType")).toInt();
        u[QStringLiteral("level")]       = o.value(QStringLiteral("level")).toInt();
        u[QStringLiteral("listenSongs")] = o.value(QStringLiteral("listenSongs")).toVariant();
        emit userDetailReady(u);
    });
}

// 别人的歌单列表。和 loadUserPlaylists（我的）用的是同一个端点，
// 区别只在 uid —— 别人的列表里没有 specialType==5 那条「喜欢的音乐」要挑出来。
void NcmApi::loadUserPlaylistsOf(qint64 uid, int limit)
{
    if (uid <= 0)
        uid = userId();
    if (uid <= 0)
        return;

    QVariantMap params;
    params[QStringLiteral("uid")]    = QString::number(uid);
    params[QStringLiteral("limit")]  = QString::number(limit);
    params[QStringLiteral("offset")] = QStringLiteral("0");

    QNetworkReply *r = get(QStringLiteral("/api/user/playlist"), params, kBaseMusic);
    connect(r, &QNetworkReply::finished, this, [this, r, uid]() {
        r->deleteLater();
        if (r->error() != QNetworkReply::NoError) {
            fail(QStringLiteral("用户歌单"), r->errorString());
            return;
        }
        const QJsonObject o = QJsonDocument::fromJson(r->readAll()).object();
        QVariantList created, collected;
        for (const QJsonValue &v : o.value(QStringLiteral("playlist")).toArray()) {
            const QVariantMap p = normalizePlaylist(v.toObject().toVariantMap());
            (p.value(QStringLiteral("authorId")).toLongLong() == uid ? created : collected) << p;
        }
        emit userPublicPlaylistsReady(created, collected);
    });
}

// 听歌排行：type 0=所有时间 1=最近一周
void NcmApi::loadUserRecord(qint64 uid, int type)
{
    if (uid <= 0)
        uid = userId();
    if (uid <= 0)
        return;

    QVariantMap params;
    params[QStringLiteral("uid")]  = QString::number(uid);
    params[QStringLiteral("type")] = QString::number(type);

    QNetworkReply *r = get(QStringLiteral("/api/v1/play/record"), params, kBaseMusic);
    connect(r, &QNetworkReply::finished, this, [this, r]() {
        r->deleteLater();
        if (r->error() != QNetworkReply::NoError) {
            fail(QStringLiteral("听歌排行"), r->errorString());
            return;
        }
        const QJsonObject o = QJsonDocument::fromJson(r->readAll()).object();
        QVariantList list;
        int idx = 1;
        // 周榜是 weeklyData、总榜是 allData，服务端不会同时给
        const QJsonArray arr = o.contains(QStringLiteral("weekData"))
                                   ? o.value(QStringLiteral("weekData")).toArray()
                                   : o.value(QStringLiteral("allData")).toArray();
        for (const QJsonValue &v : arr) {
            QVariantMap s = normalizeSong(v.toObject().value(QStringLiteral("song")).toObject()
                                              .toVariantMap());
            s[QStringLiteral("playCount")] = v.toObject().value(QStringLiteral("playCount")).toInt();
            s[QStringLiteral("index")] = idx++;
            list << s;
        }
        emit userRecordReady(list);
    });
}

void NcmApi::loadUserLevel()
{
    QNetworkReply *r = get(QStringLiteral("/api/user/level"), {}, kBaseMusic);
    connect(r, &QNetworkReply::finished, this, [this, r]() {
        r->deleteLater();
        if (r->error() != QNetworkReply::NoError) {
            fail(QStringLiteral("等级"), r->errorString());
            return;
        }
        const QJsonObject o = QJsonDocument::fromJson(r->readAll()).object();
        emit userLevelReady(o.value(QStringLiteral("data")).toObject().toVariantMap());
    });
}

// 评论点赞。threadId 是 R_SO_4_<id> 这种（评论响应里带），cid 是评论 id。
// t=1 点赞 / t=0 取消。传错（比如把歌曲 id 当 threadId）会回 code 400。
void NcmApi::likeComment(const QString &threadId, qint64 cid, bool like)
{
    if (threadId.isEmpty() || cid <= 0)
        return;

    QVariantMap params;
    params[QStringLiteral("id")]   = threadId;
    params[QStringLiteral("cid")]  = QString::number(cid);
    params[QStringLiteral("t")]    = like ? QStringLiteral("1") : QStringLiteral("0");
    params[QStringLiteral("type")] = QStringLiteral("0");

    QNetworkReply *r = get(QStringLiteral("/api/v1/comment/like"), params, kBaseMusic);
    connect(r, &QNetworkReply::finished, this, [this, r, cid, like]() {
        r->deleteLater();
        if (r->error() != QNetworkReply::NoError) {
            fail(QStringLiteral("评论点赞"), r->errorString());
            return;
        }
        const QJsonObject o = QJsonDocument::fromJson(r->readAll()).object();
        if (o.value(QStringLiteral("code")).toInt() == 200)
            emit commentLikeChanged(cid, like);
    });
}

// 歌单广场：/api/playlist/highquality/list?cat=<分类>&limit=N&lasttime=0
void NcmApi::loadTopPlaylists(const QString &cat, int limit)
{
    QVariantMap params;
    params[QStringLiteral("cat")]      = cat.isEmpty() ? QStringLiteral("全部") : cat;
    params[QStringLiteral("limit")]    = QString::number(limit);
    params[QStringLiteral("lasttime")] = QStringLiteral("0");
    params[QStringLiteral("total")]    = QStringLiteral("true");

    QNetworkReply *r = get(QStringLiteral("/api/playlist/highquality/list"), params);
    connect(r, &QNetworkReply::finished, this, [this, r, cat]() {
        r->deleteLater();
        if (r->error() != QNetworkReply::NoError) {
            fail(QStringLiteral("歌单广场"), r->errorString());
            return;
        }
        const QJsonObject o = QJsonDocument::fromJson(r->readAll()).object();
        QVariantList list;
        for (const QJsonValue &v : o.value(QStringLiteral("playlists")).toArray())
            list << normalizePlaylist(v.toObject().toVariantMap());
        Q_UNUSED(cat)
        emit topPlaylistsReady(list);
    });
}

// ─────────────────────────────────────────────────────────
//  榜单
// ─────────────────────────────────────────────────────────

void NcmApi::loadToplists()
{
    QNetworkReply *r = get(QStringLiteral("/api/toplist/detail/v2"));
    connect(r, &QNetworkReply::finished, this, [this, r]() {
        r->deleteLater();
        if (r->error() != QNetworkReply::NoError) {
            fail(QStringLiteral("排行榜"), r->errorString());
            return;
        }
        const QJsonObject o = QJsonDocument::fromJson(r->readAll()).object();
        QVariantList blocks;
        for (const QJsonValue &bv : o.value(QStringLiteral("data")).toArray()) {
            const QJsonObject b = bv.toObject();
            QVariantList items;
            for (const QJsonValue &iv : b.value(QStringLiteral("list")).toArray()) {
                const QJsonObject it = iv.toObject();
                QVariantMap m;
                m[QStringLiteral("id")]    = it.value(QStringLiteral("id")).toVariant();
                m[QStringLiteral("name")]  = it.value(QStringLiteral("name")).toString();
                m[QStringLiteral("cover")] =
                    withSize(it.value(QStringLiteral("coverUrl")).toString(), 336);
                m[QStringLiteral("updateFrequency")] =
                    it.value(QStringLiteral("updateFrequency")).toString();
                m[QStringLiteral("description")] =
                    it.value(QStringLiteral("description")).toString();
                // 官方在每个榜单里塞了前几首，直接拿来当预览/首播
                QVariantList tracks;
                int idx = 1;
                for (const QJsonValue &sv : it.value(QStringLiteral("tracks")).toArray()) {
                    QVariantMap s = normalizeSong(sv.toObject().toVariantMap());
                    s[QStringLiteral("index")] = idx++;
                    tracks << s;
                }
                m[QStringLiteral("tracks")] = tracks;
                items << m;
            }
            QVariantMap blk;
            blk[QStringLiteral("name")] = b.value(QStringLiteral("name")).toString();
            blk[QStringLiteral("code")] = b.value(QStringLiteral("categoryCode")).toString();
            blk[QStringLiteral("list")] = items;
            blocks << blk;
        }
        emit toplistsReady(blocks);
    });
}

// ─────────────────────────────────────────────────────────
//  歌手 / 专辑
// ─────────────────────────────────────────────────────────

void NcmApi::loadArtistDetail(qint64 id, int songLimit)
{
    // 歌手信息
    QNetworkReply *ra = get(QStringLiteral("/api/v1/artist/%1").arg(id));
    connect(ra, &QNetworkReply::finished, this, [this, ra]() {
        ra->deleteLater();
        if (ra->error() != QNetworkReply::NoError) {
            fail(QStringLiteral("歌手"), ra->errorString());
            return;
        }
        const QJsonObject o = QJsonDocument::fromJson(ra->readAll()).object();
        const QJsonObject a = o.value(QStringLiteral("artist")).toObject();
        QVariantMap artist;
        artist[QStringLiteral("id")]   = a.value(QStringLiteral("id")).toVariant();
        artist[QStringLiteral("name")] = a.value(QStringLiteral("name")).toString();
        artist[QStringLiteral("alias")] =
            a.value(QStringLiteral("alias")).toArray().isEmpty()
                ? QString()
                : a.value(QStringLiteral("alias")).toArray().first().toString();
        artist[QStringLiteral("cover")] =
            withSize(a.value(QStringLiteral("picUrl")).toString(), 440);
        artist[QStringLiteral("briefDesc")] =
            a.value(QStringLiteral("briefDesc")).toString();
        artist[QStringLiteral("albumSize")] = a.value(QStringLiteral("albumSize")).toInt();
        artist[QStringLiteral("musicSize")] = a.value(QStringLiteral("musicSize")).toInt();
        emit artistDetailReady(artist, QVariantList(), QVariantList());
    });

    // 热门歌曲。⚠️ order 是必需参数，不带会 400
    QVariantMap params;
    params[QStringLiteral("id")]     = QString::number(id);
    params[QStringLiteral("offset")] = QStringLiteral("0");
    params[QStringLiteral("limit")]  = QString::number(songLimit);
    params[QStringLiteral("order")]  = QStringLiteral("hot");

    QNetworkReply *rs = get(QStringLiteral("/api/v1/artist/songs"), params);
    connect(rs, &QNetworkReply::finished, this, [this, rs]() {
        rs->deleteLater();
        if (rs->error() != QNetworkReply::NoError) {
            fail(QStringLiteral("歌手歌曲"), rs->errorString());
            return;
        }
        const QJsonObject o = QJsonDocument::fromJson(rs->readAll()).object();
        QVariantList songs, albums;
        QSet<qint64> seenAlbum;
        int idx = 1;
        for (const QJsonValue &v : o.value(QStringLiteral("songs")).toArray()) {
            QVariantMap s = normalizeSong(v.toObject().toVariantMap());
            s[QStringLiteral("index")] = idx++;
            songs << s;
            // 专辑列表没有可用端点（/api/artist/albums 返回 400），
            // 直接从歌曲里按 albumId 去重推出来
            const qint64 aid = s.value(QStringLiteral("albumId")).toLongLong();
            if (aid > 0 && !seenAlbum.contains(aid)) {
                seenAlbum.insert(aid);
                QVariantMap al;
                al[QStringLiteral("id")]    = aid;
                al[QStringLiteral("name")]  = s.value(QStringLiteral("album"));
                al[QStringLiteral("cover")] =
                    withSize(s.value(QStringLiteral("cover")).toString()
                                 .section(QLatin1Char('?'), 0, 0), 336);
                al[QStringLiteral("author")] = s.value(QStringLiteral("artist"));
                al[QStringLiteral("count")]  = 0;
                albums << al;
            }
        }
        emit artistDetailReady(QVariantMap(), songs, albums);
    });
}

void NcmApi::loadAlbumDetail(qint64 id)
{
    QNetworkReply *r = get(QStringLiteral("/api/v1/album/%1").arg(id));
    connect(r, &QNetworkReply::finished, this, [this, r]() {
        r->deleteLater();
        if (r->error() != QNetworkReply::NoError) {
            fail(QStringLiteral("专辑"), r->errorString());
            return;
        }
        const QJsonObject o = QJsonDocument::fromJson(r->readAll()).object();
        const QJsonObject a = o.value(QStringLiteral("album")).toObject();
        if (a.isEmpty()) {
            fail(QStringLiteral("专辑"), QStringLiteral("返回为空"));
            return;
        }
        QVariantMap album;
        album[QStringLiteral("id")]    = a.value(QStringLiteral("id")).toVariant();
        album[QStringLiteral("name")]  = a.value(QStringLiteral("name")).toString();
        album[QStringLiteral("cover")] =
            withSize(a.value(QStringLiteral("picUrl")).toString(), 440);
        album[QStringLiteral("description")] =
            a.value(QStringLiteral("description")).toString();
        album[QStringLiteral("company")] = a.value(QStringLiteral("company")).toString();
        const QJsonObject ar = a.value(QStringLiteral("artist")).toObject();
        album[QStringLiteral("author")] = ar.value(QStringLiteral("name")).toString();
        album[QStringLiteral("authorId")] = ar.value(QStringLiteral("id")).toVariant();
        const qint64 pt = a.value(QStringLiteral("publishTime")).toVariant().toLongLong();
        album[QStringLiteral("publishTime")] = pt > 0
            ? QDateTime::fromMSecsSinceEpoch(pt).toString(QStringLiteral("yyyy-MM-dd 发行"))
            : QString();

        QVariantList songs;
        int idx = 1;
        for (const QJsonValue &v : o.value(QStringLiteral("songs")).toArray()) {
            QVariantMap s = normalizeSong(v.toObject().toVariantMap());
            s[QStringLiteral("index")] = idx++;
            songs << s;
        }
        album[QStringLiteral("songs")] = songs;
        emit albumDetailReady(album);
    });
}

// ─────────────────────────────────────────────────────────
//  私人 FM
// ─────────────────────────────────────────────────────────

void NcmApi::loadPersonalFm(int count)
{
    Q_UNUSED(count)
    // 注意：这个接口只在 music.163.com 上有，interface.music.163.com 返回 404
    QNetworkReply *r = get(QStringLiteral("/api/v1/radio/get"), {}, kBaseMusic);
    connect(r, &QNetworkReply::finished, this, [this, r]() {
        r->deleteLater();
        if (r->error() != QNetworkReply::NoError) {
            fail(QStringLiteral("私人FM"), r->errorString());
            return;
        }
        const QJsonObject o = QJsonDocument::fromJson(r->readAll()).object();
        QVariantList list;
        for (const QJsonValue &v : o.value(QStringLiteral("data")).toArray())
            list << normalizeSong(v.toObject().toVariantMap());
        emit personalFmReady(list);
    });
}

// ─────────────────────────────────────────────────────────
//  播客 / 电台
// ─────────────────────────────────────────────────────────

void NcmApi::loadSubscribedRadios(int limit)
{
    if (userId() <= 0)
        return;
    QVariantMap params;
    params[QStringLiteral("limit")]  = QString::number(limit);
    params[QStringLiteral("offset")] = QStringLiteral("0");
    params[QStringLiteral("total")]  = QStringLiteral("true");

    QNetworkReply *r = get(QStringLiteral("/api/djradio/get/subed"), params);
    connect(r, &QNetworkReply::finished, this, [this, r]() {
        r->deleteLater();
        if (r->error() != QNetworkReply::NoError) {
            fail(QStringLiteral("我的播客"), r->errorString());
            return;
        }
        const QJsonObject o = QJsonDocument::fromJson(r->readAll()).object();
        QVariantList list;
        for (const QJsonValue &v : o.value(QStringLiteral("djRadios")).toArray())
            list << normalizePlaylist(v.toObject().toVariantMap());
        emit subscribedRadiosReady(list);
    });
}

void NcmApi::loadRadioDetail(qint64 id, int limit)
{
    // 电台节目列表：/api/v4/dj/program/byradio?radioId=<id>
    QVariantMap p2;
    p2[QStringLiteral("radioId")] = QString::number(id);
    p2[QStringLiteral("offset")]  = QStringLiteral("0");
    p2[QStringLiteral("limit")]   = QString::number(limit);
    p2[QStringLiteral("asc")]     = QStringLiteral("false");

    QNetworkReply *r = get(QStringLiteral("/api/v4/dj/program/byradio"), p2);
    connect(r, &QNetworkReply::finished, this, [this, r]() {
        r->deleteLater();
        if (r->error() != QNetworkReply::NoError) {
            fail(QStringLiteral("电台"), r->errorString());
            return;
        }
        const QJsonObject o = QJsonDocument::fromJson(r->readAll()).object();
        QVariantList programs;
        int idx = 1;
        for (const QJsonValue &v : o.value(QStringLiteral("programs")).toArray()) {
            const QJsonObject p = v.toObject();
            QVariantMap s = normalizeSong(p.toVariantMap());
            s[QStringLiteral("programId")] = p.value(QStringLiteral("id")).toVariant();
            s[QStringLiteral("index")]     = idx++;
            s[QStringLiteral("description")] = p.value(QStringLiteral("description")).toString();
            programs << s;
        }
        emit radioDetailReady(QVariantMap(), programs);
    });
}

// ─────────────────────────────────────────────────────────
//  评论
// ─────────────────────────────────────────────────────────

void NcmApi::loadComments(qint64 songId, int offset, int limit)
{
    QVariantMap params;
    params[QStringLiteral("offset")]      = QString::number(offset);
    params[QStringLiteral("limit")]       = QString::number(limit);
    params[QStringLiteral("total")]       = QStringLiteral("true");
    const QString path =
        QStringLiteral("/api/v1/resource/comments/R_SO_4_%1").arg(songId);

    QNetworkReply *r = get(path, params);
    connect(r, &QNetworkReply::finished, this, [this, r, songId]() {
        r->deleteLater();
        if (r->error() != QNetworkReply::NoError) {
            fail(QStringLiteral("评论"), r->errorString());
            return;
        }
        const QJsonObject o = QJsonDocument::fromJson(r->readAll()).object();
        // 点赞接口要的是 threadId（R_SO_4_<id>），不是歌曲 id。
        // 服务端在每条评论里也带了一份，但热评/普通评里偶尔缺失，所以这里用请求路径兜底。
        const QString threadId = QStringLiteral("R_SO_4_%1").arg(songId);

        auto conv = [&threadId](const QJsonArray &arr) {
            QVariantList out;
            for (const QJsonValue &v : arr) {
                const QJsonObject c = v.toObject();
                const QJsonObject u = c.value(QStringLiteral("user")).toObject();
                QVariantMap m;
                m[QStringLiteral("id")]       = c.value(QStringLiteral("commentId")).toVariant();
                m[QStringLiteral("content")]  = c.value(QStringLiteral("content")).toString();
                m[QStringLiteral("time")]     = c.value(QStringLiteral("time")).toVariant();
                m[QStringLiteral("likedCount")] =
                    c.value(QStringLiteral("likedCount")).toInt();
                m[QStringLiteral("liked")]    = c.value(QStringLiteral("liked")).toBool();
                m[QStringLiteral("threadId")] =
                    c.value(QStringLiteral("threadId")).toString().isEmpty()
                        ? threadId : c.value(QStringLiteral("threadId")).toString();
                m[QStringLiteral("userId")]   = u.value(QStringLiteral("userId")).toVariant();
                m[QStringLiteral("userName")] = u.value(QStringLiteral("nickname")).toString();
                m[QStringLiteral("avatar")]   =
                    withSize(u.value(QStringLiteral("avatarUrl")).toString(), 64);
                m[QStringLiteral("location")] = c.value(QStringLiteral("ipLocation"))
                                                    .toObject()
                                                    .value(QStringLiteral("location")).toString();

                // 「回复 @xxx：yyy」—— 官方把它画成引用块，这里先拆成两个字段给 QML
                const QJsonArray be = c.value(QStringLiteral("beReplied")).toArray();
                if (!be.isEmpty()) {
                    const QJsonObject b = be.first().toObject();
                    m[QStringLiteral("replyTo")] =
                        b.value(QStringLiteral("user")).toObject()
                            .value(QStringLiteral("nickname")).toString();
                    m[QStringLiteral("replyContent")] =
                        b.value(QStringLiteral("content")).toString();
                }
                out << m;
            }
            return out;
        };

        emit commentsReady(songId,
                           conv(o.value(QStringLiteral("hotComments")).toArray()),
                           conv(o.value(QStringLiteral("comments")).toArray()),
                           o.value(QStringLiteral("total")).toInt());
    });
}

// ─────────────────────────────────────────────────────────
//  喜欢
// ─────────────────────────────────────────────────────────

void NcmApi::likeSong(qint64 id, bool like)
{
    QVariantMap params;
    params[QStringLiteral("trackId")] = QString::number(id);
    params[QStringLiteral("like")]    = like ? QStringLiteral("true") : QStringLiteral("false");

    QNetworkReply *r = post(QStringLiteral("/api/song/like"), params);
    connect(r, &QNetworkReply::finished, this, [this, r, id, like]() {
        r->deleteLater();
        if (r->error() != QNetworkReply::NoError) {
            fail(QStringLiteral("喜欢"), r->errorString());
            return;
        }
        const QJsonObject o = QJsonDocument::fromJson(r->readAll()).object();
        const int code = o.value(QStringLiteral("code")).toInt();
        if (code == 200) {
            emit likeChanged(id, like);
        } else {
            // 301 / 未登录 等
            fail(QStringLiteral("喜欢"),
                 o.value(QStringLiteral("message")).toString().isEmpty()
                     ? QStringLiteral("需要登录后才能操作（code %1）").arg(code)
                     : o.value(QStringLiteral("message")).toString());
            emit likeChanged(id, !like);   // 回滚 UI
        }
    });
}

void NcmApi::loadLikelist()
{
    if (userId() <= 0)
        return;
    QVariantMap params;
    params[QStringLiteral("uid")] = QString::number(userId());

    QNetworkReply *r = get(QStringLiteral("/api/song/like/get"), params);
    connect(r, &QNetworkReply::finished, this, [this, r]() {
        r->deleteLater();
        if (r->error() != QNetworkReply::NoError)
            return;                       // 静默：拿不到就用本地缓存
        const QJsonObject o = QJsonDocument::fromJson(r->readAll()).object();
        QVariantList ids;
        for (const QJsonValue &v : o.value(QStringLiteral("ids")).toArray())
            ids << v.toVariant();
        if (!ids.isEmpty())
            emit likelistReady(ids);
    });
}

// ─────────────────────────────────────────────────────────
//  搜索
// ─────────────────────────────────────────────────────────

void NcmApi::search(const QString &keyword, int type, int limit, int offset)
{
    if (keyword.trimmed().isEmpty())
        return;

    QVariantMap params;
    params[QStringLiteral("s")]      = keyword;
    params[QStringLiteral("type")]   = QString::number(type);
    params[QStringLiteral("limit")]  = QString::number(limit);
    params[QStringLiteral("offset")] = QString::number(offset);
    params[QStringLiteral("total")]  = QStringLiteral("true");

    QNetworkReply *r = post(QStringLiteral("/api/cloudsearch/pc"), params);
    connect(r, &QNetworkReply::finished, this, [this, r]() {
        r->deleteLater();
        if (r->error() != QNetworkReply::NoError) {
            fail(QStringLiteral("搜索"), r->errorString());
            return;
        }
        const QJsonObject o = QJsonDocument::fromJson(r->readAll()).object();
        const QJsonObject res = o.value(QStringLiteral("result")).toObject();
        QVariantList songs;
        int idx = 1;
        for (const QJsonValue &v : res.value(QStringLiteral("songs")).toArray()) {
            QVariantMap s = normalizeSong(v.toObject().toVariantMap());
            s[QStringLiteral("index")] = idx++;     // 表格里要显示序号
            songs << s;
        }
        emit searchReady(songs, res.value(QStringLiteral("songCount")).toInt());
    });
}

// 搜索页要分 tab，所以一次性把四种类型都取回来
void NcmApi::searchAll(const QString &keyword, int limitEach)
{
    if (keyword.trimmed().isEmpty())
        return;

    struct Agg {
        QVariantMap res;
        int pending = 4;
    };
    auto agg = QSharedPointer<Agg>::create();

    const QVector<QPair<int, QString>> kinds = {
        { 1,    QStringLiteral("songs")     },
        { 100,  QStringLiteral("artists")   },
        { 10,   QStringLiteral("albums")    },
        { 1000, QStringLiteral("playlists") }
    };

    for (const auto &k : kinds) {
        QVariantMap params;
        params[QStringLiteral("s")]     = keyword;
        params[QStringLiteral("type")]  = QString::number(k.first);
        params[QStringLiteral("limit")] = QString::number(limitEach);
        params[QStringLiteral("offset")] = QStringLiteral("0");
        params[QStringLiteral("total")] = QStringLiteral("true");

        QNetworkReply *r = post(QStringLiteral("/api/cloudsearch/pc"), params);
        connect(r, &QNetworkReply::finished, this, [this, r, agg, k, keyword]() {
            r->deleteLater();
            if (r->error() == QNetworkReply::NoError) {
                const QJsonObject o = QJsonDocument::fromJson(r->readAll()).object();
                const QJsonObject res = o.value(QStringLiteral("result")).toObject();
                QVariantList list;

                if (k.first == 1) {                    // 单曲
                    int idx = 1;
                    for (const QJsonValue &v : res.value(QStringLiteral("songs")).toArray()) {
                        QVariantMap s = normalizeSong(v.toObject().toVariantMap());
                        s[QStringLiteral("index")] = idx++;
                        list << s;
                    }
                    agg->res[QStringLiteral("songCount")] =
                        res.value(QStringLiteral("songCount")).toInt();
                } else if (k.first == 100) {           // 歌手
                    for (const QJsonValue &v : res.value(QStringLiteral("artists")).toArray()) {
                        const QJsonObject a = v.toObject();
                        QVariantMap m;
                        m[QStringLiteral("id")]     = a.value(QStringLiteral("id")).toVariant();
                        m[QStringLiteral("name")]   = a.value(QStringLiteral("name")).toString();
                        m[QStringLiteral("cover")]  =
                            withSize(a.value(QStringLiteral("picUrl")).toString(), 168);
                        m[QStringLiteral("alias")]  =
                            a.value(QStringLiteral("alias")).toArray().isEmpty()
                                ? QString()
                                : a.value(QStringLiteral("alias")).toArray().first().toString();
                        m[QStringLiteral("count")]  =
                            a.value(QStringLiteral("albumSize")).toInt();
                        list << m;
                    }
                } else if (k.first == 10) {            // 专辑
                    for (const QJsonValue &v : res.value(QStringLiteral("albums")).toArray()) {
                        const QJsonObject a = v.toObject();
                        const QJsonObject ar = a.value(QStringLiteral("artist")).toObject();
                        QVariantMap m;
                        m[QStringLiteral("id")]     = a.value(QStringLiteral("id")).toVariant();
                        m[QStringLiteral("name")]   = a.value(QStringLiteral("name")).toString();
                        m[QStringLiteral("cover")]  =
                            withSize(a.value(QStringLiteral("picUrl")).toString(), 168);
                        m[QStringLiteral("author")] = ar.value(QStringLiteral("name")).toString();
                        m[QStringLiteral("authorId")] = ar.value(QStringLiteral("id")).toVariant();
                        m[QStringLiteral("count")]  =
                            a.value(QStringLiteral("size")).toInt();
                        list << m;
                    }
                } else {                               // 歌单
                    for (const QJsonValue &v : res.value(QStringLiteral("playlists")).toArray())
                        list << normalizePlaylist(v.toObject().toVariantMap());
                }
                agg->res[k.second] = list;
            }
            if (--agg->pending == 0)
                emit searchAllReady(keyword, agg->res);
        });
    }
}

// ─────────────────────────────────────────────────────────
//  播放地址 / 歌词
// ─────────────────────────────────────────────────────────

void NcmApi::loadSongUrl(qint64 id, int maxBr)
{
    // 实测：GET /api/song/enhance/player/url?ids=[id]&br=<br> 可用
    // （带 /v1 的那个用 GET 会报"参数错误"）
    QVariantMap params;
    params[QStringLiteral("ids")] = jsonIds({ id });
    params[QStringLiteral("br")]  = QString::number(maxBr);

    QNetworkReply *r = get(QStringLiteral("/api/song/enhance/player/url"), params);
    connect(r, &QNetworkReply::finished, this, [this, r, id]() {
        r->deleteLater();
        if (r->error() != QNetworkReply::NoError) {
            fail(QStringLiteral("播放地址"), r->errorString());
            emit songUrlReady(id, QString(), 0);
            return;
        }
        const QJsonObject o = QJsonDocument::fromJson(r->readAll()).object();
        const QJsonArray data = o.value(QStringLiteral("data")).toArray();
        if (data.isEmpty()) {
            emit songUrlReady(id, QString(), 0);
            return;
        }
        const QJsonObject d = data.first().toObject();
        emit songUrlReady(id, d.value(QStringLiteral("url")).toString(),
                          d.value(QStringLiteral("br")).toInt());
    });
}

void NcmApi::loadLyric(qint64 id)
{
    QVariantMap params;
    params[QStringLiteral("id")] = QString::number(id);
    params[QStringLiteral("lv")] = QStringLiteral("-1");
    params[QStringLiteral("kv")] = QStringLiteral("-1");
    params[QStringLiteral("tv")] = QStringLiteral("-1");

    QNetworkReply *r = get(QStringLiteral("/api/song/lyric/v1"), params);
    connect(r, &QNetworkReply::finished, this, [this, r, id]() {
        r->deleteLater();
        if (r->error() != QNetworkReply::NoError) {
            fail(QStringLiteral("歌词"), r->errorString());
            emit lyricReady(id, QVariantList());
            return;
        }
        const QJsonObject o = QJsonDocument::fromJson(r->readAll()).object();
        const QString lrc = o.value(QStringLiteral("lrc")).toObject()
                                .value(QStringLiteral("lyric")).toString();
        const QString tr  = o.value(QStringLiteral("tlyric")).toObject()
                                .value(QStringLiteral("lyric")).toString();
        emit lyricReady(id, parseLyric(lrc, tr));
    });
}
