1. Turn **on** special `Happ` checkboxes:

```
a. Settings -> Allow LAN connections
b. Settings -> Subscriptions -> Alternative HWID
```

2. Make sure **SOCKS5 port** is `10808` (`Settings -> Allow LAN connections`)

3. Update `Happ` `User-Agent` value by the mask (`Settings -> Subscriptions`):

```
Safari/*.*.*/MacOS/*******
```
*(Neither Happ nor Linux recommended!)*

4. Install `Redsocks` SOCKS5 proxy-server and `iptables` ip-routing utility:

```
sudo apt update && sudo apt install redsocks iptables  -y
```

5. Edit `Redsocks` config file:

```
sudo nano /etc/redsocks.conf
```

6. Modify the config to be like this (search for `redsocks` section):

```
redsocks {
    local_ip = 0.0.0.0;
    local_port = 12345;

    ip = 127.0.0.1;
    port = 10808;
    type = socks5;
}
```

7. Enable and restart `Redsocks` service to apply changes:

```
sudo systemctl enable --now redsocks
```

8. Edit `Ubuntu system network resolver` config file:

```
sudo nano /etc/systemd/resolved.conf
```

9. Modify the config to be like this (search for `Resolve` section):

```
[Resolve]
DNS=1.1.1.1 8.8.8.8
FallbackDNS=9.9.9.9
DNSOverTLS=yes
```

10. Copy prepared shell-scripts, configs and services from current directory:

```
sudo cp vpn-routing.sh /usr/local/bin/
sudo cp vpn-clear.sh /usr/local/bin/

sudo cp vpn-routing.service /etc/systemd/system/

sudo cp secure-dns.conf /etc/NetworkManager/dnsmasq.d/
```

11. Make prepared scripts executable:

```
sudo chmod +x /usr/local/bin/vpn-routing.sh
sudo chmod +x /usr/local/bin/vpn-clear.sh
```

12. Restart all dependend services:

```
sudo systemctl daemon-reload

sudo systemctl restart systemd-resolved
sudo systemctl restart NetworkManager
sudo systemctl restart redsocks
```

13. Enable new routing service:

```
sudo systemctl enable --now vpn-routing.service
```
