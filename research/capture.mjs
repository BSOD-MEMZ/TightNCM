// 通过 CDP 渲染 music.163.com/st/webplayer 并截图 + 导出 DOM/样式
import fs from 'node:fs';

const CDP = 'http://127.0.0.1:9222';
const URL_TARGET = process.argv[2] || 'https://music.163.com/st/webplayer';
const OUT_PNG = process.argv[3] || 'D:/Dev/TightNCM/research/snapshot/render.png';
const OUT_DOM = process.argv[4] || 'D:/Dev/TightNCM/research/snapshot/dom.html';
const WAIT_MS = Number(process.argv[5] || 15000);
const UA = process.env.NCM_UA || null;

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// 1. 新建标签页
const t = await (await fetch(`${CDP}/json/new?${encodeURIComponent('about:blank')}`, { method: 'PUT' })).json();
const ws = new WebSocket(t.webSocketDebuggerUrl);
await new Promise((res, rej) => { ws.onopen = res; ws.onerror = rej; });

let id = 0;
const pending = new Map();
const events = [];
ws.onmessage = (e) => {
  const m = JSON.parse(e.data);
  if (m.id && pending.has(m.id)) {
    const { res, rej } = pending.get(m.id);
    pending.delete(m.id);
    m.error ? rej(new Error(JSON.stringify(m.error))) : res(m.result);
  } else if (m.method) {
    events.push(m);
  }
};
const send = (method, params = {}) => new Promise((res, rej) => {
  const i = ++id;
  pending.set(i, { res, rej });
  ws.send(JSON.stringify({ id: i, method, params }));
});

// 2. 打开页面
await send('Page.enable');
await send('Runtime.enable');
await send('Network.enable');
await send('Emulation.setDeviceMetricsOverride', {
  width: 1440, height: 900, deviceScaleFactor: 1, mobile: false,
});
if (UA) {
  await send('Network.setUserAgentOverride', { userAgent: UA });
  console.log('UA override ->', UA);
}
await send('Page.navigate', { url: URL_TARGET });

// 等 load 事件（最多 30s）
const t0 = Date.now();
while (Date.now() - t0 < 30000 && !events.some((e) => e.method === 'Page.loadEventFired')) await sleep(300);
console.log('loadEventFired after', Date.now() - t0, 'ms');
await sleep(WAIT_MS);

// 3. DOM 概况
const probe = await send('Runtime.evaluate', {
  returnByValue: true,
  expression: `(() => {
    const root = document.getElementById('root');
    const cs = (el, p) => el ? getComputedStyle(el)[p] : null;
    const first = root && root.firstElementChild;
    return {
      title: document.title,
      href: location.href,
      referrer: document.referrer,
      rootChildren: root ? root.children.length : -1,
      rootHTMLSize: root ? root.innerHTML.length : 0,
      bodyHTMLSize: document.body.innerHTML.length,
      scripts: [...document.querySelectorAll('script[src]')].map(s => s.src),
      styleSheets: [...document.styleSheets].map(s => s.href).filter(Boolean),
      bodyBg: cs(document.body, 'backgroundColor'),
      bodyFont: cs(document.body, 'fontFamily'),
      firstChildClass: first ? first.className : null,
      firstChildBg: cs(first, 'backgroundColor'),
      cssVarSample: (() => {
        const out = {};
        if (!first) return out;
        const s = getComputedStyle(first);
        for (const v of ['--colorBlack1','--colorBlack2','--colorBlack3','--colorWhite1','--colorWhite2','--colorWhite3']) out[v] = s.getPropertyValue(v);
        return out;
      })(),
      // 抓一下顶栏/侧栏可见文本，帮助判断是不是旧版
      text: document.body.innerText.slice(0, 600),
    };
  })()`,
});
console.log('=== PROBE ===');
console.log(JSON.stringify(probe.result.value, null, 2));

// 4. 导出完整 DOM
const dom = await send('Runtime.evaluate', {
  returnByValue: true,
  expression: `'<!doctype html>\\n' + document.documentElement.outerHTML`,
});
fs.writeFileSync(OUT_DOM, dom.result.value, 'utf8');
console.log('DOM saved:', OUT_DOM, dom.result.value.length, 'chars');

// 5. 截图
const shot = await send('Page.captureScreenshot', { format: 'png', captureBeyondViewport: false });
fs.writeFileSync(OUT_PNG, Buffer.from(shot.data, 'base64'));
console.log('PNG saved:', OUT_PNG);

ws.close();
process.exit(0);
