// 在已登录会话里走一遍交互流程，逐页截图 + 导 DOM + 导样式
import fs from 'node:fs';

const CDP = 'http://127.0.0.1:9222';
const OUTDIR = 'D:/Dev/TightNCM/research/snapshot';
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

const list = await (await fetch(`${CDP}/json/list`)).json();
const target = list.find((t) => t.type === 'page' && t.url.includes('music.163.com/st/webplayer'));
if (!target) { console.error('找不到 webplayer 标签页'); process.exit(1); }
const ws = new WebSocket(target.webSocketDebuggerUrl);
await new Promise((res, rej) => { ws.onopen = res; ws.onerror = rej; });
let id = 0;
const pending = new Map();
ws.onmessage = (e) => {
  const m = JSON.parse(e.data);
  if (m.id && pending.has(m.id)) { const { res, rej } = pending.get(m.id); pending.delete(m.id); m.error ? rej(new Error(JSON.stringify(m.error))) : res(m.result); }
};
const send = (method, params = {}) => new Promise((res, rej) => { const i = ++id; pending.set(i, { res, rej }); ws.send(JSON.stringify({ id: i, method, params })); });
const evalJS = async (expr) => (await send('Runtime.evaluate', { returnByValue: true, expression: expr })).result.value;

await send('Page.enable');
await send('Runtime.enable');

// 固定视口
await send('Emulation.setDeviceMetricsOverride', { width: 1440, height: 900, deviceScaleFactor: 1, mobile: false });
await sleep(2500);

async function shot(name) {
  const s = await send('Page.captureScreenshot', { format: 'png', captureBeyondViewport: false });
  fs.writeFileSync(`${OUTDIR}/${name}.png`, Buffer.from(s.data, 'base64'));
  console.log('  png  ->', name + '.png');
}
async function dumpDom(name) {
  const d = await evalJS(`'<!doctype html>\\n' + document.documentElement.outerHTML`);
  fs.writeFileSync(`${OUTDIR}/${name}.html`, d, 'utf8');
  console.log('  dom  ->', name + '.html', d.length);
}

// 用真实鼠标事件点击某元素的中心
async function clickEl(exprFind) {
  const box = await evalJS(`(() => { const el = ${exprFind}; if(!el) return null;
    el.scrollIntoView({block:'center'});
    const r = el.getBoundingClientRect();
    return { x: r.x + r.width/2, y: r.y + r.height/2, w: r.width, h: r.height, t: (el.innerText||'').slice(0,40) }; })()`);
  if (!box) { console.log('    未找到目标'); return null; }
  console.log('    点击:', JSON.stringify(box.t), `@${box.x.toFixed(0)},${box.y.toFixed(0)}`);
  for (const type of ['mousePressed', 'mouseReleased']) {
    await send('Input.dispatchMouseEvent', { type, x: box.x, y: box.y, button: 'left', clickCount: 1 });
    await sleep(60);
  }
  return box;
}

// ---------- 1. 首页 ----------
console.log('[1] 首页');
await sleep(1500);
await shot('new-home');
await dumpDom('new-home-dom');

// 抓一下当前关键元素样式
const shell = await evalJS(`(() => {
  const g = (sel) => { const el = document.querySelector(sel); if(!el) return null; const cs=getComputedStyle(el); const r=el.getBoundingClientRect();
    return { sel, cls:String(el.className).slice(0,80), x:+r.x.toFixed(1), y:+r.y.toFixed(1), w:+r.width.toFixed(1), h:+r.height.toFixed(1),
      bg:cs.backgroundColor, bgImage:String(cs.backgroundImage).slice(0,120), br:cs.borderRadius, shadow:cs.boxShadow, backdrop:cs.backdropFilter,
      pad:cs.padding, gap:cs.gap, display:cs.display, flexDir:cs.flexDirection, color:cs.color, fs:cs.fontSize, fw:cs.fontWeight, ff:String(cs.fontFamily).slice(0,60) }; };
  return {
    viewport: { w: innerWidth, h: innerHeight },
    sidebar: g('#page_pc_main_tab'),
    sidebarInner: g('#contentContainer'),
    topbar: g('#page_pc_main_nav'),
    rightWrap: g('[class*=RightContainer]'),
    scrollArea: g('[class*=AppScrollContainer]'),
    footer: g('footer'),
    app: g('[class*=AppEle_]'),
    bg1: g('[class*=StyledBackground]'),
  };
})()`);
fs.writeFileSync(`${OUTDIR}/shell-styles.json`, JSON.stringify(shell, null, 2));
console.log('  json -> shell-styles.json');
console.log(JSON.stringify(shell, null, 1).slice(0, 2200));

// ---------- 2. 点歌单 ----------
console.log('\n[2] 打开一个歌单');
await clickEl(`[...document.querySelectorAll('#page_pc_main_tab [class*=ItemContainer], #page_pc_main_tab li, #page_pc_main_tab a')].find(e => /Miku/.test(e.innerText||''))`);
await sleep(4000);
await shot('new-playlist');
await dumpDom('new-playlist-dom');

const pl = await evalJS(`(() => {
  const cs = (el,p)=>el?getComputedStyle(el)[p]:null;
  const rows = [...document.querySelectorAll('[class*=PlayListItemContent], [class*=SongItem], [class*=songItem], tr')].slice(0,3);
  return {
    href: location.href,
    text: document.body.innerText.slice(0,400),
    rowSamples: rows.map(el => { const c=getComputedStyle(el); const r=el.getBoundingClientRect();
      return { cls:String(el.className).slice(0,70), h:+r.height.toFixed(1), w:+r.width.toFixed(1), bg:c.backgroundColor, fs:c.fontSize, pad:c.padding, display:c.display }; }),
  };
})()`);
console.log(JSON.stringify(pl, null, 1).slice(0, 1500));

// ---------- 3. 播放第一首 ----------
console.log('\n[3] 播放第一首');
const played = await clickEl(`[...document.querySelectorAll('[class*=PlayListItemContent], [class*=SongItem], tr')].find(e => (e.innerText||'').length > 3)`);
await sleep(3000);
if (played) await clickEl(`[...document.querySelectorAll('[class*=PlayListItemContent], [class*=SongItem], tr')].find(e => (e.innerText||'').length > 3)`);
await sleep(6000);
await shot('new-playing');
await dumpDom('new-playing-dom');

const footer = await evalJS(`(() => {
  const f = document.querySelector('footer'); if(!f) return { err: 'no footer' };
  const c = getComputedStyle(f); const r = f.getBoundingClientRect();
  const kids = [...f.children].map(el => { const cs=getComputedStyle(el); const rr=el.getBoundingClientRect();
    return { cls:String(el.className).slice(0,60), x:+rr.x.toFixed(0), w:+rr.width.toFixed(0), h:+rr.height.toFixed(0), bg:cs.backgroundColor, display:cs.display }; });
  return { rect:{x:+r.x.toFixed(0),y:+r.y.toFixed(0),w:+r.width.toFixed(0),h:+r.height.toFixed(0)},
           bg:c.backgroundColor, borderTop:c.borderTop, backdrop:c.backdropFilter, shadow:c.boxShadow, pad:c.padding, zIndex:c.zIndex,
           children:kids, text:(f.innerText||'').slice(0,200) };
})()`);
fs.writeFileSync(`${OUTDIR}/footer-styles.json`, JSON.stringify(footer, null, 2));
console.log('footer:', JSON.stringify(footer, null, 1).slice(0, 1600));

ws.close();
process.exit(0);
