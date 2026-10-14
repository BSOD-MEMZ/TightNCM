// 从已打开的 webplayer 页面导出：设计 token + 布局几何 + 关键元素计算样式
// 连到现有 target，不新建标签页（保留登录会话）
import fs from 'node:fs';

const CDP = 'http://127.0.0.1:9222';
const OUT = process.argv[2] || 'D:/Dev/TightNCM/research/design-tokens.json';
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// 找到 webplayer 那个 target
const list = await (await fetch(`${CDP}/json/list`)).json();
const target = list.find((t) => t.type === 'page' && t.url.includes('music.163.com/st/webplayer'));
if (!target) { console.error('找不到 webplayer 标签页'); process.exit(1); }
console.log('attach ->', target.id, target.url);

const ws = new WebSocket(target.webSocketDebuggerUrl);
await new Promise((res, rej) => { ws.onopen = res; ws.onerror = rej; });
let id = 0;
const pending = new Map();
ws.onmessage = (e) => {
  const m = JSON.parse(e.data);
  if (m.id && pending.has(m.id)) { const { res, rej } = pending.get(m.id); pending.delete(m.id); m.error ? rej(new Error(JSON.stringify(m.error))) : res(m.result); }
};
const send = (method, params = {}) => new Promise((res, rej) => { const i = ++id; pending.set(i, { res, rej }); ws.send(JSON.stringify({ id: i, method, params })); });

await send('Runtime.enable');

const EXPR = `(() => {
  const out = {};

  // ---------- 1. 全量 CSS 自定义属性（设计 token） ----------
  const tokens = {};
  const collect = (rules) => {
    for (const r of rules) {
      if (r.cssRules) { try { collect(r.cssRules); } catch(e){} continue; }
      if (!r.style) continue;
      for (let i = 0; i < r.style.length; i++) {
        const p = r.style[i];
        if (p.startsWith('--')) tokens[p] = r.style.getPropertyValue(p).trim();
      }
    }
  };
  for (const ss of document.styleSheets) { try { collect(ss.cssRules); } catch(e) {} }

  // 运行时实际生效的（含 JS 动态写入的）
  const runtime = {};
  for (const el of [document.documentElement, document.body, document.getElementById('root'), document.querySelector('[class*=AppEle_]')]) {
    if (!el) continue;
    const cs = getComputedStyle(el);
    for (let i = 0; i < cs.length; i++) { const p = cs[i]; if (p.startsWith('--')) runtime[p] = cs.getPropertyValue(p).trim(); }
  }
  out.cssTokensFromSheets = tokens;
  out.cssTokensRuntime = runtime;

  // ---------- 2. 布局几何 ----------
  const geo = (sel, label) => {
    const el = document.querySelector(sel);
    if (!el) return null;
    const r = el.getBoundingClientRect();
    return { label, sel, x: +r.x.toFixed(1), y: +r.y.toFixed(1), w: +r.width.toFixed(1), h: +r.height.toFixed(1),
             scrollW: el.scrollWidth, scrollH: el.scrollHeight, scrollTop: el.scrollTop, tag: el.tagName.toLowerCase(), cls: el.className };
  };
  out.layout = [
    ['#root','root'], ['[class*=AppEle_]','App'],
    ['#page_pc_main_nav','主导航(#page_pc_main_nav)'],
    ['#page_pc_main_tab','主标签容器'],
    ['#contentContainer','内容容器'],
    ['[class*=RightContainer]','RightContainer'],
    ['footer','footer/播放栏'],
    ['[class*=TopLeft]','左上拖拽区'], ['[class*=TopRight]','右上'],
    ['[class*=SearchBox], [class*=searchBox], [class*=SearchWrapper]','搜索框'],
  ].map(([s,l]) => geo(s,l)).filter(Boolean);

  // ---------- 3. 关键元素的完整计算样式 ----------
  const PROPS = ['width','height','padding','margin','background-color','background-image','border-radius','border','border-color','box-shadow','backdrop-filter','-webkit-backdrop-filter','filter','color','font-family','font-size','font-weight','line-height','letter-spacing','display','flex-direction','align-items','justify-content','gap','position','top','left','right','bottom','z-index','overflow','opacity','transform','transition','text-align','grid-template-columns'];
  const styleOf = (sel, label) => {
    const el = document.querySelector(sel);
    if (!el) return null;
    const cs = getComputedStyle(el);
    const o = { label, sel, cls: el.className, tag: el.tagName.toLowerCase() };
    for (const p of PROPS) { const v = cs.getPropertyValue(p); if (v && v !== 'none' && v !== 'normal' && v !== 'auto' && v !== 'rgba(0, 0, 0, 0)') o[p] = v; }
    return o;
  };
  out.styles = [
    ['body','body'],
    ['[class*=AppEle_]','App 根'],
    ['#page_pc_main_nav','主导航'],
    ['#contentContainer','内容容器'],
    ['footer','footer/播放栏'],
    ['[class*=RightContainer]','RightContainer'],
    ['[class*=StyledBackground]','背景层(StyledBackground)'],
  ].map(([s,l]) => styleOf(s,l)).filter(Boolean);

  // ---------- 4. 侧栏导航项（拿一个样本） ----------
  const navItems = [...document.querySelectorAll('#page_pc_main_nav [class*=ItemContainer], #page_pc_main_nav li, #page_pc_main_nav a')].slice(0, 6);
  out.navItemSamples = navItems.map(el => {
    const cs = getComputedStyle(el); const r = el.getBoundingClientRect();
    return { cls: el.className, text: (el.innerText||'').slice(0,30), w: +r.width.toFixed(1), h: +r.height.toFixed(1),
             bg: cs.backgroundColor, color: cs.color, br: cs.borderRadius, fs: cs.fontSize, fw: cs.fontWeight, pad: cs.padding, gap: cs.gap, display: cs.display };
  });

  // ---------- 5. 字体清单 ----------
  out.fonts = [...new Set([...document.querySelectorAll('*')].slice(0,400).map(e => getComputedStyle(e).fontFamily))].slice(0, 25);

  // ---------- 6. @font-face ----------
  const ff = [];
  for (const ss of document.styleSheets) {
    try { for (const r of ss.cssRules) if (r instanceof CSSFontFaceRule) ff.push({ family: r.style.getPropertyValue('font-family'), src: (r.style.getPropertyValue('src')||'').slice(0,120), weight: r.style.getPropertyValue('font-weight') }); } catch(e){}
  }
  out.fontFaces = ff;

  // ---------- 7. keyframes 名清单（运行时） ----------
  const kf = [];
  for (const ss of document.styleSheets) {
    try { for (const r of ss.cssRules) if (r instanceof CSSKeyframesRule) kf.push(r.name); } catch(e){}
  }
  out.keyframes = [...new Set(kf)];

  out.meta = { href: location.href, title: document.title, ua: navigator.userAgent };
  return out;
})()`;

const r = await send('Runtime.evaluate', { returnByValue: true, expression: EXPR, awaitPromise: false });
const data = r.result.value;
fs.writeFileSync(OUT, JSON.stringify(data, null, 2));
console.log('已导出 ->', OUT);

console.log('\n=== 设计 token（运行时生效） ===');
const rt = data.cssTokensRuntime || {};
const keys = Object.keys(rt);
console.log('数量:', keys.length);
for (const k of keys.slice(0, 60)) console.log('  ', k, '=', rt[k]);

console.log('\n=== 布局几何 ===');
for (const g of data.layout) console.log('  ', g.label.padEnd(22), `x=${g.x} y=${g.y} w=${g.w} h=${g.h}`, 'scrollH=' + g.scrollH);

console.log('\n=== keyframes ===', data.keyframes.length, data.keyframes.slice(0, 30).join(', '));
console.log('\n=== fontFaces ===');
console.log(JSON.stringify(data.fontFaces, null, 1).slice(0, 1200));
console.log('\n=== fonts ===');
console.log(data.fonts.join('\n  '));

ws.close();
process.exit(0);
