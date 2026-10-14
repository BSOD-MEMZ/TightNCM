// 从抓到的登录态 DOM 里提取全部内联 SVG 图标
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';

const DOMS = [
  'D:/Dev/TightNCM/research/snapshot/dom-loggedin.html',
  'D:/Dev/TightNCM/research/snapshot/new-playing-dom.html',
  'D:/Dev/TightNCM/research/snapshot/new-home-dom.html',
  'D:/Dev/TightNCM/research/snapshot/dom-real-ua.html',
];
const OUT = 'D:/Dev/TightNCM/assets/icons-svg';

const icons = new Map();
let total = 0;

for (const f of DOMS) {
  if (!fs.existsSync(f)) continue;
  const html = fs.readFileSync(f, 'utf8');
  const re = /<svg\b[\s\S]{0,12000}?<\/svg>/g;
  let m;
  while ((m = re.exec(html))) {
    total++;
    let svg = m[0];
    // 规范化：去掉动态 id 的 clipPath（会导致重复），保留结构
    const h = crypto.createHash('md5').update(svg.replace(/\sid="[^"]*"/g, '')).digest('hex').slice(0, 10);
    if (icons.has(h)) { icons.get(h).count++; continue; }

    const before = html.slice(Math.max(0, m.index - 600), m.index);
    const vb = (svg.match(/viewBox="([^"]*)"/) || [, ''])[1];
    // 名称线索：就近的 class / aria-label / title / 父按钮文字
    const cls = [...before.matchAll(/class="([^"]+)"/g)].pop();
    const aria = (before.match(/aria-label="([^"]*)"/) || [])[1];
    const title = (before.match(/title="([^"]*)"/) || [])[1];
    icons.set(h, {
      svg, hash: h, count: 1, viewBox: vb,
      cls: cls ? cls[1].split(/\s+/).filter((c) => !/^[A-Za-z]+_[a-z0-9]{6,}$/.test(c)).slice(-2).join(' ') : '',
      aria: aria || title || '',
      file: path.basename(f),
    });
  }
}
console.log(`扫描 ${DOMS.length} 个 DOM，命中 <svg> ${total} 处，去重后 ${icons.size} 个`);

fs.mkdirSync(OUT, { recursive: true });
const manifest = [];
for (const [h, o] of [...icons.entries()].sort((a, b) => b[1].count - a[1].count)) {
  // 优先用官方 cmd-icon-<name> 类名作为文件名，和 JS 提取器保持一致
  const iconCls = (o.cls.match(/cmd-icon-([A-Za-z0-9_-]+)/) || [])[1];
  const hint = iconCls
    || (o.cls || o.aria || 'icon').replace(/[^\w\u4e00-\u9fa5-]/g, '_').slice(0, 36)
    || 'icon';
  const name = `ncm_${hint}.svg`;
  // ⚠️ 别用「没有绘制元素」的空壳覆盖已有图标。
  // 踩过的坑：DOM 里有些 <svg> 的图形是通过 <use> 引用的，抓下来只剩一个空壳
  // `<svg viewBox="..."></svg>`；它会把 extract-icons-from-js 挖到的真图标整个覆盖掉，
  // 表现是图标彻底消失（音量/静音/细齿轮等）。
  const hasDrawing = /<(path|circle|rect|polygon|polyline|ellipse|line|g)\b/.test(o.svg);
  if (!hasDrawing) {
    console.log(`  [skip] ${name}：DOM 里只有空壳，保留 JS 提取器挖到的版本`);
    continue;
  }
  fs.writeFileSync(path.join(OUT, name), o.svg, 'utf8');
  manifest.push({ name, hash: h, count: o.count, viewBox: o.viewBox, cls: o.cls, aria: o.aria, bytes: o.svg.length });
}
fs.writeFileSync(path.join(OUT, '_manifest.json'), JSON.stringify(manifest, null, 2));

console.log(`已写出 ${manifest.length} 个 SVG -> ${OUT}\n`);
console.log('=== 出现次数最多的（就是核心图标） ===');
for (const m of manifest.slice(0, 45)) {
  console.log(`  ${String(m.count).padStart(3)}x  vb=${(m.viewBox || '-').padEnd(16)} ${(m.cls || m.aria || '').padEnd(28)} ${m.name}`);
}
console.log('\n=== viewBox 分布 ===');
const vb = {};
for (const m of manifest) vb[m.viewBox || '(无)'] = (vb[m.viewBox || '(无)'] || 0) + 1;
for (const [k, v] of Object.entries(vb).sort((a, b) => b[1] - a[1])) console.log(String(v).padStart(5), k);
