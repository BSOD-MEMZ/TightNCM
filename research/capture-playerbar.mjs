// 触发播放并把播放栏抓下来
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
try { await send('Browser.setPermission', { permission: { name: 'autoplay' }, setting: 'granted', origin: 'https://music.163.com' }); console.log('autoplay 权限已授予'); } catch (e) { console.log('autoplay 权限设置失败:', e.message); }

// 重置页面状态
await send('Page.reload', { ignoreCache: false });
await sleep(12000);

console.log('\n=== 所有按钮 ===');
const btns = await evalJS(`[...document.querySelectorAll('button,[class*=cmd-button],[role=button]')].slice(0,40).map(e=>{const r=e.getBoundingClientRect();const c=getComputedStyle(e);
  return {t:(e.innerText||'').trim().slice(0,14), cls:String(e.className).slice(0,50), x:Math.round(r.x), y:Math.round(r.y), w:Math.round(r.width), h:Math.round(r.height), bg:c.backgroundColor, br:c.borderRadius, color:c.color, fs:c.fontSize};})`);
for (const b of btns) console.log('  ', JSON.stringify(b));

console.log('\n=== 点击「播放全部」 ===');
const box = await evalJS(`(() => { const el = [...document.querySelectorAll('button,[class*=cmd-button]')].find(e=>(e.innerText||'').trim()==='播放全部');
  if(!el) return null; const r=el.getBoundingClientRect(); return {x:r.x+r.width/2,y:r.y+r.height/2,w:r.width,h:r.height}; })()`);
if (!box) console.log('  未找到按钮');
else {
  console.log('  位置', JSON.stringify(box));
  for (const type of ['mouseMoved', 'mousePressed', 'mouseReleased']) {
    await send('Input.dispatchMouseEvent', { type, x: box.x, y: box.y, button: type === 'mouseMoved' ? 'none' : 'left', clickCount: type === 'mouseMoved' ? 0 : 1 });
    await sleep(120);
  }
}

// 等播放状态出现
for (let i = 0; i < 12; i++) {
  await sleep(2500);
  const st = await evalJS(`(() => { const f=document.querySelector('footer'); const a=document.querySelector('audio');
    return { fh: f?Math.round(f.getBoundingClientRect().height):-1, audio: !!a, paused: a?a.paused:null, src: a?(a.currentSrc||'').slice(0,60):'', fc: f?f.children.length:0 }; })()`);
  console.log(`  [${i}] footer高度=${st.fh} 子元素=${st.fc} audio=${st.audio} paused=${st.paused}`);
  if (st.fh > 0) break;
}

const s = await send('Page.captureScreenshot', { format: 'png' });
fs.writeFileSync(`${OUTDIR}/new-playerbar.png`, Buffer.from(s.data, 'base64'));
console.log('  png -> new-playerbar.png');

const dom = await evalJS(`'<!doctype html>\\n' + document.documentElement.outerHTML`);
fs.writeFileSync(`${OUTDIR}/new-playerbar-dom.html`, dom, 'utf8');
console.log('  dom ->', dom.length);

const fb = await evalJS(`(() => { const f=document.querySelector('footer'); if(!f) return {err:'no footer'};
  const P=['background-color','background-image','border-radius','box-shadow','backdrop-filter','padding','height','display','align-items','justify-content','gap','color','font-size','border-top','z-index','position'];
  const grabEl = (el,label) => { const c=getComputedStyle(el); const r=el.getBoundingClientRect(); const o={label,cls:String(el.className).slice(0,70),rect:{x:Math.round(r.x),y:Math.round(r.y),w:Math.round(r.width),h:Math.round(r.height)},text:(el.innerText||'').slice(0,26)};
    for(const p of P){const v=c.getPropertyValue(p); if(v&&v!=='none'&&v!=='normal'&&v!=='auto'&&v!=='rgba(0, 0, 0, 0)'&&v!=='0px')o[p]=v;} return o; };
  const out = [grabEl(f,'footer 播放栏')];
  const walk = (el, d) => { if(d>3) return; for(const c of el.children){ out.push(grabEl(c, '  '.repeat(d+1)+String(c.className).slice(0,44))); walk(c,d+1);} };
  walk(f,0);
  return out;
})()`);
fs.writeFileSync(`${OUTDIR}/playerbar-styles.json`, JSON.stringify(fb, null, 2));
console.log('\n=== 播放栏结构 ===');
for (const e of (Array.isArray(fb) ? fb : [])) console.log('  ', e.label.padEnd(46), JSON.stringify(e.rect), 'bg=' + (e['background-color'] || '-'), 'br=' + (e['border-radius'] || '-'));

ws.close(); process.exit(0);
