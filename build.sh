#!/usr/bin/env bash
# ============================================================
#  TightNCM 构建脚本（Git Bash / MSYS）
#  Windows 上更推荐直接跑 build.bat
# ============================================================
set -e

QTDIR="D:/Qt/5.15.2/mingw81_64"
MINGW="D:/Qt/Tools/mingw810_64"
TOOLS="C:/Users/Miku/.workbuddy/binaries/python/envs/qt-tools/Scripts"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

[ -f "$QTDIR/bin/qmake.exe" ] || { echo "[错误] 找不到 Qt: $QTDIR"; exit 1; }
[ -f "$MINGW/bin/g++.exe" ]  || { echo "[错误] 找不到 MinGW: $MINGW"; exit 1; }

export PATH="$MINGW/bin:$PATH"

# 注意：必须显式给 CMAKE_MAKE_PROGRAM，ninja 不在默认搜索路径里
"$TOOLS/cmake.exe" -S "$ROOT" -B "$ROOT/build" -G Ninja \
    -DCMAKE_MAKE_PROGRAM="$TOOLS/ninja.exe" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_PREFIX_PATH="$QTDIR" \
    -DCMAKE_CXX_COMPILER="$MINGW/bin/g++.exe"

"$TOOLS/cmake.exe" --build "$ROOT/build" --parallel

# 把 MinGW 运行库拷到 exe 旁边：从 Git Bash 直接跑 exe 时，
# PATH 对原生 DLL 解析不生效
for dll in libstdc++-6.dll libgcc_s_seh-1.dll libwinpthread-1.dll; do
    [ -f "$MINGW/bin/$dll" ] && cp -f "$MINGW/bin/$dll" "$ROOT/build/" || true
done

echo
echo "构建完成: $ROOT/build/TightNCM.exe"
echo "渲染验证: cmd //c tools\\verify.bat"
