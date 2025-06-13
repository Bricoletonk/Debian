#!/bin/bash

# === Variables ===
CARTE_EXT="ens18"
CARTE_LAN="ens20"
IP_APACHE="10.10.10.10"
RESEAU_LAN="172.16.2.0/24"

# === Nettoyage des anciennes règles ===
iptables -F
iptables -t nat -F

# XXX Politiques par défaut : tout bloquer XXX
iptables -P INPUT   DROP
iptables -P OUTPUT  DROP
iptables -P FORWARD DROP

# ====================
# === Règles de FORWARD ===
# ====================

# <-> FTP vers le serveur Apache
iptables -A FORWARD -p tcp --dport 21             -d $IP_APACHE -j ACCEPT
iptables -A FORWARD -p tcp --sport 21             -s $IP_APACHE -j ACCEPT
iptables -A FORWARD -p tcp --dport 40000:50000    -d $IP_APACHE -j ACCEPT
iptables -A FORWARD -p tcp --sport 40000:50000    -s $IP_APACHE -j ACCEPT

# <-> Accès public HTTP, HTTPS, SSH vers serveur Apache
iptables -A FORWARD -p tcp --dport 80             -d $IP_APACHE -j ACCEPT
iptables -A FORWARD -p tcp --dport 443            -d $IP_APACHE -j ACCEPT
iptables -A FORWARD -p tcp --dport 22             -d $IP_APACHE -j ACCEPT
iptables -A FORWARD -p tcp --dport 2222           -d $IP_APACHE -j ACCEPT

# <-> DNS, ICMP vers Apache
iptables -A FORWARD -p udp --dport 53             -d $IP_APACHE -j ACCEPT
iptables -A FORWARD -p icmp                       -d $IP_APACHE -j ACCEPT

# <-> Réponses aux connexions établies
iptables -A FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT

# ====================
# === INPUT / OUTPUT sur le firewall ===
# ====================

# --> SSH sur port 22222 (sécurisé) vers le firewall
iptables -A INPUT  -i $CARTE_EXT -p tcp --dport 22222 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A OUTPUT -o $CARTE_EXT -p tcp --sport 22222 -m state --state ESTABLISHED     -j ACCEPT

# --> Loopback
iptables -A INPUT  -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# ====================
# === NAT : PREROUTING (DNAT) ===
# ====================

# --> FTP vers Apache
iptables -t nat -A PREROUTING -i $CARTE_EXT -p tcp --dport 21             -j DNAT --to-destination $IP_APACHE
iptables -t nat -A PREROUTING -i $CARTE_EXT -p tcp --dport 40000:50000    -j DNAT --to-destination $IP_APACHE

# --> HTTP / HTTPS vers Apache
iptables -t nat -A PREROUTING -i $CARTE_EXT -p tcp --dport 80             -j DNAT --to-destination $IP_APACHE
iptables -t nat -A PREROUTING -i $CARTE_EXT -p tcp --dport 443            -j DNAT --to-destination $IP_APACHE

# --> SSH privé vers Apache
iptables -t nat -A PREROUTING -p tcp --dport 2222                         -j DNAT --to-destination $IP_APACHE:22

# ====================
# === NAT : POSTROUTING (MASQUERADE) ===
# ====================

# <-- Apache vers Internet
iptables -t nat -A POSTROUTING -p tcp --dport 80   -o $CARTE_EXT -j MASQUERADE
iptables -t nat -A POSTROUTING -p tcp --dport 443  -o $CARTE_EXT -j MASQUERADE
iptables -t nat -A POSTROUTING -p udp --dport 53   -o $CARTE_EXT -j MASQUERADE
iptables -t nat -A POSTROUTING -p icmp             -o $CARTE_EXT -j MASQUERADE

# <-- LAN vers Internet
iptables -t nat -A POSTROUTING -s $RESEAU_LAN -o $CARTE_EXT -j MASQUERADE

# ====================
# === FORWARD LAN ===
# ====================

# <-> Le LAN peut accéder à Internet
iptables -A FORWARD -s $RESEAU_LAN -p tcp --dport 80   -j ACCEPT
iptables -A FORWARD -s $RESEAU_LAN -p tcp --dport 443  -j ACCEPT
iptables -A FORWARD -s $RESEAU_LAN -p udp --dport 53   -j ACCEPT
iptables -A FORWARD -s $RESEAU_LAN -p icmp             -j ACCEPT

# <-> Le LAN peut accéder au serveur Apache
iptables -A FORWARD -s $RESEAU_LAN -d $IP_APACHE -p tcp --dport 80             -j ACCEPT
iptables -A FORWARD -s $RESEAU_LAN -d $IP_APACHE -p tcp --dport 443            -j ACCEPT
iptables -A FORWARD -s $RESEAU_LAN -d $IP_APACHE -p tcp --dport 21             -j ACCEPT
iptables -A FORWARD -s $RESEAU_LAN -d $IP_APACHE -p tcp --dport 22             -j ACCEPT
iptables -A FORWARD -s $RESEAU_LAN -d $IP_APACHE -p tcp --dport 40000:50000    -j ACCEPT

# ====================
# === Affichage final des règles avec couleurs ===
# ====================

echo -e "\n\e[1;35m╔════════════════════════════╗"
echo -e "║        TABLE NAT          ║"
echo -e "╚════════════════════════════╝\e[0m"
echo -e "\e[0;36m"
iptables -t nat -vL
echo -e "\e[0m"

echo -e "\n\e[1;34m╔════════════════════════════╗"
echo -e "║       TABLE FILTER        ║"
echo -e "╚════════════════════════════╝\e[0m"
echo -e "\e[0;37m"
iptables -t filter -vL
echo -e "\e[0m"
