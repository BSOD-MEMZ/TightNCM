// 拉取 static_public/<ver>/public/ 下的全部静态资源（图片 / SVG 图标 / 字体等）
// 引用来源：镜像 bundle 里的 "public/assets/..." 与 "orpheus://orpheus/pub/public/assets/..."
import fs from 'node:fs';
import path from 'node:path';

const ROOT = 'D:/Dev/TightNCM/research/mirror';
const BASE = fs.readFileSync(path.join(ROOT, 'index.html'), 'utf8')
  .match(/\/\/s5\.music\.126\.net\/static_public\/[^/]+\//)[0];
const HOST_BASE = 'https:' + BASE; // https://s5.music.126.net/static_public/<ver>/
const UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

console.log('BASE', HOST_BASE);

// ---------- 1. 收集引用 ----------
const files = [];
(function walk(d) {
  for (const e of fs.readdirSync(d, { withFileTypes: true })) {
    const p = path.join(d, e.name);
    if (e.isDirectory()) walk(p);
    else if (/\.(js|css)$/.test(e.name)) files.push(p);
  }
})(ROOT);

const rel = new Set();
const re = /(?:orpheus:\/\/orpheus\/pub\/)?public\/assets\/[A-Za-z0-9_@%./~+-]+\.(?:png|jpe?g|webp|gif|svg|woff2?|ttf|otf|json|mp4|mp3)/g;

for (const f of files) {
  const s = fs.readFileSync(f, 'utf8').split('\\/').join('/');
  for (const m of s.matchAll(re)) {
    rel.add(m[0].replace(/^orpheus:\/\/orpheus\/pub\//, ''));
  }
}
console.log('收集到', rel.size, '个 public/assets 资源');

// 顺带记录外部字体/MV 等（只登记不下载，体积大且版权敏感）
const external = new Set();
for (const f of files) {
  const s = fs.readFileSync(f, 'utf8');
  for (const m of s.matchAll(/https:\/\/d1\.music\.126\.net\/[A-Za-z0-9_@%./~+-]+\.(?:ttf|mp4|mp3)/g)) external.add(m[0]);
}
fs.writeFileSync(path.join(ROOT, '_external-assets.json'), JSON.stringify([...external].sort(), null, 2));

// ---------- 2. 下载 ----------
const list = [...rel];
let idx = 0, ok = 0, bytes = 0, miss = 0;
const misses = [];
await Promise.all(Array.from({ length: 16 }, async () => {
  while (idx < list.length) {
    const r = list[idx++];
    const url = HOST_BASE + r;
    const dest = path.join(ROOT, r);
    if (fs.existsSync(dest)) { ok++; bytes += fs.statSync(dest).size; continue; }
    try {
      const res = await fetch(url, { headers: { 'User-Agent': UA, Referer: 'https://music.163.com/' } });
      if (!res.ok) { miss++; misses.push([res.status, r]); continue; }
      const buf = Buffer.from(await res.arrayBuffer());
      fs.mkdirSync(path.dirname(dest), { recursive: true });
      fs.writeFileSync(dest, buf);
      ok++; bytes += buf.length;
    } catch (e) { miss++; misses.push(['ERR', r]); }
  }
}));

console.log(`\n下载成功 ${ok} 个，${(bytes / 1048576).toFixed(2)} MB；失败 ${miss} 个`);
if (misses.length) {
  const byStatus = {};
  for (const [s] of misses) byStatus[s] = (byStatus[s] || 0) + 1;
  console.log('失败状态分布:', byStatus);
  for (const [s, r] of misses.slice(0, 12)) console.log('   ', s, r);
}

// ---------- 3. 统计目录 ----------
const tree = {};
(function walk2(d, base) {
  for (const e of fs.readdirSync(d, { withFileTypes: true })) {
    const p = path.join(d, e.name);
    const rb = path.posix.join(base, e.name);
    if (e.isDirectory()) walk2(p, rb);
    else { const k = path.posix.dirname(rb); tree[k] = (tree[k] || 0) + 1; }
  }
})(path.join(ROOT, 'public'), 'public');
console.log('\n=== public/ 目录结构 ===');
for (const [k, v] of Object.entries(tree).sort()) console.log(String(v).padStart(5), k);
console.log('\n外部资源（仅登记）->', path.join(ROOT, '_external-assets.json'), [...external].length, '条');
