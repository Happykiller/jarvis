@echo off
REM Galakrond Dev Setup
powershell -ExecutionPolicy Bypass -File "%~dp0dev-setup.ps1" -Mode start
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: the PowerShell script failed with exit code %ERRORLEVEL%
    pause
)
