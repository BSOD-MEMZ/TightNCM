// 镜像 music.163.com/st/webplayer 的静态资源（bundle + CSS + 所有懒加载 chunk）
// 用法: node mirror.mjs [outDir]
import fs from 'node:fs';
import path from 'node:path';

const PAGE = 'https://music.163.com/st/webplayer';
const UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';
const OUT = path.resolve(process.argv[2] || 'D:/Dev/TightNCM/research/mirror');

const log = (...a) => console.log(...a);

// ---------- 1. 拿外壳 HTML ----------
const html = await (await fetch(PAGE, { headers: { 'User-Agent': UA } })).text();
fs.mkdirSync(OUT, { recursive: true });
fs.writeFileSync(path.join(OUT, 'index.html'), html);
log('HTML', html.length, 'bytes');

// 公共静态根（含版本号，形如 //s5.music.126.net/static_public/<hash>_<hash>/）
const base = html.match(/\/\/s5\.music\.126\.net\/static_public\/[^/]+\//)[0];
log('BASE', base);

// ---------- 2. 解析 webpack chunk 清单 ----------
// 形如  {0:"hash",1:"hash",...}
const maps = [];
const mapRe = /\{((?:\d+:"[0-9a-f]{8,}",?){3,})\}/g;
let m;
while ((m = mapRe.exec(html))) {
  const entries = [...m[1].matchAll(/(\d+):"([0-9a-f]+)"/g)].map((x) => [x[1], x[2]]);
  // 看这个 map 之后 120 字符里的后缀，判断是 js 还是 css
  const after = html.slice(m.index + m[0].length, m.index + m[0].length + 120);
  maps.push({ entries, after: after.replace(/\s+/g, ' ').trim().slice(0, 90) });
}
log('\n发现', maps.length, '个 hash 映射表:');
maps.forEach((mp, i) => log(`  [${i}] ${mp.entries.length} 项  after="${mp.after}"`));

// chunk 名称表（有些 webpack 配置有 {id:"chunkName"}）
const nameMapMatch = html.match(/\{((?:\d+:"[a-zA-Z0-9_~.-]+",?){3,})\}/g) || [];

// ---------- 3. 生成下载清单 ----------
const targets = new Set();

// 3a. HTML 里直接引用的 js/css
for (const mm of html.matchAll(/(?:src|href)="([^"]+\.(?:js|css))"/g)) targets.add(mm[1]);

// 3b. 清单里的 chunk
//     CSS: {20位hash}[e] + ".css"     -> styles/<hash>.css
//     JS : "hybrid/" + id + "." + {8位hash}[e] + ".js"  -> hybrid/<id>.<hash>.js
for (const mp of maps) {
  const isCss = /\.css/.test(mp.after);
  const isJs = /\.js/.test(mp.after);
  for (const [id, hash] of mp.entries) {
    if (isCss) targets.add(`${base}styles/${hash}.css`);
    if (isJs) targets.add(`${base}hybrid/${id}.${hash}.js`);
  }
}

// 归一化成完整 URL
const urls = [...targets].map((u) => (u.startsWith('//') ? 'https:' + u : u.startsWith('http') ? u : base.replace(/^\/\//, 'https://') + u.replace(/^\//, '')));

log('\n候选 URL:', urls.length);

// ---------- 4. 下载（并发 12，404 直接跳过） ----------
const results = { ok: [], miss: [] };
let idx = 0;
const workers = Array.from({ length: 12 }, async () => {
  while (idx < urls.length) {
    const u = urls[idx++];
    const rel = u.split('/static_public/')[1] || u.split('/').slice(3).join('/');
    const dest = path.join(OUT, rel);
    if (fs.existsSync(dest)) { results.ok.push([u, fs.statSync(dest).size]); continue; }
    try {
      const r = await fetch(u, { headers: { 'User-Agent': UA, Referer: 'https://music.163.com/' } });
      if (!r.ok) { results.miss.push([u, r.status]); continue; }
      const buf = Buffer.from(await r.arrayBuffer());
      fs.mkdirSync(path.dirname(dest), { recursive: true });
      fs.writeFileSync(dest, buf);
      results.ok.push([u, buf.length]);
    } catch (e) {
      results.miss.push([u, String(e.message || e)]);
    }
  }
});
await Promise.all(workers);

const total = results.ok.reduce((a, [, s]) => a + s, 0);
log('\n下载成功', results.ok.length, '个文件, 合计', (total / 1048576).toFixed(2), 'MB');
log('失败/不存在', results.miss.length, '个');
if (results.miss.length && results.miss.length < 25) for (const [u, s] of results.miss) log('   miss', s, u);
else if (results.miss.length) log('   (示例)', results.miss.slice(0, 5).map((x) => x[1] + ' ' + x[0]).join('\n   '));

// ---------- 5. 汇总 ----------
const byExt = {};
for (const [u, s] of results.ok) {
  const e = path.extname(u.split('?')[0]) || '(none)';
  byExt[e] = byExt[e] || [0, 0];
  byExt[e][0]++;
  byExt[e][1] += s;
}
log('\n按类型:');
for (const [e, [n, s]] of Object.entries(byExt)) log(`  ${e.padEnd(6)} ${String(n).padStart(4)} 个  ${(s / 1048576).toFixed(2)} MB`);
fs.writeFileSync(path.join(OUT, '_mirror-report.json'), JSON.stringify({ base, total, ok: results.ok, miss: results.miss }, null, 2));
log('\n输出目录:', OUT);
