// 解出镜像 CSS 内联 source map 中的原始源码
import fs from 'node:fs';
import path from 'node:path';

const ROOT = 'D:/Dev/TightNCM/research/mirror';
const VER = fs.readdirSync(ROOT).find((d) => /^[0-9a-f]{20,}_/.test(d));
const CSSDIR = path.join(ROOT, VER, 'styles');
const OUT = 'D:/Dev/TightNCM/research/src-recovered';

const files = fs.readdirSync(CSSDIR).filter((f) => f.endsWith('.css'));
const sources = new Map(); // 原始路径 -> 内容
let mapCount = 0, dupes = 0;

for (const f of files) {
  const text = fs.readFileSync(path.join(CSSDIR, f), 'utf8');
  const re = /sourceMappingURL=data:application\/json;base64,([A-Za-z0-9+/=]+)/g;
  let m;
  while ((m = re.exec(text))) {
    mapCount++;
    let j;
    try { j = JSON.parse(Buffer.from(m[1], 'base64').toString('utf8')); } catch { continue; }
    if (!j.sources) continue;
    j.sources.forEach((src, i) => {
      const content = j.sourcesContent && j.sourcesContent[i];
      if (!content) return;
      const key = String(src).replace(/^\/workspace\/git-source\//, '');
      if (sources.has(key)) { if (sources.get(key) !== content) dupes++; return; }
      sources.set(key, content);
    });
  }
}

console.log(`CSS 文件 ${files.length} 个，解出 source map ${mapCount} 份，去重后源码文件 ${sources.size} 个（跨文件不一致 ${dupes} 处）`);

// 写盘
fs.mkdirSync(OUT, { recursive: true });
let bytes = 0;
const manifest = [];
for (const [rel, content] of sources) {
  const dest = path.join(OUT, rel);
  fs.mkdirSync(path.dirname(dest), { recursive: true });
  fs.writeFileSync(dest, content, 'utf8');
  bytes += Buffer.byteLength(content);
  manifest.push({ path: rel, bytes: Buffer.byteLength(content), lines: content.split('\n').length });
}
manifest.sort((a, b) => b.bytes - a.bytes);
fs.writeFileSync(path.join(OUT, '_manifest.json'), JSON.stringify(manifest, null, 2));

console.log(`已写出 ${(bytes / 1048576).toFixed(2)} MB，共 ${manifest.length} 个文件 -> ${OUT}`);

// 目录分布
const dirs = {};
for (const { path: p } of manifest) { const d = path.posix.dirname(p); dirs[d] = (dirs[d] || 0) + 1; }
console.log('\n=== 目录分布 top 30 ===');
for (const [d, n] of Object.entries(dirs).sort((a, b) => b[1] - a[1]).slice(0, 30)) console.log(String(n).padStart(5), d);

console.log('\n=== 最大的 25 个文件 ===');
for (const { path: p, bytes: b, lines } of manifest.slice(0, 25)) console.log(String(lines).padStart(6), '行', (b / 1024).toFixed(1).padStart(7), 'KB ', p);
