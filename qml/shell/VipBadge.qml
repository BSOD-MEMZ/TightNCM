// VipBadge —— 顶栏用户区里的「黑胶 VIP」徽章
//
// 之前这里是一个 Icon{name:"vip"}，被整块染成 #282432（近黑），看起来就是一块黑方块。
// 实测官方（1280×800 登录态，DOM rect + 逐像素扫描）后，它其实是**双色**图案：
//
//   整体 48×16（x=1078..1125，y=28..43）
//     ├ 左侧 16×16 圆：黑胶唱片，盘面深灰，中心 4×4 红标（实测 #FC5053）
//     └ 右侧 40×14 药丸：深色（#3D3434 → #2A2626 的渐变），圆角 7
//         └ 米白文字「VIP·N」（实测文字色 #F2E0DE / #D6BCB7）
//
// 所以它不是单色图标，必须自己拼 —— ColorOverlay 那套会把盘面和文字压成同一个颜色。
import QtQuick 2.15
import TightNCM 1.0
import "../widgets"

Item {
    id: root

    // vipType 是**位掩码**不是等级（实测这台账号是 110，直接显示会变成 VIP·110）。
    // 只把 1..7 当作「黑胶等级」显示，其它一律只写 VIP。
    property int level: 0
    property bool showLevel: level >= 1 && level <= 7

    width: Metrics.headerVipWidth          // 48
    height: Metrics.headerVipHeight        // 16
    visible: level > 0

    readonly property color badgeDark:  "#2B2727"   // 药丸底 / 唱片内圈
    readonly property color badgeRim:   "#6B615F"   // 唱片外沿（比底浅一档，才看得出是黑胶）
    readonly property color badgeInk:   "#F0DCD7"   // 文字：米白（实测 #F2E0DE）
    readonly property color badgeRed:   "#FC3D49"   // 唱片中心红标（实测 #FC5053）

    // ── 药丸底（从黑胶盘圆心往右 40） ──────────────────
    RoundRect {
        x: 8
        y: 1
        width: 40
        height: 14
        radius: 7
        color: root.badgeDark
    }

    // ── 黑胶唱片 ────────────────────────────────────
    // 外沿（浅一档，否则整块糊成一个黑圆看不出是唱片）
    RoundRect {
        x: 0; y: 0
        width: 16; height: 16
        radius: 8
        color: root.badgeRim
    }
    // 盘面
    RoundRect {
        x: 2; y: 2
        width: 12; height: 12
        radius: 6
        color: root.badgeDark
    }
    // 中心红标
    // ⚠️ 不能 anchors.centerIn: parent —— parent 是 48×16 的整个徽章，
    // 红标会被放到 x=24（药丸中间），而唱片圆心在 x=8。这就是「VIP 徽章错位」。
    RoundRect {
        x: 6; y: 6          // (16-4)/2 —— 落在唱片正中
        width: 4; height: 4
        radius: 2
        color: root.badgeRed
    }

    // ── 文字 ────────────────────────────────────────
    Text {
        x: 13
        anchors.verticalCenter: parent.verticalCenter
        // 药丸从 x=8 起、宽 40，文字可用 40-5-5 = 30px。
        // 9px 粗体下 "VIP·7" 约 27px，放得下；10px 会顶出药丸右边缘（踩过）。
        text: (root.showLevel && root.level > 0) ? ("VIP·" + root.level) : "VIP"
        font.pixelSize: 9
        font.weight: Font.Bold
        font.family: "Microsoft YaHei"
        color: root.badgeInk
    }
}
