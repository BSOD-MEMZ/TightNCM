// 从 app.js 的图标注册表里挖出全部图标（含未渲染到的播放栏图标）
import fs from 'node:fs';
import path from 'node:path';

const JS = 'D:/Dev/TightNCM/research/mirror/68aea63daca57500bb3fb4b6_68aea63daca57500bb3fb4b7/hybrid/app.4c9df986.js';
const OUT = 'D:/Dev/TightNCM/assets/icons-svg';

const s = fs.readFileSync(JS, 'utf8');

// 图标注册点： ,"<name>",[x,y,w,h]
const re = /,"([a-zA-Z0-9_\-]+)",\[(\d+),(\d+),(\d+),(\d+)\]/g;
const marks = [];
let m;
while ((m = re.exec(s))) marks.push({ name: m[1], vb: `${m[2]} ${m[3]} ${m[4]} ${m[5]}`, at: m.index, end: m.index + m[0].length });
console.log('候选图标注册点:', marks.length);

const dec = (str) => str.replace(/\\"/g, '"').replace(/\\n/g, ' ').replace(/\\\\/g, '\\');

const icons = new Map();
let prev = 0;
for (const mk of marks) {
  const seg = s.slice(prev, mk.at);
  prev = mk.end;

  // 该段里的 svg 根节点
  const svgIdx = seg.lastIndexOf('createElement("svg"');
  if (svgIdx < 0) continue;
  const svgSeg = seg.slice(svgIdx);

  // viewBox 优先用注册点的，其次用 svg 属性
  const vbAttr = (svgSeg.match(/viewBox:"([^"]+)"/) || [])[1];
  const viewBox = vbAttr || mk.vb;

  // 抽取绘制元素
  // ⚠️ `[\s\S]{0,4000}?` 这个上限踩过坑：有 12 个图标的 path 数据超过 4000 字符
  // （最多 4.3K），正则够不到闭合的 `})`，于是 parts 为空、图标被跳过，
  // 最后被 extract-icons-from-dom 写成了**空的 `<svg>`**。
  // 表现就是这些图标完全不可见（PlayBar 的音量、静音，设置页的细齿轮等）。
  const parts = [];
  for (const p of svgSeg.matchAll(/createElement\("path",\{([\s\S]{0,40000}?)\}\)/g)) {
    const d = (p[1].match(/\bd:"((?:[^"\\]|\\.)*)"/) || [])[1];
    if (!d) continue;
    const fillRule = (p[1].match(/fillRule:"([^"]+)"/) || [])[1] || 'nonzero';
    const clipRule = (p[1].match(/clipRule:"([^"]+)"/) || [])[1] || '';
    const fill = (p[1].match(/\bfill:"([^"]+)"/) || [])[1] || 'currentColor';
    const op = (p[1].match(/fillOpacity:"?([0-9.]+)"?/) || [])[1];
    parts.push(`<path d="${dec(d)}" fill="${fill === 'none' ? 'none' : 'currentColor'}"${fillRule !== 'nonzero' ? ` fill-rule="${fillRule}"` : ''}${clipRule ? ` clip-rule="${clipRule}"` : ''}${op && op !== '1' ? ` fill-opacity="${op}"` : ''}/>`);
  }
  for (const c of svgSeg.matchAll(/createElement\("circle",\{([\s\S]{0,600}?)\}\)/g)) {
    const cx = (c[1].match(/cx:"?([0-9.]+)"?/) || [])[1];
    const cy = (c[1].match(/cy:"?([0-9.]+)"?/) || [])[1];
    const r = (c[1].match(/\br:"?([0-9.]+)"?/) || [])[1];
    if (cx != null && cy != null && r != null) parts.push(`<circle cx="${cx}" cy="${cy}" r="${r}" fill="currentColor"/>`);
  }
  for (const rc of svgSeg.matchAll(/createElement\("rect",\{([\s\S]{0,600}?)\}\)/g)) {
    const g = (k) => (rc[1].match(new RegExp(`\\b${k}:"?([0-9.]+)"?`)) || [])[1];
    const [x, y, w, h] = [g('x'), g('y'), g('width'), g('height')];
    if (x != null && y != null && w != null && h != null) {
      const rx = g('rx');
      parts.push(`<rect x="${x}" y="${y}" width="${w}" height="${h}"${rx ? ` rx="${rx}"` : ''} fill="currentColor"/>`);
    }
  }
  if (!parts.length) continue;

  const svg = `<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="${viewBox}">${parts.join('')}</svg>`;
  if (!icons.has(mk.name)) icons.set(mk.name, { svg, viewBox, paths: parts.length });
}

console.log('解析出图标:', icons.size);

fs.mkdirSync(OUT, { recursive: true });
const manifest = [];
for (const [name, o] of icons) {
  const file = `ncm_${name}.svg`;
  fs.writeFileSync(path.join(OUT, file), o.svg, 'utf8');
  manifest.push({ name, file, viewBox: o.viewBox, paths: o.paths, bytes: o.svg.length });
}
manifest.sort((a, b) => a.name.localeCompare(b.name));
fs.writeFileSync(path.join(OUT, '_js-manifest.json'), JSON.stringify(manifest, null, 2));
console.log(`已写出 ${manifest.length} 个图标 -> ${OUT}\n`);

console.log('=== 图标名清单 ===');
const groups = {};
for (const x of manifest) {
  const g = x.name.includes('_') ? x.name.split('_')[0] : (x.name.match(/^[a-z]+/) || ['other'])[0];
  (groups[g] = groups[g] || []).push(x.name);
}
for (const [g, list] of Object.entries(groups).sort((a, b) => b[1].length - a[1].length)) {
  console.log(`  [${g}] (${list.length}) ${list.join(', ')}`);
}

console.log('\n=== 多路径图标（结构较复杂） ===');
for (const x of manifest.filter((y) => y.paths > 1).slice(0, 20)) console.log(`  ${x.name.padEnd(42)} ${x.paths} paths  vb=${x.viewBox}`);
