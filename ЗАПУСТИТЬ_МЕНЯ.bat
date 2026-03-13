@echo off
chcp 65001 >nul 2>&1
title OpenClaw Setup — OG.OC_01k
color 0A

echo.
echo ╔══════════════════════════════════════════════════════════╗
echo ║     OpenClaw + LiteLLM + GCP — Автозапуск             ║
echo ║     Project: gen-lang-client-0454675031                ║
echo ╚══════════════════════════════════════════════════════════╝
echo.

:: Путь к папке проекта (текущая папка)
set "PROJ_DIR=%~dp0"
set "KEY_PATH=C:\Users\Евгений\OneDrive\Документи\kovalenko_ev\gen-lang-client-0454675031-a92bf51ffd4a.json"
set "GCP_PROJECT=gen-lang-client-0454675031"
set "LITELLM_CONFIG=%PROJ_DIR%litellm\config.yaml"

echo [1/6] Проверка прав администратора...
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo.
    echo  ВНИМАНИЕ: Запустите этот файл от имени Администратора!
    echo  Кликните правой кнопкой → "Запуск от имени администратора"
    echo.
    pause
    exit /b 1
)
echo   OK

echo.
echo [2/6] Настройка переменной GOOGLE_APPLICATION_CREDENTIALS...
if not exist "%KEY_PATH%" (
    echo   ОШИБКА: Файл ключа не найден:
    echo   %KEY_PATH%
    echo.
    echo   Проверьте путь и перезапустите.
    pause
    exit /b 1
)
setx GOOGLE_APPLICATION_CREDENTIALS "%KEY_PATH%" >nul 2>&1
set GOOGLE_APPLICATION_CREDENTIALS=%KEY_PATH%
echo   OK: %KEY_PATH%

echo.
echo [3/6] Проверка Python и установка LiteLLM...
python --version >nul 2>&1
if %errorLevel% neq 0 (
    echo   ОШИБКА: Python не найден! Установите: https://www.python.org/downloads/
    pause
    exit /b 1
)
python -c "import litellm" >nul 2>&1
if %errorLevel% neq 0 (
    echo   Устанавливаем litellm[proxy]...
    pip install "litellm[proxy]" --quiet
    if %errorLevel% neq 0 (
        echo   ОШИБКА установки LiteLLM!
        pause
        exit /b 1
    )
    echo   LiteLLM установлен
) else (
    echo   LiteLLM уже установлен
)

echo.
echo [4/6] Проверка gcloud и Vertex AI API...
gcloud --version >nul 2>&1
if %errorLevel% neq 0 (
    echo   ВНИМАНИЕ: gcloud не найден. Пропускаем проверку API.
) else (
    echo   gcloud найден. Проверяем Vertex AI API...
    gcloud services enable aiplatform.googleapis.com --project %GCP_PROJECT% >nul 2>&1
    echo   Vertex AI API активен
)

echo.
echo [5/6] Проверка cloudflared...
cloudflared --version >nul 2>&1
if %errorLevel% neq 0 (
    echo   cloudflared не найден. Устанавливаем через winget...
    winget install --id Cloudflare.cloudflared -e --silent >nul 2>&1
    if %errorLevel% neq 0 (
        echo   ВНИМАНИЕ: Установите cloudflared вручную:
        echo   https://github.com/cloudflare/cloudflared/releases
        echo   (Туннель будет недоступен, но LiteLLM работает)
    ) else (
        echo   cloudflared установлен
    )
) else (
    echo   cloudflared найден
)

echo.
echo [6/6] Запуск LiteLLM шлюза...
echo   Конфиг: %LITELLM_CONFIG%
echo   API URL: http://127.0.0.1:4000
echo   API Key: sk-openclaw-local
echo   UI:      http://127.0.0.1:4000/ui
echo.

start "LiteLLM Gateway" cmd /k "echo LiteLLM Gateway — gen-lang-client-0454675031 && echo. && litellm --config "%LITELLM_CONFIG%" --port 4000"

timeout /t 5 /nobreak >nul

echo.
echo ╔══════════════════════════════════════════════════════════╗
echo ║  ГОТОВО! Настройки для OpenClaw:                       ║
echo ║                                                         ║
echo ║  Provider : OpenAI-Compatible                          ║
echo ║  Base URL : http://127.0.0.1:4000                      ║
echo ║  API Key  : sk-openclaw-local                          ║
echo ║  Model    : sonnet-4.5                                 ║
echo ║                                                         ║
echo ║  LiteLLM UI: http://127.0.0.1:4000/ui                 ║
echo ╚══════════════════════════════════════════════════════════╝
echo.
echo Открываем LiteLLM UI в браузере...
start "" "http://127.0.0.1:4000/ui"

echo.
echo Нажмите любую клавишу для выхода...
pause >nul
