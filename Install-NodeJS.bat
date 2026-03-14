@echo off
REM Node.js Installer Batch Wrapper
REM Решение проблемы установки Node.js v22.14.0 на Windows 11 (Error 1603)

echo.
echo ════════════════════════════════════════════════════════════════════
echo   Node.js Installer with Error 1603 Fix
echo ════════════════════════════════════════════════════════════════════
echo.

REM Проверить права администратора
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo ERROR: Требуются права администратора!
    echo.
    echo Пожалуйста, запустите этот скрипт с правами администратора:
    echo   1. Нажмите Win+X
    echo   2. Выберите "Windows PowerShell (администратор)"
    echo   3. Скопируйте и запустите:
    echo      powershell -ExecutionPolicy Bypass -File "Install-NodeJS.ps1"
    echo.
    pause
    exit /b 1
)

REM Запустить PowerShell скрипт
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-NodeJS.ps1"

pause
