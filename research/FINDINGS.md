# TightNCM 前期调研

日期：2026-10-13　目标：把 `https://music.163.com/st/webplayer` 做成非 Electron 的桌面客户端，C++/Qt 一比一还原界面。

---

## 一、现成项目调研

结论：**有同类项目，但没有一个是你想要的形态。用 Qt 原生 1:1 复刻新版界面，这个位置是空的。**

### A 类 · 原生 UI 重写（界面自己设计，非 1:1）

| 项目 | 技术 | 说明 |
|---|---|---|
| `shiro123444/netease-cloud-music-gtk`、`gmg137/netease-cloud-music-gtk` | Rust + GTK4 | 安装包约 3MB，最轻之一；**仅 Linux**，GNOME Music 风格 |
| `MCredbear/netease_cloudmusic_Qt` | Qt5 QML + Qt-AES | 用 linuxapi 加密绕开 OpenSSL 依赖；2022 年后停更 |
| `and2long/musica-cpp` | Qt6 | 功能很少（搜索 + 播放），Apache-2.0 |
| `shenjing023/CloudMusic`、`xiaoheizi112/KYYMusic`、`EoYll/WYYMusic` | Qt QML | 仿界面练习项目，不成气候 |

### B 类 · Web 壳（把官方 web UI 塞进桌面窗口）

| 项目 | 技术 | 说明 |
|---|---|---|
| `PLFJY/cloudmusic-web-player-qt` | **Qt WebEngine** | 直接嵌 `music.163.com/st/webplayer`，带托盘控制、播放进度持久化。**QtWebEngine 打包整个 Chromium，比你嫌弃的 Electron 还重** |
| `YUCLing/open-orpheus` | **Electron** + Svelte，MIT | 关键情报源，见下 |
| `xiyidaiwa/net-ease-web-player-qt` | Qt5 + WebEngine | 仅 Linux，MPRIS/D-Bus |

> **关键情报**：网易官方 PC 客户端本身就是「Orpheus 浏览器宿主」+ 同一套 web UI。所以你觉得 web 版和客户端长得一模一样——**因为它们本来就是同一份代码**。代码里写得很直白：
> `isWeb ? "/st/webplayer/public/" : "orpheus://orpheus/pub/public/"`

### C 类 · Tauri（Rust + 系统 WebView，非 Electron，最接近"轻量"）

| 项目 | 技术 | 说明 |
|---|---|---|
| `kongbaier/YueEasy` | Tauri 2.0 + 内嵌 `ncm-api-rs` | 体积小、占用低，Mica 透明背景 |
| `1sen3/YeeMusic` | Tauri 2.0 + React + Rodio | AGPL-3.0 |
| `wnfxsa1213/shiyin-player` | Tauri v2 + GStreamer | 网易云 + QQ 双音源 |
| `joueyl/cloudmusic-app` | Tauri + Vue3 | 较早，已停更 |

---

## 二、抓站结果

### 1. `/st/webplayer` 未登录会回落到老版（已验证）

重定向链：

```
https://music.163.com/st/webplayer
  → https://music.163.com/login?targetUrl=https%3A%2F%2Fmusic.163.com%2Fst%2Fwebplayer
  → https://music.163.com/#/login?targetUrl=...
```

落地的 DOM 是老版播放器，特征是 `g-topbar` / `g-btmbar` / `m-playbar` / `m-nav` 这套 `g-/m-/f-` 前缀类名，CSS 来自 `s2.music.126.net/web/s/core_*.css` + `pt_frame_*.css`。

**要拿到真实的新版界面，必须登录。** 见 `snapshot/render-real-ua.png`。

### 2. 新版结构（从静态资源分析）

- SPA 外壳：`<div id="root">`，Webpack 4 分块，约 110 个懒加载 chunk
- 主 bundle 体积：`app.js` 5.6MB + `vendors~app.js` 2.5MB + 主 CSS 3.16MB
- 样式方案：**CSS-in-JS**，类名带哈希（`InputWrapper_i1rdhscy`、`StyledCommon_s144hwqc`），设计 token 也是哈希的（`var(--a1llnfj4-0)`）
- 灰阶 token 24 个：`--colorBlack1..12`、`--colorWhite1..12`
- 共享组件库前缀 `cmd-`（cmd-input / cmd-tabs / cmd-checkbox / cmd-carousel …）
- 内嵌字体 4 个 data:font，字体族 `dolphin`、`dolphin-s`、`SFPro-Regular`、`desktop-ui-tag-font`

---

## 三、关键结论：Qt Widgets 路线不可行

主 CSS 效果使用统计：

| 特性 | 次数 | QSS 支持 |
|---|---|---|
| `border-radius` | 309 | 部分 |
| `transform` | 244 | **不支持** |
| `animation` | 142 | **不支持** |
| `transition` | 94 | **不支持** |
| `linear-gradient` | 71 | 很弱 |
| `box-shadow` | 54 | **不支持** |
| `filter` | 27 | **不支持** |
| `backdrop-filter` | 26 | **不支持** |

→ **Qt Widgets + QSS 直接否掉**，还原度会明显打折。
→ 用 Qt 就只能走 **Qt Quick/QML**（`MultiEffect` / `ShaderEffect` 能做模糊、阴影、渐变、transform、动画）。

---

## 四、比 Qt 更轻的选择（从轻到重）

| # | 方案 | 体积 | 还原度 | 备注 |
|---|---|---|---|---|
| 1 | **NeutralinoJS** | <2MB | 100% | C/C++ 后端 + 系统 WebView，MIT。生态很小 |
| 2 | **Tauri v2** | <10MB | 100% | Rust + 系统 WebView2。**生态最成熟**，上面 C 类全在用 |
| 3 | **Sciter** | ~5MB | 高 | C++ + 自研 HTML/CSS 引擎，可大量复用网站 CSS。商业授权 $310 起，CSS 是子集 |
| 4 | **Qt Quick / QML** | ~30MB | 高（需手写） | 原生自绘，内存约 80–150MB，控制力最强，工作量最大 |
| 5 | Qt Widgets + QSS | ~25MB | **低** | 最省事但达不到 1:1 |
| — | Qt WebEngine / Electron | 150MB+ | 100% | 直接排除 |

**最轻 + 100% 还原 = 内嵌系统 WebView2**（Win10 1803+ 自带，不用打包 Chromium）。代价：内核仍是 Chromium（内存约 150–250MB，比 Electron 省一半以上），且 **Win7 不支持 WebView2**。

---

## 五、当前产出文件

```
research/
  capture.mjs               CDP 渲染脚本（无头 Edge → 截图 + 导出 DOM + 探测计算样式）
  snapshot/
    webplayer.html          /st/webplayer 原始外壳 HTML
    main.css                新版设计系统 CSS（3.16MB）
    base.css                新版基础 CSS
    dom.html                未登录渲染结果 DOM（老版）
    dom-real-ua.html        正常 UA 渲染结果 DOM（老版，重定向到登录页）
    render.png              未登录渲染截图
    render-real-ua.png      正常 UA 渲染截图
```
