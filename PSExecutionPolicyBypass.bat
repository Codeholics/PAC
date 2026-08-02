@echo off
setlocal

set "PS=pwsh.exe"
set "SCRIPT_DIR=%~dp0"
set "TARGET_SCRIPT=%SCRIPT_DIR%start.ps1"

where "%PS%" >nul 2>&1
if errorlevel 1 (
    echo [ERROR] PAC requires PowerShell 7 ^(pwsh.exe^), but it was not found on PATH.
    echo Install PowerShell 7 and relaunch this shortcut.
    echo.
    pause
    exit /b 1
)

REM Validate script exists
if not exist "%TARGET_SCRIPT%" (
    echo [ERROR] start.ps1 not found at:
    echo %TARGET_SCRIPT%
    echo.
    pause
    exit /b 1
)

REM Launch PowerShell
"%PS%" -NoProfile -ExecutionPolicy Bypass -File "%TARGET_SCRIPT%"
set "PS_EXIT_CODE=%ERRORLEVEL%"

if errorlevel 1 (
    echo [ERROR] PowerShell script exited with code %PS_EXIT_CODE%
    echo.
    pause
)

endlocal & exit /b %PS_EXIT_CODE%