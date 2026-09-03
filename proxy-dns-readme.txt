sudo apt update && sudo apt install redsocks iptables  -y

sudo nano /etc/redsocks.conf

====

redsocks {
    local_ip = 0.0.0.0;
    local_port = 12345;

    ip = 127.0.0.1;
    port = 10808;
    type = socks5;
}

====

sudo systemctl enable --now redsocks

sudo nano /usr/local/bin/vpn-routing.sh

sudo chmod +x /usr/local/bin/vpn-routing.sh

====

#!/bin/bash

# 1. Удаляем только наши старые правила для wlan1, чтобы не было дубликатов
# При этом системные правила Ubuntu и NetworkManager остаются нетронутыми
iptables -t nat -D PREROUTING -i wlan1 -p tcp -j REDSOCKS_TUNNEL 2>/dev/null
iptables -t nat -D PREROUTING -i wlan1 -p udp --dport 53 -j DNAT --to-destination 10.42.0.1:53 2>/dev/null
iptables -t nat -F REDSOCKS_TUNNEL 2>/dev/null
iptables -t nat -X REDSOCKS_TUNNEL 2>/dev/null

# 2. Создаем чистую изолированную цепочку правил
iptables -t nat -N REDSOCKS_TUNNEL

# 3. Исключаем из проксирования локальные подсети
iptables -t nat -A REDSOCKS_TUNNEL -d 0.0.0.0/8 -j RETURN
iptables -t nat -A REDSOCKS_TUNNEL -d 10.0.0.0/8 -j RETURN
iptables -t nat -A REDSOCKS_TUNNEL -d 127.0.0.0/8 -j RETURN
iptables -t nat -A REDSOCKS_TUNNEL -d 169.254.0.0/16 -j RETURN
iptables -t nat -A REDSOCKS_TUNNEL -d 172.16.0.0/12 -j RETURN
iptables -t nat -A REDSOCKS_TUNNEL -d 192.168.0.0/16 -j RETURN

# 4. Заворачиваем весь TCP-трафик смартфона в redsocks (порт 12345)
iptables -t nat -A REDSOCKS_TUNNEL -p tcp -j REDIRECT --to-ports 12345
iptables -t nat -A PREROUTING -i wlan1 -p tcp -j REDSOCKS_TUNNEL

# 5. Перенаправляем DNS смартфона на ваш рабочий 10.42.0.1 NetworkManager
iptables -t nat -A PREROUTING -i wlan1 -p udp --dport 53 -j DNAT --to-destination 10.42.0.1:53

# 6. Включаем маскарадинг ТОЛЬКО для подсети смартфона
iptables -t nat -A POSTROUTING -s 10.42.0.0/24 -j MASQUERADE

# 7. КРИТИЧЕСКИЙ ШАГ ДЛЯ YOUTUBE: Оптимизируем размер TCP-пакетов (MSS Clamping)
# Без этого правила тяжелые зашифрованные TLS-пакеты блокируются DPI провайдера
iptables -I FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu

====

sudo nano /etc/systemd/system/vpn-routing.service

====
[Unit]
Description=Постоянный роутинг для раздачи VPN через redsocks
After=network-online.target redsocks.service
Wants=network-online.target redsocks.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/bin/vpn-routing.sh

[Install]
WantedBy=multi-user.target
====

sudo systemctl daemon-reload
sudo systemctl enable --now vpn-routing.service
