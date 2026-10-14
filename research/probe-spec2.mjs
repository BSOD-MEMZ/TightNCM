// 登录态驱动新版 webplayer：把「外壳 + 卡片 + 播放栏」的尺寸与圆角一次性量全。
// 用法: node probe-spec2.mjs <cookieFile> <outJson> [width] [height]
import fs from 'node:fs';

const CDP = 'http://127.0.0.1:9222';
const COOKIE_FILE = process.argv[2];
const OUT = process.argv[3] || 'D:/Dev/TightNCM/research/snapshot/spec2.json';
const W = Number(process.argv[4] || 1280);
const H = Number(process.argv[5] || 800);
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
while (Date.now() - t0 < 45000 && !events.some((e) => e.method === 'Page.loadEventFired')) await sleep(300);
await sleep(15000);

const helper = `
window.__probe = function() {
  const out = {};
  const box = (el) => {
    if (!el) return null;
    const r = el.getBoundingClientRect(), s = getComputedStyle(el);
    const keep = {};
    for (const p of ['display','position','flex','flexDirection','alignItems','justifyContent','padding','margin','gap','rowGap','columnGap','backgroundColor','backgroundImage','background','border','borderRadius','boxShadow','fontSize','fontWeight','lineHeight','fontFamily','color','overflow','opacity','width','height','minWidth','maxWidth','textAlign','letterSpacing','objectFit','clipPath','zIndex','backdropFilter','transform']) {
      const v = s[p];
      if (v && v !== 'none' && v !== 'normal' && v !== '0px' && v !== 'auto' && v !== 'rgba(0, 0, 0, 0)' && v !== '0s' && v !== '1') keep[p] = v;
    }
    return {
      tag: el.tagName.toLowerCase(),
      cls: (el.className||'').toString().slice(0,120),
      text: (el.childElementCount===0 ? el.textContent : '').trim().slice(0,50),
      rect: { x: Math.round(r.x*10)/10, y: Math.round(r.y*10)/10, w: Math.round(r.width*10)/10, h: Math.round(r.height*10)/10, right: Math.round(r.right*10)/10, bottom: Math.round(r.bottom*10)/10 },
      style: keep
    };
  };
  const all = (sel) => [...document.querySelectorAll(sel)].map(box).filter(Boolean);
  const one = (sel) => box(document.querySelector(sel));

  // 顶栏右侧：整个 header 的所有后代，按 x 排序
  const header = document.querySelector('header') || document.querySelector('[class*=Header]');
  out.header = box(header);
  out.headerDesc = header ? [...header.querySelectorAll('*')].map(box).filter(Boolean) : [];

  // 侧栏
  const aside = document.querySelector('aside') || document.querySelector('[class*=left]');
  out.aside = box(aside);
  out.asideDesc = aside ? [...aside.querySelectorAll('*')].map(box).filter(e => e.rect.w > 3 && e.rect.h > 3).slice(0, 200) : [];

  // 播放栏：最靠下的那一条
  let bar = null, barBottom = 0;
  for (const el of document.querySelectorAll('*')) {
    const r = el.getBoundingClientRect();
    if (r.height > 50 && r.height < 130 && r.width > innerWidth * 0.8 && r.bottom > innerHeight - 5) {
      if (r.top > barBottom) { barBottom = r.top; bar = el; }
    }
  }
  out.playbar = box(bar);
  out.playbarDesc = bar ? [...bar.querySelectorAll('*')].map(box).filter(e => e.rect.w > 3 && e.rect.h > 3).slice(0, 200) : [];

  // 首页卡片：找所有带 mask/border-radius 的封面
  out.cards = [...document.querySelectorAll('[class*=Card],[class*=card],a[href*="playlist"]')].map(box).filter(e => e && e.rect.w > 100 && e.rect.w < 260).slice(0, 20);

  // 所有不同的 borderRadius 值统计
  const radii = {};
  for (const el of document.querySelectorAll('*')) {
    const s = getComputedStyle(el);
    const r = s.borderRadius;
    if (r && r !== '0px') {
      const key = r + ' | ' + s.backgroundColor + ' | ' + el.tagName.toLowerCase() + '.' + (el.className||'').toString().split(' ')[0].slice(0,40);
      radii[key] = (radii[key]||0)+1;
    }
  }
  out.radii = radii;
  return out;
};`;

await evaluate(helper);
const data = await evaluate('JSON.stringify(__probe())');
fs.writeFileSync(OUT, JSON.stringify(JSON.parse(data), null, 1), 'utf8');
console.log('written', OUT, 'bytes', fs.statSync(OUT).size);
ws.close();
