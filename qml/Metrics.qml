// 自动生成 —— 由 research/gen-theme.mjs 产出
// 尺寸全部来自还原源码 / 运行时实测，见 research/NEW-UI-SPEC.md
pragma Singleton
import QtQuick 2.15

QtObject {
    // ── 渲染开关 ─────────────────────────
    // box-shadow 在 Qt 里要额外一次 FBO pass（QtGraphicalEffects.DropShadow），
    // 代价大且难以做到像素级一致，暂时全局关掉。需要时改成 true 即可，
    // ShadowBox 会自动开始渲染阴影。
    readonly property bool enableBoxShadow: false

    // ── 骨架 ─────────────────────────────
    readonly property int sidebarWidth:    204     // Container_c1udi5wp 实测 204x全高
    readonly property int topBarHeight:     72     // HEADER_HEIGHT
    readonly property int playBarHeight:    80     // 源码常量 PlayBarHeight
    readonly property int contentPadding:   40     // CONTENT_AREA_PADDING（顶栏 + 内容区左右留白）
    readonly property int barPadding:       30     // 播放栏 padding: 0 30px
    // 内容滚动区 padding-top —— 实测 scrollArea padding "18px 40px 0px"
    readonly property int pageTopPad:        18

    // ── 左侧栏（实测 1280x800 登录态逐元素坐标） ──────
    // .draggable { padding: APP_CONTAINER_SPACE 0 0 24px }
    readonly property int sidebarHMargin:    24    // 导航项左边距（不是 (204-164)/2=20）
    readonly property int sidebarTopPad:     18
    readonly property int logoRowHeight:     72    // BackContainer_b19x2gto 204x72
    readonly property int logoIconSize:      28    // cmd-icon-logo 28x28
    readonly property int logoTitleWidth:    99    // cmd-icon-title 99x18
    readonly property int logoTitleHeight:   18
    readonly property int logoGap:           10    // 71.5-(33.5+28)
    readonly property int logoBoxGap:         0

    readonly property int navItemHeight:      36
    readonly property int navItemWidth:      164
    readonly property int navItemRadius:       8
    readonly property int navItemPadding:      8
    readonly property int navItemIconSize:    20
    readonly property int navItemIconGap:      8    // IconWrapper margin-right: 8px
    // NavItemContainer > *:not(:last-child) { margin-bottom: 4px }  -> 项距 40
    readonly property int navItemGap:          4
    readonly property int navItemFontSize:    14
    readonly property int navItemFontLine:    18
    readonly property int navGroupPadY:       14    // NavItemContainer padding: 14px 0
    readonly property int navGroupFirstPadB:  14    // .first-group padding: 0 0 14px
    readonly property int navDividerInset:     9    // show-bottom-border::after left/right: 9px

    readonly property int sectionHeaderHeight: 32   // TitleContainer_t2femva 164x32
    readonly property int sectionHeaderPadL:   10   // 标题文字距分组头左边缘
    readonly property int sectionHeaderIcon:   16   // 折叠箭头 / 新建按钮图标 16×16
    readonly property int sectionAddHotSize:   30   // AddPointer 30×32 热区
    readonly property int sectionAddDotSize:   14   // IconWithBackground 14×14 圆底

    readonly property int playlistItemHeight:      46
    readonly property int playlistItemPillHeight:  42  // 内部 background 164x42
    readonly property int playlistCoverSize:       32
    readonly property int playlistCoverRadius:      4   // .cover border-radius: 4px（实测，原来误写 6）
    readonly property int playlistTextGap:          8
    readonly property int playlistFontSize:        12
    readonly property int playlistFontLine:        16

    // ── 顶栏（Header/index.jsx grid: 28 8 258 8 36 20 auto 20 min-content） ──
    readonly property int headerBackWidth:  28      // HistoryIconBackground 28x36
    readonly property int headerBackHeight: 36
    readonly property int headerBackRadius:  8
    readonly property int headerSearchGap:   8      // grid 里的 8px 占位列
    readonly property int headerIconGap:    10      // MiniModeIconBar > *:not(:last-child) margin-right: 10px
    readonly property int headerIconSize:   20
    readonly property int searchBoxWidth:    258
    readonly property int searchBoxHeight:    36
    // 用户区（Bar_b2jgnke，实测 1280×800 登录态）：
    //   Bar { height:36; > *:not(:last-child){ margin-right:4px } }
    //   头像 28 圆形 → 昵称(13px/500) → VIP 徽章 48×16 → 下拉箭头 20×20
    readonly property int headerUserGap:     4    // Bar_b2jgnke 子项间距
    readonly property int headerAvatarSize: 28
    readonly property int headerNameSize:   13    // .Name_n1q7o360 font-size:13px
    readonly property int headerNameWeight: 500   // .Name_n1q7o360 font-weight:500
    readonly property int headerVipWidth:   48    // Icon_i5d0txk 内 img 实测 48×16
    readonly property int headerVipHeight:  16
    readonly property int headerVipBox:     20    // Content_c1r4hsv0 height:20px
    readonly property int headerDropdownSize: 20  // cmd-icon-unfold 20×20

    // ── 设置页（官方 pages/setting 的 BaseItem 字面值） ──────
    //   section { display:flex; flex-direction:row; padding:30px 0;
    //             font-size:16px; line-height:18px; color: colorBlack2;
    //             border-bottom: 1px solid colorBlack11 }
    //     h3 { width:132px; flex:none; margin-bottom:20px; weight:600; font-size:16px }
    //     h4 { font-size:14px }  .tip { color: colorBlack6 }
    readonly property int sLabelWidth:   132   // h3 宽度
    readonly property int sRowPadY:       30   // section padding: 30px 0
    readonly property int sRowLabelSize:  16
    readonly property int sRowTextSize:   14
    readonly property int sRowLine:       18
    readonly property int sMenuWidth:    160   // 左侧分栏

    // ── 播放栏内部 ────────────────────────
    readonly property int playBarSideWidth:   262
    readonly property int playBarMiddleWidth: 376
    readonly property int playBarLeftGap:      10
    readonly property int playBarBtnsTopPad:   12

    // ── 歌单详情页（2026-10-14 登录态在 1280×800 / 1440×900 两次实测） ──────
    // 实测：scrollArea 204,72 1076x728 padding "18px 26px 40px 40px"
    readonly property int pBodyPadding:          40
    readonly property int pBodyPaddingRight:     26
    readonly property int pBodyPaddingBottom:    40
    // StyledCommon  244,90  996x222  padding "0 0 28px"
    readonly property int pHeaderHeight:        222   // = 封面 194 + padding-bottom 28
    readonly property int pHeaderCoverTop:        8   // 封面相对页头内容框再下移 8
    readonly property int pPlaylistCoverSize:   194   // ★ 实测 194，不是还原源码里写的 216
    readonly property int pPlaylistCoverRadius:  12
    readonly property int pInfoMarginLeft:       40   // .info margin-left
    readonly property int pHeaderPaddingBottom:  28   // .StyledCommon padding-bottom
    readonly property int pHeaderTitleSize:      24   // .info .title font-size
    readonly property int pHeaderTitleLine:      32
    // .more { margin: 10px 0 12px; 子项间距 12 }  实测高 24
    readonly property int pMoreMarginTop:        10
    readonly property int pMoreMarginBottom:     12
    readonly property int pMoreGap:              12
    readonly property int pAuthorAvatarSize:     24
    readonly property int pAuthorGap:            10   // 头像与昵称间距
    readonly property int pAuthorFontSize:       12
    readonly property int pPlayAllWidth:         94   // 播放全部按钮 94x40
    readonly property int pPlayAllHeight:        40
    readonly property int pPlayAllRadius:         8
    readonly property int pPlayAllFontSize:      13
    readonly property int pSecBtnSize:           40   // 右侧圆形「…」按钮 40x40
    readonly property int pBtnGap:               12
    // CmdTabs 实测 244,312 996x40；单个 tab 25 高
    readonly property int pTabsHeight:           40
    readonly property int pTabHeight:            25
    readonly property int pTabFontSize:          14
    readonly property int pTabPadX:              10
    readonly property int pTabCountFontSize:     12

    // ── 歌曲表格（TableViewer/index.tsx + 实测） ─────────────
    readonly property int tHeadHeight:   40   // .thead .tr { height: 40px }
    readonly property int tHeadTotal:    41   // 40 + 底边线 1px
    readonly property int tHeadGap:       8   // .thead-boundary margin-bottom: 8px
    readonly property int tHeadNumPadL:  20   // .th-num { padding-left: 20px }
    readonly property int tRowHeight:    64   // .tbody .tr { height: 64px }
    readonly property int tRowRadius:    10   // .tbody .tr { border-radius: 10px }
    readonly property int tFirstPadL:    16   // .tr .th/.td:first-child { padding-left: 16px }
    readonly property int tCoverSize:    48   // .StyledTitleCell .cover
    readonly property int tCoverRadius:   8
    readonly property int tCoverInsetX:   8   // 封面距 td-title 左边缘 8
    readonly property int tCoverGap:     10   // 封面与文字间距
    readonly property int tCellPaddingX:  8   // .tr .td { padding: 0 8px }
    readonly property int tTitleFontSize: 16
    readonly property int tSubFontSize:  13   // .sub-title font-size: 13px

    // 列宽：与官方 flex 布局一致 = minWidth + free * grow / growSum
    readonly property var tColumns: [
        { key: "num",      title: "#",    minWidth:  45, grow:  0.0000 },
        { key: "title",    title: "标题",  minWidth: 180, grow: 60.0649 },
        { key: "album",    title: "专辑",  minWidth: 115, grow: 37.3377 },
        { key: "like",     title: "喜欢",  minWidth:  60, grow:  0.0000 },
        { key: "duration", title: "时长",  minWidth:  64, grow:  2.5974 }
    ]
    readonly property int searchBoxRadius:    8
    readonly property int avatarSize:         28
    readonly property int tabBarHeight:       40
    readonly property int buttonHeight:       40

    // ── 字号（官方 body 基准 12px） ─────────
    readonly property int fontTiny:   10
    readonly property int fontSmall:  12
    readonly property int fontNormal: 13
    readonly property int fontMedium: 14
    readonly property int fontLarge:  16

    // ── 窗控 ─────────────────────────────
    readonly property int windowRadius:  0
    readonly property int resizeHandle:  8
}
