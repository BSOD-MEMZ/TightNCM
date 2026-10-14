// 从镜像 CSS 中提取指定 class 的完整规则（源 CSS，比运行时更准）
// 用法: node extract-rules.mjs <classA,classB,...>   或   node extract-rules.mjs --scan <关键词>
import fs from 'node:fs';
import path from 'node:path';

const ROOT = 'D:/Dev/TightNCM/research/mirror';
const VER = fs.readdirSync(ROOT).find((d) => /^[0-9a-f]{20,}_/.test(d));
const DIR = path.join(ROOT, VER, 'styles');
const files = fs.readdirSync(DIR).filter((f) => f.endsWith('.css'));

// 把所有 CSS 拼起来，并记录每段来自哪个文件
const chunks = files.map((f) => ({ f, s: fs.readFileSync(path.join(DIR, f), 'utf8') }));

/** 极简 CSS 解析：按 } 切顶层规则（本项目的 CSS 是编译产物，规则嵌套很少） */
function* rules(text, file) {
  // 先剥掉 @media 外壳：本文件里 @media 内层规则也一并展开（保留条件）
  let i = 0;
  const stack = [];
  let buf = '';
  while (i < text.length) {
    const ch = text[i];
    if (ch === '{') {
      const sel = buf.trim();
      buf = '';
      // 判断是不是 at-rule 容器
      if (/^@(media|supports|layer|container)/.test(sel)) { stack.push(sel); }
      else {
        // 找到匹配的 }
        let depth = 1, j = i + 1;
        while (j < text.length && depth > 0) { if (text[j] === '{') depth++; else if (text[j] === '}') depth--; j++; }
        const body = text.slice(i + 1, j - 1);
        yield { sel, body, cond: stack.join(' '), file };
        i = j - 1;
      }
    } else if (ch === '}') { stack.pop(); buf = ''; }
    else buf += ch;
    i++;
  }
}

const arg = process.argv[2] || '';
const scanMode = arg === '--scan';
const keys = scanMode
  ? [process.argv[3]]
  : arg.split(',').map((s) => s.trim()).filter(Boolean);

const hits = new Map(); // cls -> [{sel, body, cond, file}]
for (const { f, s } of chunks) {
  for (const r of rules(s, f)) {
    if (!r.sel || r.sel.startsWith('@')) continue;
    for (const k of keys) {
      if (r.sel.includes(k)) {
        if (!hits.has(k)) hits.set(k, []);
        hits.get(k).push(r);
      }
    }
  }
}

const pretty = (body) => body.split(';').map((d) => d.trim()).filter(Boolean).join(';\n      ');
const cond = (c) => (c ? `\n    /* in ${c} */` : '');

for (const k of keys) {
  const list = hits.get(k) || [];
  console.log(`\n${'='.repeat(78)}\n### ${k}   (${list.length} 条规则)`);
  for (const r of list) {
    console.log(`\n  ${r.sel}   [${r.file}]${cond(r.cond)}`);
    console.log('      ' + pretty(r.body));
  }
  if (!list.length) console.log('  (无匹配)');
}
