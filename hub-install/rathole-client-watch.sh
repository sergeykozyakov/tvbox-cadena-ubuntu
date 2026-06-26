#!/bin/bash

# Значения по умолчанию
CONFIG_FILE=""
SERVICE_NAME="rathole"
SSH_PORT="22"
LOG_FILE="/var/log/rathole-client-watch.log"

# Парсинг именованных аргументов
while [[ $# -gt 0 ]]; do
  case "$1" in
    --config)
      if [[ -z "$2" ]]; then
        echo "ERROR: После ключа --config нужно указать путь к файлу конфигурации клиента Rathole"
        exit 1
      fi
      CONFIG_FILE="$2"
      shift 2
      ;;
    --service)
      if [[ -z "$2" ]]; then
        echo "ERROR: После ключа --service нужно указать имя основной службы Rathole"
        exit 1
      fi
      SERVICE_NAME="$2"
      shift 2
      ;;
    --sshport)
      if [[ -z "$2" ]]; then
        echo "ERROR: После ключа --sshport нужно указать номер ssh-порта сервера Rathole"
        exit 1
      fi
      SSH_PORT="$2"
      shift 2
      ;;
    --logfile)
      if [[ -z "$2" ]]; then
        echo "ERROR: После ключа --logfile нужно указать путь к лог-файлу клиента Rathole"
        exit 1
      fi
      LOG_FILE="$2"
      shift 2
      ;;
    *)
      echo "ERROR: Неизвестный параметр: $1"
      echo "Использование: $0 --config /путь/к/файлу.toml [--service имя_службы] [--sshport порт] [--logfile /путь/к/логу]"
      exit 1
      ;;
  esac
done

# Проверка обязательного параметра --config
if [[ -z "$CONFIG_FILE" ]]; then
    echo "ERROR: Обязательный параметр --config не указан"
    exit 1
fi

# Проверка существования конфигурационного файла
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "ERROR: Файл конфигурации '$CONFIG_FILE' не найден"
    exit 1
fi

# Извлечение значения remote_addr регулярными выражениями
FULL_ADDR=$(awk '
    /^[ \t]*\[.*\][ \t]*$/ {
        in_client = ($0 ~ /^[ \t]*\[client\][ \t]*$/)
    }
    in_client && /^[ \t]*remote_addr[ \t]*=/ {
        sub(/^[^=]*=[ \t]*/, "");
        gsub(/^"|"[ \t]*$/, "");
        print;
        exit;
    }
' "$CONFIG_FILE")

if [[ -z "$FULL_ADDR" ]]; then
    echo "ERROR: Не удалось найти параметр remote_addr в секции [client]"
    exit 1
fi

# Разделение IPv4 и порта из конфига
SERVER_IP="${FULL_ADDR%:*}"
#SERVER_PORT="${FULL_ADDR##*:}"

# Дальнейшая обработка перезапуска службы по условиям недоступности
SSH_BANNER=$(nc -w10 "$SERVER_IP" "$SSH_PORT" 2>/dev/null | head -n 1)

if [[ "$SSH_BANNER" != *"SSH"* ]]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - WARNING: Сервер $SERVER_IP не отвечает. Перезапуск службы $SERVICE_NAME..." >> "$LOG_FILE"

    systemctl restart --no-block "$SERVICE_NAME"

    if [[ $? -eq 0 ]]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - SUCCESS: Служба $SERVICE_NAME успешно перезапущена" >> "$LOG_FILE"
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: Не удалось перезапустить службу $SERVICE_NAME" >> "$LOG_FILE"
    fi
fi
