# 新版界面规格（从还原源码提取）

来源：登录态抓取 + CSS 内联 source map 还原出的 666 个原始源文件。
所有数值都是从源码里读出来的，不是量的。

---

## ⚠️ 先看这个

还原出来的源码是**网易的专有代码**（`packages/pc/src/...`、`packages/desktop-ui/...`）。
它只能当**参照物**：看布局数值、看交互逻辑、理解设计意图。
**不要把源码复制进要公开的仓库**（你的 Github 仓库是公开的，被扫到会有麻烦）。
正确用法：照着规格用 QML 重写。

---

## 1. 骨架尺寸

| 区域 | 尺寸 | 备注 |
|---|---|---|
| 左侧栏 | 宽 **204px**，全高 | `background: rgba(40,50,72,0.03)`（= `colorSidebar7`） |
| 顶栏 | 高 **72px**，`padding: 0 40px`，`display:flex` | class 含 `draggable` —— 它是窗口拖拽区 |
| 内容滚动区 | `x=204, y=72`，占满剩余 | 独立滚动容器 |
| 播放栏 | 高 **80px**（源码常量 `PlayBarHeight = 80`） | `<footer>`，`z-index: 998` |
| 页面底色 | `rgb(247,249,252)` | = `--colorBackground` |

**播放栏细节（来自 `PlayBar/style.ts`）**
```
border-top: 0.5px solid colorBlack10
background: colorFunction17 (rgba(250,250,250,1))  // 或 colorFunction4 (纯白)
padding: 0 30px
display: flex; align-items: center; justify-content: space-between
  .left   高 80px，子元素间距 10px
  .middle 宽 376px，居中，.btns padding-top: 12px
  .side   宽 262px（右侧那组按钮）
```

**播放/暂停按钮**
```css
background: linear-gradient(270deg, #FC3D49 0%, #FC3D49 26%, #FB3B5B 99%);
border-radius: 50%;
/* hover */
transform: scale(1.05);
background-color: #FB3B5B;
```

**黑胶（正在播放）模式的播放栏** —— 这就是那 120px 毛玻璃的出处：
```css
background: colorWhite12;          /* rgba(255,255,255,0.03) */
backdrop-filter: blur(120px);
```

**播放栏时间文字**：`font-size: 10px; line-height: 10px; color: colorBlack7`

---

## 2. 组件尺寸（运行时实测 + 源码对照）

| 组件 | 尺寸 | 样式 |
|---|---|---|
| 侧栏导航项 `ItemContainer` | **164 × 36** | `border-radius: 8px`，`padding: 8px`，图标 20×20，字号 12px |
| 侧栏歌单项 `PlayListItemContent` | **164 × 46** | `display:flex` |
| 顶部搜索框 | **258 × 36** | `border-radius: 8px`，字号 14px |
| 头像 | 28 × 28 | |
| Tabs | 高 40px | `cmd-tabs` |
| 「播放全部」按钮 | 高 40px，`border-radius` 走 token | `cmd-button-surfacePri` |

---

## 3. 设计 token 全表（82 个，运行时实测值）

### 灰阶（文字/图标，全部基于 `rgb(40,50,72)`）
| token | 值 |
|---|---|
| `colorBlack1` | `rgba(40,50,72,1)` ← 主文字 |
| `colorBlack2` | `rgba(40,50,72,0.9)` |
| `colorBlack3` | `rgba(40,50,72,0.8)` ← 次要文字 |
| `colorBlack4` | `rgba(40,50,72,0.7)` |
| `colorBlack5` | `rgba(40,50,72,0.6)` ← 第三级/图标常态 |
| `colorBlack6` | `rgba(40,50,72,0.5)` |
| `colorBlack7` | `rgba(40,50,72,0.4)` ← 时间文字 |
| `colorBlack8` | `rgba(40,50,72,0.3)` |
| `colorBlack9` | `rgba(40,50,72,0.25)` |
| `colorBlack10` | `rgba(40,50,72,0.1)` ← 分隔线 |
| `colorBlack11` | `rgba(40,50,72,0.06)` |
| `colorBlack12` | `rgba(40,50,72,0.03)` |

`colorWhite1..12` 同规律：白，α = 1 / 0.9 / 0.8 / 0.7 / 0.6 / 0.5 / 0.4 / 0.3 / 0.25 / 0.1 / 0.06 / 0.03

### 品牌色
| token | 值 |
|---|---|
| `colorPrimary1` | `rgba(255,58,58,1)` ← 主品牌红 |
| `colorPrimary2/3` | α 0.9 / 0.8 |
| `colorPrimary6/7/8` | α 0.3 / 0.1 / 0.08 |
| `colorSecondary1_1` | `rgba(252,59,91,1)` ← 渐变末端 |
| `colorSecondary1_2` | `rgba(252,61,73,1)` ← 渐变起点 |
| `colorSecondary2_1` | `rgba(255,58,58,1)` |
| `colorSecondary2_4` | `rgba(54,93,178,1)` |
| `colorSecondary3_1` | `rgba(252,110,163,1)` |
| `colorSecondary3_3` | `rgba(50,169,252,1)` |
| `colorSecondary4` | `rgba(211,160,59,1)` |

### 语义 / 功能色
| token | 值 | 用途 |
|---|---|---|
| `colorBackground` | `rgba(247,249,252,1)` | 页面底色 |
| `colorFunction4` / `15` | `rgba(255,255,255,1)` | 面板白 |
| `colorFunction17` | `rgba(250,250,250,1)` | 播放栏底 |
| `colorFunction12` | `rgba(252,61,73,1)` | 危险红 |
| `colorFunction13` | `rgba(50,119,255,1)` | |
| `colorFunction14` | `rgba(119,88,255,1)` | |
| `colorFunction16` | `rgba(45,45,56,1)` | 深色面板 |
| `colorFunction8` | `rgba(40,50,72,1)` | |
| `colorFunction9/10` | α 0.06 / 0.1 | |
| `colorMask1..5` | 黑 α 0.7 / 0.3 / 0.25 / 0.1 / 0 | 遮罩 |

### 侧栏专用
`colorSidebar1` `rgba(40,50,72,1)` · `2` α0.7 · `3` α0.6 · `4` α0.4 · `5` α0.1 · `7` α0.03（侧栏底） · `8` `rgba(255,255,255,1)` · `9/10/11` `rgba(252,59,91,1)`/`rgba(252,61,73,1)`（选中态红）

---

## 4. 还原出的源码（666 个文件 / 4.96 MB）

目录：`research/src-recovered/`

| 目录 | 文件数 | 内容 |
|---|---|---|
| `packages/pc/src/components/PlayBar/` | 22 | **播放栏全部组件**：PlayProgress、Volume、PlayMode、Playlist、TrackSoundQuality、RedStar(红心)、Vinyl(黑胶)、Comment、Download … |
| `packages/pc/src/components/left/` | 11 | **左侧栏**：nav-area(1072行)、nav-item、playlist-item、top-area、NavigationBackground、mac-winctrl |
| `packages/pc/src/components/Header/` | 3 | 顶栏（含搜索） |
| `packages/pc/src/components/` | 14+ | TrackViewer(歌曲列表)、PlaylistCard、Banner、UserVip、AppModal、SearchBox、MessageSheet |
| `packages/pc/src/pages/` | 大量 | home-page、playlist、vinyl-page(黑胶页)、audio、video-detail、album、user-detail、login、setting、community、localMusic、download、search |
| `packages/desktop-ui/es/` | 40+ 组件 | **设计系统组件库全部源码**：button、input、tabs、modal、image、list、slider、ummary… |

最大的几个：
```
2285 行  packages/pc/src/pages/home-page/views/MainViewOptimized.jsx
2237 行  packages/pc/src/pages/home-page/views/MainView.jsx
1831 行  packages/pc/src/pages/musicDesktop/index.tsx
1999 行  packages/pc/src/components/AppModal/index.tsx
1255 行  packages/pc/src/pages/vinyl-page/views/TrackPage/components/VinylCover.tsx
1072 行  packages/pc/src/components/left/components/nav-area.jsx
 844 行  packages/pc/src/components/Header/index.jsx
 804 行  packages/pc/src/components/PlayBar/PlayProgress.tsx
```

这些是 `.tsx/.jsx` 全文件（含 import、组件逻辑、linaria styled 定义），
`styled.div\`...\`` 里的 CSS 可以**几乎逐行翻译成 QML**。

---

## 5. 抓到的截图

| 文件 | 内容 |
|---|---|
| `snapshot/render-loggedin.png` | 登录后首页（侧栏 + 顶栏，内容区数据加载失败） |
| `snapshot/new-home.png` | 首页（1440×900） |
| `snapshot/new-playing.png` | ★ **歌单详情页**，含播放全部按钮、Tabs、歌曲表格、音质徽章、红心 |
| `snapshot/new-home-dom.html` | 首页 DOM（241 KB） |
| `snapshot/new-playing-dom.html` | 歌单详情页 DOM（780 KB） |
| `design-tokens.json` | 82 个 token + 布局几何 + 计算样式 |
| `shell-styles.json` | 骨架各区域计算样式 |
| `components.json` | 组件样式抽样 |

**没拿到的**：播放栏的实际渲染截图（headless 无音频设备，播放起不来；
而且它用 Web Audio/rudio 引擎，没有 `<audio>` 元素可探测）。
但播放栏的源码和样式规格已经完整拿到，比截图更准。
