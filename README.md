# TightNCM

网易云音乐桌面客户端 —— **C++ / Qt 5.15 + QML** 原生实现，1:1 复刻官方客户端界面。
目标：**低内存占用 + 支持 Windows 7**，刻意避开 Electron / WebView 方案。

> **要动代码先看 [`AGENTS.md`](AGENTS.md)** —— 编译/验证命令、加页面/接口/图标的清单、
> 以及一批会咬人的坑（`Column` 漏排子项、部署缺 QML 模块、`.bat` 只能写 ASCII 等）。
> 本文件偏「为什么这么设计」，`AGENTS.md` 偏「怎么干活」。

---

## 为什么是 Qt 5.15

| 事实 | 依据 |
|---|---|
| **Qt 6 不支持 Windows 7**（最低 Win10 1809） | QTBUG-85851 / QTBUG-85855 |
| Qt **5.15** 是最后一个支持 Win7 的系列 | 同上 |
| Qt **5.15.2** 是最后一个 LGPL 开源发布版 | qt.io 公告（5.15.3+ 长期仅商业版） |
| KDE 维护 `kde/5.15` 补丁集供开源项目续用 | community.kde.org/Qt5PatchCollection |

**内存预期**：Qt Quick 基线 35–45 MB，本项目目标 80–140 MB。
（对比：WebView2 壳 150–250 MB，Electron 300–500 MB。）

顺带一个反直觉的点：**Qt 5.15 的 `QtGraphicalEffects` 覆盖面比 Qt 6.5 的 `MultiEffect` 更宽** ——
MultiEffect 没有 `hue-rotate`、没有 shadow 的 `spread`，而 Qt5 的 `HueSaturation` / `DropShadow` 两个都有。

---

## 构建

### 依赖
- **Qt 5.15.2**（`Qt Quick` / `Qt Quick Controls 2` / `Qt SVG` / `Qt Graphical Effects`）
- **MinGW 8.1.0 64bit**（或 MSVC 2019）
- CMake 3.16–3.31（**别用 CMake 4.x**，它会拒绝 Qt5 里那些老的 `cmake_minimum_required`）
- Ninja

### 一键安装环境（推荐）
```bat
setup-env.bat
```
用 `aqtinstall` 从官方源装（**不需要 Qt 账号**），装到 `D:\Qt`：
- `D:\Qt\5.15.2\mingw81_64`
- `D:\Qt\Tools\mingw810_64`

### 一键编译 + 运行
```bat
run.bat              :: 需要时自动编译，然后启动
run.bat rebuild      :: 强制重新编译再启动
run.bat console      :: 出带控制台的版本（能看到 QML 报错）再启动

build.bat            :: 只编译（发布版，无控制台）
build.bat console    :: 只编译带控制台的调试版
```
产物：`build\TightNCM.exe`

> ⚠️ 编译前要先把正在运行的 `TightNCM.exe` 关掉，否则链接会报
> `cannot open output file TightNCM.exe: Permission denied`（exe 被占用）。

### 渲染验证（无窗口）
```bat
tools\verify.bat                     :: 渲染默认页 → build\shell-render.png
tools\verify.bat --page playlist     :: 渲染歌单页 → build\render-playlist.png
tools\verify.bat --page recent --seed-demo
                                     :: --seed-demo 会往播放历史塞几条演示数据
```
离屏渲染一帧 + `build\verify.log`。改完 QML 跑一下就能确认没画错，不用真开窗口。
`%*` 会透传给 exe，所以 `--page` 之类的参数都能用。

配合两个检查脚本（**不靠肉眼看图**）：

```bat
set TIGHTNCM_DUMP_TREE=1 && tools\verify.bat --page home
python tools\check-layout.py build\verify.log      :: 布局重叠回归检查
python tools\probe-pages.py                        :: 逐页像素体检
```

`check-layout.py` 是专为「positioner 漏排子项」那个坑写的回归守卫：
解析场景树 dump，逐父级检测子项是否落在同一个 `(x, y)`。
`TIGHTNCM_DUMP_TREE=1` 会在抓图前把 QML 场景树打到 stderr（含 `xy / 尺寸 / scene 坐标 / 可见性 / ListView 的 count 和 contentHeight`）。

### 正常运行
```bat
tools\dev-run.bat
```
直接双击 `build\TightNCM.exe` 也可以 —— 输出目录是完全自包含的
（Qt 运行库 + Qt 自带 QML 模块 + OpenSSL + Multimedia 插件 + MinGW 运行库）。
已实测：把 PATH 剥到只剩 `C:\Windows\system32` 也能正常渲染和联网播放。

### 调试开关
| 参数 / 环境变量 | 作用 |
|---|---|
| `--page <key>` | 启动直接落到指定页（`home`/`playlist`/`album`/`artist`/`toplist`/`featured`/`podcast`/`fm`/`recent`/`search`） |
| `--screenshot <png>` | 离屏渲染一帧后截图退出 |
| `--playtest <songId>` | 拉播放地址并真播 12 秒，验证音频链路（返回码非 0 即失败） |
| `--seed-demo` | 往播放历史塞 3 条演示数据（离屏验证「最近播放」用） |
| `TIGHTNCM_DUMP_TREE=1` | 抓图前 dump QML 场景树 |
| `TIGHTNCM_SHOT_DELAY_MS` | 调整抓图延迟（默认 4500） |
| `QT_OPENGL` | `angle`（默认）/ `desktop` / `software` |

### Windows 7 注意
- 老显卡走 ANGLE（D3D9/11）最稳：`set QT_OPENGL=angle`（脚本里已默认）。
  ⚠️ `QT_OPENGL=dynamic` 在 MinGW 版 Qt 上是**非法值**，别用。
- 低配机可以试 `QSG_RENDER_LOOP=basic` 降低渲染线程开销（代价是动画略降帧）。

---

## 环境踩坑记录（都已在脚本里绕开）

| 坑 | 现象 | 解 |
|---|---|---|
| 清华 Qt 镜像 | 5.15.2 归档校验和不符（返回的其实是错误页） | 用官方 `download.qt.io` |
| pip 全局配置 | 指向不可达的 tuna 镜像，`pip install` 一律 "from versions: none" | 命令行显式 `--index-url pypi.org` |
| CMake 4.x | 报 Qt5 的 `cmake_minimum_required` 太老 | 钉 `cmake==3.31.6` |
| Git Bash + 原生 exe | PATH 对 DLL 解析不生效，报 `libstdc++-6.dll` 缺失 | 把 MinGW 运行库拷到 exe 旁（`build.bat` 已自动做） |
| `.bat` 里的中文 | cmd.exe 按 OEM 码页解析，命令被拆碎 | **所有 `.bat` 只写 ASCII**（我自己又犯过一次，见下） |
| Qt 日志 | Windows 上走 `OutputDebugString`，重定向到文件就丢 | 设 `QT_FORCE_STDERR_LOGGING=1` |
| **HTTPS 全部失败** | `QSslSocket::supportsSsl()` 返回 0，报 `TLS initialization failed` | Qt 是拿 OpenSSL 1.1.1 编的，必须随包 `libssl-1_1-x64.dll` + `libcrypto-1_1-x64.dll`（放 `assets/runtime/`，`build.bat` 自动拷） |
| windeployqt 提前中止 | 输出 `Unable to find the platform plugin` 后停止，**漏部署 Qt5Multimedia 等 DLL 和插件目录** | 别依赖它，`build.bat` 改成显式 DLL 清单 + robocopy 插件目录 |
| QtMultimedia 无 service | `no service found for - "org.qt-project.qt.mediaplayer"` | 补 `plugins/mediaservice/` 和 `plugins/audio/` |
| `xcopy` 卡住 | 目标已存在时等交互输入，脚本挂死 12 分钟 | 换 `robocopy` |
| C++ 对象与 engine 的声明顺序 | 退出时刷 `Cannot read property 'xxx' of null` | 上下文属性的对象必须声明在 `QQmlApplicationEngine` **之前**（析构是逆序的） |
| 图片占满带宽 | 封面单张 1.1 MB，12 张十几 MB，界面长时间空白 | 图片 URL 一律加 `?param=WxH` |
| `property X` 与 `signal XChanged` | 重名，QML 报 "Duplicate signal name" | 信号改名（如 `volumeEdited`） |
| `Qt.color("...")` | QML 里**不存在**这个函数 | 颜色存字符串，交给 `color` 类属性自动转换 |
| `RoundRect.radius` 写成 alias | 只改了左上角，其余三角还是 0 → 误判为非统一圆角，全走 Shape 慢路径 | `radius` 独立成属性，四角默认绑定它 |
| `Row` 不设 `width` | 内部的 `parent.width` 变循环依赖算成 0 | 给 Row 显式宽度 |
| 同名属性当函数用 | `title: { win.currentSong().name }` 绑定不刷新 | 改成 `readonly property var currentSong` |
| 我自己的疏忽 | 往 `.bat` 里加了中文注释，`%BUILD%` 直接变空、部署全跳过 | ASCII-only 是硬规矩，加注释前先想一遍 |
| `offscreen` 平台 | Windows 上不能创建 GL 上下文，Qt Quick 什么都不画 | 用真实平台 + 窗口直接建在屏幕外 |
| `visible: false` 的窗口 | `contentItem` 尺寸不同步（停在 0x0），**所有 anchors 塌掉** | 窗口保持 visible，靠 `x/y` 放到屏幕外；C++ 再兜底同步一次尺寸 |
| `layer.enabled + layer.effect` | layer 纹理尺寸停在 0x0，图标整个不显示 | 改用「隐藏 Image 当源 + 独立 ColorOverlay」的官方写法 |
| 部署是否自包含 | 只拷 DLL 不够：Qt 自己的 QML 模块（QtQuick / Controls / Shapes / GraphicalEffects）必须也在 `<exe目录>\qml`，否则脱离 Qt 的 PATH 启动就报 `rootObjects is EMPTY` | `build.bat` 里 robocopy 整个 `qml/`（27 MB） |
| `QML2_IMPORT_PATH` 与部署目录同时存在 | 模块解析到一半对不上，刷屏 `type 'Button' is not a type ... 'QtQuick.Controls' '2'` | 脚本里把它指向部署目录 `build\qml`，不要指向 Qt 安装目录 |
| 默认 GL 后端 | 本机走 desktop OpenGL 创建上下文时直接挂（无输出、0xC0000005） | `main.cpp` 里 `QT_OPENGL` 为空时默认设 `angle`；可用环境变量覆盖 |
| **`Column` / `Grid` 漏排子项** | 区块 y 全停在 0、互相重叠、页面总高算错 | 用 `VStack` / `ScrollColumn` 手动排位（见「手动布局」一节） |
| `ListView` 先隐藏后显示 | 不可见时完成首次布局，之后变可见**不会重排** → 整页空白（「最近播放」必现） | `onVisibleChanged: if (visible) Qt.callLater(forceLayout)` |
| `Loader` 里的页头 | item 的 `parent` 创建时是 `null`，`width: parent.width` 的 `Text` 高度被算成 0 且不重算 | 这类 `Text` 用 `TextMetrics` 写死行高 |
| 图标提取带进整块 `rect` | `<defs><clipPath><rect 0 0 24 24>` 被提到根层级，35 个图标渲染成纯色方块 | `normalize-icons.mjs` 里删掉「根层级且等于 viewBox」的 rect |
| 歌词格式 | 新版返回的 `lrc.lyric` **不是 LRC 文本而是 JSONL**（每行一个 `{"t":ms,"c":[{"tx":"..."}]}`） | C++ 侧解析成 `[{t, text, tr}]`，同时兼容标准 LRC |
| `/api/v1/artist/songs` | 不带 `order` 参数直接返回 `400 参数错误` | 必须带 `order=hot` |
| 私人 FM 端点 | `/api/v1/radio/get` 在 `interface.music.163.com` 上 404 | 只在主站 `music.163.com` 上存在 |

---

## 工程结构

> 完整目录职责、加东西的清单、坑位速查表在 **[`AGENTS.md`](AGENTS.md)**。
> 下面是速览。

```
CMakeLists.txt
src/
  main.cpp                注册 QML 单例、注入 Api/Player/Store、基准字体、渲染后端
  net/NcmApi.{h,cpp}      ★ 接口客户端（明文 /api/ + MUSIC_U），歌词 JSONL 解析也在里面
  audio/AudioPlayer.{h,cpp} ★ 播放器（QMediaPlayer 封装）
  core/AppStore.{h,cpp}   ★ 本地持久化：音量 / 播放模式 / 喜欢集合 / 播放历史（QSettings）
qml/
  Theme.qml               ★ 80 个设计 token（自动生成，勿手改）
  Metrics.qml             ★ 骨架与组件尺寸（自动生成，勿手改）
  Main.qml                外壳：无边框窗口 / 拖拽 / 四角缩放 / 三区布局 / 播放控制中枢
  shell/
    SideBar.qml           左侧栏（导航 + 吸顶搜索 + 歌单列表）
    NavItem.qml           导航项  164×36 r8
    PlaylistItem.qml      歌单项  164×46
    SectionHeader.qml     分组头「创建的歌单 N」
    TopBar.qml            顶栏 高 72，拖拽区 + 窗控
    SearchBox.qml         搜索框 258×36 r8
    PlayBar.qml           播放栏 高 80，播放模式 / 进度 / 音量 / 音质徽章
    PlayQueuePanel.qml    右侧滑出的播放队列
    LyricPanel.qml        歌词页（含翻译行，点击行可 seek）
    CommentsPanel.qml     右侧滑出的评论区
    LoginOverlay.qml      登录层（粘贴 MUSIC_U）
  pages/
    PageHost.qml          内容区路由 + 各页上行信号的统一转发
    HomePage.qml          推荐（推荐歌单网格 + 每日推荐）
    PlaylistDetailPage.qml 歌单详情（也用于专辑，showTabs:false）
    PlaylistHeader.qml    歌单头部：封面 216 r12 + 堆叠卡 + 信息 + 播放全部 94×40
    SongList.qml          ★ 可复用歌曲表格（表头 + 虚拟化列表 + 可滚动页头）
    SongTableHeader.qml   表头 高 40，列宽与官方 flex 语义一致
    SongRow.qml           歌曲行 高 64，封面 48 r8
    ToplistPage.qml       排行榜（/api/toplist/detail/v2，按分组渲染）
    FeaturedPage.qml      精选 / 歌单广场（分类标签 + 网格）
    ArtistPage.qml        歌手（圆形头像 + 热门歌曲 + 专辑网格）
    FmPage.qml            漫游 / 私人 FM
    PodcastPage.qml       我的播客（订阅的电台）
    RecentPage.qml        最近播放（本地历史）
    SearchPage.qml        搜索（单曲 / 歌手 / 专辑 / 歌单 四个 tab）
    CmdTabs.qml           标签栏（padding 0 16px，激活态靠字重+颜色）
  widgets/
    RoundRect.qml         四角独立圆角（Qt5 的 Rectangle 不支持）
    ShadowBox.qml         CSS box-shadow → DropShadow，可直接粘 CSS 字符串
    AngleGradientRect.qml CSS 角度线性渐变
    CmdButton.qml         对齐官方 desktop-ui 按钮
    Icon.qml              单色 SVG 图标 + 着色
    PlaylistCard.qml      歌单 / 专辑 / 歌手 通用卡片
    CardGrid.qml          卡片网格（手动定位，见下文「手动布局」）
    ScrollColumn.qml      ★ 页面容器（可滚动 + 留白 + 手动纵向堆叠）
    VStack.qml            ★ 手动纵向堆叠（替代不可靠的 Column positioner）
    SectionTitle.qml      区块标题 + 右侧「更多」
assets/
  icons-svg/              319 个官方图标（ncm_<name>.svg）
  runtime/                OpenSSL 1.1.1 DLL（Qt5Network 的 HTTPS 必需）
resources.qrc             自动生成，勿手改
tools/
  verify.bat              离屏渲染验证（--page <key> 可指定页面，--seed-demo 灌演示数据）
  dev-run.bat             正常 / 离屏运行
  check-layout.py         ★ 解析场景树 dump，检测「同位置重叠」的布局回归
  probe-pages.py          逐页像素体检（内容区非背景占比 / 品牌红命中）
  nettest.cpp/.sh         HTTPS 可用性自检
research/                 抓站工具、规格数据、397 个端点清单、还原源码
```

---

## 手动布局：为什么没用 `Column` / `Grid`

这是本项目最容易踩的一个坑，值得单独写一段。

官方界面里纵向堆叠到处都是，直觉上应该用 `Column`。但**在本工程的结构下，
positioner（`Column` / `Grid`）会漏排子项** —— 已用场景树逐项核对：

```
QQuickColumn  xy[40,12] 996x186
  QQuickText  xy[0,0]    36    ← 排到了
  QQuickText  xy[0,36]   26    ← 排到了
  QQuickItem  xy[0,62]   16    ← 排到了
  SectionTitle xy[0,0]   ...   ← 漏了，y 停在 0
  CardGrid     xy[0,0]   ...   ← 漏了，y 停在 0
```

表现是**多个区块全部叠在页面顶部**、页面总高算错、后面内容被裁掉。
触发条件是本工程特有的组合：**内容区所有页面常驻 + 用 `visible` 切换 + 数据在首帧之后才到**。
同样的坑还出现过两次：

- `ListView` 在不可见时完成首次布局，之后变可见不会重排 → 列表整页空白
  （修法：`onVisibleChanged: if (visible) Qt.callLater(forceLayout)`）
- `Loader` 创建页头时 `parent` 还是 `null`，`width: parent.width` 的 `Text`
  高度被算成 0 且不再重算 → 页头文字叠在列表上
  （修法：给这类 `Text` 用 `TextMetrics` 写死行高）

所以本项目里凡是「会动态增删子项 / 子项高度会变」的纵向堆叠，一律用
**`VStack` / `ScrollColumn` 的手动排位**。响应式原理是利用 QML 的
**动态依赖捕获**：`readonly property real _stacked: relayout()` 里的
`relayout()` 会读 `children.length` 和每个子项的 `height`，这些属性都会被
登记为依赖，因此任一子项高度变化都会自动重排 —— 不需要 Timer 轮询。

横向堆叠（`Row`）实测没问题，保持使用。
`tools/check-layout.py` 就是为这件事写的回归守卫：解析场景树，
逐父级检测子项是否落在同一个 `(x, y)`。

---

## 地基组件的设计要点

### `RoundRect` —— 为什么要自己写
Qt 5.15 的 `Rectangle` **只有统一的 `radius`**，而官方界面有 53 处需要「单侧圆角」
（如 `border-radius: 0 80px 80px 0`）。Qt 6.7 才补上分角圆角。
所以这里做了双路径：**四角相同 → 退化成原生 `Rectangle`（零开销）**，
只有真需要分角时才走 `Shape` 路径。实测 855 处 `border-radius` 里 824 处是统一值，快路径命中率 96%。

### `ShadowBox` —— 可以直接粘 CSS
```qml
ShadowBox { css: "0 6px 16px rgba(0,0,0,0.04)" }
```
CSS → `DropShadow` 的映射：

| CSS | DropShadow | 说明 |
|---|---|---|
| `offsetX` | `horizontalOffset` | 直取 |
| `offsetY` | `verticalOffset` | 直取 |
| `blur-radius` | `radius` | 两者都 ≈ 2σ，数值可近似直取 |
| `spread` | `spread` | CSS 是 px 扩张，Qt 是 0..1 比例，已换算 |
| `color` | `color` | 直取 |

`inset 0 0 0 Npx <color>`（官方 CSS 里最常用的 inset 形式）语义等价于 N px 内描边，
Qt 没有对应能力，所以直接画 `border`。

> ⚠️ **`blur-radius ↔ radius` 需要标定一次**。两者量纲相同、都是「≈2σ」，
> 直取是很好的起点，但要像素级一致，建议写个 3 行 QML 并排渲染两个框拟合出曲线。

> 🔌 **当前 box-shadow 是全局关掉的**：`Metrics.enableBoxShadow = false`。
> 原因就是上面那条 —— Qt 里阴影要多一遍 FBO，而且还没标定到像素级。
> 组件（`ShadowBox`）完整保留，把那一个布尔改成 `true` 就全部生效；
> 也可以单独给某个实例写 `shadowEnabled: true` 覆盖。

### `AngleGradientRect` —— QML 的 Gradient 只有横/竖
官方 CSS 里全是带角度的渐变（`242.83deg`、`270deg`…），这里按 CSS 规范把角度换算成起止端点：
```
方向向量 = (sin θ, -cos θ)        // CSS: 0deg 向上，顺时针
渐变线长 L = |w·sinθ| + |h·cosθ|
start = center - dir·L/2 ,  end = center + dir·L/2
```

### `backdrop-filter: blur(120px)` 怎么办
这是全站唯一没法直译的属性（49 处，半径 100~160px）。Qt 没有 backdrop 概念。
**方案：预烘焙。** 这些毛玻璃层背后基本是「专辑封面的模糊放大图」或静态渐变，
不是任意滚动内容。所以把封面缩到 1/8、做一次小半径模糊、缓存成纹理直接贴即可，
视觉几乎一致而成本接近 0 —— 比浏览器还省（`backdrop-filter` 恰恰是浏览器最贵的属性之一）。

---

## 后端：为什么**不需要写加密**

这是本项目最重要的一个发现。新版 web 播放器走的是**明文 `/api/` 端点 + Cookie 鉴权**，
完全没有 weapi 的 AES+RSA，也没有 eapi 的 AES-ECB。

依据（直接从官方 bundle 里读出来的）：

```js
// vendors~app.js —— web 版的 native 加密垫片是直通的
serialData(e)   { return e }     // 原样返回，什么都不做
deSerialData(e) { return e }
encryptId(e)    { return e }
```

而且加密分支还有前置条件：`if (encrypt && deviceId && (osx || clientSign) && appver)`，
浏览器里拿不到 `clientSign`，所以**加密请求会被直接跳过**。

于是实现上只需要：

```
Base    https://interface.music.163.com      （官方把 //music 换成 //interface.music）
鉴权    Cookie: MUSIC_U=<值>
头      os: pc / appver / osver / deviceId / requestId / Referer / Origin
参数    明文，GET 走 query，POST 走 x-www-form-urlencoded
```

已实测可用的端点（`src/net/NcmApi.cpp` 里就是这么用的）：

| 用途 | 端点 |
|---|---|
| 账号 | `GET /api/nuser/account/get` |
| 我的歌单 | `GET /api/user/playlist?uid=&limit=1000` |
| 歌单详情 | `GET /api/v6/playlist/detail?id=&n=100000&s=8` |
| 歌曲详情 | `GET /api/v3/song/detail?c=[{"id":…}]` |
| **播放地址** | `GET /api/song/enhance/player/url?ids=[…]&br=320000` |
| 歌词 | `GET /api/song/lyric/v1?id=&lv=-1&kv=-1&tv=-1` |
| 搜索 | `POST /api/cloudsearch/pc`（`s=&type=1&limit=&offset=&total=true`） |
| 推荐歌单 | `GET /api/personalized/playlist?limit=` |
| 推荐歌曲 | `GET /api/personalized/newsong?limit=` |
| 排行榜 | `GET /api/toplist/detail/v2`（按 TOPPING / OFFICIAL / FEATURE / MUSIC_STYLE / GLOBAL / LANGUAGE / MORE 分组） |
| 歌单广场 | `GET /api/playlist/highquality/list?cat=<分类>&limit=&lasttime=0` |
| 歌手信息 | `GET /api/v1/artist/<id>` |
| **歌手热门** | `GET /api/v1/artist/songs?id=&offset=0&limit=&order=hot`（**`order` 必需**） |
| 专辑详情 | `GET /api/v1/album/<id>`（含 `songs`；`/api/album/v3/detail`、`/api/album/v4/detail` 都返回参数错误） |
| 私人 FM | `GET https://music.163.com/api/v1/radio/get`（**只在主站**，interface 域 404） |
| 我的播客 | `GET /api/djradio/get/subed?limit=&offset=&total=true` |
| 电台节目 | `GET /api/v4/dj/program/byradio?radioId=&limit=&offset=&asc=false` |
| 评论 | `GET /api/v1/resource/comments/R_SO_4_<songId>?offset=&limit=&total=true` |
| 喜欢 / 取消 | `POST /api/song/like`（`trackId=&like=true|false`） |
| 我喜欢的 id 列表 | `GET /api/song/like/get?uid=` |

`research/api-endpoints.txt` 里是从 bundle 里导出的**全部 397 个端点**，需要别的功能直接查。

> ⚠️ 几个坑
> 1. `/api/song/enhance/player/url/v1` 用 GET 会返回 `{"msg":"参数错误","code":400}`；
>    要用 **不带 v1** 的 `/api/song/enhance/player/url`，或者用 POST。
> 2. 图片 URL 一定要加 `?param=WxH`。不加的话 CDN 返回原图，封面单张 **1.1 MB**，
>    一页 12 张就是十几 MB，界面会长时间空着。加了之后 `?param=96y96` 只有 22 KB。
> 3. `/api/v1/artist/songs` 的 `order` 参数是**必需**的，不带就 400。
> 4. `/api/artist/albums` 和 `/api/artist/detail/dynamic` 都返回 400 ——
>    歌手页的专辑列表是从歌曲结果里按 `albumId` 去重推出来的。
> 5. 歌词返回的 `lrc.lyric` 是 **JSONL**，不是 LRC 文本（见「环境踩坑记录」最后几条）。
> 6. 喜欢 / 我的歌单等需要登录态，未登录返回 `code: 301`。`likeSong` 在这种情况会
>    回滚本地 UI 并弹提示，不会假装成功。

### 登录
没实现手机号/二维码登录（那需要接官方登录态加密，工作量大且容易被封）。
走的是**粘贴浏览器 cookie**：从已登录的浏览器里复制 `MUSIC_U` 的值贴进来即可。
界面上有步骤说明（`qml/shell/LoginOverlay.qml`）。

---

## 音频播放

`src/audio/AudioPlayer.cpp`，用 Qt5Multimedia 的 `QMediaPlayer`
（Windows 上走 DirectShow 后端，Windows 7 也支持，MP3/FLAC/M4A 都能解）。

为什么不用 miniaudio：那需要自己处理 HTTPS 拉流 + 解码 + 时钟同步，工作量大得多。
以后如果想更省内存或要更精确的时钟，可以换成 miniaudio + dr_mp3，接口不用变。

自检：
```bat
tools\dev-run.bat --playtest 33894312
```
会打印拿到的 URL、播放状态、12 秒后的播放位置，位置 > 0 就算通路（返回码 0）。
已实测：`state=playing, pos=10162ms / dur=267284ms`，**并且是在把 PATH 剥到只剩
`C:\Windows\system32` 的情况下**跑通的 —— 证明输出目录完全自包含。

> ⚠️ QtMultimedia 需要 `plugins/mediaservice/`（`dsengine.dll` + `qtmedia_audioengine.dll`）
> 和 `plugins/audio/`。缺了会报 `no service found for - "org.qt-project.qt.mediaplayer"`。
> windeployqt 在这台机器上没部署它们，`build.bat` 里已改成显式拷贝。

### 播放逻辑（`qml/Main.qml`）

播放状态集中在 `Main.qml`，`PlayBar` 只做展示和转发：

| 项 | 实现 |
|---|---|
| 播放模式 | `order` 顺序 / `loop` 列表循环 / `singleloop` 单曲循环 / `shuffle` 随机，四种都真实生效；点图标循环切换并 toast 提示 |
| 随机 | `randomIndex(avoid)` 避免连续重复同一首 |
| 自动下一首 | `Player.mediaFinished` → `playNext(true)`；`auto=true` 时顺序模式播完停在最后一首 |
| 私人 FM | 播到批次末尾自动 `loadPersonalFm()` 续下一批（`playingSource === "fm"`） |
| 音量 / 模式 | 写进 `AppStore`（`QSettings`），下次启动恢复 |
| 喜欢 | `AppStore` 本地集合 + `/api/song/like` 双向；`QSet` 对 QML 不可见，所以用 `likeRevision` 版本号当绑定依赖 |
| 播放历史 | `AppStore.addRecent`：去重 + 置顶 + 上限 200 条 + 只存展示字段 |
| 正在播放哪首 | 用**歌曲 id** 判断而不是行号（行号只在当前列表内有效，切页后就对不上） |
| 歌词 | `loadLyric` → C++ 解析 JSONL/LRC → `[{t,text,tr}]`；当前行 = 最后一个 `t <= position`；点击行 seek；自动滚到中间 |

---

## 数据来源与工具

`research/` 目录里的东西都是实测/挖出来的，不是猜的：

| 文件 | 内容 |
|---|---|
| `NEW-UI-SPEC.md` | ★ 界面规格：骨架尺寸、82 个 token 全表、组件尺寸 |
| `QT-FEASIBILITY.md` | CSS → Qt 逐属性可行性对照（基于 100 个真实 CSS 分块统计） |
| `FINDINGS.md` | 前期调研：现成项目对比、抓站结论 |
| `design-tokens.json` | 82 个 token 运行时实测值 + 布局几何 |
| `gen-theme.mjs` | 从 design-tokens.json 生成 `Theme.qml` / `Metrics.qml` |
| `gen-qrc.mjs` | 生成 `resources.qrc` |
| `extract-icons-from-js.mjs` | 从 app.js 挖出 312 个图标 |
| `normalize-icons.mjs` | ★ 图标规范化：清 `width="1em"`、补 `fill="currentColor"`、删掉根层级那块 `viewBox` 大小的 `rect` |
| `decode-sourcemaps.mjs` | 解 CSS 内联 source map |
| `capture*.mjs` | 无头 Edge + CDP 抓站（截图 / DOM / 计算样式） |
| `mirror*.mjs` | 镜像官方静态资源 |
| `api-endpoints.txt` | 397 个端点清单 |
| `snapshot/` | 登录态截图与 DOM |

### 图标体系
官方不用图标字体，而是**内联 SVG**（`fill="currentColor"`）。
317 个 `ncm_<name>.svg` 从两处挖出：app.js 的图标注册表 + 渲染后 DOM。
命名沿用官方 `cmd-icon-<name>`，例如：
`sidebar_home` `sidebar_featured` `sidebar_podcast` `sidebar_fm` `sidebar_community`
`play2` `pause2` `pre` `next` `lyric` `playlist`
`order` `loop` `singleloop` `shuffle`
`Volume0`~`Volume3` `sq` `hq` `sky` `hires` `jymaster`
`logo`(29×29) `title`(101×19 字标) `like` `likenumber_red` `more` `dropdown` …

---

## 进度

- [x] 前期调研：确认无同类「Qt 原生 1:1 复刻」项目
- [x] 抓站：登录态新版界面截图 + DOM + 计算样式
- [x] 规格提取：82 token / 骨架尺寸 / CSS 属性统计
- [x] 资源：319 图标 + 270 张图片 + 100 个 CSS 分块
- [x] 选型论证：Win7 → Qt 5.15.2 + QML + QtGraphicalEffects
- [x] **环境一键安装（`setup-env.bat`）+ 一键编译（`build.bat`）跑通**
- [x] 工程骨架 + 三个地基组件（RoundRect / ShadowBox / AngleGradientRect）
- [x] 外壳：侧栏 / 顶栏 / 播放栏
- [x] **离屏渲染验证管线（`tools\verify.bat`）+ 布局重叠回归守卫（`tools\check-layout.py`）**
- [x] **box-shadow 全局关掉**（`Metrics.enableBoxShadow = false`，组件保留，改一个开关就能开回来）
- [x] **后端接入**：`src/net/NcmApi.cpp`，明文 `/api/` + Cookie，**无需任何加密**
- [x] **音频播放**：`src/audio/AudioPlayer.cpp`（QMediaPlayer），已实测出声
- [x] 登录：粘贴 `MUSIC_U`
- [x] 部署自包含（Qt 运行库 + Qt 自带 QML 模块 + OpenSSL + Multimedia 插件 + MinGW 运行库）

**页面（全部真数据）**
- [x] 推荐（推荐歌单 + 每日推荐）
- [x] 歌单详情（含音质徽章、列宽按官方 flex 语义）
- [x] 搜索结果（单曲 / 歌手 / 专辑 / 歌单 四 tab）
- [x] 排行榜（按官方分组渲染 7 个榜单分类）
- [x] 精选 / 歌单广场（23 个分类标签可切换）
- [x] 歌手（圆形头像 + 热门歌曲 + 专辑）
- [x] 专辑（复用歌单版式，去掉 tab 栏）
- [x] 漫游 / 私人 FM（含「换一批」「不喜欢」「喜欢」）
- [x] 我的播客（订阅的电台）
- [x] 最近播放（本地历史，可一键清空）
- [ ] 关注 / 动态（`StubPage` 占位，写明待做端点）
- [ ] 电台节目详情页

**业务逻辑**
- [x] 四种播放模式真实生效：顺序 / 列表循环 / 单曲循环 / 随机
- [x] 喜欢（本地集合 + 服务端 `/api/song/like` 双向同步，失败回滚）
- [x] 音量与播放模式持久化（`QSettings`）
- [x] 播放历史（去重 + 置顶 + 上限 200 条）
- [x] 歌词：JSONL / LRC 双格式解析、中英对照、点击行 seek、播放自动居中滚动
- [x] 播放队列抽屉（清空 / 点选切歌）
- [x] 评论区（热评 + 最新）
- [x] 私人 FM 播完自动续下一批
- [x] 页面返回栈
- [ ] 本地下载 / 离线缓存
- [ ] 跨设备播放进度同步

### 页面渲染结果
`docs/page-*.png` —— 全部由 `tools\verify.bat --page <key>` 离屏渲染产出，非模拟图。

| 文件 | 页面 |
|---|---|
| `page-home.png` | 推荐 |
| `page-playlist.png` | 歌单详情 |
| `page-toplist.png` | 排行榜 |
| `page-featured.png` | 精选 / 歌单广场 |
| `page-artist.png` | 歌手 |
| `page-album.png` | 专辑 |
| `page-fm.png` | 漫游 / 私人 FM |
| `page-podcast.png` | 我的播客 |
| `page-recent.png` | 最近播放 |
| `page-search.png` | 搜索结果 |
- [ ] 模糊背景预烘焙管线（黑胶页的 blur(120px)）
- [ ] box-shadow 的 `blur-radius ↔ DropShadow.radius` 像素级标定
- [ ] 打包（安装器）

### 当前渲染效果（都是真实 API 数据）
- `docs/home-page.png` —— 推荐页，真实推荐歌单 + 封面
- `docs/playlist-page.png` —— 热歌榜详情，200 首真实歌曲 + 封面 + 音质徽章
- 都由 `tools\verify.bat` 离屏渲染产出

### 自检命令
```bat
tools\verify.bat                     :: 渲染首页
tools\verify.bat --page playlist     :: 渲染歌单页
build\TightNCM.exe --playtest 33894312   :: 音频链路自检（会响 12 秒）
```

---

## ⚠️ 免责声明

本项目为**互操作性目的**的独立开源实现，与网易公司无任何关联、授权或认可关系。

`assets/icons-svg/`、`research/mirror/`、`research/src-recovered/` 下的资源与代码
**版权归网易所有**，仅用于学习与界面还原研究。**不要把它们提交到公开仓库**（见 `.gitignore`）。
发布版应由使用者自行从合法取得的官方客户端中获取资源，或改为自绘同风格素材。

本项目不提供、不鼓励、不支持任何绕过广告、付费内容、会员权益或 DRM 的功能。
使用本项目的音乐服务仍需遵守网易云音乐的服务条款。
