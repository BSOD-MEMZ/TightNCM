// AppStore —— 本地持久化（音量 / 播放模式 / 喜欢的歌 / 播放历史）
//
// 用 QSettings 存。为什么不直接上 Qt.labs.settings：
// windeployqt 在这个 Qt 安装上会提前中止，`Qt/labs/settings` 模块不一定被部署，
// 一旦缺了 QML 侧会静默失效。用 C++ 侧写死更可靠，也能顺手做去重 / 截断。
#pragma once

#include <QObject>
#include <QVariantList>
#include <QSet>

class AppStore : public QObject
{
    Q_OBJECT
    Q_PROPERTY(int     volume   READ volume   WRITE setVolume   NOTIFY volumeChanged)
    Q_PROPERTY(QString playMode READ playMode WRITE setPlayMode NOTIFY playModeChanged)
    Q_PROPERTY(QVariantList recentSongs READ recentSongs NOTIFY recentSongsChanged)
    // 「喜欢」集合是 QSet，QML 侧看不到变化。用一个自增版本号当绑定依赖：
    // QML 里写 `Store.likeRevision; Store.isLiked(id)` 就能在被改动后自动刷新。
    Q_PROPERTY(int     likeRevision READ likeRevision NOTIFY likeRevisionChanged)

    // ── 设置项（设置页里的开关，全部持久化） ────────────────
    Q_PROPERTY(bool resumeLastProgress READ resumeLastProgress WRITE setResumeLastProgress
               NOTIFY resumeLastProgressChanged)
    Q_PROPERTY(bool autoplayOnStart    READ autoplayOnStart   WRITE setAutoplayOnStart
               NOTIFY autoplayOnStartChanged)
    Q_PROPERTY(bool fadeInOut          READ fadeInOut         WRITE setFadeInOut
               NOTIFY fadeInOutChanged)
    Q_PROPERTY(bool notifyOnTrackChange READ notifyOnTrackChange WRITE setNotifyOnTrackChange
               NOTIFY notifyOnTrackChangeChanged)
    Q_PROPERTY(QString downloadDir     READ downloadDir       WRITE setDownloadDir
               NOTIFY downloadDirChanged)
    Q_PROPERTY(int     downloadQuality READ downloadQuality   WRITE setDownloadQuality
               NOTIFY downloadQualityChanged)
    Q_PROPERTY(int     downloadThreads READ downloadThreads   WRITE setDownloadThreads
               NOTIFY downloadThreadsChanged)

    // 上次播放到哪（「记住上次播放进度」用）
    Q_PROPERTY(QVariantMap lastPlayed READ lastPlayed NOTIFY lastPlayedChanged)

public:
    explicit AppStore(QObject *parent = nullptr);

    int     volume()   const { return m_volume; }
    QString playMode() const { return m_playMode; }
    QVariantList recentSongs() const { return m_recent; }
    int     likeRevision() const { return m_likeRevision; }

    // ⚠️ 这两个必须带 Q_INVOKABLE：Q_PROPERTY 的 WRITE setter 默认**不是**可调用方法，
    // QML 里写 `Store.setPlayMode(x)` 会抛 "not a function"（踩过：播放模式点不动、音量没持久化）。
    Q_INVOKABLE void setVolume(int v);
    Q_INVOKABLE void setPlayMode(const QString &m);

    // ── 喜欢（本地集合 + 服务端同步过来的并集） ──────────
    Q_INVOKABLE bool isLiked(qint64 id) const;
    Q_INVOKABLE void setLiked(qint64 id, bool liked);
    Q_INVOKABLE void mergeLikedIds(const QVariantList &ids);   // 本地追加（未登录时用）
    Q_INVOKABLE void setLikedIds(const QVariantList &ids);     // 服务端为准，整体替换
    Q_INVOKABLE void clearLiked();                             // 退出登录/换号时清空
    Q_INVOKABLE QVariantList likedIds() const;

    // ── 播放历史 ─────────────────────────────────────────
    Q_INVOKABLE void addRecent(const QVariantMap &song);
    Q_INVOKABLE void clearRecent();

    // ── 设置 ─────────────────────────────────────────────
    bool    resumeLastProgress() const { return m_resumeLastProgress; }
    bool    autoplayOnStart()    const { return m_autoplayOnStart; }
    bool    fadeInOut()          const { return m_fadeInOut; }
    bool    notifyOnTrackChange()const { return m_notifyOnTrackChange; }
    QString downloadDir()        const { return m_downloadDir; }
    int     downloadQuality()    const { return m_downloadQuality; }
    int     downloadThreads()    const { return m_downloadThreads; }
    QVariantMap lastPlayed()     const { return m_lastPlayed; }

    void setResumeLastProgress(bool v);
    void setAutoplayOnStart(bool v);
    void setFadeInOut(bool v);
    void setNotifyOnTrackChange(bool v);
    void setDownloadDir(const QString &v);
    void setDownloadQuality(int v);
    void setDownloadThreads(int v);
    Q_INVOKABLE void saveLastPlayed(const QVariantMap &song, qint64 positionMs);
    Q_INVOKABLE void clearLastPlayed();

signals:
    void volumeChanged();
    void playModeChanged();
    void recentSongsChanged();
    void likeRevisionChanged();
    void resumeLastProgressChanged();
    void autoplayOnStartChanged();
    void fadeInOutChanged();
    void notifyOnTrackChangeChanged();
    void downloadDirChanged();
    void downloadQualityChanged();
    void downloadThreadsChanged();
    void lastPlayedChanged();

private:
    static QString key(qint64 id) { return QString::number(id); }

    int          m_volume = 70;
    QString      m_playMode = QStringLiteral("loop");
    int          m_likeRevision = 0;
    QSet<qint64> m_liked;
    QVariantList m_recent;      // 最近在前，最多 200 条

    bool    m_resumeLastProgress = true;
    bool    m_autoplayOnStart    = false;
    bool    m_fadeInOut          = false;
    bool    m_notifyOnTrackChange= false;
    QString m_downloadDir;
    int     m_downloadQuality    = 1;   // 0 标准 / 1 较高 / 2 无损
    int     m_downloadThreads    = 3;
    QVariantMap m_lastPlayed;
};
