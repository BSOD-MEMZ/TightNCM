# CSS → Qt 可行性对照（实测版）

数据来源：`research/mirror/` 里镜像下来的全部 100 个 CSS 分块（新版设计系统）。
所有样例都是从真实 CSS 里抽出来的，不是猜的。

---

## 0. 先说版本：Win7 把选型锁死了

| 事实 | 出处 |
|---|---|
| Qt 6 **不支持 Win7/Win8.x**，最低 Win10 1809 | QTBUG-85851 / QTBUG-85855，官方发布说明 |
| 最后一个支持 Win7 的 Qt 系列是 **5.15**（32/64 位都行） | 同上 |
| Qt **5.15.2** 是最后一个开源（LGPL）发布版；5.15.3 起长期只有商业版 | qt.io 公告 |
| KDE 维护 `kde/5.15` 补丁集供开源项目继续用 | community.kde.org/Qt5PatchCollection |

**结论：`Qt 5.15.2 + QML + QtGraphicalEffects`。**
配套：MSVC 2019（或 MinGW 8.1）+ CMake，Windows 上让 Qt 自己选渲染后端（`-opengl dynamic`，老显卡会自动落到 ANGLE/D3D）。

顺带一个反直觉的好消息：**Qt 5.15 的 `QtGraphicalEffects` 覆盖面比 Qt 6.5 的 `MultiEffect` 还宽**——Qt 6 的 MultiEffect 只有 blur/shadow/mask/colorization/brightness/contrast/saturation（**没有 hue-rotate，也没有 shadow spread**），而 Qt 5 的 `HueSaturation` / `DropShadow` 两个都有。代价是 QtGraphicalEffects 每个效果多一次 FBO pass，靠缓存解决。

---

## 1. 逐属性对照表

### ✅ border-radius — 855 处 / 122 种
实际分布：单值 824、**多角 53**、含 `%` 103、含 `var()` 123。

高频值：`8px`(125) `50%`(96) `10px`(92) `4px`(70) `6px`(62) `12px`(39) `80px`(36)
多角样例：`0 80px 80px 0`(9) `10px 10px 0 0`(8) `80px 0 0 80px`(4)

**Qt 方案**
- 单值 → `Rectangle { radius: 8 }` 直接对应
- `50%` → 圆形，`radius: width/2`
- **多角（53 处）→ Qt 5 的 `Rectangle` 只有统一 radius**，需要 `Shape` + 圆角 `PathAngleArc` 手撕路径，或者 `OpacityMask`（用一张圆角遮罩图裁）。Qt 6.7 才给 Rectangle 加了分角圆角；Qt 5.15 没有，这块要自己封装一个 `RoundedRect` 组件。
- 多角样例里最常见的形态就是"一侧圆角"（`0 80px 80px 0`），封装一次就能全用

### ✅ box-shadow — 128 处 / 56 种，**全是单层小阴影**
高频样例：
```
22x  0 6px 16px rgba(0,0,0,0.04)          ← 主卡片阴影
10x  inset 0 0 0 1px var(--colorBlack11)  ← 这其实是 1px 内描边，直接换 border
 7x  0 6px 16px rgba(40,50,72,0.04)
 4x  0 1px 2px rgba(0, 0, 0, 0.2)
 4x  0 2px 15px rgba(0,0,0,0.1)
```

**Qt 方案**：`QtGraphicalEffects.DropShadow`
- `horizontalOffset` / `verticalOffset` → CSS 的 x / y，对应关系直白
- **`spread` → `spread`，连名字都一样**
- `color` → `color`
- `blur-radius` → `radius` + `samples`。CSS 的 blur-radius ≈ 2σ 的高斯，DropShadow 用 `radius`(≈2σ) + `samples`（建议 = 1+radius）近似。**这一项需要标定**：写个 3 行 QML 小工具并排渲两个框，把映射曲线拟合出来，之后所有阴影就能机器翻译。
- `inset 0 0 0 1px` 这类假阴影 → 直接用 `Rectangle.border.width: 1`，比渲染阴影还便宜
- 多层阴影 → 叠多个 DropShadow（本项目没有多层，最多 1~2 层）

**结论：box-shadow 是三个里最好办的**，跟你的直觉一致。

### ✅ filter — 只有 12 处，几乎白送
镜像是 `blur()` 43 次、`brightness()` 8、`grayscale()` 2、`drop-shadow()` 1（含 backdrop 统计）。

**Qt 方案**（全部一一对应）

| CSS | Qt 5.15 QML |
|---|---|
| `blur(Npx)` | `GaussianBlur { radius: N; deviation: N/2; samples: ... }` 或 `FastBlur` |
| `brightness(v)` | `BrightnessContrast { brightness: v-1 }` |
| `contrast(v)` | `BrightnessContrast { contrast: v-1 }` |
| `saturate(v)` | `HueSaturation { saturation: v-1 }` |
| `grayscale()` | `Desaturate { desaturation: 1 }` |
| `hue-rotate(Ndeg)` | `HueSaturation { hue: N/360 }` ← **Qt 6 MultiEffect 反而没这个** |
| `drop-shadow(...)` | `DropShadow` |
| `opacity(v)` | `opacity: v` |
| `sepia()` / `invert()` | 自写一个 10 行 `ShaderEffect`（本项目 CSS 里没用到） |

### ⚠️ backdrop-filter — 49 处，**唯一真实的硬骨头**
```
10x  blur(100px)
 8x  blur(112.5px)
 6x  blur(120px)
 4x  blur(20px)
 2x  blur(160px) / blur(50px) / blur(30px) / blur(25px) / blur(11.77px)
 2x  grayscale()
```
注意：**只有 `blur()` 和 `grayscale()` 两个函数，但半径大得离谱**（100~160px，是全屏级别的背景虚化，不是小玻璃面板）。另有 `var(--skin-blur)` 皮肤变量。

详见解第 2 节。

### ✅ linear-gradient — 51 处 / 12 种，含**带角度多停靠点**
```
 6x  0deg, #a3aacc 0%, #7a8099 100%
 4x  242.83deg, #fc3d49 16.96%, #fc3d49 34.33%, #ff1168 83.04%
 2x  158deg, #fa5b5b 13%, #ff3a3a 88%
 1x  256deg, #ff8f50 -7%, #ff473c 99%
```
（还有 18 处 `#fff 0 0` / 12 处 `#fff 0, #fff 0` —— 是纯色兜底写法，可以直接当 `color`）

**Qt 方案**：`Qt5Compat.GraphicalEffects.LinearGradient` 或 `Shape { ShapePath { fillGradient: LinearGradient{...} } }`，支持任意 `x1,y1,x2,y2` + 任意多 stop。
角度要换算（CSS 的 `Ndeg` 是基于中心、从"向上"开始顺时针）：
```qml
// CSS linear-gradient(<deg>, ...) -> QML 端点
const rad = (deg - 90) * Math.PI / 180;
const L = Math.max(w, h);          // 起止点放在外接半径上
x1 = w/2 - Math.cos(rad)*L/2;  y1 = h/2 - Math.sin(rad)*L/2;
x2 = w/2 + Math.cos(rad)*L/2;  y2 = h/2 + Math.sin(rad)*L/2;
```
**注意：QSS 的 `qlineargradient(x1,y1,x2,y2,stop:..)` 不支持角度写法，且语法是私有格式。这是 Qt Widgets 路线第二次被判死刑。**

### ✅ transform — 244 处，全支持
QML 的 `Item` 天生有 `scale` / `rotation` / `transformOrigin` / `transform: [ Translate, Rotate, Scale, Matrix4x4 ]`，`Matrix4x4` 能给任意 2D/3D 仿射矩阵。CSS 的 `translate/rotate/scale/skew/matrix/perspective` 全能写。

### ✅ animation / @keyframes — 80 组
实测 keyframes 里真正动的属性：
```
291x opacity      269x transform     55x width
 49x height        20x top           19x left
 16x background    15x color         10x bottom
  6x right          3x border         3x box-shadow
```
**Qt 方案**：`SequentialAnimation` + `NumberAnimation` / `PropertyAnimation`；多关键帧场景用 Qt 6.4 才有的 `KeyframeGroup`（Qt 5 没有），所以改用多个 `SequentialAnimation` 串联或手写 `onXChanged` 插值。旋转/呼吸/骨架屏/跑马灯这些都能做。

**这里 Qt 反而占优**：CSS 里动 `width/height/top/left` 会触发 layout 重排（浏览器里很贵），而 QML 的属性都是可直接动画的普通属性，成本低得多。

### ✅ transition — 120 处 / 50 种，含延迟
```
11x opacity 0.2s ease-in 0s
 6x opacity 0.48s ease-out 1s      ← 有 1s 延迟
 8x width 0.2s
 6x all 0.4s ease-in 0s
 4x transform 0.3s
```
**Qt 方案**：`Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }`；延迟用 `PauseAnimation` 前缀包进 `SequentialAnimation`。

### ✅ cubic-bezier — 8 条曲线 / 33 处 → **1:1 直译**
```
10x cubic-bezier(0.25, 0.46, 0.45, 0.94)
 8x cubic-bezier(0.215, 0.61, 0.355, 1)
 6x cubic-bezier(0.65, 0, 0.35, 1)
 3x cubic-bezier(0.62, 0.05, 0.36, 0.95)
```
QML 有现成的 `Easing.Bezier`，四个控制点直接填：
```qml
NumberAnimation { easing.type: Easing.Bezier
                  easing.bezierCurve: [0.25, 0.46, 0.45, 0.94, 1, 1] }   // 后两个 1,1 是 CSS 隐含的 P2
```
CSS 的三次贝塞尔隐含终点 `(1,1)`，正好补上就行。**这是整条路上最丝滑的一对映射。**

### ✅ clip-path — 只有 2 处 / 1 种
`inset(8px 7px 7px 9px round 10px)` → 就是一个带 margin 的圆角矩形，用 `Rectangle` + 外边距即可，或 `OpacityMask`。可忽略复杂度。

### ✅ mix-blend-mode — **只用过 `normal`**，直接忽略
### ✅ 字体 — 内嵌 `data:font` + 外部 ttf
字体族：`dolphin` / `dolphin-s`（网易自制）、`SFPro-Regular`、`desktop-ui-tag-font`；外部还有 `desktop_time.ttf`、`DreamHanSerifCN-W17.ttf`。
**Qt 方案**：`QFontDatabase::addApplicationFontFromData(QByteArray::fromBase64(...))` 或 `addApplicationFont(path)`。**字形能 100% 一致，这是 Qt 相对 webview 方案的独有优势。**

### ✅ 图标 / 图片 — 已镜像 270 个 PNG + 61 个 SVG
`Image { source: "qrc:/assets/..." }` + `QtSvg` 模块。打包进 qrc 还能省掉运行时 IO。

### ✅ 布局 / 文本
| CSS | QML |
|---|---|
| flex row/col | `RowLayout` / `ColumnLayout` / `Row` / `Column` |
| flex wrap | `Flow` |
| grid | `GridLayout` |
| position: fixed/sticky | 拿出来单独摆，不给它滚动 |
| `line-height` | `Text.lineHeight` + `lineHeightMode: Text.ProportionalHeight` |
| `letter-spacing` | `font.letterSpacing` |
| `text-overflow: ellipsis` | `elide: Text.ElideRight` |
| `::before / ::after` | 加子 `Item` |

### ✅ 长列表（歌单几千条）
`ListView` + `reuseItems: true`（Qt 5.15 已支持 delegate 复用）。这块比 DOM 强得多，是原生方案的主要收益点之一。

---

## 2. 唯一硬骨头：backdrop-filter: blur(100~160px)

**为什么难**：它要求采样"已经画在自己背后的那些像素"。Qt 没有 backdrop 这个原生概念。

三条路，按工程推荐度：

**A. 实时方案（能跑但不推荐）**
```qml
ShaderEffectSource { id: bg; sourceItem: behindItem; live: true }
GaussianBlur { source: bg; radius: 120; ... }
```
或自己写个 dual-pass Kawase blur 的 `ShaderEffect`（性能可控性更好）。
问题：半径 100~160px 是全屏级模糊，每帧重算，低配机上必炸。

**B. 预烘焙方案（推荐，⭐）**
观察一下这些 backdrop 层背后到底是什么：**几乎全是「专辑封面的模糊放大背景」或静态渐变**，不是任意滚动内容。
所以：
1. 拿封面图 → 缩到 1/8 尺寸 → 做一次小半径模糊 → 缓存成纹理
2. backdrop 区域直接贴这张纹理（`Image` 拉伸），效果和大半径模糊几乎一致（大半径模糊本来就是低频信息）
3. 换歌时才重算一次，成本接近 0

**C. 分层缓存**
`ShaderEffectSource { live: false; recursive: true }` 只在背景真正变化时重算；配 `layer.enabled` + 合理 `layer.textureSize`。
⚠️ 别乱开 `layer.enabled`：每个 layer 就是一张 FBO 纹理，显存和内存都涨。

**结论：能还原，而且能比浏览器更省。** 浏览器里 `backdrop-filter` 恰恰是它最贵的属性之一（要额外全屏采样 + 独立合成层），我们把它换成"预模糊纹理"反而更快。

---

## 3. 性能 / RAM 预算

| 方案 | 常驻内存 | 备注 |
|---|---|---|
| Qt Quick 空窗口 | 35–45 MB | 基线 |
| **本项目预期** | **80–140 MB** | 视封面缓存与列表规模 |
| WebView2 壳 | 150–250 MB | 你已排除（Win7 也不支持） |
| Electron | 300–500 MB | 你已排除 |

**具体的省内存手段**
- 封面统一走 `QPixmapCache`，设硬上限（如 60MB），别让长列表无限缓存
- `ListView { reuseItems: true }`，delegate 里别放重对象
- 静态阴影 / 渐变 / 背景模糊 **预烘焙成 PNG/纹理**，运行时只贴不算
- 大面积元素慎用 `layer.enabled`
- Win7 老显卡：`QT_OPENGL=angle`（走 D3D9/11，兼容性最好），或 `-opengl dynamic` 让 Qt 自选
- 可选：`QSG_RENDER_LOOP=basic` 降低渲染线程开销（代价是动画流畅度略降），低配机上做成开关

---

## 4. 登录：cookie 怎么弄（你没手机）

**可以，不需要账号密码，只要 cookie 值。**

网易云 web 的登录态核心是 cookie **`MUSIC_U`**（另外 `__csrf`、`NMTID` 也一起带上更稳）。

流程：
1. 找一台**已经登录了网易云网页版**的浏览器（你自己的、或家人朋友的）
2. F12 → Application → Cookies → 选 `https://music.163.com` → 找到 `MUSIC_U`，复制它的值
3. 我用 CDP 的 `Network.setCookie` 注入无头浏览器 → 就能拿到**登录后的真实新版界面**（完整 DOM + 计算样式 + 逐页截图）

**⚠️ 风险必须说清楚**：这么干等于把那个账号借出去用。网易云有设备/异地风控，可能触发二次验证、强制踢下线，极端情况会冻结账号。**务必让账号主人在知情的情况下同意。**

**备选**：如果你名下/家里有邮箱注册的网易云账号，网页版支持邮箱登录，不需要手机（现在新注册基本强制手机号，老账号才行）。

---

## 5. 已完成成果

```
research/
  FINDINGS.md              前期调研（现成项目、抓站结论）
  QT-FEASIBILITY.md        本文档

  capture.mjs              CDP 渲染脚本（截图 + DOM + 计算样式探测）
  mirror.mjs               镜像 bundle（外壳 + 192 JS + 100 CSS）
  mirror-assets.mjs        镜像 public/assets 全量资源
  scan-assets.mjs          扫描 bundle 内引用的外部资源
  extract-css.mjs          抽取代表性 CSS 声明（本文档的数据来源）
  probe2.mjs               统计多角圆角 / keyframes 属性

  mirror/                  ★ 562 个文件 / 48 MB
    index.html             /st/webplayer 外壳
    <ver>/hybrid/*.js      192 个 JS（含 app.js 5.6MB）
    <ver>/styles/*.css     100 个 CSS（9.09 MB）
    public/assets/img/…    27 类图片（cover / play / vinyl / vip / listenTogether / empty…）
    public/assets/svg/…    61 个 SVG（vip 39 + new-vip 22）
    _assets.json           去重后的资源引用清单（975 条）
    _external-assets.json  外部资源（字体 ttf / MV mp4，仅登记未下载）
    _mirror-report.json    镜像报告

  snapshot/                CDP 渲染快照
    render-real-ua.png     未登录 → 老版界面（重定向到 /#/login）
    dom-real-ua.html       对应 DOM
```

**缺口（需注意）**：`public/assets/svg/menu/*.svg` 在 web 端 404 —— 这类菜单图标**只在官方桌面客户端的安装包里**（`orpheus://orpheus/pub/public/assets/svg/menu/`）。这正是 open-orpheus 要求用户从官方客户端目录拷贝 `package/` `resource/` 的原因。后续要么从官方客户端安装目录取，要么自己补一套同风格图标。
