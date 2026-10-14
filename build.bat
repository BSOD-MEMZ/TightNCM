@echo off
REM ============================================================
REM  TightNCM one-click build
REM
REM  ASCII ONLY - THIS IS NOT OPTIONAL. cmd.exe reads .bat files using
REM  the OEM codepage; any non-ASCII byte in a comment corrupts parsing
REM  and silently breaks the rest of the script (seen twice now).
REM
REM  Toolchain installed by setup-env.bat:
REM    Qt 5.15.2 (mingw81_64)   D:\Qt\5.15.2\mingw81_64
REM    MinGW 8.1.0 (x86_64)     D:\Qt\Tools\mingw810_64
REM    cmake / ninja            %TOOLS%
REM
REM  Usage:
REM    build.bat            release build (no console window)
REM    build.bat console    build with a console (shows QML errors live)
REM ============================================================
setlocal

set "QTDIR=D:\Qt\5.15.2\mingw81_64"
set "MINGW=D:\Qt\Tools\mingw810_64"
set "TOOLS=C:\Users\Miku\.workbuddy\binaries\python\envs\qt-tools\Scripts"
set "ROOT=%~dp0."
set "BUILD=%ROOT%\build"

if not exist "%QTDIR%\bin\qmake.exe" (
    echo [ERROR] Qt not found at %QTDIR%
    echo         Run setup-env.bat first.
    exit /b 1
)
if not exist "%MINGW%\bin\g++.exe" (
    echo [ERROR] MinGW not found at %MINGW%
    echo         Run setup-env.bat first.
    exit /b 1
)

set "CONSOLE_OPT=OFF"
if /i "%~1"=="console" set "CONSOLE_OPT=ON"

set "PATH=%QTDIR%\bin;%MINGW%\bin;%TOOLS%;%PATH%"

echo ============================================================
echo  Qt      : %QTDIR%
echo  MinGW   : %MINGW%
echo  Console : %CONSOLE_OPT%
echo ============================================================

REM NOTE: pass CMAKE_MAKE_PROGRAM explicitly - ninja lives outside the
REM default search path here, otherwise cmake finds no generator.
"%TOOLS%\cmake.exe" -S "%ROOT%" -B "%BUILD%" -G Ninja ^
    -DCMAKE_MAKE_PROGRAM="%TOOLS%\ninja.exe" ^
    -DCMAKE_BUILD_TYPE=Release ^
    -DCMAKE_PREFIX_PATH="%QTDIR%" ^
    -DCMAKE_CXX_COMPILER="%MINGW%\bin\g++.exe" ^
    -DTIGHTNCM_CONSOLE=%CONSOLE_OPT%
if errorlevel 1 ( echo. & echo [FAILED] cmake configure & exit /b 1 )

"%TOOLS%\cmake.exe" --build "%BUILD%" --parallel
if errorlevel 1 ( echo. & echo [FAILED] compile & exit /b 1 )

REM ---- MinGW runtime: launching the exe from Git Bash does not apply
REM ---- PATH to native DLL resolution, so put them next to the exe.
for %%F in (libstdc++-6.dll libgcc_s_seh-1.dll libwinpthread-1.dll) do (
    if exist "%MINGW%\bin\%%F" copy /y "%MINGW%\bin\%%F" "%BUILD%\%%F" >nul
)

REM ---- Deployment: do NOT rely on windeployqt.
REM ---- On this Qt install windeployqt aborts early with
REM ---- "Unable to find the platform plugin", so parts of the DLL set and
REM ---- plugin folders never get collected (it missed Qt5Multimedia).
REM ---- Explicit list instead, deterministic.
for %%F in (
    Qt5Core.dll Qt5Gui.dll Qt5Qml.dll Qt5QmlModels.dll Qt5Quick.dll
    Qt5Network.dll Qt5Svg.dll Qt5Widgets.dll Qt5Multimedia.dll
    Qt5QuickControls2.dll Qt5QuickTemplates2.dll Qt5QuickShapes.dll
    Qt5QmlWorkerScript.dll Qt5MultimediaQuick.dll
    libEGL.dll libGLESv2.dll opengl32sw.dll D3Dcompiler_47.dll
) do (
    if exist "%QTDIR%\bin\%%F" copy /y "%QTDIR%\bin\%%F" "%BUILD%\" >nul
)

REM ---- Qt's own QML modules (27 MB) must sit next to the exe too.
REM ---- Our application QML lives inside the .qrc, but QtQuick /
REM ---- QtQuick.Controls / QtQuick.Shapes / QtGraphicalEffects are resolved
REM ---- through the QML import path, which for a deployed app is <exedir>\qml.
REM ---- Without this the app only runs when Qt's bin is on PATH; launched
REM ---- standalone it prints "rootObjects is EMPTY -> QML failed".
robocopy "%QTDIR%\qml" "%BUILD%\qml" /E /NFL /NDL /NJH /NJS /NP /R:1 /W:1 >nul

REM ---- OpenSSL 1.1.x: Qt5Network needs it for HTTPS. Without these two
REM ---- DLLs QSslSocket::supportsSsl() returns 0 and every https request
REM ---- fails with "TLS initialization failed". Kept in assets\runtime\.
if exist "%ROOT%\assets\runtime\libssl-1_1-x64.dll" (
    copy /y "%ROOT%\assets\runtime\libssl-1_1-x64.dll" "%BUILD%\" >nul
    copy /y "%ROOT%\assets\runtime\libcrypto-1_1-x64.dll" "%BUILD%\" >nul
) else (
    echo [WARN] OpenSSL DLLs missing from assets\runtime\ - HTTPS will not work
)

REM ---- Plugin folders. Use robocopy: xcopy blocks on an interactive
REM ---- prompt when the destination already exists.
for %%D in (platforms imageformats iconengines mediaservice audio styles tls) do (
    if exist "%QTDIR%\plugins\%%D" (
        robocopy "%QTDIR%\plugins\%%D" "%BUILD%\%%D" /E /NFL /NDL /NJH /NJS /NP /R:1 /W:1 >nul
    )
)

echo.
echo ============================================================
echo  OK: %BUILD%\TightNCM.exe
echo  Verify render  : tools\verify.bat
echo  Run with window: tools\dev-run.bat
echo ============================================================
endlocal
