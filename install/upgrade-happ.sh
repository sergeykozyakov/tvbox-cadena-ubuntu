#!/bin/bash

set -e

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

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
apt-get install -f -y >/dev/null

echo "Удаление лишних зависимостей и очистка кэша пакетов..."

apt-get autoremove -y >/dev/null
apt-get clean >/dev/null

rm -f "$HAPP_BIN"

echo "Обновление успешно выполнено!"
echo "Графическая сессия gdm3 сейчас будет перезапущена..."
echo ""

systemctl restart gdm3 >/dev/null 2>&1

exit 0
