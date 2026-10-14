# AGENTS.md

给在这个仓库里干活的 AI / 人看的操作手册。**先读这一页，再动代码。**

更细的背景（规格、可行性论证、抓站结论）在 `README.md` 和 `research/`。
日常开发日志在 `.workbuddy/memory/`。

---

## 这是什么

**TightNCM** —— 网易云音乐的 PC 客户端，用 **Qt 5.15.2 + QML** 从零实现。

两个不可动摇的目标，所有技术决定都是它们的推论：

1. **必须能跑在 Windows 7 SP1 上** → 锁死 Qt 5.15（Qt 6 官方最低 Win10 1809，
   QTBUG-85851）。5.15.2 是最后一个 LGPL 开源版。
2. **RAM 必须低** → 排除 Electron / WebView2。目标是 80–160 MB
   （实测当前启动约 156 MB）。

界面是**按照官方 web 播放器的实测规格 1:1 复刻**的：

- 尺寸 = 从官方 CSS/DOM 抠出来的字面值（`research/NEW-UI-SPEC.md`）
- 颜色 = 82 个运行时 CSS 变量的实测值（`Theme.qml`，自动生成）
- 图标 = 官方 SVG 原样（`assets/icons-svg/`，319 个）
- 组件源码 = 从 CSS 内联 source map 还原出来的官方 `.tsx`（`research/src-recovered/`）

---

## 硬性约束（违反会出事，没有例外）

### 1. `.bat` 文件只写 ASCII
cmd.exe 用 **OEM 码页**解析批处理文件。任何一个非 ASCII 字节写进 `.bat`
（哪怕只是中文注释）都会**把命令拆碎、静默跳过后面整段脚本**。
这个坑已经踩了两次，两次都是「只加了个中文注释」。
要写中文说明，写进 `.md` 或 `REM` 之外的注释文件里。

### 2. 不要提交 `research/mirror/`、`research/src-recovered/`、`research/snapshot/`
这三个目录是官方静态资源的原样拷贝和反编译产物，已在 `.gitignore` 里。
**不要把里面的内容复制进要发布的代码**。照着规格重新实现，不要粘贴。

### 3. 不要动 `.workbuddy/`
工作区数据，已 gitignore。

### 4. 编译前先关掉正在运行的 exe
否则链接报 `cannot open output file TightNCM.exe: Permission denied`。

```bash
taskkill //F //IM TightNCM.exe        # Git Bash
```

### 5. `Theme.qml` / `Metrics.qml` / `resources.qrc` / `assets/icons-svg/` 是生成物
**不要手改。** 改生成器再重跑：

```bash
cd research
node gen-theme.mjs        # → qml/Theme.qml + qml/Metrics.qml
node gen-qrc.mjs          # → resources.qrc（扫 qml/ 全部文件 + 图标）
node normalize-icons.mjs  # → 规范化 assets/icons-svg/
```

> `Metrics.enableBoxShadow` 这类「开关」也写在生成器里，所以重生成不会丢。

---

## 环境与命令

工具链装在独立目录，**不需要 Qt 账号**（用 aqtinstall 从官方源拉）：

| 组件 | 位置 |
|---|---|
| Qt 5.15.2 (win64_mingw81) | `D:\Qt\5.15.2\mingw81_64` |
| MinGW 8.1.0 64bit | `D:\Qt\Tools\mingw810_64` |
| cmake 3.31.6 / ninja | `C:\Users\Miku\.workbuddy\binaries\python\envs\qt-tools\Scripts` |
| Pillow（验证脚本用） | 同上 venv |

```bat
setup-env.bat          :: 一键装环境（幂等，已装会 skip）
build.bat              :: 编译发布版（无控制台）
build.bat console      :: 编译带控制台版（能实时看到 QML 报错）
run.bat                :: 需要时自动编译，然后启动
run.bat rebuild        :: 强制重编再启动

tools\verify.bat                       :: 离屏渲染 → build\shell-render.png + verify.log
tools\verify.bat --page toplist        :: 指定页 → build\render-toplist.png
tools\verify.bat --page recent --seed-demo
tools\dev-run.bat                      :: 正常运行（带完整环境变量）
```

`build.sh` 是 Git Bash 版的等价物，但**硬编码了上面的绝对路径**，换机器要改。

---

## 目录职责

```
src/
  main.cpp                  注册 QML 单例、注入 Api/Player/Store、基准字体、渲染后端、各种调试参数
  net/NcmApi.{h,cpp}        ★ 接口客户端。明文 /api/ + MUSIC_U。歌词解析也在这里
  audio/AudioPlayer.{h,cpp} QMediaPlayer 封装（DirectShow 后端）
  core/AppStore.{h,cpp}     ★ 本地持久化：音量 / 播放模式 / 喜欢集合 / 播放历史
  core/ColorProbe.{h,cpp}   取封面平均色（沉浸式背景用，见坑 1.6）
  core/TrayNotifier.{h,cpp} 后台切歌的系统通知（直接调 Shell_NotifyIcon，不链 QtWidgets）

qml/
  Theme.qml / Metrics.qml   生成物，勿手改
  Main.qml                  ★ 外壳 + 播放控制中枢（播放模式、喜欢、歌词、面板开关都在这）
  shell/                    侧栏 / 顶栏 / 播放栏 / 三个滑出面板 / 登录层
  pages/                    PageHost 路由 + 各页面
  widgets/                  通用组件（RoundRect / ShadowBox / Icon / CardGrid / VStack …）

assets/
  icons-svg/                319 个官方图标（生成物）
  runtime/                  OpenSSL 1.1.1 DLL（HTTPS 必需，不能删）

tools/
  verify.bat                离屏渲染验证
  crop.py                   放大截图局部，用于逐像素核对（Pillow）
  check-layout.py           ★ 布局重叠回归检查（见下文「验证方法论」）
  probe-pages.py            逐页像素体检
  dev-run.bat               正常运行

research/                   抓站工具 + 规格数据 + 397 端点清单（多数已 gitignore）
  capture-ref.mjs           抓登录态真机渲染图 + 骨架几何
  probe-ref.mjs             同上，可再点进某个歌单
  probe-playlist.mjs        逐元素量官方歌单页几何（封面/Tabs/表头/行）
docs/page-*.png             各页面渲染结果（交付物，由 verify.bat 产出）
```

---

## 加东西的清单

### 加一个新页面

1. `qml/pages/XxxPage.qml` —— 根节点用 `ScrollColumn` 或 `SongList`，
   **别用 `Column`**（原因见「会咬人的坑」第 1 条）
2. `qml/pages/PageHost.qml` —— 加一个常驻实例（`visible: root.pageKey === "xxx"`），
   并在 PageHost 上定义上行的 `signal`（**把数据本体一起传出去**，别让 Main 猜是哪个列表）
3. `qml/Main.qml` ——
   - `Component.onCompleted` 的 `switch (TNCStartPage)` 加一个 `case`
   - `Connections { target: Api }` 里接数据回调
   - `SideBar` 的 `onNavActivated` 里接导航
4. `research/gen-qrc.mjs` 重跑，`build.bat` 重编
5. 必须验证：`tools\verify.bat --page xxx --seed-demo` 能出图，
   且 `check-layout.py` 通过

### 加一个新接口

1. `src/net/NcmApi.h` 声明 `Q_INVOKABLE void loadXxx(args)` + `signals: void xxxReady(...)`
2. `src/net/NcmApi.cpp` 实现。用现成的 `get()` / `post()`，
   需要换域名时传第三个参数 `base`（私人 FM 就得走主站）
3. 归一化：能用 `normalizeSong` / `normalizePlaylist` 就复用
4. **图片 URL 一律 `withSize(url, n)`** —— 不加 `?param=WxH` 会拉原图（封面单张 1.1 MB）
5. `qml/Main.qml` 的 `Connections { target: Api }` 里接上
6. 端点先在命令行实测再写代码，见「验证方法论」

### 加一个新图标

图标从官方 bundle / DOM 里挖，流程：

```bash
cd research
node extract-icons-from-js.mjs    # 从 app.js 的图标注册表挖
node extract-icons-from-dom.mjs   # 从渲染后 DOM 挖（补充上一步缺的）
node normalize-icons.mjs          # ★ 必须跑，否则图标渲染不对
node gen-qrc.mjs
```

**命名沿用官方的 `cmd-icon-<name>`**。注意官方命名有误导：
`more` 画的是**返回箭头**，三点是 `morefunctions`。

---

## 会咬人的坑（按踩到的顺序）

### 1. ★★★ `Column` / `Grid` 在本工程里会漏排子项

**这是最坑的一条。** positioner 只给「创建时已存在的子项」排位，
之后动态加进来或高度变化的子项，`y` 会一直停在 0。

```
QQuickColumn  xy[40,12] 996x186
  QQuickText   xy[0,0]   36    ← 排到了
  QQuickText   xy[0,36]  26    ← 排到了
  SectionTitle xy[0,0]  ...    ← 漏了，y 停在 0
  CardGrid     xy[0,0]  ...    ← 漏了
```

表现：**多个区块全叠在页面顶部**、页面总高算错、后面内容被裁掉。
触发条件是本工程特有的组合 —— **页面全部常驻 + 用 `visible` 切换 + 数据在首帧之后才到**。

**规矩：凡是「会动态增删子项 / 子项高度会变」的纵向堆叠，一律用
`VStack` / `ScrollColumn` 手动排位**（`CardGrid` 也是手算 x/y）。

响应式原理是 QML 的**动态依赖捕获**：

```qml
readonly property real _stacked: relayout()
function relayout() {
    var y = 0
    for (var i = 0; i < children.length; ++i) {
        var c = children[i]; if (!c.visible) continue
        c.y = y; y += c.height + root.spacing
    }
    return Math.max(0, y - root.spacing)
}
```

`relayout()` 里读到的 `children.length` 和每个子项的 `height` 都会被登记为依赖，
所以任一子项高度变化都会自动重排 —— **不需要 Timer 轮询**。

**横向 `Row` 实测没问题，继续用。**

同一根因的两个变体，也都已修：

- **`ListView` 先隐藏后显示不会重排** → 整页空白（「最近播放」必现）
  ```qml
  onVisibleChanged: if (visible) Qt.callLater(forceLayout)
  ```
- **`Loader` 建 item 时 `parent` 是 `null`** → `width: parent.width` 的 `Text`
  高度被算成 0 且不再重算，页头文字压在列表上
  → 这类 `Text` 用 `TextMetrics` 写死行高

### 1.5 ★★★ 这四个坑是「布局看着炸了」的真正来源

**a) `VStack` 必须自己撑高度。**
`VStack` 一度只把排位结果写进内部的 `host`，根节点自己的 `height` 恒为 0。
于是外层 `ScrollColumn` 排位时 `y += c.height` 每次加 0 ——
**所有 VStack 委托全落在同一个 y 上**（排行榜 6 个区块完全重叠、标题叠字）。
`check-layout.py` 抓不到：高度为 0 的子项被它跳过了。
→ 根节点必须有 `height: host.height`。

**b) `anchors.top` 会覆盖 `y`。**
写了 `anchors.top: parent.top` 又写 `y: 8`，那 8px 偏移不生效（封面位置不对）。
要偏移就只用 `y`，不要同时挂 `anchor`。

**c) `Text.lineHeightMode: ProportionalHeight` 乘的是字体的自然行高，不是字号。**
微软雅黑约 1.33em，所以 `font.pixelSize: 24` + `lineHeight: 32/24` 会算出 **42.6px**，
而 CSS 的 `line-height: 32px` 要的是刚好 32。
→ 凡是照着 CSS 的 px 行高还原，一律用 `lineHeightMode: Text.FixedHeight` + 字面 px。

**d) 同 `z` 的兄弟节点按声明顺序叠放。**
沉浸式背景写在「页面背景」那个 `Rectangle` 前面，就被它整个盖掉了（`visible` 是 true、
场景树里也在，就是看不见）。
→ 要盖住底色就把节点声明在底色**之后**；`z` 为负不等于「在最底下还能露出来」。

### 1.6 ★★ QML 的 `grabToImage` 在静止窗口上不会回调

想从封面图里取主色（沉浸式背景要用），第一反应是 `Image` 缩到 8×8 →
`grabToImage` 拿像素。**实测 7 秒都不回调** ——
`grabToImage` 挂在「下一帧」，而 QML 窗口是**按需渲染**的，页面静止时根本不产帧。
→ 取色挪到 C++（`src/core/ColorProbe.cpp`）：把 URL 的 `?param=WxH` 改写成 `8y8`
重新下一张（几百字节），缩到 8×8 求平均色。


只拷 DLL 不够。`QtQuick` / `QtQuick.Controls` / `QtQuick.Shapes` /
`QtGraphicalEffects` 必须在 `<exe目录>\qml` 下，否则脱离 Qt 的 PATH 启动就报
`rootObjects is EMPTY -> QML failed`。

`build.bat` 里用 `robocopy` 拷整个 `qml/`（27 MB）。

**连带坑**：`QML2_IMPORT_PATH` 如果指向 Qt 安装目录、而 `build\qml` 又存在，
两边模块解析会对不上，刷屏 `type 'Button' is not a type ... 'QtQuick.Controls' '2'`。
→ 脚本里一律指向**部署目录** `build\qml`。

验证自包含的正确做法（把 PATH 剥干净）：

```bash
cd build && env -i PATH="/c/Windows/system32:/c/Windows" ./TightNCM.exe --playtest 33894312
```

### 2. ★★ 部署必须包含 Qt 自己的 QML 模块

只拷 DLL 不够。`QtQuick` / `QtQuick.Controls` / `QtQuick.Shapes` /
`QtGraphicalEffects` 必须在 `<exe目录>\qml` 下，否则脱离 Qt 的 PATH 启动就报
`rootObjects is EMPTY -> QML failed`。

`build.bat` 里用 `robocopy` 拷整个 `qml/`（27 MB）。

**连带坑**：`QML2_IMPORT_PATH` 如果指向 Qt 安装目录、而 `build\qml` 又存在，
两边模块解析会对不上，刷屏 `type 'Button' is not a type ... 'QtQuick.Controls' '2'`。
→ 脚本里一律指向**部署目录** `build\qml`。

验证自包含的正确做法（把 PATH 剥干净）：

```bash
cd build && env -i PATH="/c/Windows/system32:/c/Windows" ./TightNCM.exe --playtest 33894312
```

### 2.5 ★★★ 图标着色不能用 `ColorOverlay`（两个独立的坑叠在一起）

**结论：`widgets/Icon.qml` 一行 `ColorOverlay` 都不要有，着色走 C++ 的 `SvgIcon`。**

坑一：**半透明颜色会被预乘**。`Theme.colorBlack5` 是 `rgba(40,50,72,0.6)`，
`ColorOverlay` 把它当预乘色处理，RGB 也被乘 0.6 —— 画出来是 `(24,30,43)` 的近黑，
而不是叠在白底上应有的 `(126,149,185)`。所有三级灰图标都偏黑。

坑二（更致命）：**它是着色器效果，软件渲染后端下整块不画**。
本项目默认后端是 `QT_QUICK_BACKEND=software`（见下一条），
实测切过去之后**侧栏所有图标、播放栏所有按钮全部凭空消失**。

现在 `Icon.qml` 只是 `SvgIcon` 的薄壳：

```qml
SvgIcon {                 // src/core/SvgIcon.{h,cpp}
    property real size: 20
    implicitWidth: size; implicitHeight: size
    multicolor: name === "logo"
}
```

`SvgIcon` 的做法：`QSvgRenderer` 光栅成 ARGB 图 → `QPainter` 用
`CompositionMode_SourceIn` 盖一层纯色（等价 CSS 的 `fill: currentColor`）。
两种后端都成立，透明度语义正确，而且缓存有上限（源图 4MB / 着色结果 8MB）。

**双色图标（`logo`、VIP 徽章这类）必须走 `multicolor: true` 原样画**，
不然红圆 + 白云会被压成一片纯色。

### 3. ★★★ 默认渲染后端是 `software`，不是 ANGLE

实测（1280×800、登录态、全部页面加载完，私有提交内存 / `PagefileUsage`）：

| 后端 | 常驻内存 | 着色器效果 |
|---|---|---|
| `QT_QUICK_BACKEND=software` | **98 MB** | ❌ 不画 |
| `QT_OPENGL=software`（Mesa） | 157 MB | ✅ |
| `QT_OPENGL=angle`（D3D11） | 210 MB | ✅ |

空窗口对照 36.5MB vs 50.2MB —— 也就是说 ANGLE 的开销会随场景复杂度**放大到 100MB+**，
纯粹是 D3D/WARP 那套光栅化栈（`QT_ANGLE_PLATFORM=d3d9` 更差，321MB）。

本工程「RAM 要低」是硬指标，所以 `main.cpp` 里默认设 `QT_QUICK_BACKEND=software`。

代价与对策：**QtGraphicalEffects 的效果在这个后端下行为不一致** ——
实测 `ColorOverlay` 不画（图标全消失），但 `LinearGradient` 正常
（`AngleGradientRect` 的选中药丸、播放按钮渐变都在）。所以：
- 图标 → `SvgIcon`（QPainter，不依赖着色器）
- 渐变 → 继续用 `LinearGradient`（已验证可用）
- 阴影 → `ShadowBox` 的 `DropShadow` 默认关着（`Metrics.enableBoxShadow=false`），要开的话得改成分层圆角矩形

要换回 GPU 时用环境变量或 `--renderer`：

```bash
QT_OPENGL=angle  ./TightNCM.exe      # 或 --renderer angle（+100MB）
QT_OPENGL=desktop ./TightNCM.exe     # 有好显卡驱动时最快
QT_OPENGL=software ./TightNCM.exe    # Mesa 软件 GL（着色器可用，+46MB）
```

**`QT_OPENGL=desktop` 在本机创建上下文时直接挂**（无输出、`0xC0000005`）。
**`QT_OPENGL=dynamic` 在 MinGW 版 Qt 上是非法值**，会打
`Invalid value set for QT_OPENGL`，别用。

### 4. ★★ 图标 SVG 的四个陷阱

**先跑整条流水线，别手改 `assets/icons-svg/`：**

```bash
cd research
node extract-icons-from-js.mjs   # 从 app.js 的图标注册表挖（权威，354 个）
node extract-icons-from-dom.mjs  # 从渲染后 DOM 补（会跳过「只有空壳」的，不会覆盖）
node normalize-icons.mjs         # ★ 必须跑
node gen-qrc.mjs
```

`normalize-icons.mjs` 处理这两件事：

- 根节点带 `width="1em"` → 只会渲染成 12px（这就是 logo 变「...」的原因）
- `<defs><clipPath><rect x=0 y=0 width=24 height=24>` 里的遮罩 rect 被提取器
  提到了根层级 → 被当成实心方块画出来（**35 个图标中枪**，表现是图标变纯色块）。
  修法是删掉「根层级且正好等于 viewBox」的 rect（`<defs>` 内的保留）

另外：没写 `fill` 的路径默认黑色、无法着色 → 统一补 `fill="currentColor"`。
`logo` 是红圆+白云的双色图标，特例处理。

**图标流水线自己踩过的三个坑（都已在脚本里修好，别改回去）：**

1. **提取器的 `[\s\S]{0,4000}?` 上限太小** —— 有 12 个图标的 path 数据超过 4000 字符
   （最多 4.3K），正则够不到闭合的 `})`，图标被静默跳过，随后被 DOM 提取器写成
   **空的 `<svg>`**。表现是图标完全不可见（播放栏的音量/静音、`next`、设置页细齿轮…）。
   → 上限提到 40000；DOM 提取器也加了「只有空壳就跳过」的保护。
2. **多色特例的正则没保住自闭合的 `/`** —— 生成出 `<circle ... / fill="#FC3D49">`，
   不是合法 XML，整张 SVG 解析失败（logo 直接不显示）。
3. **viewBox 和路径坐标对不上** —— 例如 `ncm_next.svg` 的 viewBox 是 `0 0 24 24`
   而路径坐标在 45~57，整个画到可视区外面（**播放栏的「下一首」就是这么消失的**）。
   → `normalize-icons.mjs` 会按真实几何算包围盒，**只对明显溢出的**（>1.5× 画布）
   做 viewBox 自适应。留白型的图标不动，免得被放大。

**坑三：名字对得上的图标未必是同一个设计。**
`ncm_next.svg` 是从别的上下文挖出来的（viewBox 被自动裁成 `14.88×16.23`），
画出来是个**实心大三角**，比旁边的 `pre` 大一倍。官方 `next` 是 `pre` 的水平镜像，
对应资源是 **`next_song`**（24×24 那套）。播放栏现在用 `next_song`。

**坑四：VIP 徽章不是单色图标，没法用 `Icon` 画。**
实测（1280×800 登录态）它是 48×16 的双色合成图：
左侧 16×16 **黑胶唱片**（深灰外沿 + 深色盘面 + 中心 4×4 红标 `#FC3D49`），
右侧 40×14 深色药丸（`#2B2727`）配米白文字（`#F2E0DE`）。
原来写成 `Icon{name:"vip"}` 就被整块染成近黑。现在独立组件 `shell/VipBadge.qml`。

顺带：`Api.vipType` 是**位掩码不是等级**（这台账号是 110），
直接拼进 "VIP·N" 会变成 "VIP·110"，只在 1..7 时才显示数字。

**改名/新增图标后跑 `python tools/check-icons.py`** ——
它会扫出「QML 引用了但 svg 不存在」和「svg 存在但是空文件」两类问题，
这两种在运行时都不会报错，只是图标默默不显示。
### 5. 歌词不是 LRC，是 JSONL

新版 `/api/song/lyric/v1` 返回的 `lrc.lyric` **不是 LRC 文本**：

```json
{"t":0,"c":[{"tx":"作词: "},{"tx":"张国祥"}]}
{"t":1000,"c":[{"tx":"作曲: "}]}
```

每行一个 JSON 对象，`t` 是毫秒，`c` 是片段数组（拼 `tx` 就是整行）。
`NcmApi::parseLyric` 统一解析成 `[{t, text, tr}]`，**同时兼容标准 LRC**（老接口/部分歌曲）。

### 6. QML 语言层面的坑

| 坑 | 现象 | 解 |
|---|---|---|
| `property int volume` + `signal volumeChanged` | `Duplicate signal name` | 信号改名（如 `volumeEdited`） |
| `Qt.color("...")` | QML 里**不存在**这个函数 | 颜色存字符串，交给 `color` 类属性转换 |
| `RoundRect.radius` 写成 `alias topLeftRadius` | 只改左上角，其余三角为 0 → 误判为非统一圆角，全走 Shape 慢路径 | `radius` 独立属性，四角默认 `: radius` |
| `Row` 不设 `width` | 内部的 `parent.width` 变循环依赖算成 0（歌手名整列不显示） | 给 `Row` 显式宽度 |
| 属性当函数用 | `title: { win.currentSong().name }` 绑定不刷新 | 改成 `readonly property var currentSong` |
| `layer.enabled` + `layer.effect: ColorOverlay` | layer 纹理停在 0x0，**所有图标都不可见** | 用「隐藏 `Image` 当源 + 独立 `ColorOverlay`」 |
| `Column` + 占位 `Item` 模拟 `margin-top:auto` | `childrenRect` 自引用，算不出来 | 用 `anchors.bottom` |
| `visible: false` 创建的窗口 | `contentItem` 尺寸不同步（停在 0x0），**所有 anchors 塌掉** | 窗口保持 visible + `x/y` 放屏幕外；C++ 再兜底 `setSize()` |
| `offscreen` 平台 | Windows 上不能创建 GL 上下文，Qt Quick 什么都不画 | 用真实平台 + 窗口建在屏幕外 |
| C++ 对象声明顺序 | 退出时刷 `Cannot read property of xxx of null` | 上下文属性的对象必须声明在 `QQmlApplicationEngine` **之前**（析构逆序） |
| ★★ `Item` 只写 `implicitHeight` 不写 `height` | 自身 `height` 恒为 0，外层容器量到 0 → **整段内容叠在一起**（设置页的开关全糊成一团） | 自定义组件两个都要给：`height: implicitHeight`。`Row` / `Column` 这类 positioner 的 `height` 同理 |
| ★★ `default property alias content: someVStack.data` | 子项进的是**根节点**的 data，跟内部 `host` 平级，VStack 的排位函数（遍历 `host.children`）看不到 → 量出来高度 0 | alias 到 `.content`（即 `host.data`），不要 alias 到 `.data` |
| 用了 `Screen.devicePixelRatio` 却没 import | 满屏 `ReferenceError: Screen is not defined`（一个列表能刷几百条） | `Screen` 是 `QtQuick.Window` 的附属属性，必须 `import QtQuick.Window 2.15` |
| 图片 `sourceSize` 硬编码成 2× | 1× 屏上白白多占 **4 倍** 内存/显存（封面 336² vs 168²） | `sourceSize.width: Math.max(1, Math.round(width * Screen.devicePixelRatio))` |

### 7. 接口层的坑

| 坑 | 解 |
|---|---|
| `/api/song/enhance/player/url/v1` GET → 400 | 用**不带 v1** 的 `/api/song/enhance/player/url` |
| 图片不带 `?param=WxH` | 封面单张 **1.1 MB**，一页 12 张十几 MB，界面长时间空白 |
| `/api/v1/artist/songs` 不带 `order` → 400 | `order` 是**必需参数** |
| `/api/artist/albums`、`/api/album/v3/detail`、`/api/album/v4/detail` 全 400 | 歌手页的专辑从歌曲结果里按 `albumId` 去重推出来；专辑详情用 `/api/v1/album/<id>` |
| 私人 FM `/api/v1/radio/get` 在 interface 域 404 | 只在主站 `music.163.com`（`get()` 的第三个参数） |
| `/api/song/like` 未登录返回 `code:301` | `likeSong` 要**回滚本地 UI 并提示**，不能假装成功 |
| ★★ `/api/v6/playlist/detail` 的 `tracks` / `privileges` **会被截断** | 实测同一接口：741 首的歌单回 741 条，**900 首的只回 20 条**、`privileges` 也只有 20 条。表现就是「打开歌单只显示前几首」。**只有 `trackIds` 是完整的** → 一律以它为准，缺的用 `/api/v3/song/detail?c=[{"id":..},...]` 分批补（这个接口 `songs` 和 `privileges` 一起给）。`NcmApi::loadPlaylistDetail` 已经这么做了 |
| ★★ `specialType == 5` 不代表「**我**喜欢的音乐」 | 每个用户都有一条「XX喜欢的音乐」，`specialType` 都是 5，**收藏了别人的**也会出现在 `/api/user/playlist` 里。只判断 specialType 会：① 把别人的 liked 歌单 prepend 进「创建的歌单」② 用别人的 id 覆盖 `m_likedPlaylistId` → 点「我喜欢的音乐」进去是别人的歌单。必须同时判 `authorId == userId()` |
| 换号后仍显示上一账号的歌单 | `setMusicU` 换 token 时要**立刻**清空 `m_profile` / `m_likedPlaylistId` 并 emit，否则 `loadAccount` 回来之前 `loggedIn()` 一直是 true，登录层会误判成功、界面继续挂旧数据。QML 侧还要清 `createdPlaylists` / `collectedPlaylists`，`AppStore` 用 `setLikedIds`（整体替换）而不是 `mergeLikedIds`（并集） |

### 8. 环境层的坑

| 坑 | 解 |
|---|---|
| 清华 Qt 镜像的 5.15.2 归档**校验和不符**（返回的其实是 HTML 错误页） | 只用官方 `download.qt.io` |
| 本机 pip 全局配置指向不可达的 tuna 镜像 | 命令行显式 `--index-url https://pypi.org/simple` |
| CMake 4.x 拒绝 Qt5 的老 `cmake_minimum_required` | 钉 `cmake==3.31.6` |
| Git Bash 直接跑原生 exe，PATH 对 DLL 解析不生效 | 把 MinGW 运行库拷到 exe 旁（`build.bat` 已自动做） |
| Qt 日志在 Windows 走 `OutputDebugString`，重定向就丢 | 设 `QT_FORCE_STDERR_LOGGING=1` |
| windeployqt **提前中止**（`Unable to find the platform plugin`），漏部署 Qt5Multimedia 和插件目录 | 别依赖它，`build.bat` 用显式 DLL 清单 + robocopy |
| `xcopy` 目标已存在时等交互输入，脚本挂死 12 分钟 | 换 `robocopy` |
| `QSslSocket::supportsSsl() == 0`，HTTPS 全挂 | Qt 是拿 OpenSSL 1.1.1 编的，必须随包 `libssl-1_1-x64.dll` + `libcrypto-1_1-x64.dll` |

---

## 验证方法论

### 这里没法靠眼睛

**当前会话的模型读不了图片。** 而且离屏渲染的截图肉眼看也容易漏掉「区块叠在一起」
这种问题（它们看起来就像只有一块）。所以验证全部走**几何数据**。

### 三条硬指标

```bash
# 1) 编译通过
cmd //c "build.bat"

# 2) 渲染 + 布局回归（核心）
cmd //c "set TIGHTNCM_DUMP_TREE=1&& tools\\verify.bat --page home --seed-demo"
python tools/check-layout.py build/verify.log     # 必须输出「布局检查通过」
grep -icE "qrc:/qml|TypeError|Binding loop|is not a type" build/verify.log   # 必须为 0

# 3) 音频链路（自包含验证：故意把 PATH 剥干净）
cd build && env -i PATH="/c/Windows/system32:/c/Windows" ./TightNCM.exe --playtest 33894312
# 期望 state=playing，exit 0
```

### 全量跑一遍所有页面

```bash
for p in home toplist featured artist album fm recent search podcast; do
  cmd //c "set TIGHTNCM_DUMP_TREE=1&& tools\\verify.bat --page $p --seed-demo"
  python tools/check-layout.py build/verify.log | tail -1
done
```

### `tools/check-layout.py` 是干什么的

解析场景树 dump，逐父级检测子项是否落在**同一个 `(x, y)`**。
它就是为了「positioner 漏排子项」那个坑写的**回归守卫** —— 不是可有可无的工具，
改任何布局之后都要跑。

`TIGHTNCM_DUMP_TREE=1` 会打印：
`className / 本地 xy / 尺寸 / scene 坐标 / visible / ListView 的 count 和 contentHeight`。

> `count` 和「真正实例化了几条委托」**不是一回事**（`reuseItems` / 懒加载）。
> 排查「列表是空的」时要看委托实例数，不是 `count`。

### 写新接口前先在命令行实测

不要写完 C++ 再发现端点不通。`curl` 一发就知道：

```bash
UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/131.0.0.0 Safari/537.36"
curl -s -A "$UA" -H "Referer: https://music.163.com/" -H "os: pc" -H "appver: 3.1.0" \
  "https://interface.music.163.com/api/toplist/detail/v2" | head -c 300
```

---

## 调试开关

| 参数 / 环境变量 | 作用 |
|---|---|
| `--page <key>` | 启动直接落到指定页：`home` `playlist` `album` `artist` `toplist` `featured` `podcast` `fm` `recent` `search` |
| `--screenshot <png>` | 离屏渲染一帧后截图退出 |
| `--playtest <songId>` | 拉播放地址并真播 12 秒，验证音频链路（返回码非 0 即失败） |
| `--seed-demo` | 往播放历史塞 3 条演示数据（离屏验证「最近播放」用） |
| `--musicu <token>` | 命令行注入 MUSIC_U 登录态（写进 QSettings，只需传一次） |
| `--page playlist:<id>` | `--page` 也认 `playlist:` / `album:` / `artist:` 冒号语法，用来验证大歌单这类只在特定数据下暴露的问题 |
| `--page-delay <ms>` | 启动先停在首页，延迟这么久再切到 `--page`。**复现「页面先隐藏、数据后到」必须用它**（`--page` 是首帧前就切好，复现不了） |
| `--memtest <id,id,...>` | 连续换歌，每次打点进程私有提交内存。用来判断「越听 RAM 越大」到底是不是泄漏 |
| `--memtest-sec <n>` | 上面那条每首歌停留几秒（默认 5） |
| `--memhold <sec>` | 正常启动，每秒打点一次私有提交内存，到期退出。**量稳态内存用这个** |
| `--blank` | 加载 `qml/Blank.qml`（只有一个同尺寸空窗口）。拿它量「C++ + Qt + 引擎」的底噪 |
| `--qml <路径>` | 从**文件系统**加载入口 QML。内存/布局二分时用，改 QML 不用重编译 |
| `--renderer <sw\|angle\|desktop\|mesa>` | 覆盖渲染后端（等价于设 `QT_OPENGL`） |
| `--selftest` | 只验证动态库能否加载 |
| `TIGHTNCM_DUMP_TREE=1` | 抓图前 dump QML 场景树 |
| `TIGHTNCM_SHOT_DELAY_MS` | 抓图延迟（默认 4500ms；带网络请求的页面可调到 6000） |
| `QT_QUICK_BACKEND` | `software`（默认，见坑 3）/ 不设则走 GL |
| `QT_OPENGL` | `angle` / `desktop` / `software`（设了它就会覆盖默认的软件光栅） |
| `QT_DEBUG_PLUGINS=1` | 排查插件/模块加载失败 |
| `QT_FORCE_STDERR_LOGGING=1` | 让 Qt 日志能重定向到文件 |

---

## 设计约定

- **中文注释，且解释「为什么」** —— 这个项目里几乎每条注释都在记录一个踩过的坑。
  写注释时优先写清「为什么这么做」而不是「这行做了什么」。
- **尺寸/颜色一律来自 `Theme` / `Metrics`**，不要在页面里硬编码魔法数。
  新规格先加进 `research/gen-theme.mjs` 再重生成。
- **`PageHost` 的上行信号要传数据本体**（`playRequested(songs, index)`），
  不要让 `Main` 去猜「当前是哪个列表」。
- **「正在播放哪首」用歌曲 `id` 判断，不要用行号** ——
  行号只在当前列表内有效，切页/搜索之后就对不上了。
- **`QSet` 之类的容器对 QML 不可见** ——
  要暴露给 QML 做绑定依赖时，加一个自增版本号属性（参考 `AppStore.likeRevision`）。

---

## 已知未完成

- 关注 / 动态页（`StubPage` 占位，待做端点写在里面了）
- 电台节目详情页
- 播放队列不能拖动排序
- 本地下载（设置页的「下载」栏目前只存偏好，功能没落地）
- `box-shadow` 全局关着（`Metrics.enableBoxShadow = false`，组件保留）
- 最大化的窗口会盖住任务栏（要处理 frame margin）
- VIP 徽章的多色还原
- 本地下载 / 离线缓存
- 跨设备播放进度同步
