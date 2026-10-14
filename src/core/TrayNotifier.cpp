#include "TrayNotifier.h"

#include <QWindow>
#include <iterator>

#ifdef Q_OS_WIN
#  include <windows.h>
#  include <shellapi.h>
#endif

TrayNotifier::TrayNotifier(QObject *parent)
    : QObject(parent)
{
}

TrayNotifier::~TrayNotifier()
{
#ifdef Q_OS_WIN
    if (m_added && m_window) {
        NOTIFYICONDATAW nid{};
        nid.cbSize = sizeof(nid);
        nid.hWnd   = reinterpret_cast<HWND>(m_window->winId());
        nid.uID    = 1;
        Shell_NotifyIconW(NIM_DELETE, &nid);
    }
#endif
}

void TrayNotifier::setWindow(QWindow *w)
{
    m_window = w;
}

#ifdef Q_OS_WIN
namespace {
void fillIconData(NOTIFYICONDATAW &nid, HWND hwnd)
{
    nid.cbSize = sizeof(nid);
    nid.hWnd   = hwnd;
    nid.uID    = 1;
}
}
#endif

void TrayNotifier::ensureIcon()
{
#ifdef Q_OS_WIN
    if (m_added || !m_window)
        return;
    NOTIFYICONDATAW nid{};
    fillIconData(nid, reinterpret_cast<HWND>(m_window->winId()));
    nid.uFlags     = NIF_ICON | NIF_TIP;
    // 用 MAKEINTRESOURCEW 而不是 IDI_APPLICATION ——
    // 后者在没定义 UNICODE 的 TU 里会展开成窄字符，和 *W 版本对不上
    nid.hIcon      = LoadIconW(nullptr, MAKEINTRESOURCEW(32512));
    lstrcpynW(nid.szTip, L"TightNCM", static_cast<int>(std::size(nid.szTip)));
    m_added = Shell_NotifyIconW(NIM_ADD, &nid);
#endif
}

void TrayNotifier::notify(const QString &title, const QString &body)
{
#ifdef Q_OS_WIN
    if (!m_window || body.isEmpty())
        return;
    ensureIcon();
    if (!m_added)
        return;

    NOTIFYICONDATAW nid{};
    fillIconData(nid, reinterpret_cast<HWND>(m_window->winId()));
    nid.uFlags      = NIF_INFO;
    nid.dwInfoFlags = NIIF_INFO;
    nid.uTimeout    = 5000;

    const QString t = title.isEmpty() ? QStringLiteral("TightNCM") : title;
    int n = qMin(int(std::size(nid.szInfoTitle)) - 1, t.size());
    t.left(n).toWCharArray(nid.szInfoTitle);
    nid.szInfoTitle[n] = 0;

    n = qMin(int(std::size(nid.szInfo)) - 1, body.size());
    body.left(n).toWCharArray(nid.szInfo);
    nid.szInfo[n] = 0;

    Shell_NotifyIconW(NIM_MODIFY, &nid);
#else
    Q_UNUSED(title);
    Q_UNUSED(body);
#endif
}
