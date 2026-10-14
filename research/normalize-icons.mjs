// 规范化图标 SVG：
//   1) 去掉根节点的 width="1em" height="1em"（会让 SVG 只渲染 12px）
//   2) 统一 fill：显式颜色 → currentColor；没写 fill → currentColor；fill="none" 保留
//   3) 多色图标（logo 等）单独处理
import fs from 'node:fs';
import path from 'node:path';

const DIR = 'D:/Dev/TightNCM/assets/icons-svg';
const files = fs.readdirSync(DIR).filter((f) => f.endsWith('.svg'));

// 需要保留多色的图标：{ 选择器 -> 颜色 }，按出现顺序赋值
const MULTI = {
  // 官方 logo：红底 + 白色云朵
  'ncm_logo.svg': ['#FC3D49', '#FFFFFF'],
};

const SHAPES = 'path|circle|rect|ellipse|polygon|polyline|line';

// ── SVG path 包围盒 ─────────────────────────────────────────
// 为什么需要它：提取器是「按注册点的 viewBox」配「按顺序抓到的 path」，
// 有时候两者根本不是一个坐标系 —— 例如 ncm_next.svg 的 viewBox 是 24×24，
// 路径坐标却在 45~57，画出来整个跑到可视区外面，表现就是**图标看不见**
// （播放栏的「下一首」就是这么消失的）。
// 这里按真实几何算包围盒，超出 viewBox 就把它撑开。
// 圆弧只取端点近似（会略微低估），够用。
function pathBBox(d) {
  const toks = d.match(/[MmLlHhVvCcSsQqTtAaZz]|-?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?/g);
  if (!toks) return null;
  let i = 0, cx = 0, cy = 0, sx = 0, sy = 0, cmd = '';
  let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
  const add = (x, y) => {
    if (!Number.isFinite(x) || !Number.isFinite(y)) return;
    if (x < minX) minX = x;
    if (y < minY) minY = y;
    if (x > maxX) maxX = x;
    if (y > maxY) maxY = y;
  };
  const num = () => parseFloat(toks[i++]);
  const isRel = (c) => c === c.toLowerCase();
  while (i < toks.length) {
    if (/[A-Za-z]/.test(toks[i])) { cmd = toks[i++]; if (i >= toks.length) break; }
    const r = isRel(cmd);
    const C = cmd.toUpperCase();
    const ox = cx, oy = cy;
    if (C === 'M' || C === 'L' || C === 'T') {
      const x = num(), y = num();
      cx = r ? ox + x : x; cy = r ? oy + y : y;
      if (C === 'M') { sx = cx; sy = cy; }
      add(cx, cy);
    } else if (C === 'H') {
      const x = num(); cx = r ? ox + x : x; add(cx, cy);
    } else if (C === 'V') {
      const y = num(); cy = r ? oy + y : y; add(cx, cy);
    } else if (C === 'C' || C === 'S' || C === 'Q') {
      const n = C === 'C' ? 6 : 4;
      const a = [];
      for (let k = 0; k < n; ++k) a.push(num());
      for (let k = 0; k < n - 2; k += 2) add(r ? ox + a[k] : a[k], r ? oy + a[k + 1] : a[k + 1]);
      cx = r ? ox + a[n - 2] : a[n - 2];
      cy = r ? oy + a[n - 1] : a[n - 1];
      add(cx, cy);
    } else if (C === 'A') {
      num(); num(); num(); num(); num();
      const x = num(), y = num();
      cx = r ? ox + x : x; cy = r ? oy + y : y;
      add(cx, cy);
    } else if (C === 'Z') {
      cx = sx; cy = sy; add(cx, cy);
    } else {
      i++;   // 认不出来的指令，跳过，别死循环
    }
  }
  if (!Number.isFinite(minX)) return null;
  return { minX, minY, maxX, maxY };
}

// 元素级包围盒（path / circle / rect / ellipse / line / polygon）
function shapeBBox(tag, attrs) {
  const num = (k) => {
    const r = attrs.match(new RegExp(`\\b${k}="([\\d.eE+-]+)"`));
    return r ? Number(r[1]) : null;
  };
  if (tag === 'path') {
    const d = (attrs.match(/\bd="([^"]*)"/) || [])[1];
    return d ? pathBBox(d) : null;
  }
  if (tag === 'circle') {
    const cx = num('cx'), cy = num('cy'), r = num('r');
    return (cx != null && cy != null && r != null)
      ? { minX: cx - r, minY: cy - r, maxX: cx + r, maxY: cy + r } : null;
  }
  if (tag === 'ellipse') {
    const cx = num('cx'), cy = num('cy'), rx = num('rx'), ry = num('ry');
    return (cx != null && cy != null && rx != null && ry != null)
      ? { minX: cx - rx, minY: cy - ry, maxX: cx + rx, maxY: cy + ry } : null;
  }
  if (tag === 'line') {
    const x1 = num('x1'), y1 = num('y1'), x2 = num('x2'), y2 = num('y2');
    if (x1 == null || y1 == null || x2 == null || y2 == null) return null;
    return { minX: Math.min(x1, x2), minY: Math.min(y1, y2), maxX: Math.max(x1, x2), maxY: Math.max(y1, y2) };
  }
  if (tag === 'rect') {
    const x = num('x') ?? 0, y = num('y') ?? 0, w = num('width'), h = num('height');
    return (w != null && h != null) ? { minX: x, minY: y, maxX: x + w, maxY: y + h } : null;
  }
  if (tag === 'polygon' || tag === 'polyline') {
    const pts = (attrs.match(/\bpoints="([^"]*)"/) || [])[1];
    if (!pts) return null;
    const v = pts.match(/-?(?:\d+\.?\d*|\.\d+)/g);
    if (!v || v.length < 4) return null;
    const xs = [], ys = [];
    for (let k = 0; k + 1 < v.length; k += 2) { xs.push(+v[k]); ys.push(+v[k + 1]); }
    return { minX: Math.min(...xs), minY: Math.min(...ys), maxX: Math.max(...xs), maxY: Math.max(...ys) };
  }
  return null;
}

let refit = [];

let n = 0, fixed = 0;
for (const f of files) {
  let s = fs.readFileSync(path.join(DIR, f), 'utf8');
  const before = s;

  // 1) 根节点清理
  s = s.replace(/<svg\b[^>]*>/, (tag) => {
    let t = tag;
    t = t.replace(/\s+width="[^"]*"/g, '');
    t = t.replace(/\s+height="[^"]*"/g, '');
    t = t.replace(/\s+fill="none"/g, '');
    // 保证有 xmlns 和 viewBox
    if (!/\sxmlns=/.test(t)) t = t.replace('<svg', '<svg xmlns="http://www.w3.org/2000/svg"');
    return t;
  });

  // 2) 形状元素统一 fill
  const fixes = [];
  let out = s.replace(new RegExp(`<(${SHAPES})\\b([^>]*?)(/?)>`, 'g'), (m, tag, attrs, selfClose) => {
    const isNone = /\bfill="none"/.test(attrs);
    let a = attrs.replace(/\s+fill="[^"]*"/g, '');
    if (!isNone) a += ' fill="currentColor"';
    if (selfClose !== '/') { /* 闭合标签由原文本保留 */ }
    fixes.push(m);
    return `<${tag}${a}${selfClose}>`;
  });
  s = out;

  // 2.5) 删掉「铺满整块画布的 rect」
  //
  // 提取器在扒 DOM 时，会把 <defs><clipPath><rect .../></clipPath></defs> 里的
  // 那个遮罩 rect 提到根层级。它在 <defs> 里时不参与渲染（没问题），一旦提到根层级
  // 就会被当成实心方块画出来 —— dislike / volume / like 等 35 个图标都中了这一枪
  // （表现就是图标变成一块纯色方块）。
  // 这里只删「根层级 + 正好等于 viewBox」的 rect，<defs> 内的原样保留。
  {
    const vb = (s.match(/viewBox="([^"]+)"/) || [, '0 0 24 24'])[1].split(/[\s,]+/).map(Number);
    const [vx, vy, vw, vh] = vb;
    const defsBlocks = [];
    s = s.replace(/<defs[\s\S]*?<\/defs>/g, (m) => {
      defsBlocks.push(m);
      return `\u0000DEFS${defsBlocks.length - 1}\u0000`;
    });
    s = s.replace(/<rect\b[^>]*?\/>/g, (m) => {
      const num = (k) => {
        const r = m.match(new RegExp(`\\b${k}="([\\d.-]+)"`));
        return r ? Number(r[1]) : null;
      };
      const x = num('x'), y = num('y'), w = num('width'), h = num('height');
      if (x === vx && y === vy && w === vw && h === vh) return '';
      return m;
    });
    s = s.replace(/\u0000DEFS(\d+)\u0000/g, (_, i) => defsBlocks[+i]);
  }

  // 2.7) viewBox 自动适配
  // 路径坐标超出 viewBox 的图标会被裁掉/画到画布外（= 完全看不见）。
  // 这里按真实几何把 viewBox 撑开，让图形完整落在画布内。
  {
    const m = s.match(/viewBox="([^"]+)"/);
    if (m) {
      const [vx, vy, vw, vh] = m[1].split(/[\s,]+/).map(Number);
      let box = null;
      const merge = (b) => {
        if (!b) return;
        box = box
          ? { minX: Math.min(box.minX, b.minX), minY: Math.min(box.minY, b.minY),
              maxX: Math.max(box.maxX, b.maxX), maxY: Math.max(box.maxY, b.maxY) }
          : b;
      };
      const body = s.replace(/<defs[\s\S]*?<\/defs>/g, '');
      for (const g of body.matchAll(new RegExp(`<(${SHAPES})\\b([^>]*?)/?>`, 'g')))
        merge(shapeBBox(g[1], g[2]));

      if (box && Number.isFinite(box.minX)) {
        // 只在「明显溢出」时改。
        // 阈值取 1.5×：留白/轻微出血都是官方设计的一部分（back 这类图标本来就故意
        // 让图形贴近甚至微微出框），只有像 ncm_next 那种「坐标在 45~57 而画布只有 24」
        // 的才是真的配错了坐标系、会被整个裁掉。
        const over = box.maxX > vx + vw * 1.5 || box.maxY > vy + vh * 1.5
                  || box.minX < vx - vw * 0.5 || box.minY < vy - vh * 0.5;
        if (over) {
          const pad = Math.max(vw, vh) * 0.02;
          const nx = +(box.minX - pad).toFixed(2), ny = +(box.minY - pad).toFixed(2);
          const nw = +(box.maxX - box.minX + pad * 2).toFixed(2);
          const nh = +(box.maxY - box.minY + pad * 2).toFixed(2);
          s = s.replace(/viewBox="[^"]+"/, `viewBox="${nx} ${ny} ${nw} ${nh}"`);
          refit.push(`${f}: ${m[1]} -> ${nx} ${ny} ${nw} ${nh}`);
        }
      }
    }
  }

  // 3) 多色特例
  if (MULTI[f]) {
    let i = 0;
    const colors = MULTI[f];
    // ⚠️ 必须把「自闭合的 `/`」单独捕获再拼回去。
    // 之前写成 `<${tag}${attrs}>`，attrs 里带着那个 `/`，
    // 结果生成 `<circle ... / fill="#FC3D49">` —— 不是合法 XML，
    // 整张 SVG 解析失败（logo 直接不显示）。
    s = s.replace(new RegExp(`<(${SHAPES})\\b([^>]*?)(/?)>`, 'g'), (m, tag, attrs, selfClose) => {
      const c = colors[Math.min(i, colors.length - 1)];
      i++;
      const clean = attrs.replace(/\s+fill="[^"]*"/g, '');
      return `<${tag}${clean} fill="${c}"${selfClose}>`;
    });
  }

  if (s !== before) { fs.writeFileSync(path.join(DIR, f), s, 'utf8'); fixed++; }
  n++;
}
console.log(`处理 ${n} 个图标，修改 ${fixed} 个`);
if (refit.length) {
  console.log(`viewBox 自动适配 ${refit.length} 个（路径坐标原本超出画布，会被裁掉）：`);
  for (const r of refit) console.log('   ' + r);
}

// 自检：统计还有多少形状没有 fill
let noFill = 0, total = 0;
for (const f of files) {
  const s = fs.readFileSync(path.join(DIR, f), 'utf8');
  for (const m of s.matchAll(new RegExp(`<(${SHAPES})\\b([^>]*?)>`, 'g'))) {
    total++;
    if (!/\bfill=/.test(m[2])) noFill++;
  }
}
console.log(`形状元素 ${total} 个，缺 fill 的 ${noFill} 个`);

// 自检 2：清理后是否还有「只有 rect、没有任何路径」的图标（多半是提取时丢了图形）
let empty = [];
for (const f of files) {
  let s = fs.readFileSync(path.join(DIR, f), 'utf8');
  s = s.replace(/<defs[\s\S]*?<\/defs>/g, '');
  if (!/<(path|circle|ellipse|polygon|polyline)\b/.test(s)) empty.push(f);
}
console.log(`可疑（无路径图形，只剩 rect）的图标 ${empty.length} 个: ${empty.join(' ')}`);

// 抽样
for (const f of ['ncm_logo.svg', 'ncm_title.svg', 'ncm_vip.svg', 'ncm_sq.svg', 'ncm_play2.svg']) {
  const p = path.join(DIR, f);
  if (!fs.existsSync(p)) continue;
  console.log('\n---', f, fs.statSync(p).size, 'bytes');
  console.log(fs.readFileSync(p, 'utf8').slice(0, 260));
}
