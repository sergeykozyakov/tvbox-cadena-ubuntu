#!/bin/bash

set -e

if [[ "$EUID" -ne 0 ]]; then
  echo "Пожалуйста, запустите скрипт с правами sudo: sudo $0"
  exit 1
fi

echo "Скачивание дистрибутива Happ Proxy последней версии..."

HAPP_BIN="Happ.linux.arm64.deb"
HAPP_URL="https://github.com/Happ-proxy/happ-desktop/releases/latest/download/$HAPP_BIN"

curl -L "$HAPP_URL" -o "$HAPP_BIN"

echo "Обновление дистрибутива Happ Proxy..."
echo "Распаковка пакета Happ Proxy (ошибки зависимостей на этом шаге — это нормальное поведение)..."

dpkg -i "$HAPP_BIN" > /dev/null 2>&1 || true

echo "Установка недостающих зависимостей и завершение обновления Happ Proxy..."

apt update > /dev/null
apt install -f -y > /dev/null

echo "Удаление лишних зависимостей и очистка кэша пакетов..."

apt autoremove -y > /dev/null
apt clean > /dev/null

rm -f "$HAPP_BIN"

echo "Обновление успешно выполнено!"
echo "Графическая сессия gdm3 будет перезапущена через 3 секунды..."

(sleep 3 && systemctl restart gdm3) > /dev/null 2>&1 &

exit 0
