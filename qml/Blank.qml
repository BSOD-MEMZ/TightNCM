// Blank —— 只用于内存诊断的空窗口
//
// 和 Main.qml 开一样大的窗口（同样的无边框 / 屏幕外逻辑），但**不加载任何外壳页面**。
// 拿 `--blank --memhold 12` 量出来的数，就是「C++ 侧 + Qt 运行时 + QML 引擎 + 一个窗口」
// 的底噪；和完整启动的差值才是我们自己的壳与页面真实占用的部分。
// 不参与正式构建行为：只有带 --blank 时才会被加载。
import QtQuick 2.15
import QtQuick.Window 2.15

Window {
    width: 1280
    height: 800
    visible: true
    title: "TightNCM"
    x: TNCScreenshotMode ? -4000 : 200
    y: TNCScreenshotMode ? -4000 : 200
    color: "#f7f9fc"
    flags: Qt.Window | Qt.FramelessWindowHint
}
