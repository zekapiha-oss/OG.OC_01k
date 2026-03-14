# ============================================================
#  МАСТЕР-СКРИПТ УСТАНОВКИ: OpenClaw + LiteLLM + GCP + Cloudflare
#  Запускать: PowerShell от имени Администратора
#  Проект: OG.OC_01k
# ============================================================

param(
    [string]$GcpProjectId  = "gen-lang-client-0454675031",
    [string]$KeyPath       = 'C:\Users\Евгений\OneDrive\Документи\kovalenko_ev\gen-lang-client-0454675031-a92bf51ffd4a.json',
    [string]$Domain        = "",   # ваш домен для Cloudflare
    [switch]$SkipAudit     = $false,
    [switch]$LaunchAll     = $false
)

$ErrorActionPreference = "Stop"

function Step($n, $title) {
    Write-Host "`n" -NoNewline
    Write-Host ("=" * 60) -ForegroundColor DarkCyan
    Write-Host "  ШАГ $n: $title" -ForegroundColor Yellow
    Write-Host ("=" * 60) -ForegroundColor DarkCyan
}

function OK($msg)   { Write-Host "  ✓ $msg" -ForegroundColor Green }
function WARN($msg) { Write-Host "  ⚠ $msg" -ForegroundColor Yellow }
function ERR($msg)  { Write-Host "  ✗ $msg" -ForegroundColor Red }
function INFO($msg) { Write-Host "  → $msg" -ForegroundColor Gray }

# ── АУДИТ ───────────────────────────────────────────────────
if (-not $SkipAudit) {
    Step 0 "Аудит ПК"
    $auditScript = Join-Path $PSScriptRoot "audit_pc.ps1"
    if (Test-Path $auditScript) {
        INFO "Запускаем audit_pc.ps1 ..."
        & $auditScript
    } else { WARN "audit_pc.ps1 не найден, пропускаем" }
}

# ── ШАГ 1: ПРОВЕРКА ЗАВИСИМОСТЕЙ ─────────────────────────────
Step 1 "Проверка зависимостей"

# Python
if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    ERR "Python не найден! Установите: https://www.python.org/downloads/"
    ERR "После установки перезапустите PowerShell и скрипт."
    exit 1
} else {
    $pv = python --version 2>&1
    OK "Python: $pv"
}

# gcloud
if (-not (Get-Command gcloud -ErrorAction SilentlyContinue)) {
    WARN "gcloud CLI не найден."
    INFO "Скачайте: https://cloud.google.com/sdk/docs/install"
    INFO "После установки выполните: gcloud init"
    Read-Host "Нажмите Enter после установки gcloud, или Ctrl+C для выхода"
} else {
    OK "gcloud CLI: $(gcloud version 2>&1 | Select-Object -First 1)"
}

# cloudflared
if (-not (Get-Command cloudflared -ErrorAction SilentlyContinue)) {
    WARN "cloudflared не найден. Устанавливаем через winget..."
    try {
        winget install --id Cloudflare.cloudflared -e --silent 2>&1 | Out-Null
        OK "cloudflared установлен"
    } catch {
        WARN "winget недоступен. Скачайте вручную: https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/"
    }
} else {
    OK "cloudflared: $(cloudflared --version 2>&1)"
}

# ── ШАГ 2: УСТАНОВКА LITELLM ──────────────────────────────────
Step 2 "Установка LiteLLM Proxy"
$hasLitellm = pip list 2>&1 | Select-String "^litellm "
if (-not $hasLitellm) {
    INFO "Устанавливаем litellm[proxy] и google-cloud-aiplatform ..."
    pip install "litellm[proxy]" google-cloud-aiplatform --quiet
    OK "LiteLLM установлен"
} else {
    OK "LiteLLM уже установлен: $($hasLitellm.Line.Trim())"
    INFO "Обновляем до последней версии..."
    pip install --upgrade litellm --quiet
}

# ── ШАГ 3: НАСТРОЙКА GCP КЛЮЧА ───────────────────────────────
Step 3 "Настройка Google Application Credentials"

$existingCreds = [System.Environment]::GetEnvironmentVariable("GOOGLE_APPLICATION_CREDENTIALS","User")

if ($existingCreds -and (Test-Path $existingCreds)) {
    OK "GOOGLE_APPLICATION_CREDENTIALS уже задана: $existingCreds"
    try {
        $json = Get-Content $existingCreds | ConvertFrom-Json
        INFO "  project_id   : $($json.project_id)"
        INFO "  client_email : $($json.client_email)"
        if (-not $GcpProjectId) { $GcpProjectId = $json.project_id }
    } catch { WARN "Не удалось разобрать JSON-ключ" }
} else {
    if (-not $KeyPath) {
        $KeyPath = Read-Host "Введите полный путь к JSON-ключу сервисного аккаунта"
    }
    if (-not (Test-Path $KeyPath)) {
        ERR "Файл ключа не найден: $KeyPath"
        INFO "Инструкция создания SA:"
        INFO "  1. GCP Console → IAM & Admin → Service Accounts"
        INFO "  2. Создайте SA с ролью 'Vertex AI User'"
        INFO "  3. Создайте JSON-ключ и сохраните в $KeyPath"
        exit 1
    }
    [System.Environment]::SetEnvironmentVariable("GOOGLE_APPLICATION_CREDENTIALS", $KeyPath, "User")
    $env:GOOGLE_APPLICATION_CREDENTIALS = $KeyPath
    OK "GOOGLE_APPLICATION_CREDENTIALS установлена → $KeyPath"
    try {
        $json = Get-Content $KeyPath | ConvertFrom-Json
        INFO "  project_id   : $($json.project_id)"
        if (-not $GcpProjectId) { $GcpProjectId = $json.project_id }
    } catch {}
}

# ── ШАГ 4: ГЕНЕРАЦИЯ LITELLM CONFIG ──────────────────────────
Step 4 "Создание litellm/config.yaml"
$configDir = Join-Path $PSScriptRoot "litellm"
$configFile = Join-Path $configDir "config.yaml"

if (-not (Test-Path $configDir)) { New-Item -ItemType Directory -Path $configDir | Out-Null }

if (-not $GcpProjectId) {
    $GcpProjectId = Read-Host "Введите GCP Project ID"
}

$configContent = @"
model_list:
  - model_name: claude-sonnet
    litellm_params:
      model: vertex_ai/claude-sonnet-4-5@20250514
      vertex_project: "$GcpProjectId"
      vertex_location: "us-east5"
      vertex_credentials: "$KeyPath"

  - model_name: sonnet-4.5
    litellm_params:
      model: vertex_ai/claude-sonnet-4-5@20250514
      vertex_project: "$GcpProjectId"
      vertex_location: "us-east5"
      vertex_credentials: "$KeyPath"

  - model_name: gemini-flash
    litellm_params:
      model: vertex_ai/gemini-2.0-flash-001
      vertex_project: "$GcpProjectId"
      vertex_location: "us-central1"
      vertex_credentials: "$KeyPath"

router_settings:
  fallbacks:
    - claude-sonnet: ["gemini-flash"]
    - sonnet-4.5: ["gemini-flash"]
  num_retries: 3

litellm_settings:
  max_budget: 199.00
  budget_duration: "3mo"
  drop_params: true

general_settings:
  master_key: "sk-openclaw-local"
"@

Set-Content -Path $configFile -Value $configContent
OK "Конфиг записан: $configFile"

# ── ШАГ 5: ПРОВЕРКА GCP Vertex AI ────────────────────────────
Step 5 "Проверка Vertex AI API в GCP"
try {
    $enabled = gcloud services list --enabled --project $GcpProjectId --filter="name:aiplatform.googleapis.com" 2>&1
    if ($enabled -match "aiplatform") {
        OK "Vertex AI API включён в проекте $GcpProjectId"
    } else {
        WARN "Vertex AI API НЕ включён. Включаем..."
        gcloud services enable aiplatform.googleapis.com --project $GcpProjectId
        OK "Vertex AI API включён"
    }
} catch { WARN "Не удалось проверить через gcloud (ок, если SA уже настроен)" }

# ── ШАГ 6: ТЕСТ LITELLM ──────────────────────────────────────
Step 6 "Тест LiteLLM соединения с Vertex AI"
INFO "Запускаем кратковременный тест (10 сек)..."
$testJob = Start-Job -ScriptBlock {
    param($cfg)
    litellm --config $cfg --port 4001 2>&1
} -ArgumentList $configFile

Start-Sleep -Seconds 6

try {
    $resp = Invoke-WebRequest -Uri "http://127.0.0.1:4001/health" -TimeoutSec 5 -ErrorAction Stop
    OK "LiteLLM отвечает: $($resp.StatusCode)"
} catch {
    WARN "Health check не прошёл (возможно нужны ключи/квоты — это нормально на этапе настройки)"
}

Stop-Job $testJob -ErrorAction SilentlyContinue
Remove-Job $testJob -ErrorAction SilentlyContinue

# ── ШАГ 7: СОЗДАНИЕ CLOUDFLARE CONFIG ────────────────────────
Step 7 "Настройка Cloudflare Tunnel"
$cfDir = "$env:USERPROFILE\.cloudflared"
$cfConfig = Join-Path $cfDir "config.yml"

if (-not (Test-Path $cfDir)) { New-Item -ItemType Directory -Path $cfDir | Out-Null }

if (Test-Path $cfConfig) {
    OK "Cloudflare config уже существует: $cfConfig"
    Get-Content $cfConfig | ForEach-Object { INFO $_ }
} else {
    if (-not $Domain) {
        WARN "Домен не задан. Cloudflare конфиг будет создан без hostname."
        INFO "Передайте: -Domain yourdomain.com"
        $Domain = "YOUR_DOMAIN.com"
    }

    $tunnelId = ""
    try {
        $tunnelList = cloudflared tunnel list 2>&1
        WARN "Существующие туннели:"
        $tunnelList | ForEach-Object { INFO $_ }
        $tunnelId = Read-Host "Введите Tunnel ID (или Enter для создания нового)"
        if (-not $tunnelId) {
            cloudflared tunnel create openclaw-tunnel 2>&1 | ForEach-Object { INFO $_ }
            $tunnelId = (cloudflared tunnel list 2>&1 | Select-String "openclaw-tunnel" | ForEach-Object { ($_ -split '\s+')[0] } | Select-Object -First 1)
        }
    } catch { WARN "cloudflared login ещё не выполнен. Выполните: cloudflared tunnel login" }

    $cfContent = @"
tunnel: $tunnelId
credentials-file: $cfDir\$tunnelId.json

ingress:
  - hostname: agent.$Domain
    service: http://localhost:18789
  - hostname: webhook.$Domain
    service: http://localhost:3000
  - service: http_status:404
"@
    Set-Content -Path $cfConfig -Value $cfContent
    OK "Cloudflare config создан: $cfConfig"
}

# ── ШАГ 8: ФИНАЛЬНЫЙ ЗАПУСК ──────────────────────────────────
Step 8 "Запуск сервисов"

if ($LaunchAll) {
    # LiteLLM в отдельном окне
    INFO "Запускаем LiteLLM на порту 4000..."
    Start-Process powershell -ArgumentList "-NoExit -Command litellm --config `"$configFile`" --port 4000" -WindowStyle Normal
    Start-Sleep -Seconds 3

    # Cloudflare tunnel в отдельном окне
    INFO "Запускаем Cloudflare Tunnel..."
    Start-Process powershell -ArgumentList "-NoExit -Command cloudflared tunnel run" -WindowStyle Normal

    OK "Сервисы запущены!"
    INFO "LiteLLM API: http://127.0.0.1:4000"
    INFO "LiteLLM UI:  http://127.0.0.1:4000/ui"
} else {
    Write-Host ""
    Write-Host ("=" * 60) -ForegroundColor Green
    Write-Host "  УСТАНОВКА ЗАВЕРШЕНА! Для запуска выполните:" -ForegroundColor Green
    Write-Host ("=" * 60) -ForegroundColor Green
    Write-Host ""
    Write-Host "  # Запуск LiteLLM (в отдельном окне PS):" -ForegroundColor Cyan
    Write-Host "  litellm --config `"$configFile`" --port 4000" -ForegroundColor White
    Write-Host ""
    Write-Host "  # Запуск Cloudflare Tunnel:" -ForegroundColor Cyan
    Write-Host "  cloudflared tunnel run" -ForegroundColor White
    Write-Host ""
    Write-Host "  # Или запустить всё сразу:" -ForegroundColor Cyan
    Write-Host "  .\setup.ps1 -LaunchAll" -ForegroundColor White
    Write-Host ""
    Write-Host "  Настройки OpenClaw:" -ForegroundColor Yellow
    Write-Host "    Provider : OpenAI-Compatible" -ForegroundColor White
    Write-Host "    Base URL : http://127.0.0.1:4000" -ForegroundColor White
    Write-Host "    API Key  : sk-openclaw-local" -ForegroundColor White
    Write-Host "    Model    : sonnet-4.5" -ForegroundColor White
    Write-Host ""
}
