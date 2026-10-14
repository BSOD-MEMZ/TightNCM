# -*- coding: utf-8 -*-
"""从场景树 dump 里检测「同一父级下子项纵向重叠」。

为什么需要它：本工程踩过一个坑 —— positioner（Column/Grid）在
「常驻页面 + visible 切换 + 数据后到」的结构下不重排，导致一批区块 y 全停在 0、
互相压在一起。肉眼看不出来（都叠在一起）但布局是坏的，所以用几何数据做客观判定。

用法：
    set TIGHTNCM_DUMP_TREE=1 && tools\\verify.bat --page <key>
    python tools/check-layout.py build/verify.log [可见页面类型名]
"""
import re
import sys
from collections import defaultdict

LINE = re.compile(
    r"^(?P<indent>\s*)(?P<cls>\S+)\s+xy\[(?P<x>-?[\d.]+),(?P<y>-?[\d.]+)\]\s+"
    r"(?P<w>[\d.]+)x(?P<h>-?[\d.]+)\s+scene\[(?P<sx>-?[\d.]+),(?P<sy>-?[\d.]+)\]\s*"
    r"vis=(?P<vis>\d)")

# 只有这些「块级」容器参与重叠判定 —— 小图标、绘制层天然会重叠
BLOCKY = ("CardGrid", "SectionTitle", "PlaylistHeader", "CmdTabs", "SongTableHeader",
          "PlaylistCard", "SongRow", "VStack", "QQuickColumn", "QQuickText",
          "HomePage", "ToplistPage", "FeaturedPage", "PodcastPage", "RecentPage",
          "SearchPage", "ArtistPage", "FmPage", "PlaylistDetailPage")


def parse(path):
    """返回 (全部节点, 可见页面根节点名)。节点为 dict。"""
    nodes = []
    stack = []
    roots = []
    inside = False
    visible_root = None
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        for raw in f:
            if "==== scene tree ====" in raw:
                inside = True
                continue
            if "==== end tree ====" in raw:
                break
            if not inside:
                continue
            m = LINE.match(raw.rstrip("\n"))
            if not m:
                continue
            depth = len(m.group("indent")) // 2
            n = {
                "cls": m.group("cls"), "depth": depth,
                "x": float(m.group("x")), "y": float(m.group("y")),
                "w": float(m.group("w")), "h": float(m.group("h")),
                "sy": float(m.group("sy")), "vis": int(m.group("vis")),
                "kids": [],
            }
            while stack and stack[-1]["depth"] >= depth:
                stack.pop()
            if stack:
                stack[-1]["kids"].append(n)
            else:
                roots.append(n)
            stack.append(n)
            nodes.append(n)

    # 找出「可见的页面根」：PageHost 的直接子项里 vis=1 的那个
    for n in nodes:
        if n["cls"].startswith("PageHost"):
            for k in n["kids"]:
                if k["vis"] == 1:
                    visible_root = k
    return roots, visible_root


def find_misplaced(node, out, path=""):
    """同一父级下：子项 h>0 却 y 完全相同（且不是并列），视为重叠。"""
    kids = [k for k in node["kids"] if k["h"] > 0 and k["vis"] == 1
            and any(k["cls"].startswith(b) for b in BLOCKY)]
    if len(kids) >= 2:
        byy = defaultdict(list)
        for k in kids:
            byy[round(k["y"], 1)].append(k)
        for y, group in byy.items():
            if len(group) >= 2:
                # 并列的兄弟（比如 Grid 里同一行的卡片）本来就同 y，
                # 只有 x 也相同才是真重叠
                byx = defaultdict(list)
                for k in group:
                    byx[round(k["x"], 1)].append(k)
                for x, gg in byx.items():
                    if len(gg) >= 2:
                        out.append(("%s/%s" % (path, node["cls"]), y, x,
                                    [g["cls"] for g in gg]))
    for k in node["kids"]:
        find_misplaced(k, out, path + "/" + node["cls"])


def find_collapsed(node, out, path=""):
    """检测「容器高度没包住自己的可见子项」。

    这条是为了 VStack 那个坑写的回归守卫：
    VStack 一度只把排位结果写进内部 host，**根节点自己的 height 恒为 0**，
    于是外层 ScrollColumn 排位时 `y += c.height` 每次加 0，
    所有 VStack 委托全落在同一个 y 上（区块整片重叠）。

    `find_misplaced` 抓不到它 —— 它只看「子项之间」是否同 (x,y)，
    而高度为 0 的容器会被 `k["h"] > 0` 直接过滤掉。
    """
    if "VStack" in node["cls"] or "ScrollColumn" in node["cls"]:
        kids = [k for k in node["kids"] if k["vis"] == 1]
        if kids:
            extent = max(k["y"] + k["h"] for k in kids)
            if extent > node["h"] + 0.5:
                out.append(("%s/%s" % (path, node["cls"]),
                            node["h"], extent,
                            [k["cls"] for k in kids[:4]]))
    for k in node["kids"]:
        find_collapsed(k, out, path + "/" + node["cls"])


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    log = sys.argv[1]
    roots, vis = parse(log)
    if not vis:
        print("没找到可见页面根；日志里可能没有场景树 dump")
        return 1

    name = vis["cls"].split("_")[0]
    print("可见页面: %s  尺寸 %.0fx%.0f" % (name, vis["w"], vis["h"]))

    # 统计各页面子树规模
    print("\n顶层子项:")
    for k in vis["kids"]:
        print("   %-30s xy[%.0f,%.0f] %.0fx%.0f vis=%d"
              % (k["cls"], k["x"], k["y"], k["w"], k["h"], k["vis"]))

    bad = []
    find_misplaced(vis, bad)
    print()
    if bad:
        print("!! 检测到 %d 处重叠：" % len(bad))
        for where, y, x, classes in bad[:12]:
            print("   %s  同位置 (y=%.0f, x=%.0f): %s" % (where, y, x, ", ".join(classes)))
        return 1

    collapsed = []
    find_collapsed(vis, collapsed)
    if collapsed:
        print("!! 检测到 %d 处容器高度没包住子项（堆叠会全部叠在同一 y）：" % len(collapsed))
        for where, h, extent, classes in collapsed[:12]:
            print("   %s  height=%.0f 但子项占到 %.0f：%s"
                  % (where, h, extent, ", ".join(classes)))
        return 1

    print("布局检查通过：可见页面的块级子项没有同位置重叠，堆叠容器高度也包住了子项")
    return 0


if __name__ == "__main__":
    sys.exit(main())
