#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>
#include <QQuickItem>
#include <QImage>
#include <QFont>
#include <QFontDatabase>
#include <QDir>
#include <QFileInfo>
#include <QVariantMap>
#include <QTimer>
#include <QDebug>
#include <QPixmapCache>
#include <memory>
#include <functional>
#include <cstdio>
#include <cstring>

#ifdef Q_OS_WIN
#  include <windows.h>
#  include <psapi.h>
#endif

#include "net/NcmApi.h"
#include "audio/AudioPlayer.h"
#include "core/AppStore.h"
#include "core/ColorProbe.h"
#include "core/SvgIcon.h"
#include "core/TrayNotifier.h"

// 逐阶段探针：用 fprintf 直接写 stderr，绕过 Qt 的日志系统
// （Qt 在 Windows 上会把 qDebug 丢给 OutputDebugString，重定向到文件时会丢）
// 阶段打点顺带打印常驻内存 —— 这样「97MB 是谁占的」就有分段证据，不用猜。
static double residentMb();   // 定义在下面
#define STAGE(msg) do { std::fprintf(stderr, "[TightNCM] %-34s rss=%6.1fMB\n", msg, residentMb()); \
                        std::fflush(stderr); } while (0)

// 场景树 dump：排查「为什么某块没画出来」的硬证据
// 对 ListView / Flickable 额外把 count、contentHeight、可视范围读出来 ——
// 「模型有几条」和「真正实例化了几条」不是一回事（reuseItems / 懒加载）。
static void dumpItemTree(QQuickItem *it, int depth, int maxDepth)
{
    if (!it || depth > maxDepth)
        return;
    QByteArray pad(depth * 2, ' ');
    const QRectF r = it->mapRectToScene(QRectF(0, 0, it->width(), it->height()));

    QString extra;
    const QMetaObject *mo = it->metaObject();
    auto readInt = [&](const char *name) -> QVariant {
        int idx = mo->indexOfProperty(name);
        if (idx < 0)
            return QVariant();
        return mo->property(idx).read(it);
    };
    const QVariant cnt = readInt("count");
    if (cnt.isValid())
        extra += QStringLiteral(" count=%1").arg(cnt.toInt());
    const QVariant ch = readInt("contentHeight");
    if (ch.isValid())
        extra += QStringLiteral(" contentH=%1").arg(ch.toDouble());
    const QVariant ci = readInt("currentIndex");
    if (ci.isValid() && cnt.isValid())
        extra = QStringLiteral(" count=%1").arg(cnt.toInt()) + extra.mid(extra.indexOf(QStringLiteral(" contentH")));

    std::fprintf(stderr, "%s%-28s xy[%.0f,%.0f] %0.fx%.0f scene[%.0f,%.0f] vis=%d%s\n",
                 pad.constData(),
                 mo->className(),
                 it->x(), it->y(), it->width(), it->height(),
                 r.x(), r.y(),
                 it->isVisible() ? 1 : 0,
                 extra.toUtf8().constData());
    const QList<QQuickItem *> kids = it->childItems();
    for (QQuickItem *c : kids)
        dumpItemTree(c, depth + 1, maxDepth);
}

// 用法:
//   TightNCM.exe                              正常启动
//   TightNCM.exe --screenshot out.png         离屏渲染一帧后截图退出（验证 QML 用）
//   QT_QPA_PLATFORM=offscreen + 上面这行       完全无窗口，适合自动化验证

static int screenshotArg(QString *outPath)
{
    const QStringList args = QCoreApplication::arguments();
    const int i = args.indexOf(QStringLiteral("--screenshot"));
    if (i < 0 || i + 1 >= args.size())
        return -1;
    *outPath = args.at(i + 1);
    return i;
}

// --page <key>  指定启动页（给离屏验证用，例如 --page playlist）
static QString pageArg()
{
    const QStringList args = QCoreApplication::arguments();
    const int i = args.indexOf(QStringLiteral("--page"));
    if (i < 0 || i + 1 >= args.size())
        return QString();
    return args.at(i + 1);
}

// --page-delay <ms>  配合 --page 用：启动后先停在首页，延迟这么久再切过去。
// 目的是复现「页面先隐藏、数据后到」的真实交互路径（--page 是首帧前就切好，复现不了）。
static int pageDelayArg()
{
    const QStringList args = QCoreApplication::arguments();
    const int i = args.indexOf(QStringLiteral("--page-delay"));
    if (i < 0 || i + 1 >= args.size())
        return 0;
    return args.at(i + 1).toInt();
}

// 进程常驻内存（MB）。--memtest 用来判断「越听越大」到底是不是泄漏。
static double residentMb()
{
#ifdef Q_OS_WIN
    PROCESS_MEMORY_COUNTERS pmc;
    if (GetProcessMemoryInfo(GetCurrentProcess(), &pmc, sizeof(pmc))) {
        // 用 PagefileUsage（私有提交，含已换出的部分）而不是 WorkingSetSize：
        // 工作集会被 Windows 按内存压力随时裁剪（实测出现过 420MB 掉到 8.8MB 的假象），
        // 报出来的数根本没法比。
        return double(pmc.PagefileUsage) / (1024.0 * 1024.0);
    }
#endif
    return -1.0;
}

// --memtest <id,id,...>  连续换歌，每次打点常驻内存。
// 「越听 RAM 越大」要么是音频链路不释放，要么是 QML 侧累积 —— 用这个把两者分开。
static QString memTestArg()
{
    const QStringList args = QCoreApplication::arguments();
    const int i = args.indexOf(QStringLiteral("--memtest"));
    if (i < 0 || i + 1 >= args.size())
        return QString();
    return args.at(i + 1);
}

static int memTestSecArg()
{
    const QStringList args = QCoreApplication::arguments();
    const int i = args.indexOf(QStringLiteral("--memtest-sec"));
    if (i < 0 || i + 1 >= args.size())
        return 5;
    return qMax(1, args.at(i + 1).toInt());
}

// --memhold <sec>  正常启动，每秒打点一次私有提交内存，到期退出。
// 用来量「稳态内存」到底是多少、用什么渲染后端最省。
static int memHoldArg()
{
    const QStringList args = QCoreApplication::arguments();
    const int i = args.indexOf(QStringLiteral("--memhold"));
    if (i < 0 || i + 1 >= args.size())
        return 0;
    return args.at(i + 1).toInt();
}

// --playtest <songId>  拉播放地址并真的播一会儿，用来验证音频链路
static QString playTestArg()
{
    const QStringList args = QCoreApplication::arguments();
    const int i = args.indexOf(QStringLiteral("--playtest"));
    if (i < 0 || i + 1 >= args.size())
        return QString();
    return args.at(i + 1);
}

// --seed-demo <songId>  往本地播放历史里塞几条记录，用于离屏验证「最近播放」页。
// 只在自动化验证时用，正常启动不带这个参数就不会触发。
static bool seedDemoArg()
{
    return QCoreApplication::arguments().contains(QStringLiteral("--seed-demo"));
}

// --musicu <token>  命令行直接注入 MUSIC_U（等价于在登录层里贴一次）。
// 会写进 QSettings，所以只需要传一次，之后正常启动就是登录态。
// 之所以要有这个开关：登录层是贴 cookie 的，自动化验证时没法点它。
static QString musicUArg()
{
    const QStringList args = QCoreApplication::arguments();
    const int i = args.indexOf(QStringLiteral("--musicu"));
    if (i < 0 || i + 1 >= args.size())
        return QString();
    return args.at(i + 1).trimmed();
}

int main(int argc, char *argv[])
{
    STAGE("stage0: process start");

    for (int i = 1; i < argc; ++i) {
        if (std::strcmp(argv[i], "--selftest") == 0) {
            std::fprintf(stderr, "[TightNCM] selftest: loader OK\n");
            std::fflush(stderr);
            return 0;
        }
    }

    // 高 DPI（必须在 QGuiApplication 之前）
    QCoreApplication::setAttribute(Qt::AA_EnableHighDpiScaling);
    QCoreApplication::setAttribute(Qt::AA_UseHighDpiPixmaps);
    STAGE("stage1: attributes set");

    // ── 渲染后端 ─────────────────────────────────────────
    // 默认走 Qt 的**软件光栅**（QT_QUICK_BACKEND=software）。
    //
    // 实测（1280×800、登录态、全部页面加载完，私有提交内存）：
    //     QT_QUICK_BACKEND=software     111 MB
    //     QT_OPENGL=software（Mesa）    157 MB
    //     QT_OPENGL=angle（D3D11）      210 MB   ← 其中约 100MB 纯粹是 ANGLE/D3D 的栈
    //     （空窗口对照：软件 36.5MB / ANGLE 50.2MB，也就是 ANGLE 的开销随场景复杂度放大）
    //
    // 本工程「RAM 要低」是硬指标，所以默认软件光栅。
    // 代价：QtGraphicalEffects 的着色器效果在本后端下**不会绘制**，
    // 因此图标着色（Icon/SvgIcon）、斜向渐变（AngleGradientRect）、阴影（ShadowBox）
    // 都改成了 QPainter / Shape 实现，不再依赖 QtGraphicalEffects。
    //
    // 想要 GPU 加速就设环境变量覆盖（会被这里尊重）：
    //     QT_OPENGL=angle          → ANGLE（D3D），+100MB
    //     QT_OPENGL=desktop        → 桌面 OpenGL（有正规显卡驱动时最快）
    //     QT_OPENGL=software       → Mesa 软件 GL（着色器效果仍可用，+46MB）
    // 注意：MinGW 版 Qt 上 "dynamic" 是**非法值**（会打 "Invalid value set for QT_OPENGL"），别用。
    {
        // --renderer 是给本项目用的简写；环境变量优先（方便不改参数就能压测）
        const QStringList a = QCoreApplication::arguments();
        const int ri = a.indexOf(QStringLiteral("--renderer"));
        const QString want = (ri >= 0 && ri + 1 < a.size()) ? a.at(ri + 1) : QString();

        if (qEnvironmentVariableIsEmpty("QT_QUICK_BACKEND")
            && qEnvironmentVariableIsEmpty("QT_OPENGL")) {
            if (want == QLatin1String("angle"))
                qputenv("QT_OPENGL", "angle");
            else if (want == QLatin1String("desktop"))
                qputenv("QT_OPENGL", "desktop");
            else if (want == QLatin1String("mesa"))
                qputenv("QT_OPENGL", "software");
            else
                qputenv("QT_QUICK_BACKEND", "software");
        }
    }

    // 位图缓存压到 2MB（Qt 默认 10MB）。
    // 本工程的封面全部按显示尺寸解码（Image.sourceSize 都写死了），
    // 缓存命中率本来就不高，10MB 只是白占私有提交。
    QPixmapCache::setCacheLimit(2048);

    QGuiApplication app(argc, argv);
    std::fprintf(stderr, "[TightNCM] stage2: QGuiApplication OK, Qt %s, platform '%s'\n",
                 qVersion(), QGuiApplication::platformName().toUtf8().constData());
    // 后端打点：看到「200MB 还在」时先看这一行 —— angle 约 290MB，software 约 99MB
    std::fprintf(stderr, "[TightNCM] backend: QT_QUICK_BACKEND=%s QT_OPENGL=%s sg='%s'\n",
                 qgetenv("QT_QUICK_BACKEND").isEmpty() ? "(unset)"
                                                       : qgetenv("QT_QUICK_BACKEND").constData(),
                 qgetenv("QT_OPENGL").isEmpty() ? "(unset)" : qgetenv("QT_OPENGL").constData(),
                 QQuickWindow::sceneGraphBackend().toUtf8().constData());
    std::fflush(stderr);
    app.setApplicationName(QStringLiteral("TightNCM"));
    app.setApplicationDisplayName(QStringLiteral("网易云音乐"));
    app.setOrganizationName(QStringLiteral("TightNCM"));
    app.setOrganizationDomain(QStringLiteral("tightncm.local"));

    // 官方正文基准：font-family: 微软雅黑, arial, ... ; font-size: 12px
    // QML 的 Text 不显式设 font 时会继承 application font。
    QFont base(QStringLiteral("Microsoft YaHei"));
    base.setPixelSize(12);
    QGuiApplication::setFont(base);

    // 可选：从 qrc 加载随包字体（官方 logo 用的是 SVG，暂时不需要）
    QDir fd(QStringLiteral(":/fonts"));
    if (fd.exists()) {
        const QFileInfoList list =
            fd.entryInfoList(QStringList() << "*.ttf" << "*.otf", QDir::Files);
        for (const QFileInfo &fi : list)
            QFontDatabase::addApplicationFont(fi.absoluteFilePath());
    }

    // ── 注册 QML 单例 ────────────────────────────────────
    // Theme:   80 个官方设计 token（由 research/gen-theme.mjs 生成）
    // Metrics: 骨架与组件实测尺寸
    qmlRegisterSingletonType(QUrl(QStringLiteral("qrc:/qml/Theme.qml")),
                             "TightNCM", 1, 0, "Theme");
    qmlRegisterSingletonType(QUrl(QStringLiteral("qrc:/qml/Metrics.qml")),
                             "TightNCM", 1, 0, "Metrics");

    // SvgIcon: 用 QPainter 着色的 SVG 图标。
    // 不能用 QtGraphicalEffects.ColorOverlay —— 那是着色器效果，一换软件光栅后端
    // 就整块不画（图标全部消失），详见 src/core/SvgIcon.h 顶部说明。
    qmlRegisterType<SvgIcon>("TightNCM", 1, 0, "SvgIcon");

    // ── 后端与播放器 ─────────────────────────────────────
    // ⚠️ 必须声明在 engine **之前**。QML 局部对象的析构顺序是声明的逆序，
    // 如果 engine 先销毁、api/player 后销毁，QML 侧还会拿着已失效的
    // 上下文属性引用去求值，退出时会刷一堆 "Cannot read property of null"。
    NcmApi api;
    AudioPlayer player;
    AppStore store;
    ColorProbe colorProbe;   // 从封面缩略图里取平均色（沉浸式背景用）
    TrayNotifier notifier;   // 后台切歌的系统通知（设置页开关控制）

    QQmlApplicationEngine engine;
    engine.addImportPath(QStringLiteral("qrc:/qml"));

    engine.rootContext()->setContextProperty(QStringLiteral("Api"), &api);
    engine.rootContext()->setContextProperty(QStringLiteral("Player"), &player);
    engine.rootContext()->setContextProperty(QStringLiteral("Store"), &store);
    engine.rootContext()->setContextProperty(QStringLiteral("ColorProbe"), &colorProbe);
    engine.rootContext()->setContextProperty(QStringLiteral("Notifier"), &notifier);

    // 恢复上次的音量
    player.setVolume(store.volume());

    // 离屏验证用：往播放历史里塞几条，好让「最近播放」页有东西可画
    if (seedDemoArg() && store.recentSongs().isEmpty()) {
        const QVariantList seed = {
            QVariantMap{ { QStringLiteral("id"), 33894312 },
                         { QStringLiteral("name"), QStringLiteral("爱情转移") },
                         { QStringLiteral("artist"), QStringLiteral("陈奕迅") },
                         { QStringLiteral("album"), QStringLiteral("认了吧") },
                         { QStringLiteral("duration"), 259 } },
            QVariantMap{ { QStringLiteral("id"), 1330348068 },
                         { QStringLiteral("name"), QStringLiteral("海底") },
                         { QStringLiteral("artist"), QStringLiteral("一支榴莲") },
                         { QStringLiteral("album"), QStringLiteral("海底") },
                         { QStringLiteral("duration"), 237 } },
            QVariantMap{ { QStringLiteral("id"), 1824020874 },
                         { QStringLiteral("name"), QStringLiteral("群青") },
                         { QStringLiteral("artist"), QStringLiteral("YOASOBI") },
                         { QStringLiteral("album"), QStringLiteral("THE BOOK") },
                         { QStringLiteral("duration"), 254 } }
        };
        for (int i = seed.size() - 1; i >= 0; --i)
            store.addRecent(seed.at(i).toMap());
        std::fprintf(stderr, "[TightNCM] seeded %d recent songs\n", int(seed.size()));
        std::fflush(stderr);
    }

    // --musicu <token>：命令行注入登录态（写进 QSettings，只需传一次）
    const QString musicU = musicUArg();
    if (!musicU.isEmpty()) {
        api.setMusicU(musicU);
        std::fprintf(stderr, "[TightNCM] MUSIC_U injected from argv (%d chars)\n",
                     int(musicU.size()));
        std::fflush(stderr);
    }

    // 如果有存档的 cookie，启动时校验一次登录态
    if (!api.musicU().isEmpty())
        QTimer::singleShot(0, &api, &NcmApi::loadAccount);

    // ── 换歌内存打点 ─────────────────────────────────────
    // 用法: TightNCM.exe --memtest id1,id2,id3 [--memtest-sec 4]
    const QString memTest = memTestArg();
    if (!memTest.isEmpty()) {
        QStringList ids = memTest.split(QLatin1Char(','), Qt::SkipEmptyParts);
        auto idx = std::make_shared<int>(0);
        auto secs = memTestSecArg();
        std::fprintf(stderr, "[mem] baseline rss=%.1fMB songs=%d\n",
                     residentMb(), int(ids.size()));
        std::fflush(stderr);

        QObject::connect(&api, &NcmApi::songUrlReady, &api,
                         [&player](qint64, const QString &url, int) {
            if (!url.isEmpty())
                player.playUrl(url);
        });

        auto tick = std::make_shared<std::function<void()>>();
        *tick = [&api, &app, &player, ids, idx, secs, tick]() {
            if (*idx >= ids.size()) {
                std::fprintf(stderr, "[mem] done rss=%.1fMB\n", residentMb());
                std::fflush(stderr);
                QTimer::singleShot(300, &app, &QCoreApplication::quit);
                return;
            }
            const qint64 sid = ids.at(*idx).trimmed().toLongLong();
            api.loadSongUrl(sid, 320000);
            std::fprintf(stderr, "[mem] i=%d/%d id=%lld rss=%.1fMB state=%s\n",
                         *idx + 1, int(ids.size()), (long long)sid, residentMb(),
                         player.stateName().toUtf8().constData());
            std::fflush(stderr);
            ++(*idx);
            QTimer::singleShot(secs * 1000, &app, [tick]() { (*tick)(); });
        };
        QTimer::singleShot(3000, &app, [tick]() { (*tick)(); });
    }

    // ── 音频链路自检 ─────────────────────────────────────
    // 用法: TightNCM.exe --playtest 33894312
    const QString playTest = playTestArg();
    if (!playTest.isEmpty()) {
        const qint64 wantId = playTest.toLongLong();
        QObject::connect(&api, &NcmApi::songUrlReady, &api,
                         [&player, wantId](qint64 id, const QString &url, int br) {
            if (id != wantId)
                return;
            std::fprintf(stderr, "[playtest] url(br=%d) = %.140s\n", br, url.toUtf8().constData());
            std::fflush(stderr);
            player.playUrl(url);
        });
        QObject::connect(&player, &AudioPlayer::stateNameChanged, &player, [&player]() {
            std::fprintf(stderr, "[playtest] state = %s\n", player.stateName().toUtf8().constData());
            std::fflush(stderr);
        });
        api.loadSongUrl(wantId, 320000);

        QTimer::singleShot(12000, &app, [&player]() {
            std::fprintf(stderr, "[playtest] 12s 后: state=%s pos=%lldms dur=%lldms err=%s\n",
                         player.stateName().toUtf8().constData(),
                         static_cast<long long>(player.position()),
                         static_cast<long long>(player.duration()),
                         player.errorText().toUtf8().constData());
            std::fflush(stderr);
            QCoreApplication::exit(player.position() > 0 ? 0 : 5);
        });
        return app.exec();
    }

    // 截图模式必须在 load 之前告诉 QML —— QML 侧据此把窗口直接创建在屏幕外，
    // 这样窗口才能正常 show（contentItem 才会拿到真实尺寸），同时不会闪窗。
    QString shotPath;
    const bool wantShot = (screenshotArg(&shotPath) >= 0);
    engine.rootContext()->setContextProperty(QStringLiteral("TNCScreenshotMode"), wantShot);
    engine.rootContext()->setContextProperty(QStringLiteral("TNCStartPage"), pageArg());
    engine.rootContext()->setContextProperty(QStringLiteral("TNCPageDelay"), pageDelayArg());
    STAGE("stage3: QQmlApplicationEngine created");

    // --qml <路径>：从文件系统加载入口 QML。
    // 二分内存 / 调布局时非常有用 —— 改 QML 不用重编译，直接重跑。
    QString entryOverride;
    {
        const QStringList a = QCoreApplication::arguments();
        const int qi = a.indexOf(QStringLiteral("--qml"));
        if (qi >= 0 && qi + 1 < a.size())
            entryOverride = a.at(qi + 1);
    }
    const QUrl url = !entryOverride.isEmpty() ? QUrl::fromLocalFile(entryOverride)
                   : QCoreApplication::arguments().contains(QStringLiteral("--blank"))
                       ? QUrl(QStringLiteral("qrc:/qml/Blank.qml"))
                       : QUrl(QStringLiteral("qrc:/qml/Main.qml"));
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated,
                     &app, [url](QObject *obj, const QUrl &objUrl) {
        if (!obj && url == objUrl)
            qCritical() << "[TightNCM] QML 加载失败:" << objUrl;
    }, Qt::QueuedConnection);

    engine.load(url);
    STAGE("stage4: engine.load() returned");
    if (engine.rootObjects().isEmpty()) {
        std::fprintf(stderr, "[TightNCM] stage4: rootObjects is EMPTY -> QML failed\n");
        std::fflush(stderr);
        return -1;
    }
    std::fprintf(stderr, "[TightNCM] stage4: root object OK\n");
    std::fflush(stderr);

    QQuickWindow *win = qobject_cast<QQuickWindow *>(engine.rootObjects().constFirst());
    if (win) {
        notifier.setWindow(win);   // 通知要挂在窗口的消息队列上

        // 首帧打点：把「建树」和「真的渲染了一帧」分开 —— 场景图/纹理是这一帧才分配出来的
        QObject::connect(win, &QQuickWindow::frameSwapped, &app, []() {
            static bool once = false;
            if (once) return;
            once = true;
            STAGE("stage5: first frame rendered");
        });
    }

    // ── 稳态内存打点 ─────────────────────────────────────
    // 用法: TightNCM.exe --memhold 20
    // 每秒打一行，用来比较不同渲染后端 / 不同页面常驻策略的内存。
    const int memHold = memHoldArg();
    if (memHold > 0) {
        auto *t = new QTimer(&app);
        auto *sec = new int(0);
        t->setInterval(1000);
        QObject::connect(t, &QTimer::timeout, &app, [t, sec, memHold, &app]() {
            ++(*sec);
            std::fprintf(stderr, "[memhold] t=%ds rss=%.1fMB\n", *sec, residentMb());
            std::fflush(stderr);
            if (*sec >= memHold) {
                t->stop();
                QCoreApplication::quit();
            }
        });
        t->start();
        return app.exec();
    }

    // ── 离屏截图模式（用于自动化验证 QML 渲染） ──────────
    // 说明：
    //  * Windows 上的 offscreen 平台插件**不支持创建 OpenGL 上下文**，Qt Quick 画不出东西；
    //  * 而用 visible:false 创建的窗口，contentItem 尺寸不会同步（会停在 0x0，anchors 全塌）；
    //  所以做法是：窗口正常 show，但 QML 侧一开始就把它放在屏幕外（见 Main.qml 的
    //  TNCScreenshotMode 绑定），既不闪窗又能拿到完整渲染。
    if (!win) {
        if (wantShot) {
            std::fprintf(stderr, "[TightNCM] root object is not a Window, cannot screenshot\n");
            return -1;
        }
        return app.exec();
    }

    if (wantShot) {
        STAGE("shot: window created offscreen by QML");

        // 兜底：窗口在屏幕外时 Qt 不一定给它发 resize 事件，contentItem 可能停在
        // 0x0，导致所有 anchors 塌掉（侧栏高度会算成负数）。这里直接同步一次。
        if (QQuickItem *ci = win->contentItem()) {
            if (ci->width() <= 0 || ci->height() <= 0) {
                ci->setSize(QSizeF(win->width(), win->height()));
                std::fprintf(stderr, "[TightNCM] shot: forced contentItem size %.0fx%.0f\n",
                             ci->width(), ci->height());
                std::fflush(stderr);
            }
        }
        win->requestUpdate();

        auto done = std::make_shared<bool>(false);
        auto doGrab = [&app, win, shotPath, done]() {
            if (*done)
                return;
            *done = true;

            // 环境变量 TIGHTNCM_DUMP_TREE=1 时，先把场景树打出来
            if (qEnvironmentVariableIntValue("TIGHTNCM_DUMP_TREE") == 1) {
                std::fprintf(stderr, "[TightNCM] ==== scene tree ====\n");
                QQuickItem *ci = win->contentItem();
                std::fprintf(stderr, "[TightNCM] window %dx%d visible=%d, contentItem %.0fx%.0f\n",
                             win->width(), win->height(), win->isVisible() ? 1 : 0,
                             ci ? ci->width() : -1.0, ci ? ci->height() : -1.0);
                if (ci)
                    dumpItemTree(ci, 0, 12);
                std::fprintf(stderr, "[TightNCM] ==== end tree ====\n");
                std::fflush(stderr);
            }

            QImage img = win->grabWindow();
            if (img.isNull()) {
                std::fprintf(stderr, "[TightNCM] shot: grabWindow returned NULL image\n");
                std::fflush(stderr);
                QCoreApplication::exit(2);
                return;
            }
            const bool ok = img.save(shotPath);
            std::fprintf(stderr, "[TightNCM] shot: saved %s (%dx%d) %s\n",
                         shotPath.toUtf8().constData(), img.width(), img.height(),
                         ok ? "OK" : "WRITE-FAILED");
            std::fflush(stderr);
            QCoreApplication::exit(ok ? 0 : 3);
        };

        // 注意：不能在 afterRendering 里立刻抓 —— 那是**第一帧**，
        // 此时 QML 布局/尺寸往往还没稳定，抓出来会缺元素。
        // 等布局稳定后再抓（窗口在屏幕外时 grabWindow() 会强制渲染一帧）。
        const int delay = qEnvironmentVariableIntValue("TIGHTNCM_SHOT_DELAY_MS") > 0
                              ? qEnvironmentVariableIntValue("TIGHTNCM_SHOT_DELAY_MS")
                              : 4500;
        QTimer::singleShot(delay, &app, doGrab);
        QTimer::singleShot(delay + 20000, &app, []() {
            std::fprintf(stderr, "[TightNCM] shot: TIMEOUT\n");
            std::fflush(stderr);
            QCoreApplication::exit(4);
        });
    }

    return app.exec();
}
