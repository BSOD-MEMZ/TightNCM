// 扫描镜像目录里所有 js/css 中引用的外部资源
import fs from 'node:fs';
import path from 'node:path';

const root = process.argv[2] || 'D:/Dev/TightNCM/research/mirror';
const files = [];
(function walk(d) {
  for (const e of fs.readdirSync(d, { withFileTypes: true })) {
    const p = path.join(d, e.name);
    if (e.isDirectory()) walk(p);
    else if (/\.(js|css)$/.test(e.name)) files.push(p);
  }
})(root);

const hostCount = {};
const extCount = {};
const samples = {};
const all = new Map();
let total = 0;

for (const f of files) {
  const s = fs.readFileSync(f, 'utf8').split('\\/').join('/');
  const re = /[a-zA-Z0-9_./?=&%:@~-]{0,170}?\.(png|jpe?g|webp|gif|svg|woff2?|ttf|otf|wasm|mp3|mp4|json|css|js)/g;
  let m;
  while ((m = re.exec(s))) {
    let t = m[0];
    // 去掉明显的代码残留
    if (/[(){}[\]<>*+?^$|]/.test(t)) continue;
    const ext = m[1];
    total++;
    extCount[ext] = (extCount[ext] || 0) + 1;
    const hm = t.match(/^(?:https?:)?\/\/([a-z0-9.-]+)/i);
    const h = hm ? hm[1] : '(相对路径/orpheus://)';
    hostCount[h] = (hostCount[h] || 0) + 1;
    if (!samples[h]) samples[h] = [];
    if (samples[h].length < 4 && !samples[h].includes(t)) samples[h].push(t);
    all.set(t, (all.get(t) || 0) + 1);
  }
}

console.log('扫描', files.length, '个文件；资源引用命中', total, '次；去重', all.size, '条');
console.log('\n=== 主机分布 ===');
for (const [h, c] of Object.entries(hostCount).sort((a, b) => b[1] - a[1])) {
  console.log(String(c).padStart(6), h);
  for (const s of samples[h]) console.log('           ', s.slice(0, 150));
}
console.log('\n=== 后缀分布 ===');
for (const [e, c] of Object.entries(extCount).sort((a, b) => b[1] - a[1])) console.log(String(c).padStart(6), e);

// 导出清单
const out = path.join(root, '_assets.json');
fs.writeFileSync(out, JSON.stringify([...all.keys()].sort(), null, 2));
console.log('\n完整清单 ->', out);
