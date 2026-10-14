// 用 Main.qml 里那套完全相同的数值生成 HTML 预览，用来在装 Qt 之前校验规格
import fs from 'node:fs';
import path from 'node:path';

const ROOT = 'D:/Dev/TightNCM';
const TOK = JSON.parse(fs.readFileSync(path.join(ROOT, 'research/design-tokens.json'), 'utf8')).cssTokensRuntime;
const ICON = (n) => {
  const f = path.join(ROOT, 'assets/icons-svg', `ncm_${n}.svg`);
  if (!fs.existsSync(f)) return `<span style="color:red;font-size:10px">?${n}</span>`;
  return fs.readFileSync(f, 'utf8');
};
const tok = (n) => TOK['--' + n];

// Metrics（与 qml/Metrics.qml 一致）
const M = {
  sidebarWidth: 204, topBarHeight: 72, playBarHeight: 80,
  contentPadding: 40, barPadding: 30,
  playBarMiddleWidth: 376, playBarSideWidth: 262,
  navItemHeight: 36, navItemWidth: 164, navItemRadius: 8, navItemPadding: 8,
  navItemIconSize: 20, navItemGap: 8,
  playlistItemHeight: 46, searchBoxWidth: 258, searchBoxHeight: 36,
  avatarSize: 28, fontSmall: 12, fontMedium: 14,
};

const primaryNav = [
  ['sidebar_home', '推荐', false, true],
  ['sidebar_featured', '精选', false, false],
  ['sidebar_podcast', '播客', false, false],
  ['sidebar_fm', '漫游', false, false],
  ['sidebar_community', '关注', true, false],
];
const libraryNav = [
  ['sidebar_like', '我喜欢的音乐', false],
  ['sidebar_history', '最近播放', false],
  ['sidebar_my_podcast', '我的播客', true],
  ['sidebar_favourite', '我的收藏', false],
];
const created = ['Discovery', "Miku's A-Z", 'ボーカロイド', 'ポップ', 'yy Collection', 'ReadyForBGM', '过去的收藏'];
const collected = ['夜晚絮语 | 来自异次元的晚安之声', '日语流行｜当代日系青年的耳机旋律', '很杂的V家歌单', '术力口 日语 动漫番剧op ed'];

const icon = (n, size, color, extra = '') =>
  `<span class="ic" style="width:${size}px;height:${size}px;color:${color};${extra}">${ICON(n)}</span>`;

const navRow = (ic, tx, dot, sel) => `
  <div class="navrow${sel ? ' navsel' : ''}" style="width:${M.navItemWidth}px;height:${M.navItemHeight}px;border-radius:${M.navItemRadius}px;padding:0 ${M.navItemPadding}px">
    ${icon(ic, M.navItemIconSize, sel ? tok('colorWhite1') : tok('colorBlack5'), 'flex:0 0 auto')}
    <span class="navtext" style="color:${sel ? tok('colorWhite1') : tok('colorBlack3')}">${tx}</span>
    ${dot ? `<i class="dot"></i>` : ''}
  </div>`;

const plRow = (title) => `
  <div class="plrow" style="width:${M.navItemWidth}px;height:${M.playlistItemHeight}px;padding:0 ${M.navItemPadding}px">
    <div class="plcover">${icon('playlist', 16, tok('colorBlack7'))}</div>
    <span class="pltext">${title}</span>
  </div>`;

const sec = (title, count, add) => `
  <div class="sechead">
    ${icon('slide_down', 12, tok('colorBlack7'))}
    <span style="color:${tok('colorBlack6')};font-size:12px">${title}</span>
    <span style="color:${tok('colorBlack8')};font-size:10px">${count}</span>
    ${add ? `<span style="margin-left:auto">${icon('sidebar_add', 14, tok('colorBlack5'))}</span>` : ''}
  </div>`;

const html = `<!doctype html>
<html><head><meta charset="utf-8"><title>TightNCM 外壳预览</title>
<style>
  * { margin:0; padding:0; box-sizing:border-box; }
  html,body { width:1280px; height:800px; overflow:hidden;
    font-family:"Microsoft YaHei",arial,sans-serif; background:${tok('colorBackground')}; }
  .ic { display:inline-flex; align-items:center; justify-content:center; flex:0 0 auto; }
  /* 图标 SVG 一律铺满它所在的定尺寸容器 */
  svg { width:100%; height:100%; display:block; }

  #app { display:flex; flex-direction:column; width:1280px; height:800px; }
  #main { flex:1; display:flex; min-height:0; }

  /* ── 侧栏 204 ── */
  #sidebar { width:${M.sidebarWidth}px; background:${tok('colorSidebar7')}; display:flex; flex-direction:column; overflow:hidden; }
  .logorow { height:56px; flex:0 0 auto; display:flex; align-items:center; gap:8px; padding-left:20px; }
  .navrow { flex:0 0 auto; display:flex; align-items:center; gap:${M.navItemGap}px; margin:0 auto; color:${tok('colorBlack3')}; cursor:pointer; position:relative; }
  .navsel { background:${tok('colorSidebar10')}; }
  .navtext { font-size:12px; white-space:nowrap; }
  .dot { position:absolute; right:6px; top:10px; width:5px; height:5px; border-radius:50%; background:${tok('colorPrimary1')}; }
  .gap12 { height:12px; flex:0 0 auto; } .gap14 { height:14px; flex:0 0 auto; }
  .sechead { height:36px; flex:0 0 auto; display:flex; align-items:center; gap:6px; padding:0 20px; }
  .plrow { flex:0 0 auto; display:flex; align-items:center; gap:8px; margin:0 auto; cursor:pointer; }
  .plcover { width:30px; height:30px; border-radius:6px; background:${tok('colorBlack11')}; display:flex; align-items:center; justify-content:center; flex:0 0 auto; }
  .pltext { font-size:12px; color:${tok('colorBlack3')}; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }

  /* ── 右侧 ── */
  #right { flex:1; display:flex; flex-direction:column; min-width:0; }
  #topbar { height:${M.topBarHeight}px; display:flex; align-items:center; padding:0 ${M.contentPadding}px; gap:16px; flex:0 0 auto; }
  #search { width:${M.searchBoxWidth}px; height:${M.searchBoxHeight}px; border-radius:8px; background:${tok('colorBlack12')};
    border:1px solid ${tok('colorBlack10')}; display:flex; align-items:center; gap:8px; padding:0 12px; }
  #search .ph { font-size:14px; color:${tok('colorBlack8')}; }
  .topright { margin-left:auto; display:flex; align-items:center; gap:20px; }
  .userarea { display:flex; align-items:center; gap:6px; }
  .avatar { width:${M.avatarSize}px; height:${M.avatarSize}px; border-radius:50%; background:${tok('colorBlack11')}; }
  .uname { font-size:12px; color:${tok('colorBlack3')}; }

  /* ── 内容区 ── */
  #content { flex:1; overflow:hidden; padding:8px ${M.contentPadding}px 0; }
  h1 { font-size:22px; font-weight:600; color:${tok('colorBlack1')}; margin-bottom:12px; }
  .desc { font-size:14px; line-height:1.6; color:${tok('colorBlack5')}; white-space:pre-line; margin-bottom:18px; }
  .card { width:420px; height:120px; border-radius:12px; background:${tok('colorFunction4')};
    box-shadow:0 6px 16px rgba(0,0,0,0.04); display:flex; flex-direction:column; align-items:center; justify-content:center; gap:10px; }
  .cardlabel { font-size:12px; color:${tok('colorBlack3')}; }
  .btnrow { display:flex; gap:10px; }
  .btn { height:40px; border-radius:20px; display:flex; align-items:center; justify-content:center;
    padding:0 20px; font-size:14px; color:${tok('colorWhite1')};
    background:linear-gradient(242.83deg, ${tok('colorSecondary1_2')} 16.96%, ${tok('colorSecondary1_2')} 34.33%, ${tok('colorSecondary1_1')} 83.04%); }
  .btn.sec { background:${tok('colorBlack11')}; color:${tok('colorBlack3')}; height:28px; border-radius:14px; padding:0 12px; }

  /* ── 播放栏 80 ── */
  #playbar { height:${M.playBarHeight}px; flex:0 0 auto; background:${tok('colorFunction17')};
    border-top:1px solid ${tok('colorBlack10')}; display:flex; align-items:center; padding:0 ${M.barPadding}px; gap:10px; }
  .pb-left { display:flex; align-items:center; gap:10px; flex:0 0 auto; }
  .cover { width:48px; height:48px; border-radius:8px; background:${tok('colorBlack11')};
    display:flex; align-items:center; justify-content:center; }
  .meta { width:180px; display:flex; flex-direction:column; gap:2px; }
  .mtitle { font-size:14px; font-weight:500; color:${tok('colorBlack1')}; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }
  .martist { font-size:12px; color:${tok('colorBlack5')}; }
  .pb-mid { width:${M.playBarMiddleWidth}px; margin:0 auto; display:flex; flex-direction:column; gap:3px; flex:0 0 auto; }
  .btnrow2 { display:flex; align-items:center; justify-content:center; gap:18px; height:44px; padding-top:2px; }
  .playbtn { width:40px; height:40px; border-radius:50%; display:flex; align-items:center; justify-content:center;
    background:linear-gradient(270deg, ${tok('colorSecondary1_2')} 0%, ${tok('colorSecondary1_2')} 26%, ${tok('colorSecondary1_1')} 99%); }
  .times { display:flex; align-items:center; gap:8px; }
  .ttext { font-size:10px; color:${tok('colorBlack7')}; width:32px; }
  .track { flex:1; height:2px; border-radius:1px; background:${tok('colorBlack9')}; position:relative; }
  .track i { position:absolute; left:0; top:0; height:2px; border-radius:1px; background:${tok('colorPrimary1')}; }
  .pb-right { width:${M.playBarSideWidth}px; display:flex; align-items:center; justify-content:flex-end; gap:16px; flex:0 0 auto; }
  .vol { display:flex; align-items:center; gap:6px; }
  .volbar { width:80px; height:2px; border-radius:1px; background:${tok('colorBlack9')}; position:relative; }
  .volbar i { position:absolute; left:0; top:0; height:2px; border-radius:1px; background:${tok('colorBlack5')}; }
</style></head>
<body>
<div id="app">
  <div id="main">
    <div id="sidebar">
      <div class="logorow">
        ${icon('logo', 29, tok('colorPrimary1'))}
        <span style="width:101px;height:19px;display:inline-flex;color:${tok('colorBlack1')}">${ICON('title')}</span>
      </div>
      ${primaryNav.map(([i, t, d, s]) => navRow(i, t, d, s)).join('')}
      <div class="gap12"></div>
      ${libraryNav.map(([i, t, d]) => navRow(i, t, d, false)).join('')}
      <div class="gap14"></div>
      ${sec('创建的歌单', 8, true)}
      ${created.map(plRow).join('')}
      <div class="gap14"></div>
      ${sec('收藏的歌单', 113, false)}
      ${collected.map(plRow).join('')}
    </div>

    <div id="right">
      <div id="topbar">
        ${icon('back', 20, tok('colorBlack9'))}
        <div id="search">
          ${icon('search', 16, tok('colorBlack6'))}
          <span class="ph">搜索音乐/视频/电台/用户</span>
        </div>
        <div class="topright">
          <div class="userarea">
            <div class="avatar"></div>
            <span style="width:34px;height:14px;display:inline-flex">${ICON('vip')}</span>
            <span class="uname">dCbAxH</span>
            ${icon('dropdown', 14, tok('colorBlack6'))}
          </div>
          <div style="position:relative">
            ${icon('message', 20, tok('colorBlack5'))}
            <i style="position:absolute;right:-1px;top:-1px;width:5px;height:5px;border-radius:50%;background:${tok('colorPrimary1')}"></i>
          </div>
          ${icon('setting', 20, tok('colorBlack5'))}
        </div>
      </div>

      <div id="content">
        <h1>内容区（待接入）</h1>
        <div class="desc">骨架已按官方实测尺寸搭好：侧栏 204 / 顶栏 72 / 播放栏 80。
设计 token 由 82 个官方 CSS 变量生成，图标来自 312 个 cmd-icon。</div>
        <div class="card">
          <div class="cardlabel">ShadowBox&nbsp;&nbsp;shadow: 0 6px 16px rgba(0,0,0,0.04)</div>
          <div class="btnrow">
            <div class="btn">播放全部</div>
            <div class="btn sec">更多</div>
          </div>
        </div>
      </div>
    </div>
  </div>

  <div id="playbar">
    <div class="pb-left">
      <div class="cover">${icon('music', 20, tok('colorBlack8'))}</div>
      <div class="meta">
        <div class="mtitle">未在播放</div>
        <div class="martist"></div>
      </div>
      ${icon('like', 20, tok('colorBlack5'))}
      ${icon('download', 20, tok('colorBlack5'))}
      ${icon('comment', 20, tok('colorBlack5'))}
      ${icon('more', 20, tok('colorBlack5'))}
    </div>

    <div class="pb-mid">
      <div class="btnrow2">
        ${icon('loop', 18, tok('colorBlack5'))}
        ${icon('pre', 20, tok('colorBlack5'))}
        <div class="playbtn">${icon('play', 20, tok('colorWhite1'))}</div>
        ${icon('next', 20, tok('colorBlack5'))}
        ${icon('lyric', 18, tok('colorBlack5'))}
      </div>
      <div class="times">
        <span class="ttext">00:00</span>
        <div class="track"><i style="width:0%"></i></div>
        <span class="ttext" style="text-align:right">00:00</span>
      </div>
    </div>

    <div class="pb-right">
      <span style="width:26px;height:16px;display:inline-flex">${ICON('sq')}</span>
      <div class="vol">
        ${icon('Volume2', 20, tok('colorBlack5'))}
        <div class="volbar"><i style="width:70%"></i></div>
      </div>
      ${icon('playlist', 20, tok('colorBlack5'))}
    </div>
  </div>
</div>
</body></html>`;

const outDir = path.join(ROOT, 'research/preview');
fs.mkdirSync(outDir, { recursive: true });
fs.writeFileSync(path.join(outDir, 'shell.html'), html);
console.log('已生成', path.join(outDir, 'shell.html'), (Buffer.byteLength(html) / 1024).toFixed(1), 'KB');
