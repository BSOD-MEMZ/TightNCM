// 渲染预览 HTML 并截图
import fs from 'node:fs';
const CDP = 'http://127.0.0.1:9222';
const URL_TO = 'file:///D:/Dev/TightNCM/research/preview/shell.html';
const OUT = 'D:/Dev/TightNCM/research/preview/shell-preview.png';
const W = 1280, H = 800;
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

const t = await (await fetch(`${CDP}/json/new?${encodeURIComponent('about:blank')}`, { method: 'PUT' })).json();
const ws = new WebSocket(t.webSocketDebuggerUrl);
await new Promise((res, rej) => { ws.onopen = res; ws.onerror = rej; });
let id = 0; const pending = new Map();
ws.onmessage = (e) => { const m = JSON.parse(e.data); if (m.id && pending.has(m.id)) { const { res, rej } = pending.get(m.id); pending.delete(m.id); m.error ? rej(new Error(JSON.stringify(m.error))) : res(m.result); } };
const send = (method, params = {}) => new Promise((res, rej) => { const i = ++id; pending.set(i, { res, rej }); ws.send(JSON.stringify({ id: i, method, params })); });
const evalJS = async (e) => (await send('Runtime.evaluate', { returnByValue: true, expression: e })).result.value;

await send('Page.enable'); await send('Runtime.enable');
await send('Emulation.setDeviceMetricsOverride', { width: W, height: H, deviceScaleFactor: 2, mobile: false });
await send('Page.navigate', { url: URL_TO });
await sleep(2500);

// 自检：量一下实际渲染出来的关键几何，跟规格对一下
const check = await evalJS(`(() => {
  const g = (s) => { const e = document.querySelector(s); if(!e) return null; const r = e.getBoundingClientRect(); return {w:+r.width.toFixed(1), h:+r.height.toFixed(1), x:+r.x.toFixed(1), y:+r.y.toFixed(1)}; };
  const nav = document.querySelector('.navrow');
  const sel = document.querySelector('.navsel');
  const sc = getComputedStyle(sel);
  return {
    sidebar: g('#sidebar'),
    topbar: g('#topbar'),
    playbar: g('#playbar'),
    search: g('#search'),
    navItem: g('.navrow'),
    selecteBG: sc.backgroundColor,
    pageBG: getComputedStyle(document.body).backgroundColor,
    navItemCount: document.querySelectorAll('.navrow').length,
    plItemCount: document.querySelectorAll('.plrow').length,
  };
})()`);
console.log('=== 渲染自检 ===');
console.log(JSON.stringify(check, null, 1));

const s = await send('Page.captureScreenshot', { format: 'png' });
fs.writeFileSync(OUT, Buffer.from(s.data, 'base64'));
console.log('PNG ->', OUT);
ws.close(); process.exit(0);
