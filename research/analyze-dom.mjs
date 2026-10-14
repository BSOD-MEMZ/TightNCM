// 分析登录态 DOM：输出结构树 + 类名分布
import fs from 'node:fs';

const file = process.argv[2] || 'D:/Dev/TightNCM/research/snapshot/dom-loggedin.html';
const html = fs.readFileSync(file, 'utf8');

// 类名分布
const clsCount = new Map();
for (const m of html.matchAll(/class="([^"]+)"/g)) {
  for (const c of m[1].split(/\s+/).filter(Boolean)) clsCount.set(c, (clsCount.get(c) || 0) + 1);
}
console.log('=== 类名 top 40（共 ' + clsCount.size + ' 个） ===');
for (const [c, n] of [...clsCount.entries()].sort((a, b) => b[1] - a[1]).slice(0, 40)) console.log(String(n).padStart(5), c);

// 结构树（简化正则解析）
function tree(s, depth = 0, maxDepth = 4, out = [], state = { n: 0 }) {
  const re = /<(\/)?([a-zA-Z][a-zA-Z0-9-]*)((?:\s+[^>]*?)?)(\/)?>/g;
  let m;
  const stack = [];
  while ((m = re.exec(s))) {
    const [, close, tag, attrs, selfClose] = m;
    if (state.n > 900) return out;
    if (close) { stack.pop(); continue; }
    const cls = (attrs.match(/class="([^"]*)"/) || [, ''])[1];
    const id = (attrs.match(/id="([^"]*)"/) || [, ''])[1];
    const d = stack.length + depth;
    if (d <= maxDepth) {
      const label = [tag, id && '#' + id, cls && '.' + cls.split(/\s+/).join('.')].filter(Boolean).join('');
      if (!/^(script|style|link|meta|path|defs|g|circle|rect|line|polygon|use|svg)$/i.test(tag)) {
        out.push('  '.repeat(d) + label);
        state.n++;
      }
    }
    if (['script', 'style', 'link', 'meta', 'img', 'br', 'hr', 'input', 'source'].includes(tag.toLowerCase()) || selfClose) continue;
    stack.push(tag);
  }
  return out;
}

const bodyStart = html.indexOf('<body');
const body = html.slice(bodyStart, html.indexOf('</body>'));
const lines = tree(body, 0, 4);
console.log('\n=== 结构树（前 220 行） ===');
console.log(lines.slice(0, 220).join('\n'));
