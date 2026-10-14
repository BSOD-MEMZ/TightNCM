// 登录态驱动新版 webplayer：探测骨架几何 + 点进歌单页，抓图 + 抓几何。
// 用法: node probe-ref.mjs <cookieFile> <outPrefix> [width] [height] [clickText]
import fs from 'node:fs';

const CDP = 'http://127.0.0.1:9222';
const COOKIE_FILE = process.argv[2];
const OUT = process.argv[3] || 'D:/Dev/TightNCM/research/snapshot/probe';
const W = Number(process.argv[4] || 1280);
const H = Number(process.argv[5] || 800);
const CLICK = process.argv[6] || '';
const UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';
const MUSIC_U = fs.readFileSync(COOKIE_FILE, 'utf8').trim();
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

const t = await (await fetch(`${CDP}/json/new?${encodeURIComponent('about:blank')}`, { method: 'PUT' })).json();
const ws = new WebSocket(t.webSocketDebuggerUrl);
await new Promise((res, rej) => { ws.onopen = res; ws.onerror = rej; });
let id = 0; const pending = new Map(); let events = [];
ws.onmessage = (e) => {
  const m = JSON.parse(e.data);
  if (m.id && pending.has(m.id)) { const { res, rej } = pending.get(m.id); pending.delete(m.id); m.error ? rej(new Error(JSON.stringify(m.error))) : res(m.result); }
  else if (m.method) events.push(m);
};
const send = (method, params = {}) => new Promise((res, rej) => { const i = ++id; pending.set(i, { res, rej }); ws.send(JSON.stringify({ id: i, method, params })); });
const evaluate = async (expression) => (await send('Runtime.evaluate', { returnByValue: true, awaitPromise: true, expression })).result.value;

await send('Page.enable'); await send('Runtime.enable'); await send('Network.enable');
await send('Emulation.setDeviceMetricsOverride', { width: W, height: H, deviceScaleFactor: 1, mobile: false });
await send('Network.setUserAgentOverride', { userAgent: UA });
await send('Page.navigate', { url: 'https://music.163.com/' });
await sleep(3500);
await send('Network.setCookie', { name: 'MUSIC_U', value: MUSIC_U, domain: '.music.163.com', path: '/', secure: true, httpOnly: true, sameSite: 'None' });

events = [];
await send('Page.navigate', { url: 'https://music.163.com/st/webplayer' });
let t0 = Date.now();
while (Date.now() - t0 < 40000 && !events.some((e) => e.method === 'Page.loadEventFired')) await sleep(300);
await sleep(14000);

// 通用盒子探针
await evaluate(`window.__box = function(sel, all) {
  const list = all ? [...document.querySelectorAll(sel)] : [document.querySelector(sel)].filter(Boolean);
  return list.map(el => {
    const r = el.getBoundingClientRect(), s = getComputedStyle(el);
    const keep = {};
    for (const p of ['display','position','flexDirection','alignItems','justifyContent','padding','margin','gap','rowGap','columnGap','backgroundColor','backgroundImage','borderTop','borderRadius','boxShadow','fontSize','fontWeight','lineHeight','color','overflow','zIndex','backdropFilter','letterSpacing','flex','minWidth','textAlign']) {
      const v = s[p]; if (v && v !== 'none' && v !== 'normal' && v !== '0px' && v !== 'auto' && v !== 'rgba(0, 0, 0, 0)' && v !== '0s') keep[p] = v;
    }
    const rect = { x: Math.round(r.x*10)/10, y: Math.round(r.y*10)/10, w: Math.round(r.width*10)/10, h: Math.round(r.height*10)/10 };
    return { cls: (el.className||'').toString().slice(0,110), tag: el.tagName.toLowerCase(), text: (el.childElementCount===0 ? el.textContent : '').trim().slice(0,40), rect, style: keep };
  });
};`);

// 侧栏：按类名前缀把容器逐个挑出来
const side = await evaluate(`(() => {
  const f = (sel) => __box(sel, true);
  const near = (sel, xmax) => f(sel).filter(e => e.rect.x < (xmax||210) && e.rect.w > 4 && e.rect.h > 4);
  return {
    viewport: { w: innerWidth, h: innerHeight },
    // 侧栏里所有有类的元素（限宽 <210）
    sidebarAll: near('[class]').slice(0, 90),
    // 顶栏
    topbar: __box('[class*="draggable"]', true).slice(0, 4),
    inputs: f('input'),
    imgs: near('img', 210).slice(0, 20),
    svgs: near('svg', 210).slice(0, 25),
  };
})()`);
fs.writeFileSync(OUT + '-sidebar.json', JSON.stringify(side, null, 2), 'utf8');
console.log('sidebar elements:', side.sidebarAll.length, 'svgs', side.svgs.length, 'imgs', side.imgs.length);

if (CLICK) {
  const clicked = await evaluate(`(() => {
    const want = ${JSON.stringify(CLICK)};
    const els = [...document.querySelectorAll('*')].filter(e => e.childElementCount === 0 && e.textContent.trim() === want);
    if (!els.length) return 'NOT_FOUND';
    els[0].click();
    return 'OK';
  })()`);
  console.log('click', CLICK, '->', clicked);
  await sleep(9000);
  console.log('href now', await evaluate('location.href'));
}

const shot = await send('Page.captureScreenshot', { format: 'png', captureBeyondViewport: false });
fs.writeFileSync(OUT + '.png', Buffer.from(shot.data, 'base64'));
console.log('PNG saved:', OUT + '.png');
ws.close(); process.exit(0);
