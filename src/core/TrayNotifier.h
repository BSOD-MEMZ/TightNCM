// TrayNotifier —— 后台切歌时的系统通知
//
// 为什么不用 QSystemTrayIcon：它属于 **QtWidgets**，链进来会多带一个
// Qt5Widgets.dll（约 6 MB 常驻），和本工程「RAM 要低」的目标直接冲突。
// 这里直接调 Shell_NotifyIcon（system 的 shell32，零额外依赖），
// Windows 7 上是气泡提示，Win10+ 会走系统通知中心。
//
// 托盘图标本身是隐形的用途 —— 只是系统要求「必须先 NIM_ADD 一个图标」才能发通知。
#pragma once

#include <QObject>
#include <QString>

class QWindow;

class TrayNotifier : public QObject
{
    Q_OBJECT

public:
    explicit TrayNotifier(QObject *parent = nullptr);
    ~TrayNotifier() override;

    // 窗口句柄来自主窗口（通知要靠它挂到消息队列上）
    void setWindow(QWindow *w);

    Q_INVOKABLE void notify(const QString &title, const QString &body);

private:
    void ensureIcon();

    QWindow *m_window = nullptr;
    bool     m_added = false;
};
