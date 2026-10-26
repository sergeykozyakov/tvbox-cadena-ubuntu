#!/bin/bash

if [[ "$1" = "--email" ]] && [[ -n "$2" ]]; then
  MAIL_TO="$2"
fi

trap '
if [[ -n "$MAIL_TO" ]] && command -v sendmail >/dev/null 2>&1; then
  SUBJECT="[$HOSTNAME] Ошибка при автообновлении Happ Proxy"
  ENCODED_SUBJECT="=?UTF-8?B?$(echo -n "$SUBJECT" | base64 -w 0)?="

  sendmail -t <<EOF
To: $MAIL_TO
Subject: $ENCODED_SUBJECT

Произошла ошибка при обновлении Happ Proxy на хосте $HOSTNAME.
Проблема возникла при выполнении команды $BASH_COMMAND в скрипте автообновления!
EOF
fi

echo "Произошла ошибка при обновлении Happ Proxy в команде $BASH_COMMAND скрипта автообновления!"
exit 1
' ERR

if [[ "$EUID" -ne 0 ]]; then
  echo "Пожалуйста, запустите скрипт с правами sudo: sudo $0"
  exit 1
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Запуск обновления Happ Proxy"

echo "Скачивание дистрибутива Happ Proxy последней версии..."

HAPP_BIN="Happ.linux.arm64.deb"
HAPP_URL="https://github.com/Happ-proxy/happ-desktop/releases/latest/download/$HAPP_BIN"

curl -sSL "$HAPP_URL" -o "$HAPP_BIN"

echo "Обновление дистрибутива Happ Proxy..."
echo "Распаковка пакета Happ Proxy..."

dpkg -i "$HAPP_BIN" >/dev/null 2>&1 || true

echo "Установка недостающих зависимостей и завершение обновления Happ Proxy..."

apt-get update >/dev/null
DEBIAN_FRONTEND=noninteractive apt-get install -f -y -o Dpkg::Options::="--force-confold" -o Dpkg::Options::="--force-confdef" >/dev/null

echo "Удаление лишних зависимостей и очистка кэша пакетов..."

apt-get autoremove -y >/dev/null
apt-get clean >/dev/null

rm -f "$HAPP_BIN"

echo "Обновление успешно выполнено!"
echo "Графическая сессия gdm3 сейчас будет перезапущена..."
echo ""

systemctl restart gdm3 >/dev/null 2>&1
