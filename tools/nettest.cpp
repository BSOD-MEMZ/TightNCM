// 独立网络自检：确认 Qt 的 HTTPS 能不能用（决定要不要随包 OpenSSL）
// 编译见 tools/nettest.sh
#include <QGuiApplication>
#include <QSslSocket>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QTimer>
#include <cstdio>

int main(int argc, char **argv)
{
    QGuiApplication app(argc, argv);

    std::fprintf(stderr, "supportsSsl = %d\n", QSslSocket::supportsSsl() ? 1 : 0);
    std::fprintf(stderr, "Qt build ssl = %s\n", QSslSocket::sslLibraryBuildVersionString().toUtf8().constData());

    QNetworkAccessManager nam;
    const QUrl url(QStringLiteral("https://interface.music.163.com/api/search/suggest/web?s=yoasobi&limit=2"));
    QNetworkRequest req(url);
    req.setHeader(QNetworkRequest::UserAgentHeader,
                  QStringLiteral("Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/131.0.0.0 Safari/537.36"));
    req.setRawHeader("Referer", "https://music.163.com/");
    req.setRawHeader("os", "pc");

    QNetworkReply *r = nam.get(req);
    QObject::connect(r, &QNetworkReply::finished, [&]() {
        const int code = r->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        std::fprintf(stderr, "http   = %d\n", code);
        std::fprintf(stderr, "error  = %s\n", r->errorString().toUtf8().constData());
        const QByteArray body = r->readAll();
        std::fprintf(stderr, "bytes  = %d\n", int(body.size()));
        std::fprintf(stderr, "body   = %.240s\n", body.constData());
        app.quit();
    });
    QTimer::singleShot(20000, &app, [&]() {
        std::fprintf(stderr, "TIMEOUT\n");
        app.quit();
    });
    return app.exec();
}
