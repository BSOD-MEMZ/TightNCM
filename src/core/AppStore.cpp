#include "AppStore.h"

#include <QSettings>
#include <QVariantMap>

namespace {
const int kMaxRecent = 200;
}

AppStore::AppStore(QObject *parent)
    : QObject(parent)
{
    QSettings s;
    m_volume   = s.value(QStringLiteral("player/volume"), 70).toInt();
    m_playMode = s.value(QStringLiteral("player/playMode"), QStringLiteral("loop")).toString();
    m_recent   = s.value(QStringLiteral("player/recent")).toList();

    const QVariantList liked = s.value(QStringLiteral("player/liked")).toList();
    for (const QVariant &v : liked)
        m_liked.insert(v.toLongLong());

    // 设置项
    m_resumeLastProgress  = s.value(QStringLiteral("setting/resumeLastProgress"), true).toBool();
    m_autoplayOnStart     = s.value(QStringLiteral("setting/autoplayOnStart"), false).toBool();
    m_fadeInOut           = s.value(QStringLiteral("setting/fadeInOut"), false).toBool();
    m_notifyOnTrackChange = s.value(QStringLiteral("setting/notifyOnTrackChange"), false).toBool();
    m_downloadDir         = s.value(QStringLiteral("setting/downloadDir")).toString();
    m_downloadQuality     = s.value(QStringLiteral("setting/downloadQuality"), 1).toInt();
    m_downloadThreads     = s.value(QStringLiteral("setting/downloadThreads"), 3).toInt();
    m_lastPlayed          = s.value(QStringLiteral("player/lastPlayed")).toMap();
}

// ── 设置项 ───────────────────────────────────────────────
// 这一批 setter 长得一样，用宏收一下，省得二十行重复。
#define TNC_BOOL_SETTING(fn, field, sig, key)                         void AppStore::fn(bool v) {                                           if (field == v) return;                                           field = v;                                                        QSettings().setValue(QStringLiteral("setting/" key), v);          emit sig();                                                   }

TNC_BOOL_SETTING(setResumeLastProgress, m_resumeLastProgress, resumeLastProgressChanged, "resumeLastProgress")
TNC_BOOL_SETTING(setAutoplayOnStart,    m_autoplayOnStart,    autoplayOnStartChanged,    "autoplayOnStart")
TNC_BOOL_SETTING(setFadeInOut,          m_fadeInOut,          fadeInOutChanged,          "fadeInOut")
TNC_BOOL_SETTING(setNotifyOnTrackChange, m_notifyOnTrackChange, notifyOnTrackChangeChanged, "notifyOnTrackChange")

#undef TNC_BOOL_SETTING

void AppStore::setDownloadDir(const QString &v)
{
    if (m_downloadDir == v) return;
    m_downloadDir = v;
    QSettings().setValue(QStringLiteral("setting/downloadDir"), v);
    emit downloadDirChanged();
}

void AppStore::setDownloadQuality(int v)
{
    v = qBound(0, v, 2);
    if (m_downloadQuality == v) return;
    m_downloadQuality = v;
    QSettings().setValue(QStringLiteral("setting/downloadQuality"), v);
    emit downloadQualityChanged();
}

void AppStore::setDownloadThreads(int v)
{
    v = qBound(1, v, 10);
    if (m_downloadThreads == v) return;
    m_downloadThreads = v;
    QSettings().setValue(QStringLiteral("setting/downloadThreads"), v);
    emit downloadThreadsChanged();
}

void AppStore::saveLastPlayed(const QVariantMap &song, qint64 positionMs)
{
    if (song.isEmpty() || song.value(QStringLiteral("id")).toLongLong() <= 0)
        return;

    QVariantMap slim;
    static const char *keys[] = { "id", "name", "artist", "cover", "album", "duration" };
    for (const char *k : keys) {
        if (song.contains(QLatin1String(k)))
            slim.insert(QLatin1String(k), song.value(QLatin1String(k)));
    }
    slim[QStringLiteral("position")] = positionMs;

    m_lastPlayed = slim;
    QSettings().setValue(QStringLiteral("player/lastPlayed"), slim);
    emit lastPlayedChanged();
}

void AppStore::clearLastPlayed()
{
    if (m_lastPlayed.isEmpty()) return;
    m_lastPlayed.clear();
    QSettings().setValue(QStringLiteral("player/lastPlayed"), QVariantMap());
    emit lastPlayedChanged();
}

void AppStore::setVolume(int v){
    v = qBound(0, v, 100);
    if (m_volume == v)
        return;
    m_volume = v;
    QSettings().setValue(QStringLiteral("player/volume"), v);
    emit volumeChanged();
}

void AppStore::setPlayMode(const QString &m)
{
    if (m_playMode == m)
        return;
    m_playMode = m;
    QSettings().setValue(QStringLiteral("player/playMode"), m);
    emit playModeChanged();
}

// ── 喜欢 ─────────────────────────────────────────────────

bool AppStore::isLiked(qint64 id) const
{
    return m_liked.contains(id);
}

void AppStore::setLiked(qint64 id, bool liked)
{
    if (liked)
        m_liked.insert(id);
    else
        m_liked.remove(id);

    QVariantList out;
    for (qint64 x : m_liked)
        out << x;
    QSettings().setValue(QStringLiteral("player/liked"), out);
    emit likeRevisionChanged();
}

void AppStore::mergeLikedIds(const QVariantList &ids)
{
    for (const QVariant &v : ids)
        m_liked.insert(v.toLongLong());

    QVariantList out;
    for (qint64 x : m_liked)
        out << x;
    QSettings().setValue(QStringLiteral("player/liked"), out);
    emit likeRevisionChanged();
}

// 服务端返回的喜欢集合应当**整体替换**本地那份，而不是并集。
// 用并集的话换账号之后上一个账号的红心会一直留在本地（看起来像「喜欢串号」）。
void AppStore::setLikedIds(const QVariantList &ids)
{
    QSet<qint64> fresh;
    for (const QVariant &v : ids)
        fresh.insert(v.toLongLong());
    if (fresh == m_liked)
        return;
    m_liked = fresh;
    QVariantList out;
    for (qint64 x : m_liked)
        out << x;
    QSettings().setValue(QStringLiteral("player/liked"), out);
    emit likeRevisionChanged();
}

void AppStore::clearLiked()
{
    if (m_liked.isEmpty())
        return;
    m_liked.clear();
    QSettings().setValue(QStringLiteral("player/liked"), QVariantList());
    emit likeRevisionChanged();
}

QVariantList AppStore::likedIds() const
{
    QVariantList out;
    for (qint64 x : m_liked)
        out << x;
    return out;
}

// ── 播放历史 ─────────────────────────────────────────────

void AppStore::addRecent(const QVariantMap &song)
{
    const qint64 id = song.value(QStringLiteral("id")).toLongLong();
    if (id <= 0)
        return;

    // 已经在列表里就先摘掉，重新插到最前面（去重 + 置顶）
    for (int i = 0; i < m_recent.size(); ++i) {
        if (m_recent.at(i).toMap().value(QStringLiteral("id")).toLongLong() == id) {
            m_recent.removeAt(i);
            break;
        }
    }

    // 只留展示需要的字段，别把整个 JSON 塞进 QSettings
    QVariantMap slim;
    static const char *keys[] = { "id", "name", "artist", "cover", "album",
                                  "albumId", "duration", "quality", "fee" };
    for (const char *k : keys) {
        if (song.contains(QLatin1String(k)))
            slim.insert(QLatin1String(k), song.value(QLatin1String(k)));
    }
    slim[QStringLiteral("index")] = 1;

    m_recent.prepend(slim);
    while (m_recent.size() > kMaxRecent)
        m_recent.removeLast();

    // 重新编号，历史列表也要有序号
    for (int i = 0; i < m_recent.size(); ++i) {
        QVariantMap m = m_recent.at(i).toMap();
        m[QStringLiteral("index")] = i + 1;
        m_recent[i] = m;
    }

    QSettings().setValue(QStringLiteral("player/recent"), m_recent);
    emit recentSongsChanged();
}

void AppStore::clearRecent()
{
    m_recent.clear();
    QSettings().setValue(QStringLiteral("player/recent"), m_recent);
    emit recentSongsChanged();
}
