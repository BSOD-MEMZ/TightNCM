import fs from 'node:fs';
import path from 'node:path';
const ROOT = 'D:/Dev/TightNCM/research/mirror';
const VER = fs.readdirSync(ROOT).find((d) => /^[0-9a-f]{20,}_/.test(d));
const DIR = path.join(ROOT, VER, 'styles');
const files = fs.readdirSync(DIR).filter((f) => f.endsWith('.css'));

let single = 0, multi = 0, pct = 0, cssvar = 0;
const multiSamples = new Map();
const animProps = new Map();

for (const f of files) {
  const s = fs.readFileSync(path.join(DIR, f), 'utf8');
  for (const m of s.matchAll(/border-radius\s*:\s*([^;}]+)/g)) {
    const v = m[1].trim().replace(/\s+/g, ' ');
    if (v.includes('%')) pct++;
    else if (v.includes('var(')) cssvar++;
    const parts = v.split(/\s+/);
    if (parts.length === 1) single++;
    else { multi++; multiSamples.set(v, (multiSamples.get(v) || 0) + 1); }
  }
  // 动画里到底动了哪些属性
  for (const m of s.matchAll(/@keyframes\s+[A-Za-z0-9_-]+\s*\{/g)) {
    const seg = s.slice(m.index, m.index + 900);
    for (const p of seg.matchAll(/(?:^|[\s;{])(transform|opacity|width|height|background|border|color|left|top|right|bottom|filter|box-shadow|max-height)\s*:/g)) {
      animProps.set(p[1], (animProps.get(p[1]) || 0) + 1);
    }
  }
}
console.log('border-radius: 单值', single, '| 多值(多角)', multi, '| 含%', pct, '| 含var()', cssvar);
console.log('\n多角圆角样例:');
for (const [v, c] of [...multiSamples.entries()].sort((a, b) => b[1] - a[1]).slice(0, 15)) console.log(`  ${String(c).padStart(4)}x  ${v}`);
console.log('\n@keyframes 里实际动画的属性:');
for (const [k, v] of [...animProps.entries()].sort((a, b) => b[1] - a[1])) console.log(`  ${String(v).padStart(5)}x  ${k}`);
