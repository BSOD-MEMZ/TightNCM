// 从 bundle 里导出全部 /api/ 端点，供对接参考
import fs from 'node:fs';
import path from 'node:path';

const ROOT = 'D:/Dev/TightNCM/research/mirror';
const VER = fs.readdirSync(ROOT).find((d) => /^[0-9a-f]{20,}_/.test(d));
const DIR = path.join(ROOT, VER, 'hybrid');

const eps = new Set();
for (const f of fs.readdirSync(DIR).filter((x) => x.endsWith('.js'))) {
  const s = fs.readFileSync(path.join(DIR, f), 'utf8');
  for (const m of s.matchAll(/["'`]\/api\/([a-zA-Z0-9_/\-{}.:]{2,80})["'`]/g))
    eps.add('/api/' + m[1].replace(/\/+$/, ''));
}

const list = [...eps].sort();
fs.writeFileSync('D:/Dev/TightNCM/research/api-endpoints.txt', list.join('\n') + '\n');
console.log('端点总数', list.length, '-> research/api-endpoints.txt\n');

const show = (label, re) => {
  const hit = list.filter((e) => re.test(e));
  console.log(`=== ${label} (${hit.length}) ===`);
  console.log(hit.slice(0, 22).join('\n'));
  console.log();
};
show('登录 / 账号', /login|logout|session|account|user\/(detail|playlist|record|subcount)/i);
show('歌曲 / 播放地址', /song|track|\/(url|lyric|scrobble|like|play)/i);
show('歌单', /playlist/i);
show('搜索', /search/i);
show('专辑 / 歌手 / MV', /album|artist|\/mv/i);
show('首页 / 推荐 / 私人FM', /homepage|recommend|personal|fm|daily|topplist|top\//i);
show('云盘 / 下载 / 收藏', /cloud|download|sublist|clouddisk/i);
