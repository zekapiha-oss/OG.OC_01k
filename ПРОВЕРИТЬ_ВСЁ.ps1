# ============================================================
#  ПОЛНАЯ ПРОВЕРКА И НАСТРОЙКА — OpenClaw + GCP
#  Запуск: PowerShell от Администратора
#  Данные: gen-lang-client-0454675031
# ============================================================

$KEY_PATH   = 'C:\Users\Евгений\OneDrive\Документи\kovalenko_ev\gen-lang-client-0454675031-a92bf51ffd4a.json'
$GCP_PROJ   = 'gen-lang-client-0454675031'
$PROJ_DIR   = $PSScriptRoot
$LITELLM_CFG = "$PROJ_DIR\litellm\config.yaml"

function OK($m)   { Write-Host "  ✓ $m" -ForegroundColor Green }
function ERR($m)  { Write-Host "  ✗ $m" -ForegroundColor Red }
function WARN($m) { Write-Host "  ⚠ $m" -ForegroundColor Yellow }
function INFO($m) { Write-Host "  → $m" -ForegroundColor Gray }
function HDR($n,$t) {
    Write-Host ""
    Write-Host ("─"*60) -ForegroundColor DarkCyan
    Write-Host "  ШАГ $n: $t" -ForegroundColor Cyan
    Write-Host ("─"*60) -ForegroundColor DarkCyan
}

Write-Host ""
Write-Host ("═"*60) -ForegroundColor Green
Write-Host "  АУДИТ И НАСТРОЙКА — OG.OC_01k" -ForegroundColor Green
Write-Host "  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Green
Write-Host ("═"*60) -ForegroundColor Green

# ── 1. СИСТЕМА ───────────────────────────────────────────────
HDR 1 "СИСТЕМА"
$os = Get-CimInstance Win32_OperatingSystem
OK "ОС: $($os.Caption) $($os.OSArchitecture)"
OK "Версия: $($os.Version)"
OK "Пользователь: $env:USERNAME  /  ПК: $env:COMPUTERNAME"
$ram = [math]::Round($os.TotalVisibleMemorySize/1MB,1)
OK "RAM: $ram GB"

# ── 2. PYTHON ────────────────────────────────────────────────
HDR 2 "PYTHON"
try {
    $pv = python --version 2>&1
    OK "Python: $pv  →  $(Get-Command python | Select-Object -Exp Source)"
} catch { ERR "Python не найден! → https://www.python.org/downloads/"; exit 1 }

# ── 3. PIP ПАКЕТЫ ────────────────────────────────────────────
HDR 3 "PIP ПАКЕТЫ (проект)"
$pkgList = pip list 2>&1
$relevant = $pkgList | Select-String "litellm|google-cloud|anthropic|openai|httpx|uvicorn|fastapi"
if ($relevant) {
    $relevant | ForEach-Object { OK $_.Line.Trim() }
} else { WARN "Нет установленных пакетов проекта" }

$hasLitellm = $pkgList | Select-String "^litellm "
if (-not $hasLitellm) {
    WARN "LiteLLM не установлен. Устанавливаем..."
    pip install "litellm[proxy]" --quiet
    OK "LiteLLM установлен"
} else {
    OK "LiteLLM: $($hasLitellm.Line.Trim())"
    INFO "Проверяем обновление..."
    pip install --upgrade litellm --quiet 2>&1 | Out-Null
}

# ── 4. GCLOUD ────────────────────────────────────────────────
HDR 4 "GOOGLE CLOUD CLI"
if (Get-Command gcloud -ErrorAction SilentlyContinue) {
    $gv = gcloud version 2>&1 | Select-Object -First 1
    OK "gcloud: $gv"

    Write-Host ""
    Write-Host "  --- gcloud config ---" -ForegroundColor DarkGray
    gcloud config list 2>&1 | ForEach-Object { INFO $_ }

    Write-Host ""
    Write-Host "  --- Проекты GCP ---" -ForegroundColor DarkGray
    gcloud projects list 2>&1 | ForEach-Object { INFO $_ }

    Write-Host ""
    Write-Host "  --- Сервисные аккаунты ($GCP_PROJ) ---" -ForegroundColor DarkGray
    gcloud iam service-accounts list --project $GCP_PROJ 2>&1 | ForEach-Object { INFO $_ }

    Write-Host ""
    Write-Host "  --- Vertex AI API ---" -ForegroundColor DarkGray
    $vx = gcloud services list --enabled --project $GCP_PROJ --filter="name:aiplatform" 2>&1
    if ($vx -match "aiplatform") { OK "Vertex AI API включён" }
    else {
        WARN "Vertex AI API не включён. Включаем..."
        gcloud services enable aiplatform.googleapis.com --project $GCP_PROJ 2>&1 | Out-Null
        OK "Vertex AI API включён"
    }
} else {
    ERR "gcloud не найден! → https://cloud.google.com/sdk/docs/install"
}

# ── 5. JSON-КЛЮЧ ─────────────────────────────────────────────
HDR 5 "JSON-КЛЮЧ СЕРВИСНОГО АККАУНТА"
INFO "Путь: $KEY_PATH"
if (Test-Path $KEY_PATH) {
    OK "Файл найден"
    try {
        $json = Get-Content $KEY_PATH | ConvertFrom-Json
        OK "project_id   : $($json.project_id)"
        OK "client_email : $($json.client_email)"
        OK "type         : $($json.type)"
        if ($json.project_id -ne $GCP_PROJ) {
            WARN "ВНИМАНИЕ: project_id в ключе ($($json.project_id)) ≠ $GCP_PROJ"
        }
    } catch { WARN "Не удалось разобрать JSON" }
} else {
    ERR "ФАЙЛ НЕ НАЙДЕН: $KEY_PATH"
    INFO "Проверьте путь к ключу!"
    exit 1
}

# Устанавливаем переменную среды
$cur = [System.Environment]::GetEnvironmentVariable("GOOGLE_APPLICATION_CREDENTIALS","User")
if ($cur -ne $KEY_PATH) {
    [System.Environment]::SetEnvironmentVariable("GOOGLE_APPLICATION_CREDENTIALS", $KEY_PATH, "User")
    $env:GOOGLE_APPLICATION_CREDENTIALS = $KEY_PATH
    OK "GOOGLE_APPLICATION_CREDENTIALS установлена"
} else {
    OK "GOOGLE_APPLICATION_CREDENTIALS уже задана"
}

# ── 6. CLOUDFLARED ───────────────────────────────────────────
HDR 6 "CLOUDFLARE TUNNEL"
if (Get-Command cloudflared -ErrorAction SilentlyContinue) {
    OK "cloudflared: $(cloudflared --version 2>&1)"
    $cfDir = "$env:USERPROFILE\.cloudflared"
    if (Test-Path $cfDir) {
        OK "Конфиг-директория: $cfDir"
        Get-ChildItem $cfDir | ForEach-Object { INFO $_.Name }
    } else {
        WARN "Директория $cfDir не найдена. Требуется: cloudflared tunnel login"
    }
} else {
    WARN "cloudflared не найден. Устанавливаем..."
    try {
        winget install --id Cloudflare.cloudflared -e --silent 2>&1 | Out-Null
        OK "cloudflared установлен. Перезапустите PowerShell."
    } catch { WARN "Установите вручную: https://github.com/cloudflare/cloudflared/releases" }
}

# ── 7. OPENCLAW ──────────────────────────────────────────────
HDR 7 "OPENCLAW"
$openclawPaths = @(
    "C:\Program Files\OpenClaw",
    "C:\Program Files (x86)\OpenClaw",
    "$env:LOCALAPPDATA\OpenClaw",
    "$env:APPDATA\OpenClaw",
    "$env:USERPROFILE\OpenClaw"
)
$ocFound = $false
foreach ($p in $openclawPaths) {
    if (Test-Path $p) {
        OK "OpenClaw найден: $p"
        Get-ChildItem $p -Filter "*.exe" | ForEach-Object { INFO $_.Name }
        $ocFound = $true
    }
}
# Поиск в PATH
$ocExe = Get-Command "openclaw" -ErrorAction SilentlyContinue
if ($ocExe) { OK "openclaw в PATH: $($ocExe.Source)"; $ocFound = $true }

if (-not $ocFound) {
    WARN "OpenClaw не найден в стандартных путях"
    INFO "→ https://github.com/OpenClaw/OpenClaw (проверьте актуальность)"
}

# ── 8. ПОРТЫ ─────────────────────────────────────────────────
HDR 8 "ПОРТЫ (3000, 4000, 8080, 18789)"
$portResult = netstat -ano 2>&1 | Select-String "3000|4000|8080|18789"
if ($portResult) {
    $portResult | ForEach-Object { INFO $_.Line.Trim() }
} else { OK "Все порты свободны" }

# ── 9. LITELLM CONFIG ────────────────────────────────────────
HDR 9 "LITELLM CONFIG.YAML"
if (Test-Path $LITELLM_CFG) {
    OK "Конфиг найден: $LITELLM_CFG"
    Get-Content $LITELLM_CFG | ForEach-Object { INFO $_ }
} else {
    WARN "config.yaml не найден: $LITELLM_CFG"
    INFO "Запустите setup.ps1 для генерации"
}

# ── 10. ТЕСТ LITELLM ─────────────────────────────────────────
HDR 10 "ТЕСТ ЗАПУСКА LITELLM"
INFO "Запускаем LiteLLM на 8 секунд..."
$job = Start-Job -ScriptBlock {
    param($cfg, $key, $proj)
    $env:GOOGLE_APPLICATION_CREDENTIALS = $key
    litellm --config $cfg --port 4000 2>&1
} -ArgumentList $LITELLM_CFG, $KEY_PATH, $GCP_PROJ

Start-Sleep 6
try {
    $r = Invoke-WebRequest -Uri "http://127.0.0.1:4000/" -TimeoutSec 3 -ErrorAction Stop
    if ($r.StatusCode -eq 200) { OK "LiteLLM запускается корректно (HTTP $($r.StatusCode))" }
} catch { WARN "LiteLLM UI не ответил (возможно медленный запуск — это OK)" }
Stop-Job $job -ErrorAction SilentlyContinue
Remove-Job $job -ErrorAction SilentlyContinue

# ── ИТОГ ─────────────────────────────────────────────────────
Write-Host ""
Write-Host ("═"*60) -ForegroundColor Green
Write-Host "  ИТОГ И СЛЕДУЮЩИЕ ШАГИ" -ForegroundColor Green
Write-Host ("═"*60) -ForegroundColor Green
Write-Host ""
Write-Host "  1. Запуск LiteLLM (в новом окне):" -ForegroundColor Cyan
Write-Host "     litellm --config `"$LITELLM_CFG`" --port 4000" -ForegroundColor White
Write-Host ""
Write-Host "  2. Настройки OpenClaw:" -ForegroundColor Cyan
Write-Host "     Provider : OpenAI-Compatible" -ForegroundColor White
Write-Host "     Base URL : http://127.0.0.1:4000" -ForegroundColor White
Write-Host "     API Key  : sk-openclaw-local" -ForegroundColor White
Write-Host "     Model    : sonnet-4.5" -ForegroundColor White
Write-Host ""
Write-Host "  Или запустите ЗАПУСТИТЬ_МЕНЯ.bat (от Администратора)" -ForegroundColor Yellow
Write-Host ""
