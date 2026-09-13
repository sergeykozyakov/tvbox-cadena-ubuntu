#!/bin/bash

# Clearing TCP and DNS forwarding for wlan1
iptables -t nat -D PREROUTING -i wlan1 -p tcp -j REDSOCKS_TUNNEL 2>/dev/null
iptables -t nat -D PREROUTING -i wlan1 -p udp --dport 53 -j DNAT --to-destination 10.42.0.1:53 2>/dev/null
iptables -t nat -D POSTROUTING -s 10.42.0.0/24 -j MASQUERADE 2>/dev/null

# Removing tunnel routing rules
iptables -t nat -F REDSOCKS_TUNNEL 2>/dev/null
iptables -t nat -X REDSOCKS_TUNNEL 2>/dev/null

# Restoring default MSS parameters
iptables -D FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu 2>/dev/null
