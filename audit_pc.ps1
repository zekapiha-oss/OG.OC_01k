# ============================================================
#  АУДИТ ПК — OpenClaw / LiteLLM / GCP Setup
#  Запускать: PowerShell от имени Администратора
#  Результат записывается в audit_report.txt рядом со скриптом
# ============================================================

$reportPath = "$PSScriptRoot\audit_report.txt"
$timestamp  = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

function Section($title) {
    $line = "=" * 60
    Write-Host "`n$line`n  $title`n$line" -ForegroundColor Cyan
    Add-Content $reportPath "`n$line`n  $title`n$line"
}

function Log($text) {
    Write-Host $text
    Add-Content $reportPath $text
}

Set-Content $reportPath "АУДИТ ПК — $timestamp`n"

# ── 1. СИСТЕМА ──────────────────────────────────────────────
Section "1. СИСТЕМА"
$os = Get-CimInstance Win32_OperatingSystem
Log "ОС      : $($os.Caption) $($os.OSArchitecture)"
Log "Версия  : $($os.Version)"
Log "Пользоватль: $env:USERNAME  /  ПК: $env:COMPUTERNAME"
Log "RAM     : $([math]::Round($os.TotalVisibleMemorySize/1MB,1)) GB"
Log "Свободно: $([math]::Round($os.FreePhysicalMemory/1MB,1)) GB"

# ── 2. PYTHON ───────────────────────────────────────────────
Section "2. PYTHON"
$pyVersions = @("python","python3","py")
foreach ($cmd in $pyVersions) {
    try {
        $v = & $cmd --version 2>&1
        Log "${cmd}: $v  → $(Get-Command $cmd -ErrorAction SilentlyContinue | Select-Object -Exp Source)"
    } catch { Log "${cmd}: не найден" }
}

# pip пакеты связанные с проектом
Log "`n--- Установленные pip-пакеты (LiteLLM / Vertex) ---"
try {
    $pkgs = pip list 2>&1 | Select-String "litellm|anthropic|google|vertex|openai|cloudflared|httpx"
    if ($pkgs) { $pkgs | ForEach-Object { Log $_.Line } } else { Log "(не найдено)" }
} catch { Log "pip недоступен" }

# ── 3. NODE / NPM ───────────────────────────────────────────
Section "3. NODE.JS / NPM"
foreach ($cmd in @("node","npm","npx")) {
    try { Log "${cmd}: $(& $cmd --version 2>&1)" } catch { Log "${cmd}: не найден" }
}

# ── 4. GOOGLE CLOUD CLI ─────────────────────────────────────
Section "4. GOOGLE CLOUD CLI (gcloud)"
try {
    $gv = gcloud version 2>&1 | Select-Object -First 3
    $gv | ForEach-Object { Log $_ }
    Log "`n--- gcloud config list ---"
    gcloud config list 2>&1 | ForEach-Object { Log $_ }
    Log "`n--- Проекты GCP ---"
    gcloud projects list 2>&1 | ForEach-Object { Log $_ }
    Log "`n--- Активные API (Vertex AI?) ---"
    gcloud services list --enabled 2>&1 | Select-String "vertex|aiplatform|iam|cloudresource" | ForEach-Object { Log $_.Line }
    Log "`n--- Сервисные аккаунты ---"
    gcloud iam service-accounts list 2>&1 | ForEach-Object { Log $_ }
} catch { Log "gcloud не установлен или не в PATH" }

# ── 5. GOOGLE_APPLICATION_CREDENTIALS ───────────────────────
Section "5. ПЕРЕМЕННЫЕ СРЕДЫ (GCP / GOOGLE)"
$envVars = @(
    "GOOGLE_APPLICATION_CREDENTIALS",
    "GOOGLE_CLOUD_PROJECT",
    "GOOGLE_PROJECT",
    "VERTEX_PROJECT",
    "VERTEX_LOCATION",
    "OPENAI_API_KEY",
    "ANTHROPIC_API_KEY",
    "LITELLM_MASTER_KEY"
)
foreach ($v in $envVars) {
    $val = [System.Environment]::GetEnvironmentVariable($v, "User")
    $sys = [System.Environment]::GetEnvironmentVariable($v, "Machine")
    if ($val) { Log "${v} [User]   = $val" }
    if ($sys) { Log "${v} [System] = $sys" }
    if (!$val -and !$sys) { Log "${v} = (не задана)" }
}

# ── 6. ФАЙЛ КЛЮЧА GCP ───────────────────────────────────────
Section "6. JSON-КЛЮЧ СЕРВИСНОГО АККАУНТА"
$credPath = [System.Environment]::GetEnvironmentVariable("GOOGLE_APPLICATION_CREDENTIALS","User")
if ($credPath -and (Test-Path $credPath)) {
    $json = Get-Content $credPath | ConvertFrom-Json
    Log "Файл    : $credPath"
    Log "project_id      : $($json.project_id)"
    Log "client_email    : $($json.client_email)"
    Log "private_key_id  : $($json.private_key_id)"
    Log "type            : $($json.type)"
} elseif ($credPath) {
    Log "GOOGLE_APPLICATION_CREDENTIALS задана, но ФАЙЛ НЕ НАЙДЕН: $credPath"
} else {
    Log "GOOGLE_APPLICATION_CREDENTIALS не задана."
    Log "Стандартные пути для поиска ключей:"
    @("C:\Keys","$env:USERPROFILE\Keys","$env:USERPROFILE\.config\gcloud") | ForEach-Object {
        if (Test-Path $_) {
            Get-ChildItem $_ -Filter "*.json" -Recurse -ErrorAction SilentlyContinue |
                Select-Object FullName, LastWriteTime | ForEach-Object { Log "  НАЙДЕН: $($_.FullName)" }
        }
    }
}

# ── 7. CLOUDFLARED ──────────────────────────────────────────
Section "7. CLOUDFLARE TUNNEL (cloudflared)"
try {
    $cfv = cloudflared --version 2>&1
    Log "cloudflared: $cfv"
    Log "Путь: $(Get-Command cloudflared | Select-Object -Exp Source)"
} catch { Log "cloudflared: не найден" }

$cfConfigDir = "$env:USERPROFILE\.cloudflared"
if (Test-Path $cfConfigDir) {
    Log "`nДиректория $cfConfigDir содержит:"
    Get-ChildItem $cfConfigDir | ForEach-Object { Log "  $($_.Name)" }
    $cfConfig = Join-Path $cfConfigDir "config.yml"
    if (Test-Path $cfConfig) {
        Log "`n--- Содержимое config.yml ---"
        Get-Content $cfConfig | ForEach-Object { Log $_ }
    }
} else { Log "Директория $cfConfigDir не найдена" }

# ── 8. ПОРТЫ (3000, 4000, 8080, 18789) ──────────────────────
Section "8. ОТКРЫТЫЕ ПОРТЫ (агенты и туннели)"
Log "Ищем занятые порты: 3000, 4000, 8080, 18789 ..."
$result = netstat -ano 2>&1 | Select-String "3000|4000|8080|18789"
if ($result) {
    $result | ForEach-Object { Log $_.Line }
    Log "`n--- Процессы по PID ---"
    $pids = $result | ForEach-Object { ($_ -split '\s+')[-1] } | Sort-Object -Unique
    foreach ($pid in $pids) {
        try {
            $proc = Get-Process -Id $pid -ErrorAction SilentlyContinue
            if ($proc) { Log "  PID $pid → $($proc.ProcessName)  ($($proc.Path))" }
        } catch {}
    }
} else { Log "Все порты свободны" }

# ── 9. ЗАПУЩЕННЫЕ ПРОЦЕССЫ ПРОЕКТА ──────────────────────────
Section "9. ПРОЦЕССЫ СВЯЗАННЫЕ С ПРОЕКТОМ"
$procs = @("cloudflared","litellm","openclaw","opencoder","python","node")
foreach ($name in $procs) {
    $found = Get-Process $name -ErrorAction SilentlyContinue
    if ($found) {
        $found | ForEach-Object { Log "  ЗАПУЩЕН: $($_.ProcessName)  PID=$($_.Id)  CPU=$($_.CPU)s" }
    } else { Log "  $name: не запущен" }
}

# ── 10. LITELLM CONFIG ──────────────────────────────────────
Section "10. LITELLM CONFIG.YAML"
$litellmPaths = @(
    ".\config.yaml",
    "$PSScriptRoot\config.yaml",
    "$env:USERPROFILE\litellm\config.yaml",
    "C:\litellm\config.yaml"
)
$found = $false
foreach ($p in $litellmPaths) {
    if (Test-Path $p) {
        Log "НАЙДЕН: $p"
        Get-Content $p | ForEach-Object { Log $_ }
        $found = $true; break
    }
}
if (-not $found) { Log "config.yaml не найден (будет создан скриптом setup.ps1)" }

# ── 11. ИТОГ И РЕКОМЕНДАЦИИ ──────────────────────────────────
Section "11. ИТОГ"
$creds = [System.Environment]::GetEnvironmentVariable("GOOGLE_APPLICATION_CREDENTIALS","User")
$hasGcloud = $null -ne (Get-Command gcloud -ErrorAction SilentlyContinue)
$hasPython = $null -ne (Get-Command python -ErrorAction SilentlyContinue)
$hasLitellm = pip list 2>&1 | Select-String "litellm"
$hasCF      = $null -ne (Get-Command cloudflared -ErrorAction SilentlyContinue)

Log "gcloud установлен       : $hasGcloud"
Log "Python установлен       : $hasPython"
Log "LiteLLM установлен      : $($null -ne $hasLitellm)"
Log "cloudflared установлен  : $hasCF"
Log "GOOGLE_APPLICATION_CREDENTIALS задана: $($null -ne $creds)"

Log "`nСледующий шаг → запустите: .\setup.ps1"

Write-Host "`n✅ Отчёт сохранён: $reportPath" -ForegroundColor Green
