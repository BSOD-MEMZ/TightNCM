"""审计：QML 里引用到的图标名，是否都有对应的 assets/icons-svg/ncm_<name>.svg

缺失的图标在界面上就是「不显示」或「显示错东西」，是回归的高发区。
用法: python tools/check-icons.py
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ICON_DIR = os.path.join(ROOT, "assets", "icons-svg")
QML_DIR = os.path.join(ROOT, "qml")

# name: "xxx"  /  iconName: "xxx"  /  property string xxxIcon: "xxx"
# 以及三目表达式里出现的字符串（只取形如标识符的短串）
NAME_RE = re.compile(r'\b(?:name|iconName|modeIcon|volumeIcon|quality|icon)\s*:\s*([^,\n]+)')


def collect_names(text):
    out = set()
    for expr in NAME_RE.findall(text):
        for lit in re.findall(r'"([A-Za-z0-9_]+)"', expr):
            out.add(lit)
    return out


def main():
    have = {
        f[len("ncm_"):-len(".svg")]
        for f in os.listdir(ICON_DIR)
        if f.startswith("ncm_") and f.endswith(".svg")
    }
    # 空文件（不含任何图形元素）也算缺失
    empty = set()
    for f in os.listdir(ICON_DIR):
        if not (f.startswith("ncm_") and f.endswith(".svg")):
            continue
        s = open(os.path.join(ICON_DIR, f), encoding="utf-8", errors="replace").read()
        if not re.search(r"<(path|circle|rect|polygon|polyline|ellipse|line)\b", s):
            empty.add(f[len("ncm_"):-len(".svg")])

    used = set()
    for dirpath, _dirs, files in os.walk(QML_DIR):
        for f in files:
            if f.endswith(".qml"):
                used |= collect_names(open(os.path.join(dirpath, f), encoding="utf-8").read())

    missing = sorted(n for n in used if n not in have and n != "")
    blank = sorted(n for n in used if n in empty)

    print("图标总数: %d" % len(have))
    print("QML 引用的图标名: %d" % len(used))
    print()
    if missing:
        print("!! 缺失（没有对应 svg，界面上会整块不画）: %d" % len(missing))
        for n in missing:
            print("   ", n)
    else:
        print("缺失图标: 无")
    print()
    if blank:
        print("!! 空图标（文件存在但没有图形元素）: %d" % len(blank))
        for n in blank:
            print("   ", n)
    else:
        print("空图标: 无")
    print()
    unused = sorted(have - used)
    print("未被引用（仅提示）: %d 个，例如 %s" % (len(unused), ", ".join(unused[:12])))
    return 1 if (missing or blank) else 0


if __name__ == "__main__":
    sys.exit(main())
