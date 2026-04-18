@echo off
REM DraftDream Dev Setup
powershell -ExecutionPolicy Bypass -File "%~dp0dev-setup.ps1"
if %ERRORLEVEL% NEQ 0 (
    echo ERREUR : le script PowerShell a echoue avec le code %ERRORLEVEL%
    pause
)
