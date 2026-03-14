# OG.OC_01k - Node.js Installer Error 1603 Fix

## 📌 Решение проблемы установки Node.js v22.14.0 на Windows 11

Этот репозиторий содержит полное руководство и автоматизированные скрипты для решения проблемы ошибки **1603** при установке Node.js на Windows 11 Build 26200.

---

## 🚀 Быстрый старт

### Вариант 1: Через встроенный скрипт (РЕКОМЕНДУЕТСЯ)

```powershell
# Откройте PowerShell с правами администратора и выполните:
powershell -ExecutionPolicy Bypass -File "Install-NodeJS.ps1"
```

### Вариант 2: Через winget (самый простой)

```powershell
winget install OpenJS.NodeJS
```

### Вариант 3: Через nvm-windows

```powershell
# Установить nvm
# Скачайте nvm-setup.exe с https://github.com/coreybutler/nvm-windows

# Затем установить Node.js
nvm install 22.14.0
nvm use 22.14.0
```

---

## 📁 Содержимое репозитория

| Файл | Описание |
|------|---------|
| `NODE_JS_INSTALLER_FIX.md` | 📚 Подробное руководство со всеми решениями и диагностикой |
| `Install-NodeJS.ps1` | ⚙️ PowerShell скрипт для автоматизированной установки |
| `Install-NodeJS.bat` | 🖱️ Batch файл для удобного запуска скрипта |
| `README.md` | 📋 Этот файл |

---

## 🔍 Описание проблемы

**Ошибка:** MSI-установщик Node.js падает с кодом **1603** на этапе **LaunchConditions**

**Причины:**
- Windows Build 26200 может быть несовместим с Node.js v22.14.0
- Повреждение Windows Installer компонентов
- Конфликт с другим установленным ПО

**Что уже проверено:**
- ✅ Кириллица в пути установки
- ✅ Версия Windows 11 Pro Build 26200
- ✅ 64-битная разрядность
- ✅ Visual C++ 2022 x64 v14.50

---

## 💡 Рекомендуемые решения

### ⭐ #1 — Установка через winget (САМЫЙ ПРОСТОЙ)

```powershell
winget install OpenJS.NodeJS
```

**Преимущества:**
- Не требует прав администратора
- Автоматическое разрешение зависимостей
- Обходит проблемы с MSI

---

### ⭐ #2 — Использование nvm-windows (УНИВЕРСАЛЬНЫЙ)

```powershell
# Скачайте nvm-setup.exe
# https://github.com/coreybutler/nvm-windows/releases

nvm install 22.14.0
nvm use 22.14.0
```

**Преимущества:**
- Управление несколькими версиями Node.js
- Не требует постоянной переустановки
- Полный обход MSI проблем

---

### #3 — Портативная версия

Если ничего другое не сработало, используйте портативную версию Node.js.

---

## 🛠️ Использование автоматизированного скрипта

### Запуск с правами администратора:

**Способ 1: PowerShell (РЕКОМЕНДУЕТСЯ)**
```powershell
# Откройте PowerShell как администратор (Win+X → Windows PowerShell)
powershell -ExecutionPolicy Bypass -File "Install-NodeJS.ps1"
```

**Способ 2: Batch файл**
```cmd
# Запустите Install-NodeJS.bat с правами администратора
```

### Параметры скрипта:

```powershell
# Установить конкретную версию
powershell -ExecutionPolicy Bypass -File "Install-NodeJS.ps1" -NodeVersion "20.10.0"

# Использовать конкретный метод установки
powershell -ExecutionPolicy Bypass -File "Install-NodeJS.ps1" -InstallMethod "nvm"

# Параметры:
# -NodeVersion "22.14.0"              # Версия Node.js (по умолчанию 22.14.0)
# -InstallMethod "auto|winget|nvm|msi|portable" # Метод установки (по умолчанию auto)
```

---

## 📊 Как работает скрипт

1. **Определение окружения** — проверяет версию Windows, разрядность, доступные инструменты
2. **Выбор метода** — автоматически выбирает оптимальный способ установки:
   - winget (если доступен)
   - nvm-windows (если установлен или скачивает)
   - MSI установщик (с логированием ошибок)
   - Портативная версия (если всё остальное не сработало)
3. **Установка** — выполняет установку выбранным методом
4. **Проверка** — верифицирует успешность установки
5. **Логирование** — сохраняет все логи в `%TEMP%\nodejs-install-log.txt`

---

## 🐛 Диагностика и логирование

### Посмотреть логи установки:

```powershell
# Логи скрипта
Get-Content "$env:TEMP\nodejs-install-log.txt"

# Если использовалась MSI установка, логи MSI:
Get-Content "$env:TEMP\nodejs-msi-install.log" | Select-String "LaunchConditions"
```

### Анализ ошибок LaunchConditions:

```powershell
# Посмотреть точную ошибку
Get-Content "$env:TEMP\nodejs-msi-install.log" | Select-String -Context 5,2 "LaunchConditions"
```

---

## ⚙️ Восстановление Windows Installer (если требуется)

```powershell
# Требует прав администратора
# Остановить службу MSI
Stop-Service msiserver -Force

# Перерегистрировать DLL файлы
regsvr32 /s msi.dll
regsvr32 /s msihnd.dll

# Перезагрузиться
Restart-Computer
```

---

## 📋 Проверка результата

```powershell
# Проверить версию Node.js
node --version

# Проверить версию npm
npm --version

# Проверить путь до Node.js
where node
```

---

## 🔗 Полезные ссылки

- [Node.js Official Downloads](https://nodejs.org/en/download)
- [nvm-windows Repository](https://github.com/coreybutler/nvm-windows)
- [Windows Installer Error Codes](https://docs.microsoft.com/en-us/windows/win32/msi/error-codes)
- [Node.js GitHub Issues](https://github.com/nodejs/node/issues)

---

## 📖 Дополнительная информация

Подробное руководство со всеми способами решения, диагностикой и альтернативами находится в файле **`NODE_JS_INSTALLER_FIX.md`**.

---

**Версия:** 1.0
**Дата обновления:** 2026-03-14
**Статус:** ✅ Готово к использованию
