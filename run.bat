@echo off
REM ============================================================
REM  TightNCM build + run  (ASCII only - see build.bat note)
REM
REM  Usage:
REM    run.bat              build if needed, then launch
REM    run.bat rebuild      force a rebuild, then launch
REM    run.bat console      build a console version, then launch it
REM ============================================================
setlocal

set "ROOT=%~dp0."
set "EXE=%ROOT%\build\TightNCM.exe"

set "NEED_BUILD=0"
if /i "%~1"=="rebuild" set "NEED_BUILD=1"
if /i "%~1"=="console" set "NEED_BUILD=1"
if not exist "%EXE%" set "NEED_BUILD=1"

if "%NEED_BUILD%"=="1" (
    call "%ROOT%\build.bat" %1
    if errorlevel 1 exit /b 1
) else (
    echo [run] using existing build, pass "rebuild" to force a rebuild
)

echo [run] starting %EXE%
call "%ROOT%\tools\dev-run.bat"
endlocal
