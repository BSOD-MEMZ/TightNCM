// 从还原源码里提取内联 SVG 图标，去重后单独存成 .svg
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';

const SRC = 'D:/Dev/TightNCM/research/src-recovered';
const OUT = 'D:/Dev/TightNCM/assets/icons-svg';

const files = [];
(function walk(d) {
  for (const e of fs.readdirSync(d, { withFileTypes: true })) {
    const p = path.join(d, e.name);
    if (e.isDirectory()) walk(p);
    else if (/\.(tsx|jsx|ts|js)$/.test(e.name)) files.push(p);
  }
})(SRC);

const svgs = new Map(); // hash -> {svg, hints:Set}
let raw = 0;

for (const f of files) {
  const s = fs.readFileSync(f, 'utf8');
  // 1) 完整 <svg ...>...</svg>
  for (const m of s.matchAll(/<svg\b[\s\S]{0,4000}?<\/svg>/g)) {
    raw++;
    let svg = m[0];
    // JSX -> 标准 SVG：去掉 {} 表达式、className、其余 camelCase 属性转 kebab
    svg = svg.replace(/\{[^{}]*\}/g, '');
    svg = svg.replace(/\bclassName=/g, 'class=');
    svg = svg.replace(/\b(strokeWidth|strokeLinecap|strokeLinejoin|fillRule|clipRule|strokeDasharray|fillOpacity|strokeOpacity)=/g,
      (_, p) => p.replace(/[A-Z]/g, (c) => '-' + c.toLowerCase()) + '=');
    svg = svg.replace(/\s+/g, ' ').trim();
    const h = crypto.createHash('md5').update(svg).digest('hex').slice(0, 10);
    if (!svgs.has(h)) svgs.set(h, { svg, hints: new Set() });
    const near = s.slice(Math.max(0, m.index - 400), m.index);
    const name = (near.match(/(?:function|const)\s+([A-Z][A-Za-z0-9_]*)/g) || []).pop()
      || (near.match(/name=["']([^"']+)["']/g) || []).pop() || '';
    if (name) svgs.get(h).hints.add(String(name).replace(/^(function|const)\s+/, ''));
  }
  // 2) 只有 path d= 的片段（例如 ICON_MAP 之类）
  for (const m of s.matchAll(/d\s*[:=]\s*["'`](M[\s\S]{20,3000}?)["'`]/g)) {
    raw++;
    const d = m[1].replace(/\s+/g, ' ').trim();
    const svg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="${d}"/></svg>`;
    const h = crypto.createHash('md5').update(svg).digest('hex').slice(0, 10);
    if (!svgs.has(h)) svgs.set(h, { svg, hints: new Set() });
    const near = s.slice(Math.max(0, m.index - 300), m.index + 50);
    const nm = (near.match(/([A-Za-z0-9_]{3,40})\s*[:=]\s*$/) || [])[1];
    if (nm) svgs.get(h).hints.add(nm);
  }
}

console.log(`扫描 ${files.length} 个源文件，命中 SVG/路径 ${raw} 处，去重后 ${svgs.size} 个`);

fs.mkdirSync(OUT, { recursive: true });
const manifest = [];
let i = 0;
for (const [h, { svg, hints }] of svgs) {
  const label = [...hints][0] ? String([...hints][0]).replace(/[^\w-]/g, '_').slice(0, 40) : 'icon';
  const name = `${label}_${h}.svg`;
  fs.writeFileSync(path.join(OUT, name), svg, 'utf8');
  manifest.push({ name, hash: h, bytes: svg.length, hints: [...hints].slice(0, 4) });
  i++;
}
fs.writeFileSync(path.join(OUT, '_manifest.json'), JSON.stringify(manifest, null, 2));
console.log(`已写出 ${i} 个 SVG -> ${OUT}`);

// 打印一部分名称，方便看图标体系
console.log('\n=== 带名字提示的图标（前 60） ===');
for (const m of manifest.filter((x) => x.hints.length).slice(0, 60)) console.log('  ', m.name.padEnd(46), m.hints.join(','));

console.log('\n=== 尺寸分布（viewBox） ===');
const vb = {};
for (const m of manifest) { const v = (fs.readFileSync(path.join(OUT, m.name), 'utf8').match(/viewBox="([^"]*)"/) || [])[1] || '(无)'; vb[v] = (vb[v] || 0) + 1; }
for (const [k, v] of Object.entries(vb).sort((a, b) => b[1] - a[1]).slice(0, 12)) console.log(String(v).padStart(5), k);
