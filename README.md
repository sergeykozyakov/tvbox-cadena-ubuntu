# tvbox-cadena-ubuntu
Ubuntu-based Wi-Fi Access Point settings scripts (xray gateway) for CADENA PRO X tv-boxes (ru-RU)

## Source Ubuntu distrib
Based on https://github.com/devmfc/debian-on-amlogic

## Server additional settings (Debian/Ubuntu)

You don't need an extra server (VPS/VDS) in case you have static (or dynamic via DynanicDNS) **global** IP address in your place. You just need to make SSH and RDP port forwarding on your router.

### Binary:
https://github.com/rathole-org/rathole/releases/download/v0.4.8/rathole-aarch64-unknown-linux-musl.zip

### Crontab:
*/15 * * * * /usr/local/bin/rathole-server-watch.sh --config /etc/rathole/server.toml --service rathole > /dev/null 2>&1
