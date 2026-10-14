// 抓取登录态新版 webplayer 的「骨架几何 + 计算样式」，用于和 TightNCM 逐项对表。
// 用法: node capture-ref.mjs <cookieFile> <outPrefix> [width] [height] [waitMs]
// 输出: <outPrefix>.png + <outPrefix>.json
import fs from 'node:fs';

const CDP = 'http://127.0.0.1:9222';
const COOKIE_FILE = process.argv[2];
const OUT = process.argv[3] || 'D:/Dev/TightNCM/research/snapshot/ref';
const W = Number(process.argv[4] || 1280);
const H = Number(process.argv[5] || 800);
const WAIT_MS = Number(process.argv[6] || 20000);
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
const t0 = Date.now();
while (Date.now() - t0 < 40000 && !events.some((e) => e.method === 'Page.loadEventFired')) await sleep(300);
console.log('load', Date.now() - t0, 'ms');
await sleep(WAIT_MS);

// 注入探针：把整棵可见树的盒子 + 关键计算样式抠出来
await evaluate(`window.__box = function(sel, all) {
  const list = all ? [...document.querySelectorAll(sel)] : [document.querySelector(sel)].filter(Boolean);
  return list.map(el => {
    const r = el.getBoundingClientRect(), s = getComputedStyle(el);
    const keep = {};
    for (const p of ['display','position','flexDirection','alignItems','justifyContent','padding','margin','gap','rowGap','columnGap','background','backgroundColor','backgroundImage','border','borderTop','borderRadius','boxShadow','fontSize','fontWeight','fontFamily','lineHeight','color','width','height','overflow','zIndex','backdropFilter','opacity','transform','letterSpacing','textAlign','flex','gridTemplateColumns','maxWidth','minWidth']) {
      const v = s[p]; if (v && v !== 'none' && v !== 'normal' && v !== '0px' && v !== 'auto' && v !== 'rgba(0, 0, 0, 0)') keep[p] = v;
    }
    const rect = { x: Math.round(r.x*10)/10, y: Math.round(r.y*10)/10, w: Math.round(r.width*10)/10, h: Math.round(r.height*10)/10 };
    return { sel, cls: (el.className||'').toString().slice(0,120), tag: el.tagName.toLowerCase(), text: (el.childElementCount===0 ? el.textContent : '').trim().slice(0,60), rect, style: keep };
  });
};`);

const report = await evaluate(`(() => {
  const root = document.getElementById('root');
  const out = { viewport: {w: innerWidth, h: innerHeight}, href: location.href, title: document.title };
  out.body = __box('body')[0];
  out.root = __box('#root')[0];
  out.rootChildren = __box('#root > *', true);
  // 骨架三段
  out.footer = __box('footer')[0];
  out.footerChildren = __box('footer > *', true);
  // 所有带 cmd- 前缀的顶层容器
  out.cmdContainers = __box('[class*="cmd-"]', true).filter(e => e.rect.w > 100 && e.rect.h > 20).slice(0, 40);
  out.navItems = __box('[class*="nav"]', true).slice(0, 25);
  out.playlistItems = __box('[class*="laylist"]', true).slice(0, 20);
  out.headerEls = __box('header', true).slice(0, 6);
  out.inputs = __box('input', true).slice(0, 6);
  out.buttons = __box('button', true).slice(0, 12);
  out.text = document.body.innerText.slice(0, 900);
  return out;
})()`);
fs.writeFileSync(OUT + '.json', JSON.stringify(report, null, 2), 'utf8');
console.log('JSON saved:', OUT + '.json');
const shot = await send('Page.captureScreenshot', { format: 'png', captureBeyondViewport: false });
fs.writeFileSync(OUT + '.png', Buffer.from(shot.data, 'base64'));
console.log('PNG saved:', OUT + '.png', report.text ? '' : '');
if (report.text) console.log('--- TEXT ---\n' + report.text);
ws.close(); process.exit(0);
