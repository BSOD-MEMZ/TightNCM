// 播放一首歌，抓播放栏 + 关键组件样式
import fs from 'node:fs';

const CDP = 'http://127.0.0.1:9222';
const OUTDIR = 'D:/Dev/TightNCM/research/snapshot';
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

const list = await (await fetch(`${CDP}/json/list`)).json();
const target = list.find((t) => t.type === 'page' && t.url.includes('music.163.com/st/webplayer'));
if (!target) { console.error('找不到 webplayer 标签页'); process.exit(1); }
const ws = new WebSocket(target.webSocketDebuggerUrl);
await new Promise((res, rej) => { ws.onopen = res; ws.onerror = rej; });
let id = 0; const pending = new Map();
ws.onmessage = (e) => { const m = JSON.parse(e.data); if (m.id && pending.has(m.id)) { const { res, rej } = pending.get(m.id); pending.delete(m.id); m.error ? rej(new Error(JSON.stringify(m.error))) : res(m.result); } };
const send = (method, params = {}) => new Promise((res, rej) => { const i = ++id; pending.set(i, { res, rej }); ws.send(JSON.stringify({ id: i, method, params })); });
const evalJS = async (e) => (await send('Runtime.evaluate', { returnByValue: true, expression: e })).result.value;

await send('Page.enable'); await send('Runtime.enable');
await send('Emulation.setDeviceMetricsOverride', { width: 1440, height: 900, deviceScaleFactor: 1, mobile: false });
await sleep(2000);

async function shot(n) { const s = await send('Page.captureScreenshot', { format: 'png' }); fs.writeFileSync(`${OUTDIR}/${n}.png`, Buffer.from(s.data, 'base64')); console.log('  png ->', n + '.png'); }
async function click(exprFind, label) {
  const b = await evalJS(`(() => { const el = ${exprFind}; if(!el) return null; el.scrollIntoView({block:'center'}); const r = el.getBoundingClientRect(); return { x:r.x+r.width/2, y:r.y+r.height/2, t:(el.innerText||'').slice(0,30) }; })()`);
  if (!b) { console.log('    未找到:', label); return false; }
  console.log('    点击', label, JSON.stringify(b.t));
  for (const type of ['mousePressed', 'mouseReleased']) { await send('Input.dispatchMouseEvent', { type, x: b.x, y: b.y, button: 'left', clickCount: 1 }); await sleep(70); }
  return true;
}

// ---- 点「播放全部」 ----
console.log('[A] 播放全部');
await click(`[...document.querySelectorAll('button,[role=button],div')].find(e => (e.innerText||'').trim() === '播放全部')`, '播放全部');
await sleep(9000);
await shot('new-player-bar');

const info = await evalJS(`(() => {
  const f = document.querySelector('footer'); const cs = el => el?getComputedStyle(el):null;
  const r = f ? f.getBoundingClientRect() : null;
  const fc = f ? getComputedStyle(f) : null;
  const kids = f ? [...f.children].map(el => { const c=cs(el), rr=el.getBoundingClientRect();
    return { cls:String(el.className).slice(0,70), x:+rr.x.toFixed(0), y:+rr.y.toFixed(0), w:+rr.width.toFixed(0), h:+rr.height.toFixed(0), bg:c.backgroundColor, backdrop:c.backdropFilter, br:c.borderRadius, shadow:c.boxShadow.slice(0,90) }; }) : [];
  return {
    footer: r ? { x:+r.x.toFixed(0), y:+r.y.toFixed(0), w:+r.width.toFixed(0), h:+r.height.toFixed(0) } : null,
    footerStyle: fc ? { bg:fc.backgroundColor, bgImage:String(fc.backgroundImage).slice(0,140), borderTop:fc.borderTop, backdrop:fc.backdropFilter, shadow:fc.boxShadow.slice(0,120), pad:fc.padding, z:fc.zIndex, display:fc.display, align:fc.alignItems } : null,
    children: kids,
    footerText: f ? (f.innerText||'').slice(0,120) : '',
    bodyText: document.body.innerText.slice(0, 160),
  };
})()`);
fs.writeFileSync(`${OUTDIR}/playerbar.json`, JSON.stringify(info, null, 2));
console.log(JSON.stringify(info, null, 1).slice(0, 2000));

// ---- 点进度条左侧歌曲名区域，尝试打开「黑胶/正在播放」页 ----
console.log('\n[B] 尝试进入正在播放页');
await click(`document.querySelector('[class*=VinylPageContainer] , [class*=SongInfoWrapper], footer [class*=Cover], footer [class*=cover]')`, '封面/歌名');
await sleep(4500);
await shot('new-vinyl-try');

const v = await evalJS(`({ href: location.href, text: document.body.innerText.slice(0,300),
  vinylVisible: (()=>{const e=document.querySelector('[class*=VinylPageContainer]'); if(!e) return null; const c=getComputedStyle(e); return {display:c.display, opacity:c.opacity, z:c.zIndex, visible:c.visibility};})() })`);
console.log(JSON.stringify(v, null, 1).slice(0, 900));

// ---- 组件样式抽样：侧栏项 / 表格行 / 按钮 ----
console.log('\n[C] 组件样式抽样');
const comps = await evalJS(`(() => {
  const P = ['height','width','padding','margin','background-color','background-image','border-radius','box-shadow','color','font-size','font-weight','line-height','display','align-items','justify-content','gap','transition','border','opacity','backdrop-filter','transform'];
  const grab = (el, label) => { if(!el) return null; const c=getComputedStyle(el); const r=el.getBoundingClientRect(); const o={label, cls:String(el.className).slice(0,70), rect:{w:+r.width.toFixed(1),h:+r.height.toFixed(1)}, text:(el.innerText||'').slice(0,24)};
    for(const p of P){const v=c.getPropertyValue(p); if(v&&v!=='none'&&v!=='normal'&&v!=='auto'&&v!=='rgba(0, 0, 0, 0)'&&v!=='0px')o[p]=v;} return o; };
  const byText = (sel,txt) => [...document.querySelectorAll(sel)].find(e=>(e.innerText||'').trim()===txt);
  const byContains = (sel,txt) => [...document.querySelectorAll(sel)].find(e=>(e.innerText||'').includes(txt));
  return {
    navItemNormal: grab(byText('#page_pc_main_tab *','精选'), '侧栏项-普通(精选)'),
    navItemActive: grab(byText('#page_pc_main_tab *','推荐') || document.querySelector('#page_pc_main_tab [class*=active]'), '侧栏项-选中'),
    playlistRow: grab(document.querySelector('[class*=PlayListItemContent]'), '侧栏歌单项'),
    topBar: grab(document.querySelector('#page_pc_main_nav'), '顶栏'),
    searchBox: grab(document.querySelector('#page_pc_main_nav input')?.parentElement, '搜索框'),
    avatar: grab(document.querySelector('#page_pc_main_nav img')?.parentElement, '头像区'),
    playAllBtn: grab(byText('button,div','播放全部'), '播放全部按钮'),
    tab: grab(byContains('[class*=TabsWrapper] , [role=tab]','歌曲'), '标签页-选中'),
    tableHeader: grab(document.querySelector('[class*=SongListHead], thead, [class*=ListHeader]'), '表头'),
    songRow: grab(document.querySelector('[class*=SongItem], tbody tr'), '歌曲行'),
    qualityBadge: grab(byText('span,i,div','SQ') || byText('span,i,div','HD'), '音质徽章'),
    heartIcon: grab(document.querySelector('[class*=HeartIcon], [class*=likeIcon], svg[class*=heart]')?.closest('div,button'), '红心'),
  };
})()`);
fs.writeFileSync(`${OUTDIR}/components.json`, JSON.stringify(comps, null, 2));
console.log('  json -> components.json');
for (const [k, v] of Object.entries(comps)) { if (v) console.log('  ', k, '|', v.cls, '|', JSON.stringify(v.rect), '| bg=' + (v['background-color']||'-'), '| br=' + (v['border-radius']||'-'), '| fs=' + (v['font-size']||'-')); else console.log('  ', k, '-> null'); }

ws.close(); process.exit(0);
