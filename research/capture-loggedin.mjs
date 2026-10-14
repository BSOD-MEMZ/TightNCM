// 注入 MUSIC_U cookie 后抓取登录态的新版 webplayer
// cookie 从临时文件读取，不落到项目目录
// 用法: node capture-loggedin.mjs <cookieFile> <outPng> <outDom> [waitMs]
import fs from 'node:fs';

const CDP = 'http://127.0.0.1:9222';
const COOKIE_FILE = process.argv[2];
const OUT_PNG = process.argv[3];
const OUT_DOM = process.argv[4];
const WAIT_MS = Number(process.argv[5] || 22000);
const UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

const MUSIC_U = fs.readFileSync(COOKIE_FILE, 'utf8').trim();
console.log('cookie 长度', MUSIC_U.length, '前缀', MUSIC_U.slice(0, 4) + '...');

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

const t = await (await fetch(`${CDP}/json/new?${encodeURIComponent('about:blank')}`, { method: 'PUT' })).json();
const ws = new WebSocket(t.webSocketDebuggerUrl);
await new Promise((res, rej) => { ws.onopen = res; ws.onerror = rej; });

let id = 0;
const pending = new Map();
let events = [];
ws.onmessage = (e) => {
  const m = JSON.parse(e.data);
  if (m.id && pending.has(m.id)) {
    const { res, rej } = pending.get(m.id);
    pending.delete(m.id);
    m.error ? rej(new Error(JSON.stringify(m.error))) : res(m.result);
  } else if (m.method) events.push(m);
};
const send = (method, params = {}) => new Promise((res, rej) => {
  const i = ++id;
  pending.set(i, { res, rej });
  ws.send(JSON.stringify({ id: i, method, params }));
});

await send('Page.enable');
await send('Runtime.enable');
await send('Network.enable');
await send('Emulation.setDeviceMetricsOverride', { width: 1440, height: 900, deviceScaleFactor: 1, mobile: false });
await send('Network.setUserAgentOverride', { userAgent: UA });

// ---- 1. 先落到 music.163.com，建立同源上下文 ----
await send('Page.navigate', { url: 'https://music.163.com/' });
await sleep(4000);

// ---- 2. 注入 cookie ----
for (const [name, value, httpOnly] of [
  ['MUSIC_U', MUSIC_U, true],
  ['__csrf', '', false],
]) {
  if (!value) continue;
  const r = await send('Network.setCookie', {
    name, value, domain: '.music.163.com', path: '/', secure: true, httpOnly, sameSite: 'None',
  });
  console.log('setCookie', name, JSON.stringify(r));
}
const all = await send('Network.getCookies', { urls: ['https://music.163.com/'] });
console.log('当前 cookie 数:', all.cookies.length, all.cookies.map((c) => c.name).join(','));

// ---- 3. 打开新版播放器 ----
events = [];
await send('Page.navigate', { url: 'https://music.163.com/st/webplayer' });
const t0 = Date.now();
while (Date.now() - t0 < 40000 && !events.some((e) => e.method === 'Page.loadEventFired')) await sleep(300);
console.log('loadEventFired after', Date.now() - t0, 'ms');
await sleep(WAIT_MS);

// ---- 4. 探测 ----
const probe = await send('Runtime.evaluate', {
  returnByValue: true,
  expression: `(() => {
    const root = document.getElementById('root');
    const cs = (el,p)=>el?getComputedStyle(el)[p]:null;
    const q = s => document.querySelector(s);
    return {
      href: location.href,
      title: document.title,
      hasRoot: !!root,
      rootChildren: root ? root.children.length : -1,
      rootHTMLSize: root ? root.innerHTML.length : 0,
      bodyHTMLSize: document.body.innerHTML.length,
      // 是否老版特征
      legacyMarkers: ['g-topbar','g-btmbar','m-playbar','m-top'].filter(c=>q('.'+c)),
      // 是否新版特征
      newMarkers: ['cmd-'].filter(c=>q('[class*="'+c+'"]')),
      bodyBg: cs(document.body,'backgroundColor'),
      bodyFont: cs(document.body,'fontFamily'),
      tokens: (() => {
        const el = root && root.firstElementChild; if(!el) return {};
        const s = getComputedStyle(el); const o={};
        ['--colorBlack1','--colorBlack2','--colorBlack3','--colorBlack6','--colorWhite1','--colorWhite2','--colorWhite3','--colorWhite6'].forEach(v=>o[v]=s.getPropertyValue(v));
        return o;
      })(),
      topLevelClasses: root ? [...root.children].map(c=>c.className).slice(0,12) : [],
      text: document.body.innerText.slice(0, 700),
    };
  })()`,
});
console.log('=== PROBE ===');
console.log(JSON.stringify(probe.result.value, null, 2));

// ---- 5. 导出 DOM + 截图 ----
const dom = await send('Runtime.evaluate', { returnByValue: true, expression: `'<!doctype html>\\n' + document.documentElement.outerHTML` });
fs.writeFileSync(OUT_DOM, dom.result.value, 'utf8');
console.log('DOM saved:', OUT_DOM, dom.result.value.length, 'chars');

const shot = await send('Page.captureScreenshot', { format: 'png', captureBeyondViewport: false });
fs.writeFileSync(OUT_PNG, Buffer.from(shot.data, 'base64'));
console.log('PNG saved:', OUT_PNG);

ws.close();
process.exit(0);
