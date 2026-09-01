# OG.OC_01k — OpenClaw + LiteLLM + GCP Setup

Проект автоматизированной настройки **OpenClaw** с бюджетом **$199 на GCP Vertex AI**
через шлюз **LiteLLM** с фоллбэком на Llama 3.3 / Mixtral.

---

## Структура проекта

```
OG.OC_01k/
├── ЗАПУСТИТЬ_МЕНЯ.bat    # Быстрый запуск одним кликом (от Администратора)
├── audit_pc.ps1          # Аудит ПК — запустить ПЕРВЫМ
├── setup.ps1             # Мастер-скрипт установки и настройки
├── check_all.ps1         # Полная проверка всех компонентов
├── litellm/
│   └── config.yaml       # Конфиг LiteLLM (проект: mm-hub-pro-490014)
├── cloudflare/
│   └── config.yml        # Шаблон Cloudflare Tunnel конфига
└── Настройка OpenClaw с бюджетом GCP.pdf
```

---

## Порядок действий

### Шаг 0 — Аудит (понять что уже есть)
```powershell
# PowerShell от Администратора
.\audit_pc.ps1
# Читаем audit_report.txt — там полная картина
```

### Шаг 1 — GCP подготовка (один раз в консоли)
```bash
# В Google Cloud Shell или локально через gcloud
gcloud config list                        # проверяем аккаунт
gcloud projects list                      # находим/создаём проект
gcloud services enable aiplatform.googleapis.com --project YOUR_PROJECT_ID
```

Создайте **Service Account** с ролью `Vertex AI User` и скачайте JSON-ключ в `C:\Keys\vertex-sa.json`.

### Шаг 2 — Установка и настройка
```powershell
# PowerShell от Администратора

# Вариант A: ADC (Application Default Credentials — рекомендуется)
gcloud auth application-default login
.\setup.ps1

# Вариант B: Service Account JSON-ключ
.\setup.ps1 -GcpProjectId "ваш-project-id" -KeyPath "C:\Keys\vertex-sa.json"
```

### Шаг 3 — Запуск всего
```powershell
.\setup.ps1 -LaunchAll
# Или одним кликом (от Администратора):
# ЗАПУСТИТЬ_МЕНЯ.bat
```

### Настройки OpenClaw
| Параметр   | Значение                  |
|-----------|---------------------------|
| Provider  | OpenAI-Compatible         |
| Base URL  | `http://127.0.0.1:4000`   |
| API Key   | `sk-openclaw-local`       |
| Model     | `sonnet-4.5`              |

---

## Архитектура

```
iPhone / Telegram
      ↓ HTTPS
Cloudflare Tunnel
      ↓
OpenClaw (localhost:18789)
      ↓ OpenAI-compatible API
LiteLLM Proxy (localhost:4000)
      ↓ budget $199 / 3mo
GCP Vertex AI
  ├── Claude Sonnet 4.5  (основная)
  ├── Llama 3.3 70B      (фоллбэк 1)
  └── Mixtral 8x7B       (фоллбэк 2)
```

---

## GCP Бюджет-контроль (двойная защита)
1. **LiteLLM**: `max_budget: 199.00`, `budget_duration: "3mo"` — режет на уровне API
2. **GCP Billing**: Billing → Budgets & Alerts → $190 с уведомлениями на 50%/90%/100%
