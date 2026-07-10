#!/bin/bash

if [[ "$(uname -m)" != "aarch64" ]]; then
    echo "ОШИБКА! Этот скрипт предназначен только для устройств на архитектуре ARM64 (aarch64)"
    exit 1
fi

set -e

# Файл для хранения контекста между этапами
STAGE_FILE="setup-stage.tmp"

# Каталог хранения исполняемых файлов системы
SYSTEM_BIN_DIR="/usr/local/bin"

# Параметры системы по умолчанию
DEF_HOSTNAME="cadena"
DEF_TIMEZONE="Europe/Moscow"
DEF_SWAP_SIZE="4G"

# Значения домашней Wi-Fi сети (Client) по умолчанию
DEF_CLIENT_GATEWAY="192.168.0.1"

# Значения точки доступа (Hotspot) по умолчанию
DEF_HOTSPOT_SSID="cadena-ap"
DEF_HOTSPOT_PASS="MySecretPassword"

# Настройки Rathole по умолчанию
DEF_RATHOLE_HOST="X.X.X.X"
DEF_RATHOLE_PORT="X"
DEF_RATHOLE_TOKEN="XXXXXXXXXXXXX"

# Функция генерации UUID
generate_uuid() {
    if command -v uuidgen >/dev/null 2>&1; then
        uuidgen
    else
        cat /proc/sys/kernel/random/uuid 2>/dev/null || echo "ffffffff-ffff-ffff-ffff-$(date +%s)"
    fi
}

if [[ ! -f "$STAGE_FILE" ]]; then
    clear
    echo "========================================================================="
    echo "  Настройка системы для приставок CADENA Pro X (Ubuntu)                  "
    echo "========================================================================="
    echo ""
    echo "=== [ЭТАП 1] Первоначальная настройка ==="
    echo ""

    if ! command -v sudo >/dev/null 2>&1; then
        echo ""
        echo "Утилита sudo отсутствует в системе. Выполняется ее установка через root..." 1>&2

        CURRENT_USER="${USER:-$(id -un)}"

        if su -c "apt update && apt install sudo -y && usermod -aG sudo $CURRENT_USER"; then
            echo "Утилита sudo успешно установлена!"
            echo ""
            echo "Установка нового более сложного пароля для root..."

            su -c "passwd root"

            echo ""
            echo "Пожалуйста, запустите этот скрипт еще раз от своего пользователя: sudo $0"
            echo "Вам потребуется повторное открытие Терминала для применения изменений!"
            exit 0
        else
            echo "ОШИБКА! Не удалось установить sudo. Скрипт завершен" 1>&2
            exit 1
        fi
    fi

    if [[ "$EUID" -ne 0 ]]; then
        echo "Пожалуйста, запустите скрипт с правами sudo: sudo $0"
        exit 1
    fi

    echo "Настройка автовхода в систему от имени текущего пользователя..."

    GDM_CONFIG_FILE="/etc/gdm3/custom.conf"

    if [[ -f "$GDM_CONFIG_FILE" ]]; then
        if grep -v "^[[:space:]]*#" "$GDM_CONFIG_FILE" | grep -E -q "^[[:space:]]*AutomaticLoginEnable[[:space:]]*=[[:space:]]*true" && \
           grep -v "^[[:space:]]*#" "$GDM_CONFIG_FILE" | grep -E -q "^[[:space:]]*AutomaticLogin[[:space:]]*=[[:space:]]*${SUDO_USER:-$USER}"; then
            echo "Автовход в систему от имени текущего пользователя уже настроен!"
        else
            if ! grep -q "^[[:space:]]*\[daemon\]" "$GDM_CONFIG_FILE"; then
                sed -i '1i [daemon]' "$GDM_CONFIG_FILE"
            fi

            if grep -E -q "^[[:space:]]*#\?[[:space:]]*AutomaticLoginEnable" "$GDM_CONFIG_FILE"; then
                sed -i -E 's/^#?\s*AutomaticLoginEnable\s*=\s*.*/AutomaticLoginEnable = true/' "$GDM_CONFIG_FILE"
            fi

            if grep -E -q "^[[:space:]]*#\?[[:space:]]*AutomaticLogin[[:space:]]*=" "$GDM_CONFIG_FILE"; then
                sed -i -E "s/^#?\s*AutomaticLogin\s*=\s*.*/AutomaticLogin = ${SUDO_USER:-$USER}/" "$GDM_CONFIG_FILE"
            fi

            if ! grep -E -q "^[[:space:]]*#\?[[:space:]]*AutomaticLoginEnable" "$GDM_CONFIG_FILE"; then
                sed -i '/^[[:space:]]*\[daemon\]/a AutomaticLoginEnable = true' "$GDM_CONFIG_FILE"
            fi

            if ! grep -E -q "^[[:space:]]*#\?[[:space:]]*AutomaticLogin[[:space:]]*=" "$GDM_CONFIG_FILE"; then
                sed -i "/^[[:space:]]*AutomaticLoginEnable/a AutomaticLogin = ${SUDO_USER:-$USER}" "$GDM_CONFIG_FILE"
            fi
        fi
    else
        echo "Файл $GDM_CONFIG_FILE не найден. Пропуск этапа..."
    fi

    echo ""
    echo "Настройка русского языка в консоли..."

    ENV_FILE="/etc/environment"

    if ! grep -q 'LANG="ru_RU.UTF-8"' "$ENV_FILE"; then
        apt install -y language-pack-ru >/dev/null
        locale-gen ru_RU.UTF-8 >/dev/null
        update-locale LANG=ru_RU.UTF-8 LANGUAGE=ru_RU:ru LC_MESSAGES=ru_RU.UTF-8 >/dev/null
        echo 'export LANG="ru_RU.UTF-8"' | tee -a "$ENV_FILE" >/dev/null
    else
        echo "Русский язык в консоли уже настроен!"
    fi

    read -p "Имя компьютера [$DEF_HOSTNAME]: " NEW_HOSTNAME; NEW_HOSTNAME="${NEW_HOSTNAME:-$DEF_HOSTNAME}"
    read -p "Часовой пояс [$DEF_TIMEZONE]: " TIMEZONE; TIMEZONE="${TIMEZONE:-$DEF_TIMEZONE}"
    read -p "Размер файла подкачки [$DEF_SWAP_SIZE]: " SWAP_SIZE; SWAP_SIZE="${SWAP_SIZE:-$DEF_SWAP_SIZE}"

    echo ""
    echo "--- Настройка беспроводных сетей Wi-Fi ---"

    while [[ -z "$CLIENT_SSID" ]]; do
        read -p "Введите SSID (имя) домашней Wi-Fi сети для интернета: " CLIENT_SSID

        CLIENT_SSID=$(printf '%s\n' "$CLIENT_SSID" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

        if [[ -z "$CLIENT_SSID" ]]; then
            echo ""
            echo "Поле не может быть пустым! Попробуйте еще раз..."
        fi
    done

    while [[ -z "$CLIENT_PASS" ]]; do
        read -p "Введите ПАРОЛЬ от домашней Wi-Fi сети: " CLIENT_PASS

        CLIENT_PASS=$(printf '%s\n' "$CLIENT_PASS" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

        if [[ -z "$CLIENT_PASS" ]]; then
            echo ""
            echo "Поле не может быть пустым! Попробуйте еще раз..."
        fi
    done

    read -p "Основной шлюз домашней Wi-Fi сети: [$DEF_CLIENT_GATEWAY]: " CLIENT_GATEWAY; CLIENT_GATEWAY="${CLIENT_GATEWAY:-$DEF_CLIENT_GATEWAY}"
    read -p "Имя точки доступа (Hotspot) [$DEF_HOTSPOT_SSID]: " HOTSPOT_SSID; HOTSPOT_SSID="${HOTSPOT_SSID:-$DEF_HOTSPOT_SSID}"
    read -p "Пароль точки доступа [$DEF_HOTSPOT_PASS]: " HOTSPOT_PASS; HOTSPOT_PASS="${HOTSPOT_PASS:-$DEF_HOTSPOT_PASS}"

    echo ""
    echo "--- Настройка удаленного доступа Rathole ---"

    read -p "IP-адрес сервера [$DEF_RATHOLE_HOST]: " RATHOLE_HOST; RATHOLE_HOST="${RATHOLE_HOST:-$DEF_RATHOLE_HOST}"
    read -p "Порт сервера [$DEF_RATHOLE_PORT]: " RATHOLE_PORT; RATHOLE_PORT="${RATHOLE_PORT:-$DEF_RATHOLE_PORT}"
    read -p "Секретный токен [$DEF_RATHOLE_TOKEN]: " RATHOLE_TOKEN; RATHOLE_TOKEN="${RATHOLE_TOKEN:-$DEF_RATHOLE_TOKEN}"

    echo ""
    echo "Сохранение введенных параметров в контекст процесса настройки..."
    echo ""

    echo "NEW_HOSTNAME=\"$NEW_HOSTNAME\"" >> "$STAGE_FILE"
    echo "TIMEZONE=\"$TIMEZONE\"" >> "$STAGE_FILE"
    echo "SWAP_SIZE=\"$SWAP_SIZE\"" >> "$STAGE_FILE"
    echo "CLIENT_SSID=\"$CLIENT_SSID\"" >> "$STAGE_FILE"
    echo "CLIENT_PASS=\"$CLIENT_PASS\"" >> "$STAGE_FILE"
    echo "CLIENT_GATEWAY=\"$CLIENT_GATEWAY\"" >> "$STAGE_FILE"
    echo "HOTSPOT_SSID=\"$HOTSPOT_SSID\"" >> "$STAGE_FILE"
    echo "HOTSPOT_PASS=\"$HOTSPOT_PASS\"" >> "$STAGE_FILE"
    echo "RATHOLE_HOST=\"$RATHOLE_HOST\"" >> "$STAGE_FILE"
    echo "RATHOLE_PORT=\"$RATHOLE_PORT\"" >> "$STAGE_FILE"
    echo "RATHOLE_TOKEN=\"$RATHOLE_TOKEN\"" >> "$STAGE_FILE"

    echo "Изменение имени компьютера..."

    CURRENT_HOSTNAME=$(hostname)

    if [[ "$CURRENT_HOSTNAME" = "$NEW_HOSTNAME" ]]; then
        echo "Имя компьютера уже изменено!"
    else
        sed -i "s/\b${CURRENT_HOSTNAME}\b/${NEW_HOSTNAME}/g" /etc/hosts
        hostnamectl set-hostname "$NEW_HOSTNAME"
    fi

    echo "Установка часового пояса..."

    CURRENT_TIMEZONE=$(timedatectl show --property=Timezone --value)

    if [[ "$CURRENT_TIMEZONE" = "$TIMEZONE" ]]; then
        echo "Часовой пояс уже установлен!"
    else
        timedatectl set-timezone "$TIMEZONE"
    fi

    echo  "Установка русской раскладки клавиатуры..."

    if gsettings get org.gnome.desktop.input-sources sources 2>/dev/null | grep -q "'ru'"; then
        echo "Русская раскладка клавиатуры уже установлена!"
    else
        sudo -u "${SUDO_USER:-$USER}" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u ${SUDO_USER:-$USER})/bus" \
        gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'us'), ('xkb', 'ru')]" >/dev/null 2>&1
    fi

    echo ""
    echo "=== Сейчас откроется интерфейс настройки локализации! Выберите и примените везде русский язык и возвращайтесь в это окно. Для начала настройки нажмите [Enter]... ==="

    read -p ""

    if type -p gnome-language-selector >/dev/null; then
        sudo -u "${SUDO_USER:-$USER}" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u ${SUDO_USER:-$USER})/bus" \
        gnome-language-selector &

        read -p "Когда полностью завершите настройку русского языка в графическом окне, нажмите [Enter] для перезагрузки..."
    else
        echo "ВНИМАНИЕ: Графическая утилита настройки языка не найдена в системе"
        echo "Пожалуйста, откройте её самостоятельно через главное меню: «Параметры» -> «Язык и регион»"

        read -p "После того как примените русский язык везде, вернитесь в это окно и нажмите [Enter] для перезагрузки..."
    fi

    echo "STAGE=2" >> "$STAGE_FILE"

    echo "------------------------------------------------"
    echo "Первый этап завершен. Перезагрузка..."
    echo "После перезапуска запустите этот скрипт еще раз."
    echo "------------------------------------------------"

    sleep 3
    reboot
    exit 0
fi

if [[ "$EUID" -ne 0 ]]; then
    echo "Пожалуйста, запустите скрипт с правами sudo: sudo $0"
    exit 1
fi

source "$STAGE_FILE"

if [[ "$STAGE" == "2" ]]; then
    clear
    echo "========================================================================="
    echo "  Настройка системы для приставок CADENA Pro X (Ubuntu)                  "
    echo "========================================================================="
    echo ""
    echo "=== [ЭТАП 2] Продолжение настройки системы ==="
    echo ""

    echo "Обновление списка пакетов..."

    apt update >/dev/null || true

    echo ""
    echo "Создание файла подкачки..."

    SWAP_FILE="/swapfile"

    if [[ ! -f "$SWAP_FILE" ]]; then
        if ! fallocate -l "$SWAP_SIZE" "$SWAP_FILE" 2>/dev/null; then
            echo "fallocate не поддерживается файловой системой. Используется dd..."

            RAW_SIZE=$(echo "$SWAP_SIZE" | sed 's/[GgMm]//g')
            COUNT_MB=$(( RAW_SIZE * 1024 ))
            dd if=/dev/zero of="$SWAP_FILE" bs=1M count=$COUNT_MB status=progress
        fi

        chmod 600 "$SWAP_FILE"
        mkswap "$SWAP_FILE" >/dev/null
    else
        echo "Файл подкачки уже существует!"
    fi

    echo "Добавление файла подкачки в файловую систему..."

    FSTAB_CONFIG_FILE="/etc/fstab"

    if ! grep -q "$SWAP_FILE" "$FSTAB_CONFIG_FILE"; then
        echo "$SWAP_FILE none swap sw 0 0" | tee -a "$FSTAB_CONFIG_FILE" >/dev/null
    else
        echo "Файл подкачки уже добавлен в файловую систему!"
    fi

    echo "Монтирование файла подкачки..."

    if grep -q "$SWAP_FILE" /proc/swaps; then
        echo "Файл подкачки уже смонтирован!"
    else
        swapon "$SWAP_FILE"
    fi

    echo "Настройка стратегии использования файла подкачки..."

    SYSCTL_CONFIG_FILE="/etc/sysctl.conf"

    if grep -q "vm.swappiness" "$SYSCTL_CONFIG_FILE"; then
        if grep -E -q "^[[:space:]]*vm\.swappiness[[:space:]]*=[[:space:]]*15" "$SYSCTL_CONFIG_FILE"; then
            echo "Стратегия использования файла подкачки уже настроена!"
        else
            sed -i -E 's/^[[:space:]]*#*vm.swappiness.*/vm.swappiness=15/' "$SYSCTL_CONFIG_FILE"
        fi
    else
        echo "vm.swappiness=15" | tee -a "$SYSCTL_CONFIG_FILE" >/dev/null
    fi

    echo "Применение стратегии использования файла подкачки..."

    sysctl -p >/dev/null

    echo ""
    echo "Установка необходимых пакетов..."
    echo ""

    DEBIAN_FRONTEND=noninteractive apt install -y libopengl0 network-manager network-manager-gnome hostapd dnsmasq iw curl unzip gnome-remote-desktop logrotate cron

    echo "Удаление лишних зависимостей и очистка кэша пакетов..."

    apt autoremove --purge -y >/dev/null
    apt clean >/dev/null

    echo "Подготовка служб DHCP и точки доступа..."

    systemctl mask --now hostapd >/dev/null
    systemctl disable --now dnsmasq >/dev/null

    echo "Генерация UUID-значений для сетевых интерфейсов..."

    UUID_ETH=$(generate_uuid)
    UUID_CLIENT=$(generate_uuid)
    UUID_HOTSPOT=$(generate_uuid)

    echo "Настройка проводной сети (eth0 -> Wired)..."

    NETPLAN_ETH_FILE=$(grep -rl "eth0" /etc/netplan 2>/dev/null | head -n 1 || true)
    NETPLAN_ETH_UUID="$UUID_ETH"
    NETPLAN_ETH_NEED_UPDATE=true

    if [[ -f "$NETPLAN_ETH_FILE" ]] && grep -q "$RATHOLE_HOST" "$NETPLAN_ETH_FILE" 2>/dev/null; then
        echo "Файл настройки проводной сети (eth0 -> Wired) уже обновлен!"

        NETPLAN_ETH_NEED_UPDATE=false
    elif [[ -f "$NETPLAN_ETH_FILE" ]]; then
        echo "Найден файл настройки проводной сети (eth0 -> Wired)!"

        NETPLAN_ETH_UUID=$(echo "$NETPLAN_ETH_FILE" | sed -n 's/.*-NM-\(.*\)\.yaml/\1/p')

        if [[ -z "$NETPLAN_ETH_UUID" ]]; then
            echo "UUID сетевого интерфейса проводной сети (eth0 -> Wired) не найден! Генерируется новый UUID..."
            NETPLAN_ETH_UUID="$UUID_ETH"
        fi
    else
        echo "Файл настройки проводной сети (eth0) отсутствует. Создание файла..."

        NETPLAN_ETH_FILE="/etc/netplan/90-NM-${UUID_ETH}.yaml"
    fi

    if [[ "$NETPLAN_ETH_NEED_UPDATE" == "true" ]]; then
        echo "Запись конфигурации в файл настройки проводной сети (eth0 -> Wired)..."

        tee "$NETPLAN_ETH_FILE" >/dev/null <<EOF
network:
  version: 2
  ethernets:
    NM-${NETPLAN_ETH_UUID}:
      renderer: NetworkManager
      match:
        name: "eth0"
      dhcp4: true
      dhcp6: true
      ipv6-address-generation: "stable-privacy"
      wakeonlan: true
      routes:
        - to: ${RATHOLE_HOST}/32
          via: ${CLIENT_GATEWAY}
          metric: 5
      networkmanager:
        uuid: "${NETPLAN_ETH_UUID}"
        name: "Wired"
        passthrough:
          connection.autoconnect-priority: "-1"
          ethernet._: ""
          ipv6.ip6-privacy: "-1"
          proxy._: ""
EOF

        chmod 600 "$NETPLAN_ETH_FILE" >/dev/null
    fi

    echo "Настройка клиентского Wi-Fi (wlan0 -> Client)..."

    NETPLAN_CLIENT_FILE=$(grep -rl "wlan0" /etc/netplan 2>/dev/null | head -n 1 || true)
    NETPLAN_CLIENT_UUID="$UUID_CLIENT"
    NETPLAN_CLIENT_NEED_UPDATE=true

    if [[ -f "$NETPLAN_CLIENT_FILE" ]] && grep -q "$RATHOLE_HOST" "$NETPLAN_CLIENT_FILE" 2>/dev/null; then
        echo "Файл настройки клиентского Wi-Fi (wlan0 -> Client) уже обновлен!"

        NETPLAN_CLIENT_NEED_UPDATE=false
    elif [[ -f "$NETPLAN_CLIENT_FILE" ]]; then
        echo "Найден файл настройки клиентского Wi-Fi (wlan0 -> Client)!"

        NETPLAN_CLIENT_UUID=$(echo "$NETPLAN_CLIENT_FILE" | sed -n 's/.*-NM-\(.*\)\.yaml/\1/p')

        if [[ -z "$NETPLAN_CLIENT_UUID" ]]; then
            echo "UUID сетевого интерфейса клиентского Wi-Fi (wlan0 -> Client) не найден! Генерируется новый UUID..."
            NETPLAN_CLIENT_UUID="$UUID_CLIENT"
        fi
    else
        echo "Файл настройки клиентского Wi-Fi (wlan0 -> Client) отсутствует. Создание файла..."

        NETPLAN_CLIENT_FILE="/etc/netplan/90-NM-${UUID_CLIENT}.yaml"
    fi

    if [[ "$NETPLAN_CLIENT_NEED_UPDATE" == "true" ]]; then
        echo "Запись конфигурации в файл настройки клиентского Wi-Fi (wlan0 -> Client)..."

        tee "$NETPLAN_CLIENT_FILE" >/dev/null <<EOF
network:
  version: 2
  wifis:
    NM-${NETPLAN_CLIENT_UUID}:
      renderer: NetworkManager
      match:
        name: "wlan0"
      dhcp4: true
      dhcp6: true
      ipv6-address-generation: "stable-privacy"
      access-points:
        "${CLIENT_SSID}":
         auth:
            key-management: "psk-sha256"
            password: "${CLIENT_PASS}"
         networkmanager:
            uuid: "${NETPLAN_CLIENT_UUID}"
            name: "Client"
            passthrough:
              ipv6.ip6-privacy: "-1"
              proxy._: ""
      routes:
        - to: ${RATHOLE_HOST}/32
          via: ${CLIENT_GATEWAY}
          metric: 10
      networkmanager:
        uuid: "${NETPLAN_CLIENT_UUID}"
        name: "Client"
EOF

        chmod 600 "$NETPLAN_CLIENT_FILE" >/dev/null
    fi

    echo "Настройка точки доступа (wlan1 -> Hotspot)..."

    NETPLAN_HOTSPOT_FILE=$(grep -rl "wlan1" /etc/netplan 2>/dev/null | head -n 1 || true)
    NETPLAN_HOTSPOT_UUID="$UUID_HOTSPOT"
    NETPLAN_HOTSPOT_NEED_UPDATE=true

    if [[ -f "$NETPLAN_HOTSPOT_FILE" ]] && grep -q "$HOTSPOT_SSID" "$NETPLAN_HOTSPOT_FILE" 2>/dev/null; then
        echo "Файл настройки точки доступа (wlan1 -> Hotspot) уже обновлен!"

        NETPLAN_HOTSPOT_NEED_UPDATE=false
    elif [[ -f "$NETPLAN_HOTSPOT_FILE" ]]; then
        echo "Найден файл настройки точки доступа (wlan1 -> Hotspot)!"

        NETPLAN_HOTSPOT_UUID=$(echo "$NETPLAN_HOTSPOT_FILE" | sed -n 's/.*-NM-\(.*\)\.yaml/\1/p')

        if [[ -z "$NETPLAN_HOTSPOT_UUID" ]]; then
            echo "UUID сетевого интерфейса точки доступа (wlan1 -> Hotspot) не найден! Генерируется новый UUID..."
            NETPLAN_HOTSPOT_UUID="$UUID_HOTSPOT"
        fi
    else
        echo "Файл настройки точки доступа (wlan1 -> Hotspot) отсутствует. Создание файла..."

        NETPLAN_HOTSPOT_FILE="/etc/netplan/90-NM-${UUID_HOTSPOT}.yaml"
    fi

    if [[ "$NETPLAN_HOTSPOT_NEED_UPDATE" == "true" ]]; then
        echo "Запись конфигурации в файл настройки точки доступа (wlan1 -> Hotspot)..."

        tee "$NETPLAN_HOTSPOT_FILE" >/dev/null <<EOF
network:
  version: 2
  wifis:
    NM-${NETPLAN_HOTSPOT_UUID}:
      renderer: NetworkManager
      match:
        name: "wlan1"
      ipv6-address-generation: "stable-privacy"
      access-points:
        "${HOTSPOT_SSID}":
          auth:
            key-management: "psk-sha256"
            password: "${HOTSPOT_PASS}"
          mode: "ap"
          networkmanager:
            uuid: "${NETPLAN_HOTSPOT_UUID}"
            name: "Hotspot"
            passthrough:
              wifi-security.proto: "rsn"
              wifi-security.pairwise: "ccmp"
              wifi-security.group: "ccmp"
              ipv6.method: "shared"
              ipv6.ip6-privacy: "-1"
              proxy._: ""
      networkmanager:
        uuid: "${NETPLAN_HOTSPOT_UUID}"
        name: "Hotspot"
EOF

        chmod 600 "$NETPLAN_HOTSPOT_FILE" >/dev/null
    fi

    echo "Настройка маршрутизации трафика в NetworkManager..."

    NETWORK_MANAGER_CONFIG_FILE="/etc/NetworkManager/NetworkManager.conf"

    if grep -q "ip-forwarding" "$NETWORK_MANAGER_CONFIG_FILE"; then
        if grep -E -q "^[[:space:]]*ip-forwarding[[:space:]]*=[[:space:]]*true" "$NETWORK_MANAGER_CONFIG_FILE"; then
            echo "Маршрутизация трафика в NetworkManager уже настроена!"
        else
            sed -i -E 's/^[[:space:]]*#*ip-forwarding.*/ip-forwarding=true/' "$NETWORK_MANAGER_CONFIG_FILE"
        fi
    else
        sed -i '/^\[main\]/a ip-forwarding=true' "$NETWORK_MANAGER_CONFIG_FILE"
    fi

    echo "Очистка конфигурационных файлов устаревших менеджеров сетей..."
   
    rm -f /etc/systemd/network/* >/dev/null 2>&1
    rm -rf /etc/NetworkManager/system-connections/* >/dev/null 2>&1

    echo "Перезапуск службы NetworkManager для применения настроек..."

    rm -f /run/systemd/network/* >/dev/null 2>&1 && systemctl restart NetworkManager >/dev/null 2>&1

    echo "Настройка маршрутизации трафика в ядре Linux..."

    SYSCTL_CONFIG_IP_FORWARD_FILE="/etc/sysctl.d/99-ipforward.conf"

    if [[ ! -f "$SYSCTL_CONFIG_IP_FORWARD_FILE" ]]; then
        echo "net.ipv4.ip_forward=1" | tee "$SYSCTL_CONFIG_IP_FORWARD_FILE" >/dev/null
    else
        echo "Маршрутизация трафика в ядре Linux уже настроена!"
    fi

    echo "Применение настроек маршрутизации трафика в ядре Linux..."

    sysctl -p "$SYSCTL_CONFIG_IP_FORWARD_FILE" >/dev/null

    echo ""
    echo "Загрузка дистрибутива Happ Proxy..."

    HAPP_BIN="Happ.linux.arm64.deb"
    HAPP_URL="https://github.com/Happ-proxy/happ-desktop/releases/latest/download/$HAPP_BIN"

    if [[ ! -f "$HAPP_BIN" ]]; then
        curl -L "$HAPP_URL" -o "$HAPP_BIN"
    else
        echo "Дистрибутив Happ Proxy уже загружен!"
    fi

    echo "Установка дистрибутива Happ Proxy..."

    HAPP_APT_NAME="happ"

    if dpkg -s "$HAPP_APT_NAME" >/dev/null 2>&1; then
        echo "Дистрибутив Happ Proxy уже установлен!"
    else
        echo "Распаковка пакета Happ Proxy..."

        dpkg -i "$HAPP_BIN" >/dev/null || true

        echo "Установка недостающих зависимостей и завершение установки Happ Proxy..."

        apt install -f -y >/dev/null
    fi

    echo ""
    echo "=== Запустите Happ, введите ключ, настройте автозапуск при старте системы, автообновление подписки раз в 6 часов и автоподключение к последней локации, выберите и подключите желаемую локацию с лучшим пингом в TUN-режиме и возвращайтесь в это окно. ==="
    echo ""

    read -p "После настройки Happ нажмите [Enter]..."

    echo ""
    echo "Загрузка zip-архива Rathole..."

    RATHOLE_BIN="rathole"
    RATHOLE_ZIP="rathole-aarch64-unknown-linux-musl.zip"
    RATHOLE_URL="https://github.com/rathole-org/rathole/releases/download/v0.4.8/$RATHOLE_ZIP"

    if [[ ! -f "$SYSTEM_BIN_DIR/$RATHOLE_BIN" ]]; then
        if [[ ! -f "$RATHOLE_BIN" ]]; then
            if [[ ! -f "$RATHOLE_ZIP" ]]; then
                curl -L "$RATHOLE_URL" -o "$RATHOLE_ZIP"
            else
                echo "Zip-архив Rathole уже существует! Распаковка..."
            fi

            unzip "$RATHOLE_ZIP" >/dev/null
            chmod +x "$RATHOLE_BIN"

            echo "Исполняемый файл Rathole распакован из zip-архива!"
        else
            echo "Исполняемый файл Rathole уже загружен и распакован из zip-архива!"
        fi

        echo "Установка исполняемого файла Rathole..."

        cp "$RATHOLE_BIN" "$SYSTEM_BIN_DIR/"
        rm -f "$RATHOLE_BIN"
    else
        echo "Исполняемый файл Rathole уже установлен!"
    fi

    echo ""
    echo "Создание клиентской конфигурации Rathole..."

    RATHOLE_CONFIG_DIR="/etc/rathole"
    RATHOLE_CONFIG_FILE="client.toml"
    RATHOLE_SERVICE="rathole"

    mkdir -p "$RATHOLE_CONFIG_DIR"

    if [[ ! -f "$RATHOLE_CONFIG_DIR/$RATHOLE_CONFIG_FILE" ]]; then
        tee "$RATHOLE_CONFIG_DIR/$RATHOLE_CONFIG_FILE" >/dev/null <<EOF
[client]
remote_addr = "${RATHOLE_HOST}:${RATHOLE_PORT}"
heartbeat_timeout = 40
retry_interval = 5

[client.transport]
type = "tcp"

[client.transport.tcp]
keepalive_secs = 20
keepalive_interval = 8

[client.services.ssh]
local_addr = "127.0.0.1:22"
token = "${RATHOLE_TOKEN}"

[client.services.rdp]
local_addr = "127.0.0.1:3389"
token = "${RATHOLE_TOKEN}"
nodelay = true
EOF

        chmod 644 "$RATHOLE_CONFIG_DIR/$RATHOLE_CONFIG_FILE" >/dev/null
    else
        echo "Файл клиентской конфигурации Rathole уже существует!"
    fi

    echo "Создание системной службы Rathole..."

    SYSTEM_SERVICES_DIR="/etc/systemd/system"

    if [[ ! -f "$SYSTEM_SERVICES_DIR/$RATHOLE_SERVICE.service" ]]; then
        tee "$SYSTEM_SERVICES_DIR/$RATHOLE_SERVICE.service" >/dev/null <<EOF
[Unit]
Description=Rathole Client Service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
ExecStart=${SYSTEM_BIN_DIR}/${RATHOLE_BIN} --client ${RATHOLE_CONFIG_DIR}/${RATHOLE_CONFIG_FILE}
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

        chmod 644 "$SYSTEM_SERVICES_DIR/$RATHOLE_SERVICE.service" >/dev/null
    else
        echo "Системная служба Rathole уже существует!"
    fi

    echo "Запуск системной службы Rathole..."

    if systemctl is-active --quiet "$RATHOLE_SERVICE"; then
        echo "Системная служба Rathole уже запущена!"
    else
        systemctl enable "$RATHOLE_SERVICE" >/dev/null
        systemctl start "$RATHOLE_SERVICE" >/dev/null
    fi

    echo "Установка скрипта аварийного перезапуска Rathole..."

    RATHOLE_WATCH_BIN="rathole-client-watch.sh"

    if [[ ! -f "$SYSTEM_BIN_DIR/$RATHOLE_WATCH_BIN" ]]; then
        if [[ -f "$RATHOLE_WATCH_BIN" ]]; then
            chmod +x "$RATHOLE_WATCH_BIN"
            cp "$RATHOLE_WATCH_BIN" "$SYSTEM_BIN_DIR/"
            rm -f "$RATHOLE_WATCH_BIN"
        else
            echo "ОШИБКА! Скрипт аварийного перезапуска Rathole ($RATHOLE_WATCH_BIN) не найден в текущей папке! Настройка будет прервана." 1>&2
            exit 1
        fi
    else
        echo "Скрипт аварийного перезапуска Rathole уже установлен!"
    fi

    echo "Настройка ротации логов скрипта аварийного перезапуска Rathole..."

    RATHOLE_WATCH_LOG_FILE="/var/log/rathole-client-watch.log"
    RATHOLE_WATCH_LOG_ROTATE_FILE="/etc/logrotate.d/rathole-client-watch"

    if [[ ! -f "$RATHOLE_WATCH_LOG_ROTATE_FILE" ]]; then
        tee "$RATHOLE_WATCH_LOG_ROTATE_FILE" >/dev/null <<EOF
${RATHOLE_WATCH_LOG_FILE} {
    weekly
    rotate 4
    compress
    missingok
    notifempty
}
EOF

        chmod 644 "$RATHOLE_WATCH_LOG_ROTATE_FILE" >/dev/null
        logrotate -f "$RATHOLE_WATCH_LOG_ROTATE_FILE"
    else
        echo "Ротация логов скрипта аварийного перезапуска Rathole уже настроена!"
    fi

    echo "Настройка периодического запуска (раз в 15 минут) скрипта аварийного перезапуска Rathole..."

    CURRENT_CRON=$(crontab -l 2>/dev/null || true)
    RATHOLE_WATCH_CRON_JOB="*/15 * * * * $SYSTEM_BIN_DIR/$RATHOLE_WATCH_BIN --config $RATHOLE_CONFIG_DIR/$RATHOLE_CONFIG_FILE > /dev/null 2>&1"

    if echo "$CURRENT_CRON" | grep -Fq "$RATHOLE_WATCH_CRON_JOB"; then
        echo "Периодический запуск скрипта аварийного перезапуска Rathole уже настроен!"
    else
        { echo "$CURRENT_CRON"; echo "$RATHOLE_WATCH_CRON_JOB"; } | grep -v '^$' | crontab - >/dev/null
    fi

    echo "Настройка периодического запуска обновлений системы раз в неделю..."

    CURRENT_CRON=$(crontab -l 2>/dev/null || true)
    APT_UPGRADE_CRON_JOB="0    5 * * 0 apt update && apt upgrade -y && apt autoremove --purge -y && apt clean > /dev/null 2>&1"

    if echo "$CURRENT_CRON" | grep -Fq "$APT_UPGRADE_CRON_JOB"; then
        echo "Периодический запуск обновлений системы раз в неделю уже настроен!"
    else
        { echo "$CURRENT_CRON"; echo "$APT_UPGRADE_CRON_JOB"; } | grep -v '^$' | crontab - >/dev/null
    fi

    echo ""
    echo "Отключение вывода информации о последнем входе в баннере SSH..."

    SSHD_CONFIG_FILE="/etc/ssh/sshd_config"
    SSHD_CONFIG_DIR="/etc/ssh/sshd_config.d"
    SSHD_CONFIG_LASTLOG_FILE="00-disable-lastlog.conf"

    mkdir -p "$SSHD_CONFIG_DIR"

    if grep -E -riq "^[[:space:]]*PrintLastLog[[:space:]]+no" "$SSHD_CONFIG_FILE" "$SSHD_CONFIG_DIR/" 2>/dev/null; then
        echo "Вывод информации о последнем входе в баннере SSH уже отключено!"
    else
        echo "PrintLastLog no" | tee "$SSHD_CONFIG_DIR/$SSHD_CONFIG_LASTLOG_FILE" >/dev/null
    fi

    echo "Отключение вывода справочных ссылок о системе Ubuntu в баннере SSH..."

    UPDATE_MOTD_HELP_FILE="/etc/update-motd.d/10-help-text"

    if [[ -f "$UPDATE_MOTD_HELP_FILE" ]]; then
        if [[ ! -x "$UPDATE_MOTD_HELP_FILE" ]]; then
            echo "Вывод справочных ссылок о системе Ubuntu в баннере SSH уже отключен!"
        else
            chmod -x "$UPDATE_MOTD_HELP_FILE"
        fi
    fi

    echo "Настройка баннера на этапе ввода логина интерфейса SSH..."

    UNAUTH_SSH_BANNER="/etc/issue.net"
    UNAUTH_SSH_GREETING="Welcome to CADENA Ubuntu Server"

    if grep -q "$UNAUTH_SSH_GREETING" "$UNAUTH_SSH_BANNER" 2>/dev/null; then
        echo "Баннер на этапе ввода логина интерфейса SSH уже настроен!"
    else
        tee "$UNAUTH_SSH_BANNER" >/dev/null <<EOF
#############################################################################
#                                                                           #
#  ${UNAUTH_SSH_GREETING}                                                   #
#                                                                           #
# ------------------------------------------------------------------------- #
#                                                                           #
#  WARNING: This is a private system!                                       #
#           Unauthorized access to this system is forbidden and will be     #
#           prosecuted by law.                                              #
#           By accessing this system, you agree that your actions will be   #
#           monitored and logged.                                           #
#                                                                           #
# ------------------------------------------------------------------------- #
#                                                                           #
#  ${NEW_HOSTNAME}                                                          #
#                                                                           #
#############################################################################
EOF
    fi

    echo "Перезапуск службы SSH..."

    systemctl restart ssh >/dev/null 2>&1 || systemctl restart sshd >/dev/null 2>&1

    echo "Настройка удаленного доступа к рабочему столу (RDP)..."

    if systemctl --user is-active --quiet gnome-remote-desktop; then
        echo "RDP уже включен и работает!"
    else
        echo "RDP выключен! Требуется настройка..."
        echo ""
        echo "=== Будут открыты графические настройки удаленного рабочего стола. По окончании настройки закройте их и вернитесь в это окно. Для начала настройки нажмите [Enter] ==="

        if type -p gnome-control-center >/dev/null; then
            sudo -u "${SUDO_USER:-$USER}" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u ${SUDO_USER:-$USER})/bus" \
            gnome-control-center system remote-desktop >/dev/null 2>&1 &

            read -p "Когда полностью завершите настройку удаленного рабочего стола в графическом окне, нажмите [Enter] для продолжения..."
        else
            echo "ВНИМАНИЕ: Графическая утилита настройки удаленного рабочего стола не найдена в системе!"
            echo "Шаг будет пропущен без аварийного завершения скрипта настройки. У вас еще есть доступ по SSH"

            read -p "Нажмите [Enter] для продолжения..."
        fi
    fi

    echo ""
    echo "Удаление данных из контекста процесса настройки..."

    rm -f "$STAGE_FILE"

    echo ""
    echo "------------------------------------------------"
    echo "Все этапы успешно выполнены! Перезагрузка..."
    echo "------------------------------------------------"

    sleep 3
    reboot
fi
