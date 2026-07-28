# tvbox-cadena-ubuntu
Ubuntu-based Wi-Fi Access Point settings scripts (xray gateway) for CADENA PRO X tv-boxes (ru-RU)

## Source Ubuntu distrib
Based on https://github.com/devmfc/debian-on-amlogic

## How to use
To make all these sh-files executable do not forget to run `chmod +x *.sh` on their location directory.
Place all sh-install files (`install` directory) to your home directory. Use in graphical mode.

## Project structure

```
├── install/                     # directory for tv-box installation
│   └── system-setup.sh          # run this script for installation
├── server/                      # (optional) SSH/RDP port-forwarding server settings (copy files as located)
└── utils/                       # directory for tv-box every-day helpers
    ├── restart-session.sh       # use it for RDP mode restore after hang-ups and for xray server quick restart
    └── happ-info.conf           # show current xray server (gateway) name and settings
```

## Server additional settings (Debian/Ubuntu)

You don't need an extra server (VPS/VDS) in case you have static (or dynamic via DynanicDNS) **global** IP address in your place. You just need to make SSH and RDP port forwarding on your router.

### Binary:
https://github.com/rathole-org/rathole/releases/download/v0.4.8/rathole-aarch64-unknown-linux-musl.zip

### Crontab:
*/15 * * * * /root/rathole-server-watch.sh --config /etc/rathole/server.toml --service rathole >/dev/null 2>&1
