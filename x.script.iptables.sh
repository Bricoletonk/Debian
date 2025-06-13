#!/bin/bash

# === Variables ===
CARTE_EXT="ens18"
CARTE_LAN="ens20"
IP_APACHE="10.10.10.10"

# Nettoyage des anciennes règles
    iptables -F
    iptables -t nat -F

# Politiques par défaut : tout bloquer
    iptables -P INPUT   DROP
    iptables -P OUTPUT  DROP
    iptables -P FORWARD DROP

# <-> FORWARD <->

# <-> FTP vers le serveur Apache
    iptables -A FORWARD -p tcp      --dport 21          -d $IP_APACHE -j ACCEPT
    iptables -A FORWARD -p tcp      --sport 21          -s $IP_APACHE -j ACCEPT
    iptables -A FORWARD -p tcp      --dport 40000:50000 -d $IP_APACHE -j ACCEPT
    iptables -A FORWARD -p tcp      --sport 40000:50000 -s $IP_APACHE -j ACCEPT

# <-> Accès public : HTTP, HTTPS, SSH vers serveur Apache
    iptables -A FORWARD -p tcp      --dport 80          -d $IP_APACHE -j ACCEPT
    iptables -A FORWARD -p tcp      --dport 443         -d $IP_APACHE -j ACCEPT
    iptables -A FORWARD -p tcp      --dport 22          -d $IP_APACHE -j ACCEPT
    iptables -A FORWARD -p tcp      --dport 2222        -d $IP_APACHE -j ACCEPT

# <-> DNS, ICMP vers Apache
    iptables -A FORWARD -p udp      --dport 53          -d $IP_APACHE -j ACCEPT
    iptables -A FORWARD -p icmp                         -d $IP_APACHE -j ACCEPT

# <-> Réponses aux connexions établies
    iptables -A FORWARD -m state    --state RELATED,ESTABLISHED       -j ACCEPT

# --> NAT (DNAT pour redirection des ports publics vers le serveur Apache) -->

# --> FTP (port 21 et 40000 à 50000)
    iptables -t nat -A PREROUTING   -i $CARTE_EXT -p tcp --dport 21                -j DNAT --to-destination $IP_APACHE
    iptables -t nat -A PREROUTING   -i $CARTE_EXT -p tcp --dport 40000:50000       -j DNAT --to-destination $IP_APACHE

# --> HTTP / HTTPS
    iptables -t nat -A PREROUTING   -i $CARTE_EXT -p tcp --dport 80                -j DNAT --to-destination $IP_APACHE
    iptables -t nat -A PREROUTING   -i $CARTE_EXT -p tcp --dport 443               -j DNAT --to-destination $IP_APACHE

# --> SSH privé vers Apache
    iptables -t nat -A PREROUTING   -p tcp --dport 2222                            -j DNAT --to-destination $IP_APACHE:22

# <-- NAT (MASQUERADE) pour les connexions sortantes <--

# <-- NAT pour Apache vers Internet
    iptables -t nat -A POSTROUTING  -p tcp --dport 80   -o $CARTE_EXT -j MASQUERADE
    iptables -t nat -A POSTROUTING  -p tcp --dport 443  -o $CARTE_EXT -j MASQUERADE
    iptables -t nat -A POSTROUTING  -p udp --dport 53   -o $CARTE_EXT -j MASQUERADE
    iptables -t nat -A POSTROUTING  -p icmp             -o $CARTE_EXT -j MASQUERADE



# === Affichage final des règles ===
    echo -e "\e[1;32m→ Tables NAT \e[0m"
        iptables -t nat -vL
    echo -e "\e[1;32m→ Tables FILTER \e[0m"
        iptables -t filter -vL
