# -*- coding: utf-8 -*-
"""逐页像素体检：确认内容区真的画出了东西（不靠肉眼看图）。

判定思路：
  * 侧栏 (0..204) / 顶栏 (0..72) / 播放栏 (720..800) 三块是固定外壳，各页都应存在。
  * 内容区 (204..1280, 72..720) 的「非背景像素占比」能反映这页有没有内容。
  * 品牌红 #FC3D49 / #FF3A3A 出现次数能确认红元素（播放键、选中态、标签）在不在。
  * 报告每页内容区的主色分布，便于发现「一片纯色 = 没渲染出来」。
"""
import sys
from collections import Counter
from PIL import Image

PAGES = ["home", "toplist", "featured", "artist", "album", "fm", "recent", "search", "podcast"]
DIR = "D:/Dev/TightNCM/build/pages"

BRAND = [(252, 61, 73), (255, 58, 58), (251, 59, 91)]


def near(c, ref, tol=26):
    return all(abs(c[i] - ref[i]) <= tol for i in range(3))


def probe(path):
    im = Image.open(path).convert("RGB")
    w, h = im.size
    px = im.load()

    # 内容区：每 3 像素采一次
    total = 0
    bg = None
    hist = Counter()
    brand_hits = 0
    lightish = 0
    x0, y0, x1, y1 = 204, 72, w, 720
    for y in range(y0, y1, 3):
        for x in range(x0, x1, 3):
            c = px[x, y]
            total += 1
            if bg is None:
                bg = c                       # 左上角那个点当作背景基准
            if near(c, bg if bg else c, 6):
                hist["__bg__"] = hist.get("__bg__", 0) + 1
            else:
                hist[c] += 1
                if sum(c) > 600:
                    lightish += 1
            for b in BRAND:
                if near(c, b):
                    brand_hits += 1
                    break

    bg_n = hist.pop("__bg__", 0)
    content_ratio = 1.0 - bg_n / max(1, total)
    top = hist.most_common(5)
    return {
        "size": (w, h),
        "content_ratio": content_ratio,
        "brand_hits": brand_hits,
        "lightish_ratio": lightish / max(1, total),
        "top_color": top,
    }


def main():
    print("%-10s %-11s %-9s %-8s %-9s %s" % ("page", "size", "content%", "brand", "light%", "top colors"))
    print("-" * 96)
    bad = []
    for p in PAGES:
        try:
            r = probe("%s/%s.png" % (DIR, p))
        except Exception as e:
            print("%-10s ERROR %s" % (p, e))
            bad.append(p)
            continue
        colors = "  ".join("%s x%d" % (c, n) for c, n in r["top_color"][:3])
        print("%-10s %-11s %-9.1f %-8d %-9.1f %s"
              % (p, "%dx%d" % r["size"], r["content_ratio"] * 100,
                 r["brand_hits"], r["lightish_ratio"] * 100, colors))
        if r["content_ratio"] < 0.008:
            bad.append(p)
    print()
    if bad:
        print("!! 内容区几乎全空（很可能是没渲染出来）:", " ".join(bad))
        return 1
    print("全部页面内容区都有实质内容")
    print("（说明：表格页的内容本来就稀疏 —— 大片行底色 + 稀疏文字/封面，")
    print("  所以 content% 低不等于坏；判定重叠请用 tools/check-layout.py）")
    return 0


if __name__ == "__main__":
    sys.exit(main())
