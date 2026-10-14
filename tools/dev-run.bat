@echo off
REM ============================================================
REM  TightNCM dev runner  (ASCII only - see build.bat note)
REM
REM  dev-run.bat                      normal windowed launch
REM  dev-run.bat --screenshot o.png   offscreen render + grab
REM
REM  Extra env you may want:
REM    QT_OPENGL=angle | desktop | software
REM    TIGHTNCM_DUMP_TREE=1         dump the QML scene tree (layout debug)
REM    TIGHTNCM_SHOT_DELAY_MS=3000  wait longer before grabbing
REM ============================================================
setlocal

set "QTDIR=D:\Qt\5.15.2\mingw81_64"
set "MINGW=D:\Qt\Tools\mingw810_64"
set "PATH=%QTDIR%\bin;%MINGW%\bin;%PATH%"
REM Use the deployed QML module tree (build\qml). Mixing it with Qt's own qml
REM directory breaks module resolution with "type 'X' is not a type".
set "QML2_IMPORT_PATH=%~dp0..\build\qml"
REM Default renderer: software raster (NOT angle).
REM   angle  -> ~290MB private bytes at 1280x800 logged in
REM   software -> ~99MB
REM This line used to force QT_OPENGL=angle, which is why the app looked like
REM it "still eats 200+MB" even after main.cpp switched the default to software.
REM Keep it empty unless the caller asks for a GPU backend.
if "%QT_OPENGL%"=="" if "%QT_QUICK_BACKEND%"=="" set "QT_QUICK_BACKEND=software"

cd /d "%~dp0..\build"
if not exist TightNCM.exe (
    echo [ERROR] TightNCM.exe not found. Run build.bat first.
    exit /b 1
)

TightNCM.exe %*
set RC=%ERRORLEVEL%
endlocal & exit /b %RC%
