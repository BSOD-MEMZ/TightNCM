#include "AudioPlayer.h"

#include <QMediaContent>
#include <QUrl>
#include <QTimer>

AudioPlayer::AudioPlayer(QObject *parent)
    : QObject(parent)
{
    m_player.setVolume(70);
    m_targetVolume = 70;

    m_fadeTimer = new QTimer(this);
    m_fadeTimer->setInterval(20);          // 20ms 一档，300ms 走完约 15 档
    connect(m_fadeTimer, &QTimer::timeout, this, [this]() {
        const int v = m_player.volume() + m_fadeStep;
        const bool done = (m_fadeStep > 0) ? (v >= m_fadeDest) : (v <= m_fadeDest);
        if (done) {
            finishFade();
        } else {
            m_player.setVolume(qBound(0, v, 100));
        }
    });

    connect(&m_player, &QMediaPlayer::positionChanged, this, [this](qint64) {
        emit positionChanged();
    });
    connect(&m_player, &QMediaPlayer::durationChanged, this, [this](qint64) {
        emit durationChanged();
    });
    // 注意：不转发 m_player.volumeChanged —— 淡入淡出时它每 20ms 变一次，
    // 会让 QML 侧的绑定疯狂重算。音量变化只由 setVolume() 主动通知。
    connect(&m_player, &QMediaPlayer::stateChanged, this,
            [this](QMediaPlayer::State st) {
        switch (st) {
        case QMediaPlayer::PlayingState: setStateName(QStringLiteral("playing")); break;
        case QMediaPlayer::PausedState:  setStateName(QStringLiteral("paused"));  break;
        default:                         setStateName(QStringLiteral("stopped")); break;
        }
    });
    connect(&m_player, &QMediaPlayer::mediaStatusChanged, this,
            [this](QMediaPlayer::MediaStatus st) {
        switch (st) {
        case QMediaPlayer::LoadingMedia:
        case QMediaPlayer::BufferingMedia:
            if (m_stateName != QLatin1String("playing"))
                setStateName(QStringLiteral("loading"));
            break;
        case QMediaPlayer::EndOfMedia:
            emit mediaFinished();
            break;
        case QMediaPlayer::InvalidMedia:
            m_errorText = QStringLiteral("无法播放（可能是链接失效或格式不支持）");
            emit errorTextChanged();
            setStateName(QStringLiteral("error"));
            break;
        default:
            break;
        }
    });
#if QT_VERSION >= QT_VERSION_CHECK(5, 15, 0)
    connect(&m_player, QOverload<QMediaPlayer::Error>::of(&QMediaPlayer::error),
            this, [this](QMediaPlayer::Error) {
        m_errorText = m_player.errorString();
        emit errorTextChanged();
        setStateName(QStringLiteral("error"));
    });
#endif
}

void AudioPlayer::setStateName(const QString &s)
{
    if (m_stateName == s)
        return;
    m_stateName = s;
    emit stateNameChanged();
}

void AudioPlayer::setFadeEnabled(bool v)
{
    if (m_fadeEnabled == v)
        return;
    m_fadeEnabled = v;
    if (!v && m_fadeTimer->isActive()) {      // 关掉时把音量立刻归位，别停在半截
        m_fadeTimer->stop();
        m_pauseAfterFade = false;
        m_player.setVolume(m_targetVolume);
    }
    emit fadeEnabledChanged();
}

void AudioPlayer::finishFade()
{
    m_fadeTimer->stop();
    m_player.setVolume(m_fadeDest);
    if (m_fadeDest == 0 && m_pauseAfterFade) {
        m_pauseAfterFade = false;
        m_player.pause();
    }
}

// 线性音量包络。ms 是总时长，按 20ms 一档算每档步长（至少 ±1）。
void AudioPlayer::fadeTo(int dest, int ms)
{
    m_fadeDest = qBound(0, dest, 100);
    if (!m_fadeEnabled || ms <= 0 || m_player.volume() == m_fadeDest) {
        finishFade();
        return;
    }
    const int from = m_player.volume();
    const int steps = qMax(1, ms / m_fadeTimer->interval());
    m_fadeStep = (m_fadeDest > from) ? qMax(1, (m_fadeDest - from) / steps)
                                     : qMin(-1, (m_fadeDest - from) / steps);
    m_fadeTimer->start();
}

void AudioPlayer::playUrl(const QString &url)
{
    if (url.isEmpty()) {
        m_errorText = QStringLiteral("拿不到播放地址");
        emit errorTextChanged();
        setStateName(QStringLiteral("error"));
        return;
    }
    m_errorText.clear();
    emit errorTextChanged();

    m_source = url;
    emit sourceChanged();

    setStateName(QStringLiteral("loading"));
    m_fadeTimer->stop();
    m_pauseAfterFade = false;
    // 淡入：先降到 0 再爬回目标音量（只在开启时生效）
    m_player.setVolume(m_fadeEnabled ? 0 : m_targetVolume);
    m_player.setMedia(QMediaContent(QUrl(url)));
    m_player.play();
    if (m_fadeEnabled)
        QTimer::singleShot(1, this, [this]() { fadeTo(m_targetVolume, 350); });
}

void AudioPlayer::togglePause()
{
    if (m_player.state() == QMediaPlayer::PlayingState)
        pause();
    else
        resume();
}

void AudioPlayer::pause()
{
    if (m_fadeEnabled && m_player.state() == QMediaPlayer::PlayingState) {
        m_pauseAfterFade = true;
        fadeTo(0, 220);             // 淡出到 0 之后再真正 pause（见 finishFade）
        return;
    }
    m_player.pause();
}

void AudioPlayer::resume()
{
    if (m_fadeEnabled) {
        m_player.setVolume(0);
        m_player.play();
        QTimer::singleShot(1, this, [this]() { fadeTo(m_targetVolume, 300); });
        return;
    }
    m_player.play();
}

void AudioPlayer::stop()
{
    m_fadeTimer->stop();
    m_pauseAfterFade = false;
    m_player.stop();
    m_player.setVolume(m_targetVolume);
    setStateName(QStringLiteral("idle"));
}

void AudioPlayer::restart()
{
    m_player.setPosition(0);
    if (m_player.state() != QMediaPlayer::PlayingState)
        resume();
}

void AudioPlayer::seek(qint64 ms)
{
    m_player.setPosition(qMax<qint64>(0, qMin(ms, m_player.duration())));
}

void AudioPlayer::setVolume(int v)
{
    // 这里只记「用户想要多大」，真正写进播放器的是包络后的值
    m_targetVolume = qBound(0, v, 100);
    if (!m_fadeTimer->isActive())
        m_player.setVolume(m_targetVolume);
    emit volumeChanged();
}
