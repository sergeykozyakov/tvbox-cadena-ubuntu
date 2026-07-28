#!/bin/bash

# Значения по умолчанию
CONFIG_FILE=""
SERVICE_NAME="rathole"
MAX_IDLE_MS=300000
LOG_FILE="/var/log/rathole-server-watch.log"

# Парсинг именованных аргументов
while [[ $# -gt 0 ]]; do
  case "$1" in
    --config)
      if [[ -z "$2" ]]; then
        echo "ERROR: После ключа --config нужно указать путь к файлу конфигурации сервера Rathole"
        exit 1
      fi
      CONFIG_FILE="$2"
      shift 2
      ;;
    --service)
      if [[ -z "$2" ]]; then
        echo "ERROR: После ключа --service нужно указать имя службы сервера Rathole"
        exit 1
      fi
      SERVICE_NAME="$2"
      shift 2
      ;;
    --logfile)
      if [[ -z "$2" ]]; then
        echo "ERROR: После ключа --logfile нужно указать путь к лог-файлу сервера Rathole"
        exit 1
      fi
      LOG_FILE="$2"
      shift 2
      ;;
    *)
      echo "ERROR: Неизвестный параметр: $1"
      echo "Использование: $0 --config /путь/к/файлу.toml [--service имя_службы] [--logfile /путь/к/логу]"
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
        in_server = ($0 ~ /^[ \t]*\[server\][ \t]*$/)
    }
    in_server && /^[ \t]*bind_addr[ \t]*=/ {
        sub(/^[^=]*=[ \t]*/, "");
        gsub(/^"|"[ \t]*$/, "");
        print;
        exit;
    }
' "$CONFIG_FILE")

if [[ -z "$FULL_ADDR" ]]; then
    echo "ERROR: Не удалось найти параметр bind_addr в секции [server]"
    exit 1
fi

# Разделение IPv4 и порта из конфига
#MASK="${FULL_ADDR%:*}"
PORT="${FULL_ADDR##*:}"

# Дальнейшая обработка перезапуска службы по условиям недоступности
CONN_COUNT=$(ss -t -n -H state established "( sport = :$PORT )" | wc -l)

if [[ "$CONN_COUNT" -eq 0 ]]; then
    exit 0
fi

MIN_LAST_ACK=$(ss -t -n -H -i state established "( sport = :$PORT )" | grep -o "lastack:[0-9]*" | cut -d: -f2 | sort -n | head -n 1)

if [[ "$MIN_LAST_ACK" =~ ^[0-9]+$ ]]; then
    if [[ "$MIN_LAST_ACK" -gt "$MAX_IDLE_MS" ]]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - WARNING: Клиент не отвечает (неактивен: $((MIN_LAST_ACK / 1000)) с). Перезапуск службы $SERVICE_NAME..." >> "$LOG_FILE"

        systemctl restart --no-block "$SERVICE_NAME"

        if [[ $? -eq 0 ]]; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') - SUCCESS: Служба $SERVICE_NAME успешно перезапущена" >> "$LOG_FILE"
        else
            echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: Не удалось перезапустить службу $SERVICE_NAME" >> "$LOG_FILE"
        fi
    fi
fi
