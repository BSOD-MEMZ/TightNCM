// AudioPlayer —— 播放器封装
//
// 用 Qt5Multimedia 的 QMediaPlayer。Windows 上走 DirectShow 后端，
// MP3 / FLAC / M4A 都能解，Windows 7 也支持。
//
// 为什么不用 miniaudio：那需要自己处理 HTTPS 拉流 + 解码器，工作量大；
// QMediaPlayer 直接吃 URL 且能流式播放。以后如果想更省内存或要更精确的
// 时钟，可以换成 miniaudio + dr_mp3 自己接，接口保持不变即可。
#pragma once

#include <QObject>
#include <QMediaPlayer>

class QTimer;

class AudioPlayer : public QObject
{
    Q_OBJECT
    // "idle" | "loading" | "playing" | "paused" | "stopped" | "error"
    Q_PROPERTY(QString stateName READ stateName NOTIFY stateNameChanged)
    Q_PROPERTY(qint64  position  READ position  NOTIFY positionChanged)
    Q_PROPERTY(qint64  duration  READ duration  NOTIFY durationChanged)
    Q_PROPERTY(int     volume    READ volume    WRITE setVolume NOTIFY volumeChanged)
    Q_PROPERTY(QString source    READ source    NOTIFY sourceChanged)
    Q_PROPERTY(QString errorText READ errorText NOTIFY errorTextChanged)
    // 设置页的「音乐淡入淡出」：切歌/暂停时做一次音量包络
    Q_PROPERTY(bool fadeEnabled READ fadeEnabled WRITE setFadeEnabled NOTIFY fadeEnabledChanged)

public:
    explicit AudioPlayer(QObject *parent = nullptr);

    QString stateName() const { return m_stateName; }
    qint64  position()  const { return m_player.position(); }
    qint64  duration()  const { return m_player.duration(); }
    // 报「用户设定的音量」而不是包络中的瞬时值 —— 否则淡入淡出时
    // 界面上的音量条会跟着一跳一跳。
    int     volume()    const { return m_targetVolume; }
    QString source()    const { return m_source; }
    QString errorText() const { return m_errorText; }

    Q_INVOKABLE void playUrl(const QString &url);
    Q_INVOKABLE void togglePause();
    Q_INVOKABLE void pause();
    Q_INVOKABLE void resume();
    Q_INVOKABLE void stop();
    Q_INVOKABLE void restart();            // 回到 0 并继续播（单曲循环用）
    Q_INVOKABLE void seek(qint64 ms);
    Q_INVOKABLE void setVolume(int v);

    bool fadeEnabled() const { return m_fadeEnabled; }
    void setFadeEnabled(bool v);

signals:
    void stateNameChanged();
    void positionChanged();
    void durationChanged();
    void volumeChanged();
    void sourceChanged();
    void errorTextChanged();
    void mediaFinished();          // 播完一首，交给上层决定下一首
    void fadeEnabledChanged();

private:
    void setStateName(const QString &s);
    // 音量包络：从当前音量线性走到 target，ms 毫秒走完
    void fadeTo(int dest, int ms);
    void finishFade();

    QMediaPlayer m_player;
    bool m_fadeEnabled = false;
    int  m_targetVolume = 70;      // 用户设定的音量（包络结束后要回到这个值）
    int  m_fadeStep = 0;
    int  m_fadeDest = 70;      // 包络的目标值（与 m_targetVolume 分开，淡出时是 0）
    bool m_pauseAfterFade = false; // 淡出到 0 之后再真正 pause
    QTimer *m_fadeTimer = nullptr;
    QString m_source;
    QString m_stateName = QStringLiteral("idle");
    QString m_errorText;
};
