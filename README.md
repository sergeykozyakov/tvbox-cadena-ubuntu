# tvbox-cadena-ubuntu
Ubuntu-based Wi-Fi Access Point settings scripts (xray gateway) for CADENA PRO X tv-boxes (RU)

**Disclamer:** setup script now halts (and reboots a box) on _sudo netplan apply_ / _sudo systemctl restart NetworkManager_ commands due to some wlan0 device conflict. I'll try to discover and fix it later...

**Workaround:** you may comment out the wlan0 netplan config block and later set *wpa_supplicant* / *ifupdown* as a wlan0 default handler. Or just use eth0 + wlan1 as an access point.

## Source distrib
Based on https://github.com/devmfc/debian-on-amlogic

## Server additional settings (Debian/Ubuntu)

You don't need any server (VPS/VDS) in case you have static (or dynamic via DynanicDNS) **global** IP address in your place. You just need to make SSH and RDP port forwarding on your router.

### Binary:
https://github.com/rathole-org/rathole/releases/download/v0.4.8/rathole-aarch64-unknown-linux-musl.zip

### Crontab:
*/15 * * * * /usr/local/bin/rathole-server-watch.sh --config /etc/rathole/server.toml --service rathole > /dev/null 2>&1
