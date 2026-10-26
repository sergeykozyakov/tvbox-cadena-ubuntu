# tvbox-cadena-ubuntu
Ubuntu-based Wi-Fi Access Point settings scripts (xray gateway) for CADENA PRO X tv-boxes (ru-RU)

## Source Ubuntu distrib
Based on https://github.com/devmfc/debian-on-amlogic

! You must have Ubuntu version with minimal graphic desktop installed on your tv-box !

## How to use
To make all these sh-files executable do not forget to run `chmod +x *.sh` on their location directory.
Place all sh-install files (`install` directory) to your home directory.

## Project structure

```
├── install/                     # directory for tv-box installation
│   ├── system-setup.sh          # run this script for installation (non-root user in graphic mode ONLY!!!)
│   ├── rathole-client-watch.sh  # SSH/RDP port-forwarding healthcheck/restart script (used by service)
│   └── upgrade-happ.sh          # xray server (gateway) 2-weekly auto upgrades (used by service)
├── proxy-dns/                   # directory for SOCKS5 + DNS over TLS installation (see README.MD inside)
│   ├── vpn-routing.sh           # start proxy routing shell-script (used by service)
│   └── vpn-clear.sh             # stop proxy routing shell-script (used by service)
├── server/                      # (optional) SSH/RDP port-forwarding server settings (copy files as located)
└── utils/                       # directory for tv-box every-day helpers
    ├── restart-session.sh       # use it for RDP mode restore after hang-ups and for xray server quick restart     └── show-upgraded-conf.sh    # show Unattended-Upgrades config files conflict list
```

## Unattended-Upgrades sendmail settings

In order to be informed about config upgrade conflicts (and to resolve them manually later) you may optionally put down some lines to configure notifications. By default, configs remain old ones with updated versions stored separately.

Install `msmtp` and choose **no** for `AppArmor` support

```
sudo apt update && sudo apt install -y msmtp
sudo touch /var/log/msmtp.log && sudo chmod 666 /var/log/msmtp.log

sudo ln -sf /usr/bin/msmtp /usr/sbin/sendmail
sudo ln -sf /usr/bin/msmtp /usr/bin/sendmail

sudo nano /etc/msmtprc
```

Add this to empty file:

```
defaults
auth             on
tls              on
tls_starttls     on
tls_certcheck    off
logfile          /var/log/msmtp.log

account          example
host             smtp.example.com
port             587
from             your_mail@example.com
user             your_mail@example.com
password         your_smtp_password

account default : example.com
```

Open the main `Unattended-Upgrades` config

```
sudo nano /etc/apt/apt.conf.d/50unattended-upgrades
```

Edit file (uncomment or add lines) like this:

```
Unattended-Upgrade::Mail "yet_another_mail@example.com";
Unattended-Upgrade::Sender "your_mail@example.com";

Unattended-Upgrade::MailReport "only-on-error";
```

Create `logrotate` config for sent mails list

```
sudo nano /etc/logrotate.d/msmtp
```

Add this to empty file:

```
/var/log/msmtp.log {
    weekly
    rotate 4
    compress
    missingok
    notifempty
}
```

Open system `hosts` file

```
sudo nano /etc/hosts
```

Place `localhost` right after your unique host name (important for mail subject):

```
# 127.0.0.1 localhost
# 127.0.0.1 your-server-host
127.0.0.1 your-server-host localhost
```

In case you still have to use `AppArmor`, here is the code to force the log file permissions:

```
sudo nano /etc/apparmor.d/usr.bin.msmtp
```

Add this line to the bottom of the config (before the last `}`):

```
  /var/log/msmtp.log rwk,
```

Restart AppArmor daemon

```
sudo systemctl restart apparmor
```

Now you can also add an `--email` argument to `upgrade-happ.sh` script to receice e-mails about upgrade errors:

```
sudo ./upgrade-happ.sh --email yet_another_mail@example.com >> upgrade_history.log 2>&1
```

## Server additional settings (Debian/Ubuntu)

You don't need an extra server (VPS/VDS) in case you have static (or dynamic via DynanicDNS) **global** IP address in your place. You just need to make SSH and RDP port forwarding on your router.

### Binary:
https://github.com/rathole-org/rathole/releases/download/v0.4.8/rathole-aarch64-unknown-linux-musl.zip

### Crontab:

```
*/15 * * * * /root/rathole-server-watch.sh --config /etc/rathole/server.toml --service rathole >/dev/null 2>&1
```
