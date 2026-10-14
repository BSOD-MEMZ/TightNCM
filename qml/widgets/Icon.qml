// Icon —— 单色 SVG 图标
//
// 官方实现是内联 SVG + `fill: currentColor`；这里加载挖出来的 SVG 文件并按需着色。
//
// 用法：
//     Icon { name: "sidebar_home"; size: 20; color: Theme.textTertiary }
//     Icon { name: "play"; size: 24; color: "#fff" }
//
// ⚠️ 着色**不能**用 QtGraphicalEffects.ColorOverlay：
//    1) 它是着色器效果。渲染后端一旦切成软件光栅（QT_QUICK_BACKEND=software，
//       能让常驻内存少 100MB，见 main.cpp），它整块不画 —— 表现是所有图标凭空消失。
//    2) 半透明颜色会被预乘成近黑色：colorBlack5 = rgba(40,50,72,.6) 画出来是 (24,30,43)
//       的近黑，而不是叠在白底上应有的 (126,149,185)。
//
// 现在改用 C++ 的 SvgIcon（QPainter + CompositionMode_SourceIn）：
// 两种后端都成立，透明度语义正确，而且缓存有上限、不随图标数量涨内存。
import QtQuick 2.15
import TightNCM 1.0

SvgIcon {
    id: root

    // 与旧 API 完全一致：name / size / color，调用点不用改
    property real size: 20

    implicitWidth: size
    implicitHeight: size

    // 双色图标（侧栏 logo：红圆 + 白云）原样画，不能着色 —— 否则会压成一片纯色
    multicolor: name === "logo"

    // name / color 直接就是 SvgIcon 的属性，这里不再转发
}
