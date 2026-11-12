# Debian

Mes scripts d'installation et d'administration pour Debian (12 / 13).

## Utilisation rapide

Post-installation d'une machine fraîche (à lancer en root) :

```bash
curl -fsSL https://raw.githubusercontent.com/Bricoletonk/Debian/main/script.postinstall.sh -o postinstall.sh
bash postinstall.sh
```

## Contenu

| Dossier / fichier | Rôle |
|---|---|
| `script.postinstall.sh` | Script principal de post-installation : Nala, outils de base, Claude Code (+ Claude Desktop si interface graphique), Gemini CLI, Webmin, alias, hostname, SSH root, écran de login… |
| `postinstall/postinstall-ia.sh` | Ancienne variante orientée IA (Gemini / Shell-GPT) |
| `firewall/firewall-proxy-lan.sh` | Pare-feu iptables : passerelle LAN avec proxy |
| `firewall/iptables-apache-simple.sh` | Pare-feu iptables devant un serveur Apache (une seule carte) |
| `firewall/iptables-apache-lan.sh` | Pare-feu iptables Apache + réseau LAN (deux cartes) |
| `serveur-web-ftp/vsftpd.conf` | Configuration vsftpd avec utilisateurs virtuels |
| `serveur-web-ftp/gestion-apache-ftp.sh` | Menu de gestion des sites Apache et des utilisateurs FTP virtuels |
| `serveur-web-ftp/nouvel-utilisateur-apache.sh` | Première version (création d'utilisateur seulement) |
| `shell/colorprompt.sh` | Prompt coloré (rouge pour root) — à copier dans `/etc/profile.d/` |

⚠️ Les scripts de pare-feu contiennent des noms de cartes réseau et des adresses IP propres à un labo : adapter les variables en haut du fichier avant de les lancer.
