// 从镜像 CSS 中抽取代表性声明，用于 CSS -> Qt 映射
import fs from 'node:fs';
import path from 'node:path';

const ROOT = 'D:/Dev/TightNCM/research/mirror';
const VER = fs.readdirSync(ROOT).find((d) => /^[0-9a-f]{20,}_/.test(d));
const CSSDIR = path.join(ROOT, VER, 'styles');
const files = fs.readdirSync(CSSDIR).filter((f) => f.endsWith('.css')).map((f) => path.join(CSSDIR, f));
console.log('CSS 目录', CSSDIR, files.length, '个文件');

const pick = {
  'box-shadow': /box-shadow\s*:\s*([^;}]{5,140})/g,
  'backdrop-filter': /(?:-webkit-)?backdrop-filter\s*:\s*([^;}]{3,100})/g,
  filter: /(?:^|[;{])filter\s*:\s*([^;}]{3,120})/g,
  'linear-gradient': /linear-gradient\(([^()]{5,140})\)/g,
  'cubic-bezier': /cubic-bezier\(([^)]{5,60})\)/g,
  '@keyframes': /@keyframes\s+([A-Za-z0-9_-]+)/g,
  'clip-path': /clip-path\s*:\s*([^;}]{3,80})/g,
  'mix-blend-mode': /mix-blend-mode\s*:\s*([^;}]{3,40})/g,
  'border-radius': /border-radius\s*:\s*([^;}]{3,80})/g,
  transition: /transition\s*:\s*([^;}]{5,120})/g,
};

const out = {};
for (const [key, re] of Object.entries(pick)) {
  const set = new Map();
  for (const f of files) {
    const s = fs.readFileSync(f, 'utf8');
    for (const m of s.matchAll(re)) {
      const v = m[1].trim().replace(/\s+/g, ' ');
      set.set(v, (set.get(v) || 0) + 1);
    }
  }
  const sorted = [...set.entries()].sort((a, b) => b[1] - a[1]);
  out[key] = { distinct: sorted.length, total: sorted.reduce((a, [, c]) => a + c, 0), top: sorted.slice(0, 12) };
}

for (const [k, v] of Object.entries(out)) {
  console.log(`\n### ${k}   (distinct=${v.distinct}, total=${v.total})`);
  for (const [val, c] of v.top) console.log(`  ${String(c).padStart(5)}x  ${val.slice(0, 130)}`);
}

// 统计用了 filter 的具体函数
const fnRe = /([a-z-]+)\(/g;
const fnCount = {};
for (const f of files) {
  for (const m of fs.readFileSync(f, 'utf8').matchAll(/filter\s*:\s*([^;}]+)/g)) {
    for (const fn of m[1].matchAll(fnRe)) fnCount[fn[1]] = (fnCount[fn[1]] || 0) + 1;
  }
}
console.log('\n### filter 用到的函数');
for (const [k, v] of Object.entries(fnCount).sort((a, b) => b[1] - a[1])) console.log(`  ${String(v).padStart(5)}x  ${k}()`);

// backdrop-filter 的函数
const bfCount = {};
for (const f of files) {
  for (const m of fs.readFileSync(f, 'utf8').matchAll(/(?:-webkit-)?backdrop-filter\s*:\s*([^;}]+)/g)) {
    for (const fn of m[1].matchAll(fnRe)) bfCount[fn[1]] = (bfCount[fn[1]] || 0) + 1;
  }
}
console.log('\n### backdrop-filter 用到的函数');
for (const [k, v] of Object.entries(bfCount).sort((a, b) => b[1] - a[1])) console.log(`  ${String(v).padStart(5)}x  ${k}()`);
