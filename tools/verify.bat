@echo off
REM ============================================================
REM  TightNCM headless render verification  (ASCII only)
REM
REM  Renders the QML shell off-screen -> build\shell-render.png
REM  and writes build\verify.log so the caller can read that file.
REM
REM  Two traps this script works around:
REM   1. Windows' "offscreen" Qt platform plugin cannot create an OpenGL
REM      context, so Qt Quick draws nothing there. Instead we use the real
REM      "windows" platform - the app itself puts its window off-screen
REM      when --screenshot is passed (see TNCScreenshotMode in Main.qml).
REM   2. A QML window created with visible:false never gets its contentItem
REM      sized, which collapses every anchor to 0. Hence the visible window.
REM ============================================================
setlocal

set "QTDIR=D:\Qt\5.15.2\mingw81_64"
set "MINGW=D:\Qt\Tools\mingw810_64"
set "ROOT=%~dp0.."
set "BUILD=%ROOT%\build"
set "LOG=%BUILD%\verify.log"

REM Optional: --page <key> renders a specific page and names the PNG after it,
REM so you can keep renders for several pages side by side.
REM --seed-demo is forwarded to the app: it fills the local play history so the
REM "recent" page has something to draw during automated verification.
set "PAGENAME="
if /i "%~1"=="--page" set "PAGENAME=%~2"
if defined PAGENAME (
    set "PNG=%BUILD%\render-%PAGENAME%.png"
) else (
    set "PNG=%BUILD%\shell-render.png"
)

set "PATH=%QTDIR%\bin;%MINGW%\bin;%PATH%"
REM Point the QML import path at the DEPLOYED module tree (build\qml), not at the
REM Qt installation. Having both in the path makes module resolution pick the
REM qmldir from one tree and the plugin from the other, which shows up as
REM "type 'Button' is not a type ... 'QtQuick.Controls' '2'" for every type.
set "QML2_IMPORT_PATH=%BUILD%\qml"
REM ANGLE (D3D) is the most reliable GL path here, and it is also what
REM Windows 7 machines end up using.
set "QT_OPENGL=angle"
REM Qt logs to OutputDebugString on Windows and loses them on redirect.
set "QT_FORCE_STDERR_LOGGING=1"

cd /d "%BUILD%"

echo ==== TightNCM render verify ==== > "%LOG%"
echo EXE       = %BUILD%\TightNCM.exe >> "%LOG%"
echo QT_OPENGL = %QT_OPENGL% >> "%LOG%"
echo ---------------------------------- >> "%LOG%"

if not exist "%BUILD%\TightNCM.exe" (
    echo [ERROR] TightNCM.exe not found. Run build.bat first. >> "%LOG%"
    type "%LOG%"
    endlocal & exit /b 1
)

if exist "%PNG%" del /q "%PNG%"

TightNCM.exe --screenshot "%PNG%" %* >> "%LOG%" 2>&1
set "RC=%ERRORLEVEL%"

echo ---------------------------------- >> "%LOG%"
echo EXITCODE = %RC% >> "%LOG%"
if exist "%PNG%" (
    echo PNG      = OK >> "%LOG%"
) else (
    echo PNG      = MISSING >> "%LOG%"
)

type "%LOG%"
endlocal & exit /b %RC%
