# Debian

Mes scripts d'installation et d'administration pour Debian (12 / 13), et un équivalent pour Manjaro.

## Utilisation rapide

Post-installation d'une machine fraîche (à lancer en root) :

```bash
curl -fsSL https://raw.githubusercontent.com/Bricoletonk/Debian/main/script.postinstall.sh -o postinstall.sh
bash postinstall.sh
```

Post-installation Manjaro (à lancer avec sudo depuis son utilisateur normal) :

```bash
curl -fsSL https://raw.githubusercontent.com/Bricoletonk/Debian/main/manjaro/postinstall-manjaro.sh -o postinstall-manjaro.sh
sudo bash postinstall-manjaro.sh
```

## Contenu

| Dossier / fichier | Rôle |
|---|---|
| `script.postinstall.sh` | Script principal de post-installation : Nala, outils de base, Claude Code (+ Claude Desktop si interface graphique), Gemini CLI, Webmin, alias, hostname, SSH root, écran de login, TRIM SSD, Conky adapté au modèle, mises à jour de sécurité automatiques, pare-feu ufw, journal dans /var/log… |
| `manjaro/postinstall-manjaro.sh` | Équivalent pour Manjaro / Arch : miroirs + mise à jour, outils, Tailscale, Claude Code, Gemini CLI, SSH, alias bash **et** zsh, Conky adapté au modèle, Timeshift, pare-feu ufw, TRIM SSD, nettoyage du cache pacman, journal dans /var/log |
| `shell/colorprompt.sh` | Prompt coloré (rouge pour root) — à copier dans `/etc/profile.d/` |

Les scripts de mes labos TSPCR (pare-feu iptables, serveur web + FTP) ont été déplacés, corrigés, dans le dépôt [tspcr32](https://github.com/Bricoletonk/tspcr32).
