// SvgIcon —— 单色 / 双色 SVG 图标，用 QPainter 着色
//
// 为什么要自己写，而不是继续用 QML 的 ColorOverlay：
//
//   1. QtGraphicalEffects 的 ColorOverlay / LinearGradient / DropShadow 全是
//      **着色器效果**。一旦把渲染后端切成 Qt 的软件光栅
//      （QT_QUICK_BACKEND=software，见 main.cpp —— 它能让常驻内存直接少 100MB），
//      这些效果就整块不画了：实测侧栏所有图标、播放栏所有按钮**全部消失**。
//   2. 就算留在 OpenGL 上，ColorOverlay 每个图标都要多一次 FBO pass，
//      半透明色还会被预乘成近黑色（踩过）。
//
// 这里改成 QPainter 直接画：把 SVG 光栅成 ARGB 图，再用 CompositionMode_SourceIn
// 盖一层纯色 —— 等价于 CSS 的 `fill: currentColor`，而且在任何后端都成立。
//
// 内存：全局缓存是有上限的（见 kTintCacheKb），不会随着图标数量无限涨。
#pragma once

#include <QColor>
#include <QQuickPaintedItem>
#include <QString>

class SvgIcon : public QQuickPaintedItem
{
    Q_OBJECT
    Q_PROPERTY(QString name READ name WRITE setName NOTIFY nameChanged)
    Q_PROPERTY(QColor color READ color WRITE setColor NOTIFY colorChanged)
    Q_PROPERTY(bool multicolor READ multicolor WRITE setMulticolor NOTIFY multicolorChanged)

public:
    explicit SvgIcon(QQuickItem *parent = nullptr);

    QString name() const { return m_name; }
    void    setName(const QString &v);

    QColor  color() const { return m_color; }
    void    setColor(const QColor &v);

    bool multicolor() const { return m_multicolor; }
    void setMulticolor(bool v);

    void paint(QPainter *painter) override;

    // 供自检 / 诊断用：当前缓存占用（KB）与条目数
    static int cacheKb();
    static int cacheEntries();

signals:
    void nameChanged();
    void colorChanged();
    void multicolorChanged();

private:
    QString m_name;
    QColor  m_color = QColor(0x28, 0x24, 0x32);
    bool    m_multicolor = false;
};
