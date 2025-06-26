#!/bin/bash

# === Variables ===
CARTE_EXT="enp0s3"
CARTE_LAN="enp0s8"
RESEAU_LAN="10.10.14.0/24"
IP_PROXY="10.10.14.5"

# === Nettoyage des anciennes règles ===
        iptables -F
        iptables -t nat -F

# XXX Politiques par défaut : tout bloquer XXX
        iptables -P INPUT   DROP
        iptables -P OUTPUT  DROP
        iptables -P FORWARD DROP

# ====================
#  >|< INPUT / OUTPUT sur le firewall
# ====================

# ->| SSH sur port 22222 (sécurisé) vers le firewall
        iptables -t filter      -A INPUT  -i $CARTE_EXT -p tcp --dport 22222 -m state --state NEW,ESTABLISHED -j ACCEPT
        iptables -t filter      -A OUTPUT -o $CARTE_EXT -p tcp --sport 22222 -m state --state ESTABLISHED     -j ACCEPT

# --> Loopback (le firewall se contacte lui-même)
        iptables -t filter      -A INPUT  -i lo                                         -j ACCEPT
        iptables -t filter      -A OUTPUT -o lo                                         -j ACCEPT

# <-- Le firewall peut faire des requêtes sortantes vers Internet
        iptables -t filter      -A OUTPUT       -p udp  --dport 53                      -j ACCEPT
        iptables -t filter      -A OUTPUT       -p tcp  --dport 53                      -j ACCEPT
        iptables -t filter      -A OUTPUT       -p tcp  --dport 80:443                  -j ACCEPT

# ICMP (ping)
        iptables -t filter      -A OUTPUT       -p icmp                                 -j ACCEPT
        iptables -t filter      -A INPUT        -p icmp                                 -j ACCEPT

# Autoriser les réponses aux connexions initiées par le firewall
        iptables -t filter      -A INPUT        -m state --state ESTABLISHED,RELATED    -j ACCEPT
        iptables -t filter      -A OUTPUT       -m state --state NEW,RELATED            -j ACCEPT

# ====================
#  <-> Règles de FORWARD globale
# ====================
        iptables -t filter      -A FORWARD      -m state --state RELATED,ESTABLISHED    -j ACCEPT

# ====================
#  <-> FORWARD PROXY
# ====================
# <-> Le PROXY peut accéder à Internet
        iptables -t filter      -A FORWARD -s $IP_PROXY         -p tcp          --dport 80:443          -j ACCEPT
        iptables -t filter      -A FORWARD -s $IP_PROXY         -p udp          --dport 53              -j ACCEPT
        iptables -t filter      -A FORWARD -s $IP_PROXY         -p icmp                                 -j ACCEPT

# ====================
#  <-> Règles de NAT pour le PROXY
# ====================
#       <-- POSTROUTING
        iptables -t nat         -A POSTROUTING  -o $CARTE_EXT   -s $IP_PROXY    -p tcp  --dport 80:443  -j MASQUERADE
        iptables -t nat         -A POSTROUTING  -o $CARTE_EXT   -s $IP_PROXY    -p udp  --dport 53      -j MASQUERADE
        iptables -t nat         -A POSTROUTING  -o $CARTE_EXT   -s $IP_PROXY    -p icmp                 -j MASQUERADE

# Port personnalisé pour Webadmin
        iptables -t nat         -A PREROUTING   -i $CARTE_EXT                   -p tcp  --dport 12000   -j DNAT --to-destination $IP_PROXY:12000
        iptables -t nat         -A POSTROUTING  -o $CARTE_EXT   -s $IP_PROXY    -p tcp  --dport 12000   -j MASQUERADE
        iptables -t filter      -A FORWARD                      -s $IP_PROXY    -p tcp  --dport 12000   -j ACCEPT
        iptables -t filter      -A FORWARD      -i $CARTE_EXT                   -p tcp  --dport 12000   -j ACCEPT
# ====================
#  Affichage des règles
# ====================

        echo -e "\n\e[1;35m╔════════════════════════════╗"
        echo -e "║        TABLE NAT           ║"
        echo -e "╚════════════════════════════╝\e[0m"
        echo -e "\e[0;35m"
                iptables -t nat -vL
        echo -e "\e[0m"

        echo -e "\n\e[1;34m╔════════════════════════════╗"
        echo -e "║       TABLE FILTER         ║"
        echo -e "╚════════════════════════════╝\e[0m"
        echo -e "\e[0;36m"
                iptables -t filter -vL
        echo -e "\e[0m"
