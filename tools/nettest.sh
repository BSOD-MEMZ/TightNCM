#!/usr/bin/env bash
# 编译并运行网络自检（确认 Qt 的 HTTPS 是否能工作）
# 用法: bash tools/nettest.sh
set -e
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
Q="D:/Qt/5.15.2/mingw81_64"
M="D:/Qt/Tools/mingw810_64"
OUT="$ROOT/build/nettest"

mkdir -p "$OUT"
export PATH="$M/bin:$PATH"

"$M/bin/g++.exe" -std=c++17 "$ROOT/tools/nettest.cpp" -o "$OUT/nettest.exe" \
    -I"$Q/include" -I"$Q/include/QtCore" -I"$Q/include/QtNetwork" -I"$Q/include/QtGui" \
    -L"$Q/lib" -lQt5Network -lQt5Core -lQt5Gui -lqtmain

for dll in libstdc++-6.dll libgcc_s_seh-1.dll libwinpthread-1.dll; do
    cp -f "$M/bin/$dll" "$OUT/" 2>/dev/null || true
done

cd "$OUT"
PATH="$Q/bin:$PATH" ./nettest.exe
