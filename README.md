# tvbox-cadena-ubuntu
Ubuntu-based Wi-Fi Access Point settings scripts (xray gateway) for CADENA PRO X tv-boxes (RU)

## Source distrib
Based on https://github.com/devmfc/debian-on-amlogic

## Server additional settings
Crontab - */15 * * * * /usr/local/bin/rathole-server-watch.sh --config /etc/rathole/server.toml --service rathole > /dev/null 2>&1
