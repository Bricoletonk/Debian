#!/bin/bash

# Variables
CARTE_EXT="enp0s3"
IP_APACHE="10.10.1.4"

# Nettoyage des règles existantes
iptables -F
iptables -t nat -F
iptables -X
iptables -t nat -X

# Politiques par défaut
iptables -P INPUT DROP
iptables -P OUTPUT DROP
iptables -P FORWARD DROP

# Autoriser loopback
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Connexions établies/relatives
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT

# Sorties autorisées du serveur lui-même
iptables -A OUTPUT -p tcp --dport 80 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 443 -j ACCEPT
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -p icmp -j ACCEPT

# ----------------------------
# FORWARD vers le serveur Apache
# ----------------------------

# FTP (actif + passif)
iptables -A FORWARD -p tcp -d $IP_APACHE --dport 21 -j ACCEPT
iptables -A FORWARD -p tcp -s $IP_APACHE --sport 21 -j ACCEPT
iptables -A FORWARD -p tcp -d $IP_APACHE --dport 20 -j ACCEPT
iptables -A FORWARD -p tcp -s $IP_APACHE --sport 20 -j ACCEPT
iptables -A FORWARD -p tcp -d $IP_APACHE --dport 40000:50000 -j ACCEPT
iptables -A FORWARD -p tcp -s $IP_APACHE --sport 40000:50000 -j ACCEPT

# HTTP / HTTPS
iptables -A FORWARD -p tcp -d $IP_APACHE --dport 80 -j ACCEPT
iptables -A FORWARD -p tcp -d $IP_APACHE --dport 443 -j ACCEPT

# DNS
iptables -A FORWARD -p udp --dport 53 -d $IP_APACHE -j ACCEPT

# ICMP (ping)
iptables -A FORWARD -p icmp -d $IP_APACHE -j ACCEPT

# SSH (redirigé depuis 2222)
iptables -A FORWARD -p tcp -d $IP_APACHE --dport 22 -j ACCEPT

# ----------------------------
# NAT : REDIRECTIONS PUBLIQUES
# ----------------------------

# FTP
iptables -t nat -A PREROUTING -i $CARTE_EXT -p tcp --dport 21 -j DNAT --to-destination $IP_APACHE
iptables -t nat -A PREROUTING -i $CARTE_EXT -p tcp --dport 20 -j DNAT --to-destination $IP_APACHE
iptables -t nat -A PREROUTING -i $CARTE_EXT -p tcp --dport 40000:50000 -j DNAT --to-destination $IP_APACHE

# HTTP / HTTPS
iptables -t nat -A PREROUTING -i $CARTE_EXT -p tcp --dport 80 -j DNAT --to-destination $IP_APACHE
iptables -t nat -A PREROUTING -i $CARTE_EXT -p tcp --dport 443 -j DNAT --to-destination $IP_APACHE

# SSH privé (port 2222 → port 22 sur Apache)
iptables -t nat -A PREROUTING -i $CARTE_EXT -p tcp --dport 2222 -j DNAT --to-destination $IP_APACHE:22

# ----------------------------
# MASQUERADE pour le LAN/DMZ
# ----------------------------

iptables -t nat -A POSTROUTING -o $CARTE_EXT -p tcp --dport 80 -j MASQUERADE
iptables -t nat -A POSTROUTING -o $CARTE_EXT -p tcp --dport 443 -j MASQUERADE
iptables -t nat -A POSTROUTING -o $CARTE_EXT -p udp --dport 53 -j MASQUERADE
iptables -t nat -A POSTROUTING -o $CARTE_EXT -p icmp -j MASQUERADE

# ----------------------------
# Affichage des règles
# ----------------------------

iptables -t nat -nvL --line-numbers
iptables -t filter -nvL --line-numbers
