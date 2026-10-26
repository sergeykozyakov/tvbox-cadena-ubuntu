#!/bin/bash

if [[ "$EUID" -ne 0 ]]; then
  echo "Пожалуйста, запустите скрипт с правами sudo: sudo $0"
  exit 1
fi

find /etc -type f \( -name "*.dpkg-dist" -o -name "*.dpkg-old" -o -name "*.dpkg-new" \)
