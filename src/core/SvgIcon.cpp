#include "SvgIcon.h"

#include <QCache>
#include <QGuiApplication>
#include <QImage>
#include <QPainter>
#include <QQuickWindow>
#include <QSvgRenderer>
#include <QUrl>

namespace {

// 图标源图缓存上限（KB）。图标很小，8MB 够放几千个不同 (名字,尺寸) 组合。
constexpr int kSourceCacheKb = 4096;
// 着色结果缓存上限（KB）。
constexpr int kTintCacheKb = 8192;

// QSvgRenderer 持有解析后的 XML DOM，一个图标几 KB ~ 几十 KB。
// 只缓存**正在用**的那些：用 QCache 控制条目数。
QCache<QString, QSvgRenderer> &rendererCache()
{
    static QCache<QString, QSvgRenderer> c(96);   // 最多 96 个图标同时挂着
    return c;
}

QCache<QString, QImage> &sourceCache()
{
    static QCache<QString, QImage> c(kSourceCacheKb);
    return c;
}

QCache<QString, QImage> &tintCache()
{
    static QCache<QString, QImage> c(kTintCacheKb);
    return c;
}

QString iconPath(const QString &name)
{
    return QStringLiteral(":/icons/ncm_") + name + QStringLiteral(".svg");
}

// 把 SVG 按目标像素尺寸光栅成一张 ARGB32 图。
// 返回的图可能被缓存共享，调用方不要原地改。
const QImage *sourceImage(const QString &name, int w, int h)
{
    if (name.isEmpty() || w <= 0 || h <= 0)
        return nullptr;

    const QString key = name + QLatin1Char('@') + QString::number(w)
                      + QLatin1Char('x') + QString::number(h);
    if (const QImage *hit = sourceCache().object(key))
        return hit;

    const QString path = iconPath(name);
    QSvgRenderer *r = rendererCache().object(path);
    if (!r) {
        auto *nr = new QSvgRenderer(path);
        if (!nr->isValid()) {
            delete nr;
            return nullptr;
        }
        rendererCache().insert(path, nr);
        r = nr;
    }

    auto img = std::make_unique<QImage>(w, h, QImage::Format_ARGB32_Premultiplied);
    img->fill(Qt::transparent);
    {
        QPainter p(img.get());
        p.setRenderHint(QPainter::Antialiasing, true);
        p.setRenderHint(QPainter::SmoothPixmapTransform, true);
        r->render(&p, QRectF(0, 0, w, h));
    }
    sourceCache().insert(key, img.release(),
                         qMax(1, (w * h * 4) / 1024));   // 代价按 KB
    return sourceCache().object(key);
}

}   // namespace

SvgIcon::SvgIcon(QQuickItem *parent)
    : QQuickPaintedItem(parent)
{
    setAntialiasing(true);
    // 图标是 1:1 渲染的小图，开 mipmap 只会白占一层纹理
    setSmooth(false);
    setOpaquePainting(false);
    setFlag(QQuickItem::ItemHasContents, true);
}

void SvgIcon::setName(const QString &v)
{
    if (m_name == v)
        return;
    m_name = v;
    emit nameChanged();
    update();
}

void SvgIcon::setColor(const QColor &v)
{
    if (m_color == v)
        return;
    m_color = v;
    emit colorChanged();
    update();
}

void SvgIcon::setMulticolor(bool v)
{
    if (m_multicolor == v)
        return;
    m_multicolor = v;
    emit multicolorChanged();
    update();
}

void SvgIcon::paint(QPainter *painter)
{
    if (m_name.isEmpty() || width() <= 0 || height() <= 0)
        return;

    const qreal dpr = window() ? window()->devicePixelRatio() : qreal(1);
    const int pw = qMax(1, qRound(width() * dpr));
    const int ph = qMax(1, qRound(height() * dpr));

    const QImage *src = sourceImage(m_name, pw, ph);
    if (!src)
        return;

    // 双色图标（logo）原样画，不能着色 —— 否则红圆 + 白云会被压成一片纯色
    if (m_multicolor) {
        painter->drawImage(QRectF(0, 0, width(), height()), *src);
        return;
    }

    const QString key = m_name + QLatin1Char('@') + QString::number(pw)
                      + QLatin1Char('x') + QString::number(ph)
                      + QLatin1Char('#') + m_color.name(QColor::HexArgb);

    const QImage *tinted = tintCache().object(key);
    if (!tinted) {
        auto img = std::make_unique<QImage>(*src);
        {
            QPainter p(img.get());
            p.setCompositionMode(QPainter::CompositionMode_SourceIn);
            p.fillRect(img->rect(), m_color);
        }
        tintCache().insert(key, img.release(), qMax(1, (pw * ph * 4) / 1024));
        tinted = tintCache().object(key);
    }

    painter->drawImage(QRectF(0, 0, width(), height()), *tinted);
}

int SvgIcon::cacheKb()
{
    return sourceCache().totalCost() + tintCache().totalCost();
}

int SvgIcon::cacheEntries()
{
    return sourceCache().count() + tintCache().count();
}
