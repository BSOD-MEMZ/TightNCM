// ColorProbe —— 取一张封面图的「主色」
//
// 用途：官方歌单 / 专辑页会给整个窗口铺一层由封面主色推出的淡色背景：
//     background-image: linear-gradient(<主色 alpha .1> 0%, transparent 480px)
// 浏览器那边是用 canvas 取封面主色的。Qt 没有等价 API，所以这里：
//   把 URL 的 ?param=WxH 改写成 8y8（几百字节），下回来之后求平均色。
//
// 为什么不在 QML 里用 grabToImage 取现有 Image 的像素：
// grabToImage 的回调挂在「下一帧」上，而 QML 窗口是**按需渲染**的 ——
// 页面静止时根本不产帧，回调就一直不触发（实测：等 7 秒也不来）。
// 顺手也省掉了 QML 侧没有 pixel() 可调的问题。
#pragma once

#include <QObject>
#include <QColor>
#include <QNetworkAccessManager>

class ColorProbe : public QObject
{
    Q_OBJECT

public:
    explicit ColorProbe(QObject *parent = nullptr);

    // 传封面 URL，异步算平均色（同一 URL 只算一次）
    Q_INVOKABLE void probe(const QString &url);

signals:
    void sampled(const QColor &color);

private:
    QNetworkAccessManager m_nam;
    QString m_lastUrl;
};
