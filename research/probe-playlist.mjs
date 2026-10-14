// 点进歌单页后，逐元素量官方详情页的几何（封面/标题/Tabs/表头/行）。
// 用法: node probe-playlist.mjs <cookieFile> [outJson]
import fs from 'node:fs';

const CDP = 'http://127.0.0.1:9222';
const COOKIE_FILE = process.argv[2];
const OUT = process.argv[3] || 'D:/Dev/TightNCM/research/snapshot/playlist-geom.json';
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
await send("Emulation.setDeviceMetricsOverride", { width: Number(process.argv[4]||1280), height: Number(process.argv[5]||800), deviceScaleFactor: 1, mobile: false });
await send('Network.setUserAgentOverride', { userAgent: UA });
await send('Page.navigate', { url: 'https://music.163.com/' });
await sleep(3500);
await send('Network.setCookie', { name: 'MUSIC_U', value: MUSIC_U, domain: '.music.163.com', path: '/', secure: true, httpOnly: true, sameSite: 'None' });
await send('Page.navigate', { url: 'https://music.163.com/st/webplayer' });
await sleep(16000);
await evaluate(`(() => { const e=[...document.querySelectorAll('*')].filter(x=>x.childElementCount===0&&x.textContent.trim()==='Discovery'); if(e.length) e[0].click(); })()`);
await sleep(9000);

const report = await evaluate(`(() => {
  const R = (el) => { if (!el) return null; const r = el.getBoundingClientRect();
    return { x:+r.x.toFixed(1), y:+r.y.toFixed(1), w:+r.width.toFixed(1), h:+r.height.toFixed(1) }; };
  const S = (el, props) => { if (!el) return null; const s = getComputedStyle(el); const o={};
    props.forEach(p=>{ const v=s[p]; if(v&&v!=='none'&&v!=='normal'&&v!=='auto'&&v!=='0px') o[p]=v; }); return o; };
  const q = (s) => document.querySelector(s);
  const qa = (s) => [...document.querySelectorAll(s)];
  const out = {};
  out.scrollArea = R(q('[class*="AppScrollContainer"]'));
  out.scrollAreaStyle = S(q('[class*="AppScrollContainer"]'), ['padding','backgroundImage','backgroundColor','overflow']);
  // 页头
  const common = qa('[class*="StyledCommon_"]')[0];
  out.header = R(common);
  out.headerStyle = S(common, ['padding','display','alignItems','marginBottom']);
  const coverEl = qa('[class*="StyledCover_"] .img')[0] || qa('[class*="StyledCover_"]')[0];
  out.cover = R(coverEl);
  out.coverStyle = S(coverEl, ['borderRadius','backgroundColor']);
  const bgEl = q('[class*="StyledCover_"] .bg');
  out.coverBg = R(bgEl); out.coverBgStyle = S(bgEl, ['top','left','right','bottom','borderRadius','backgroundColor']);
  out.info = R(q('[class*="StyledCommon_"] .info'));
  out.infoStyle = S(q('[class*="StyledCommon_"] .info'), ['marginLeft','paddingTop','paddingBottom']);
  out.title = R(q('[class*="StyledCommon_"] .title'));
  out.titleStyle = S(q('[class*="StyledCommon_"] .title'), ['fontSize','lineHeight','fontWeight','color']);
  out.desc = R(q('[class*="StyledCommon_"] .description'));
  out.descStyle = S(q('[class*="StyledCommon_"] .description'), ['fontSize','lineHeight','color','marginTop']);
  out.more = R(q('[class*="StyledCommon_"] .more'));
  out.moreStyle = S(q('[class*="StyledCommon_"] .more'), ['margin','display','alignItems']);
  const userRow = q('[class*="StyledCommon_"] .user');
  out.user = R(userRow);
  out.userAvatar = R(userRow && userRow.querySelector('img'));
  out.userInfos = userRow ? [...userRow.children].map(c=>({ tag:c.tagName, rect:R(c), fs:getComputedStyle(c).fontSize, color:getComputedStyle(c).color })) : null;
  out.time = R(q('[class*="StyledCommon_"] .time'));
  out.timeStyle = S(q('[class*="StyledCommon_"] .time'), ['fontSize','color']);
  out.btns = R(q('[class*="StyledCommon_"] .btns'));
  out.btnsStyle = S(q('[class*="StyledCommon_"] .btns'), ['marginTop','display']);
  const playAll = q('[class*="StyledCommon_"] .btns .cmd-button');
  out.playAll = R(playAll);
  out.playAllStyle = S(playAll, ['height','borderRadius','padding','backgroundColor','backgroundImage','fontSize','color','minWidth']);
  out.btnsChildren = qa('[class*="StyledCommon_"] .btns > *').map(c=>({ rect:R(c), cls:(c.className||'').toString().slice(0,60) }));
  // Tabs
  const tabs = qa('[class*="cmd-tabs"]').filter(e=>R(e) && R(e).h>20)[0];
  out.tabs = R(tabs);
  out.tabsStyle = S(tabs, ['height','borderBottom','marginBottom']);
  out.tabItems = qa('[class*="cmd-tabs"] [class*="cmd-tabs-tab"]').slice(0,5).map(c=>({ rect:R(c), text:c.textContent.trim().slice(0,10), cls:(c.className||'').toString().slice(0,80) }));
  // 表格
  const thead = q('.thead');
  out.thead = R(thead); out.theadStyle = S(thead, ['height','borderBottom','marginBottom','color']);
  out.theadTr = R(thead && thead.querySelector('.tr'));
  out.ths = qa('.thead .th').map(c=>({ rect:R(c), text:c.textContent.trim().slice(0,6), cls:(c.className||'').toString() }));
  const rows = qa('.tbody .tr').slice(0,4);
  out.rows = rows.map(r=>({ rect:R(r), style:S(r,['height','borderRadius','background']) }));
  out.tds = rows[0] ? [...rows[0].children].map(c=>({ rect:R(c), cls:(c.className||'').toString(), style:S(c,['padding','width','flexGrow']) })) : null;
  const titleCell = rows[0] && rows[0].querySelector('[class*="StyledTitleCell"]');
  out.titleCell = R(titleCell); out.titleCellStyle = S(titleCell, ['marginLeft','padding','width']);
  out.rowCover = R(titleCell && titleCell.querySelector('.cover'));
  out.rowTitle = R(titleCell && titleCell.querySelector('.title'));
  out.rowTitleStyle = S(titleCell && titleCell.querySelector('.title'), ['fontSize','fontWeight','color']);
  out.rowSub = R(titleCell && titleCell.querySelector('.sub-title'));
  out.rowSubStyle = S(titleCell && titleCell.querySelector('.sub-title'), ['fontSize','color','marginTop']);
  // 背景
  out.bg = qa('[class*="StyledBackground"]').map(e=>({ rect:R(e), style:S(e,['backgroundImage','backgroundColor','zIndex','height']) }));
  return out;
})()`);
fs.writeFileSync(OUT, JSON.stringify(report, null, 2), 'utf8');
console.log(JSON.stringify(report, null, 2).slice(0, 6000));
ws.close(); process.exit(0);
