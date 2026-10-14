"""放大截图的局部区域，便于逐像素核对。

用法: python tools/crop.py <png> <x> <y> <w> <h> [scale] [out]
默认输出到 build/crop.png
"""
import sys
from PIL import Image

src = sys.argv[1]
x, y, w, h = (int(v) for v in sys.argv[2:6])
scale = int(sys.argv[6]) if len(sys.argv) > 6 else 4
out = sys.argv[7] if len(sys.argv) > 7 else "build/crop.png"

im = Image.open(src).convert("RGB")
box = im.crop((x, y, x + w, y + h))
box = box.resize((box.width * scale, box.height * scale), Image.NEAREST)
box.save(out)
print(f"{src} crop=({x},{y},{w},{h}) scale={scale} -> {out} {box.size}")
