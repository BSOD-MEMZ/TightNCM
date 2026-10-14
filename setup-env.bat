@echo off
REM ============================================================
REM  TightNCM environment setup  (ASCII only - see build.bat note)
REM
REM  Installs, without needing a Qt account:
REM    1. Python venv + aqtinstall + cmake(3.31.6) + ninja
REM    2. Qt 5.15.2 win64_mingw81      -> D:\Qt\5.15.2\mingw81_64
REM    3. MinGW 8.1.0 64bit            -> D:\Qt\Tools\mingw810_64
REM
REM  Why Qt 5.15: Qt 6 dropped Windows 7 support (min Win10 1809).
REM  Why cmake 3.31: cmake 4.x rejects Qt5's old cmake_minimum_required.
REM  Why download.qt.io: the tuna mirror serves corrupt 5.15.2 archives
REM      (checksum mismatch - it returns an HTML error page instead).
REM ============================================================
setlocal

set "PY=C:\Users\Miku\.workbuddy\binaries\python\versions\3.13.12\python.exe"
set "VENV=C:\Users\Miku\.workbuddy\binaries\python\envs\qt-tools"
set "PIP=%VENV%\Scripts\python.exe"
set "BASE=https://download.qt.io"
set "QTDEST=D:\Qt"

echo ============================================================
echo  [1/3] Python toolchain
echo ============================================================
if not exist "%PIP%" ( "%PY%" -m venv "%VENV%" || exit /b 1 )

REM The global pip config points at a mirror unreachable from here,
REM so pin the official index explicitly.
"%PIP%" -m pip install --quiet --upgrade pip ^
    --index-url https://pypi.org/simple --trusted-host pypi.org --trusted-host files.pythonhosted.org || exit /b 1

"%PIP%" -m pip install --quiet ^
    --index-url https://pypi.org/simple --trusted-host pypi.org --trusted-host files.pythonhosted.org ^
    aqtinstall "cmake==3.31.6" ninja || exit /b 1

"%VENV%\Scripts\cmake.exe" --version | findstr /b "cmake"

echo.
echo ============================================================
echo  [2/3] Qt 5.15.2 (win64_mingw81)
echo ============================================================
if exist "%QTDEST%\5.15.2\mingw81_64\bin\qmake.exe" (
    echo   already installed, skipping
) else (
    "%PIP%" -m aqt install-qt windows desktop 5.15.2 win64_mingw81 -O "%QTDEST%" --base "%BASE%" --timeout 60 || exit /b 1
)

echo.
echo ============================================================
echo  [3/3] MinGW 8.1.0 64bit
echo ============================================================
if exist "%QTDEST%\Tools\mingw810_64\bin\g++.exe" (
    echo   already installed, skipping
) else (
    "%PIP%" -m aqt install-tool windows desktop tools_mingw81 qt.tools.win64_mingw810 -O "%QTDEST%" --base "%BASE%" --timeout 60 || exit /b 1
)

echo.
echo ============================================================
echo  Done. Next: build.bat
echo ============================================================
"%QTDEST%\5.15.2\mingw81_64\bin\qmake.exe" -v
"%QTDEST%\Tools\mingw810_64\bin\g++.exe" --version | findstr /b "g++"
endlocal
