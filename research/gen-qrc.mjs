// 生成 resources.qrc（qml 全部文件 + 312 个图标）
import fs from 'node:fs';
import path from 'node:path';

const ROOT = 'D:/Dev/TightNCM';
const out = [];
out.push('<!-- 自动生成，请勿手改 —— 由 research/gen-qrc.mjs 产出 -->');
out.push('<RCC>');

// ── QML ──────────────────────────────────────────────
const qmlFiles = [];
(function walk(d) {
  for (const e of fs.readdirSync(d, { withFileTypes: true })) {
    const p = path.join(d, e.name);
    if (e.isDirectory()) walk(p);
    else if (e.name.endsWith('.qml') || e.name === 'qmldir' || e.name.endsWith('.js')) qmlFiles.push(path.relative(ROOT, p).split(path.sep).join('/'));
  }
})(path.join(ROOT, 'qml'));
qmlFiles.sort();
out.push('  <qresource prefix="/">');
for (const f of qmlFiles) out.push(`    <file>${f}</file>`);
out.push('  </qresource>');

// ── 图标 ─────────────────────────────────────────────
const ICON_DIR = path.join(ROOT, 'assets/icons-svg');
let svgFiles = [];
if (fs.existsSync(ICON_DIR)) svgFiles = fs.readdirSync(ICON_DIR).filter((f) => f.endsWith('.svg')).sort();
out.push('  <qresource prefix="/icons">');
for (const f of svgFiles) out.push(`    <file alias="${f}">assets/icons-svg/${f}</file>`);
out.push('  </qresource>');

// ── 字体（可选） ─────────────────────────────────────
const FONT_DIR = path.join(ROOT, 'assets/fonts');
let fontFiles = [];
if (fs.existsSync(FONT_DIR)) fontFiles = fs.readdirSync(FONT_DIR).filter((f) => /\.(ttf|otf|ttc)$/i.test(f)).sort();
if (fontFiles.length) {
  out.push('  <qresource prefix="/fonts">');
  for (const f of fontFiles) out.push(`    <file alias="${f}">assets/fonts/${f}</file>`);
  out.push('  </qresource>');
}

out.push('</RCC>');
fs.writeFileSync(path.join(ROOT, 'resources.qrc'), out.join('\n') + '\n');

console.log(`resources.qrc 已生成:`);
console.log(`  QML/其它  ${qmlFiles.length} 个`);
console.log(`  SVG 图标  ${svgFiles.length} 个`);
console.log(`  字体      ${fontFiles.length} 个`);
console.log('\nQML 文件清单:');
for (const f of qmlFiles) console.log('  ', f);
