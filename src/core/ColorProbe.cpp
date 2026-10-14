#include "ColorProbe.h"

#include <QImage>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QRegularExpression>

ColorProbe::ColorProbe(QObject *parent)
    : QObject(parent)
{
}

void ColorProbe::probe(const QString &url)
{
    if (url.isEmpty() || url == m_lastUrl)
        return;
    m_lastUrl = url;

    // 封面原图动辄 1 MB，只取主色没必要 —— 把 ?param=WxH 压到 8x8。
    // 网易的图片服务认这个参数，压完只有几百字节。
    QString small = url;
    static const QRegularExpression re(QStringLiteral("param=\\d+y\\d+"));
    if (small.contains(re))
        small.replace(re, QStringLiteral("param=8y8"));
    else
        small += (small.contains(QLatin1Char('?')) ? QStringLiteral("&") : QStringLiteral("?"))
                 + QStringLiteral("param=8y8");

    QNetworkRequest req{ QUrl(small) };
    req.setAttribute(QNetworkRequest::FollowRedirectsAttribute, true);
    req.setHeader(QNetworkRequest::UserAgentHeader,
                  QStringLiteral("Mozilla/5.0 (Windows NT 10.0; Win64; x64)"));

    QNetworkReply *reply = m_nam.get(req);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();
        if (reply->error() != QNetworkReply::NoError)
            return;

        const QImage raw = QImage::fromData(reply->readAll());
        if (raw.isNull())
            return;

        // 先平滑缩到 8x8 再平均，避免直接缩到 1x1 的采样偏差
        const QImage tiny = raw.scaled(8, 8, Qt::IgnoreAspectRatio, Qt::SmoothTransformation);
        qint64 r = 0, g = 0, b = 0;
        int n = 0;
        for (int y = 0; y < tiny.height(); ++y) {
            for (int x = 0; x < tiny.width(); ++x) {
                const QRgb p = tiny.pixel(x, y);
                if (qAlpha(p) < 8)
                    continue;
                r += qRed(p);
                g += qGreen(p);
                b += qBlue(p);
                ++n;
            }
        }
        if (n == 0)
            return;

        emit sampled(QColor(int(r / n), int(g / n), int(b / n)));
    });
}
