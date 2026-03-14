# Node.js Installer Script with Error Handling
# Решение проблемы установки Node.js v22.14.0 на Windows 11 (Error 1603)
#
# Использование:
#   PowerShell -ExecutionPolicy Bypass -File Install-NodeJS.ps1
#   или
#   .\Install-NodeJS.ps1

param(
    [string]$NodeVersion = "22.14.0",
    [string]$InstallMethod = "auto", # auto, winget, nvm, msi, portable
    [switch]$Verbose = $false
)

# ============================================================================
# КОНФИГУРАЦИЯ
# ============================================================================

$ErrorActionPreference = "Continue"
$ProgressPreference = "SilentlyContinue"

$Config = @{
    NodeVersion    = $NodeVersion
    InstallMethod  = $InstallMethod
    LogFile        = "$env:TEMP\nodejs-install-log.txt"
    Verbose        = $Verbose
}

# ============================================================================
# ФУНКЦИИ
# ============================================================================

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"

    if ($Config.Verbose) {
        Write-Host $logMessage
    }

    Add-Content -Path $Config.LogFile -Value $logMessage
}

function Test-Admin {
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")
    return $isAdmin
}

function Get-WindowsInfo {
    $osInfo = Get-WmiObject Win32_OperatingSystem
    $buildNumber = [int]$osInfo.BuildNumber
    $osVersion = $osInfo.Caption

    return @{
        Version = $osVersion
        Build   = $buildNumber
        Is64Bit = [Environment]::Is64BitOperatingSystem
    }
}

function Test-WingetAvailable {
    try {
        $null = winget --version
        return $true
    }
    catch {
        return $false
    }
}

function Test-NvmAvailable {
    try {
        $null = nvm --version
        return $true
    }
    catch {
        return $false
    }
}

function Invoke-WingetInstall {
    Write-Log "Попытка установки через winget..."

    if (-not (Test-WingetAvailable)) {
        Write-Log "winget недоступен" "ERROR"
        return $false
    }

    try {
        Write-Log "Запуск: winget install OpenJS.NodeJS"
        & winget install OpenJS.NodeJS -e -h --accept-source-agreements --accept-package-agreements

        if ($LASTEXITCODE -eq 0) {
            Write-Log "Node.js успешно установлен через winget" "SUCCESS"
            return $true
        }
        else {
            Write-Log "winget вернул код ошибки: $LASTEXITCODE" "ERROR"
            return $false
        }
    }
    catch {
        Write-Log "Ошибка при winget установке: $_" "ERROR"
        return $false
    }
}

function Invoke-NvmInstall {
    Write-Log "Попытка установки через nvm-windows..."

    if (-not (Test-NvmAvailable)) {
        Write-Log "nvm-windows недоступна. Скачивание и установка..."

        try {
            $nvmUrl = "https://github.com/coreybutler/nvm-windows/releases/download/1.1.12/nvm-setup.exe"
            $nvmSetup = "$env:TEMP\nvm-setup.exe"

            Write-Log "Скачивание nvm-setup.exe..."
            Invoke-WebRequest -Uri $nvmUrl -OutFile $nvmSetup -ErrorAction Stop

            Write-Log "Установка nvm-windows..."
            & $nvmSetup /VERYSILENT

            Start-Sleep -Seconds 3

            # Обновить PATH
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        }
        catch {
            Write-Log "Ошибка при установке nvm-windows: $_" "ERROR"
            return $false
        }
    }

    try {
        Write-Log "Установка Node.js $($Config.NodeVersion) через nvm..."
        & nvm install $Config.NodeVersion
        & nvm use $Config.NodeVersion

        if ($LASTEXITCODE -eq 0) {
            Write-Log "Node.js $($Config.NodeVersion) успешно установлен через nvm" "SUCCESS"
            return $true
        }
        else {
            Write-Log "nvm вернул код ошибки: $LASTEXITCODE" "ERROR"
            return $false
        }
    }
    catch {
        Write-Log "Ошибка при nvm установке: $_" "ERROR"
        return $false
    }
}

function Invoke-MsiInstall {
    Write-Log "Попытка установки через MSI (с диагностикой)..."

    # Скачать MSI если его нет
    $msiPath = "$env:TEMP\node-v$($Config.NodeVersion)-x64.msi"

    if (-not (Test-Path $msiPath)) {
        Write-Log "MSI файл не найден. Скачивание..."
        try {
            $msiUrl = "https://nodejs.org/dist/v$($Config.NodeVersion)/node-v$($Config.NodeVersion)-x64.msi"
            Invoke-WebRequest -Uri $msiUrl -OutFile $msiPath -ErrorAction Stop
            Write-Log "MSI скачан: $msiPath" "SUCCESS"
        }
        catch {
            Write-Log "Ошибка при скачивании MSI: $_" "ERROR"
            return $false
        }
    }

    # Запустить с логированием
    $msiLogFile = "$env:TEMP\nodejs-msi-install.log"
    Write-Log "Запуск MSI с логированием в: $msiLogFile"

    try {
        & msiexec /i "$msiPath" /l*v "$msiLogFile" /quiet /norestart

        Start-Sleep -Seconds 5

        if ($LASTEXITCODE -eq 0) {
            Write-Log "Node.js успешно установлен через MSI" "SUCCESS"
            return $true
        }
        else {
            Write-Log "MSI вернул код ошибки: $LASTEXITCODE" "ERROR"

            # Попытаться найти причину в логе
            if (Test-Path $msiLogFile) {
                Write-Log "Анализирование лога MSI..." "INFO"
                $errors = Select-String -Path $msiLogFile -Pattern "Error|LaunchConditions|1603" -Context 2,2

                if ($errors) {
                    Write-Log "Найдены ошибки в логе MSI:" "ERROR"
                    foreach ($error in $errors) {
                        Write-Log $error.Line "ERROR"
                    }
                }
            }

            return $false
        }
    }
    catch {
        Write-Log "Ошибка при MSI установке: $_" "ERROR"
        return $false
    }
}

function Invoke-PortableInstall {
    Write-Log "Установка портативной версии Node.js..."

    $portablePath = "C:\Program Files\nodejs"
    $zipUrl = "https://nodejs.org/dist/v$($Config.NodeVersion)/node-v$($Config.NodeVersion)-win-x64.zip"
    $zipPath = "$env:TEMP\nodejs-portable.zip"

    try {
        # Скачать
        Write-Log "Скачивание портативной версии..."
        Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -ErrorAction Stop

        # Распаковать
        Write-Log "Распаковка в $portablePath..."
        Expand-Archive -Path $zipPath -DestinationPath $env:TEMP -Force

        # Переместить
        if (Test-Path "$env:TEMP\node-v$($Config.NodeVersion)-win-x64") {
            Remove-Item -Path $portablePath -Recurse -Force -ErrorAction SilentlyContinue
            Move-Item -Path "$env:TEMP\node-v$($Config.NodeVersion)-win-x64" -Destination $portablePath
        }

        # Добавить в PATH
        Write-Log "Добавление в PATH..."
        $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
        if ($currentPath -notlike "*$portablePath*") {
            [Environment]::SetEnvironmentVariable("Path", "$currentPath;$portablePath", "User")
        }

        # Обновить текущую сессию
        $env:Path = "$env:Path;$portablePath"

        Write-Log "Портативная версия установлена в $portablePath" "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Ошибка при портативной установке: $_" "ERROR"
        return $false
    }
}

function Repair-WindowsInstaller {
    Write-Log "Попытка восстановления Windows Installer..."

    if (-not (Test-Admin)) {
        Write-Log "Требуются права администратора для восстановления Windows Installer" "ERROR"
        return $false
    }

    try {
        Write-Log "Остановка службы msiserver..."
        Stop-Service msiserver -Force -ErrorAction SilentlyContinue

        Start-Sleep -Seconds 2

        Write-Log "Перерегистрация MSI DLL файлов..."
        & regsvr32 /s msi.dll
        & regsvr32 /s msihnd.dll

        Write-Log "Перезагрузка требуется. Перезагружаемся..."
        Restart-Computer -Force

        return $true
    }
    catch {
        Write-Log "Ошибка при восстановлении Windows Installer: $_" "ERROR"
        return $false
    }
}

function Get-NodeInstallationStatus {
    Write-Log "Проверка установки Node.js..."

    try {
        $nodeVersion = & node --version
        $npmVersion = & npm --version

        Write-Log "Node.js: $nodeVersion" "SUCCESS"
        Write-Log "npm: $npmVersion" "SUCCESS"

        return $true
    }
    catch {
        Write-Log "Node.js не найден в системе" "ERROR"
        return $false
    }
}

# ============================================================================
# ОСНОВНОЙ СКРИПТ
# ============================================================================

Write-Host "═══════════════════════════════════════════════════════════════════"
Write-Host "  Node.js Installer Script (с обходом ошибки 1603)"
Write-Host "═══════════════════════════════════════════════════════════════════"
Write-Host ""

# Инициализация лога
"Node.js Installation Script Log" | Set-Content -Path $Config.LogFile
Write-Log "Script started"
Write-Log "Node Version: $($Config.NodeVersion)"
Write-Log "Install Method: $($Config.InstallMethod)"

# Проверить информацию о Windows
$winInfo = Get-WindowsInfo
Write-Log "Windows Info: $($winInfo.Version) (Build $($winInfo.Build), 64-bit: $($winInfo.Is64Bit))"

Write-Host "ℹ️  Windows: $($winInfo.Version) (Build $($winInfo.Build))"
Write-Host "ℹ️  Версия Node.js: $($Config.NodeVersion)"
Write-Host ""

# Auto-detection метода установки
$methods = @()

if ($Config.InstallMethod -eq "auto") {
    Write-Host "🔍 Определение оптимального метода установки..."

    if (Test-WingetAvailable) {
        $methods += "winget"
    }

    if (Test-NvmAvailable) {
        $methods += "nvm"
    }

    $methods += "msi", "portable"
}
else {
    $methods = @($Config.InstallMethod)
}

Write-Host "📦 Методы установки (в порядке приоритета):"
$methods | ForEach-Object { Write-Host "   - $_" }
Write-Host ""

# Попытаться установить
$installed = $false

foreach ($method in $methods) {
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    Write-Host "Попытка: $method"
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    $result = $false

    switch ($method) {
        "winget" { $result = Invoke-WingetInstall }
        "nvm" { $result = Invoke-NvmInstall }
        "msi" {
            if (Test-Admin) {
                $result = Invoke-MsiInstall
            }
            else {
                Write-Log "MSI установка требует прав администратора" "WARNING"
            }
        }
        "portable" { $result = Invoke-PortableInstall }
    }

    if ($result) {
        $installed = $true
        break
    }

    Write-Host ""
}

# ============================================================================
# РЕЗУЛЬТАТЫ
# ============================================================================

Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if ($installed) {
    # Проверить установку
    Write-Host "✅ Установка завершена!"
    Write-Host ""

    if (Get-NodeInstallationStatus) {
        Write-Host "✅ Node.js успешно установлен и работает"
        Write-Host ""
        Write-Host "Используйте:"
        Write-Host "  node --version"
        Write-Host "  npm --version"
    }
}
else {
    Write-Host "❌ Установка не удалась"
    Write-Host ""
    Write-Host "Логи сохранены в: $($Config.LogFile)"
    Write-Host ""
    Write-Host "Рекомендации:"
    Write-Host "1. Посмотрите логи установки для диагностики"
    Write-Host "2. Проверьте совместимость Windows Build"
    Write-Host "3. Попробуйте восстановить Windows Installer"
    Write-Host "4. Используйте портативную версию Node.js"
}

Write-Host ""
Write-Host "📋 Логи: $($Config.LogFile)"
Write-Host "═══════════════════════════════════════════════════════════════════"

Write-Log "Script finished"
