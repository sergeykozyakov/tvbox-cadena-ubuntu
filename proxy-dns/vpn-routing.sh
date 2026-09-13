#!/bin/bash

# =====================================================================
# 1. CLEARING OLD ROUTING RULES
# =====================================================================
iptables -t nat -D PREROUTING -i wlan1 -p tcp -j REDSOCKS_TUNNEL 2>/dev/null
iptables -t nat -D PREROUTING -i wlan1 -p udp --dport 53 -j DNAT --to-destination 10.42.0.1:53 2>/dev/null
iptables -t nat -D POSTROUTING -s 10.42.0.0/24 -j MASQUERADE 2>/dev/null

iptables -t nat -F REDSOCKS_TUNNEL 2>/dev/null
iptables -t nat -X REDSOCKS_TUNNEL 2>/dev/null

# =====================================================================
# 2. ADDING REDSOCKS ROUTING RULES
# =====================================================================
iptables -t nat -N REDSOCKS_TUNNEL

# Exceptions for LAN
iptables -t nat -A REDSOCKS_TUNNEL -d 0.0.0.0/8 -j RETURN
iptables -t nat -A REDSOCKS_TUNNEL -d 10.0.0.0/8 -j RETURN
iptables -t nat -A REDSOCKS_TUNNEL -d 127.0.0.0/8 -j RETURN
iptables -t nat -A REDSOCKS_TUNNEL -d 169.254.0.0/16 -j RETURN
iptables -t nat -A REDSOCKS_TUNNEL -d 172.16.0.0/12 -j RETURN
iptables -t nat -A REDSOCKS_TUNNEL -d 192.168.0.0/16 -j RETURN

# TCP traffic forwarding to Redsocks port 12345
iptables -t nat -A REDSOCKS_TUNNEL -p tcp -j REDIRECT --to-ports 12345

# =====================================================================
# 3. ACTIATING WLAN1 ROUTING
# =====================================================================
# a) Transferring all TCP client traffic to REDSOCKS_TUNNEL
iptables -t nat -A PREROUTING -i wlan1 -p tcp -j REDSOCKS_TUNNEL

# b) Transferring DNS client requests to default 10.42.0.1 address (DNS over TLS)
iptables -t nat -A PREROUTING -i wlan1 -p udp --dport 53 -j DNAT --to-destination 10.42.0.1:53

# c) Turning on MASQUERADE mode for access point clients
iptables -t nat -A POSTROUTING -s 10.42.0.0/24 -j MASQUERADE

# =====================================================================
# 4. ADDING NETWORK OPTIMIZATION (MSS Clamping)
# =====================================================================
iptables -D FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu 2>/dev/null
iptables -I FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
