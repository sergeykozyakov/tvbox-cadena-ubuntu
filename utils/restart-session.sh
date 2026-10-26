#!/bin/bash

if [[ "$EUID" -ne 0 ]]; then
  echo "Пожалуйста, запустите скрипт с правами sudo: sudo $0"
  exit 1
fi

echo "Графическая сессия gdm3 будет перезапущена через 3 секунды..."

(sleep 3 && systemctl restart gdm3) >/dev/null 2>&1 &

exit 0
