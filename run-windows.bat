@echo off
rem ===========================================================================
rem  Death by Slides - build the Windows app and play it.
rem
rem    run-windows.bat            release build (default)
rem    run-windows.bat debug      debug build, builds quicker
rem    run-windows.bat profile    profile build, for performance work
rem
rem  Double-clicking the file works too. For a hot-reload development loop use
rem  `flutter run -d windows` instead; this script produces a standalone build
rem  and launches it detached, the way a player would start the game.
rem ===========================================================================

setlocal
pushd "%~dp0"

set "BINARY=death_by_slides"

rem --- Pick the build configuration ------------------------------------------
set "MODE=%~1"
if "%MODE%"=="" set "MODE=release"

set "CONFIG="
if /i "%MODE%"=="release" set "CONFIG=Release"
if /i "%MODE%"=="debug"   set "CONFIG=Debug"
if /i "%MODE%"=="profile" set "CONFIG=Profile"
if not defined CONFIG goto :bad_mode

rem --- Check the toolchain ----------------------------------------------------
where flutter >nul 2>nul
if errorlevel 1 goto :no_flutter

rem --- Build ------------------------------------------------------------------
echo.
echo  Building %BINARY% [%MODE%]. The first build takes a few minutes.
echo.
rem `flutter` is itself a batch file, so it needs `call` to return control here.
call flutter build windows --%MODE%
if errorlevel 1 goto :build_failed

rem --- Locate the executable --------------------------------------------------
set "EXE=build\windows\x64\runner\%CONFIG%\%BINARY%.exe"
if not exist "%EXE%" set "EXE=build\windows\arm64\runner\%CONFIG%\%BINARY%.exe"
if not exist "%EXE%" goto :exe_missing

for %%F in ("%EXE%") do (
    set "EXE_FULL=%%~fF"
    set "EXE_DIR=%%~dpF"
)

rem `%%~dpF` leaves a trailing backslash, and inside quotes that backslash
rem escapes the closing quote -- `start` then silently launches nothing.
if "%EXE_DIR:~-1%"=="\" set "EXE_DIR=%EXE_DIR:~0,-1%"

rem --- Play -------------------------------------------------------------------
echo.
echo  Launching %EXE_FULL%
rem Start detached and from the bundle directory, so the game keeps running
rem after this window closes and finds its `data` folder.
start "Death by Slides" /d "%EXE_DIR%" "%EXE_FULL%"

popd
endlocal
exit /b 0


:bad_mode
echo ERROR: unknown build mode "%MODE%".
echo        Use one of: release, debug, profile.
goto :fail

:no_flutter
echo ERROR: `flutter` is not on your PATH.
echo        Install it from https://docs.flutter.dev/get-started/install/windows
goto :fail

:build_failed
echo ERROR: the build failed. The compiler output above says why.
goto :fail

:exe_missing
echo ERROR: the build reported success but %BINARY%.exe was not found under
echo        build\windows\. Try `flutter clean` and run this again.
goto :fail

:fail
echo.
pause
popd
endlocal
exit /b 1
