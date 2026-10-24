#!/bin/bash

# Arrête le script immédiatement si une commande critique échoue
set -e

# Vérifie que le script est exécuté en tant que root
if [[ $EUID -ne 0 ]]; then
    echo -e "\e[1;31mCe script doit être exécuté en tant que root.\e[0m"
    exit 1
fi

ask() {
    local prompt="$1"
    local varname="$2"
    read -e -p "$(echo -e "\e[1;33m$prompt\e[0m") " "$varname"
}

# Détection de nala (initiale)
if command -v nala >/dev/null 2>&1; then
    INSTALLER="nala"
    echo -e "\e[1;32m→ Nala déjà installé : les paquets seront installés avec nala.\e[0m"
else
    INSTALLER="apt"
    echo -e "\e[1;33m→ Nala non détecté : on utilisera apt par défaut (à moins qu'il soit sélectionné plus tard).\e[0m"
fi

# Détection interface graphique
if pgrep -x "Xorg" >/dev/null || pgrep -x "gnome-session" >/dev/null || \
   pgrep -x "sddm" >/dev/null || pgrep -x "gdm" >/dev/null || pgrep -x "lightdm" >/dev/null; then
    HAS_GUI=true
    echo -e "\e[1;32m→ Interface graphique détectée.\e[0m"
else
    HAS_GUI=false
    echo -e "\e[1;33m→ Pas d'interface graphique détectée.\e[0m"
fi

# Test eza/exa dispo dynamiquement pour l'affichage
if apt-cache show eza >/dev/null 2>&1; then
    LS_PKG="eza"
    LS_DESC="Remplaçant moderne de 'ls' (eza)"
elif apt-cache show exa >/dev/null 2>&1; then
    LS_PKG="exa"
    LS_DESC="Remplaçant moderne de 'ls' (exa)"
else
    LS_PKG=""
fi

declare -A packages=(
    [bat]="Remplaçant de 'cat' avec coloration syntaxique"
    [btop]="Moniteur système moderne (remplaçant de htop)"
    [info]="Affiche la documentation GNU"
    [inxi]="Outil complet d’information système"
    [nala]="Interface améliorée pour apt"
    [screenfetch]="Affiche les infos système en ASCII"
    [tgpt]="Assistant IA autonome en ligne de commande (sans clé API)"
    [webmin]="Interface web d'administration système (port 10000)"
)

if [[ -n "$LS_PKG" ]]; then
    packages[$LS_PKG]="$LS_DESC"
fi

if [[ "$HAS_GUI" == true ]]; then
    packages[fun]="Utilitaires fun : cbonsai, cmatrix, tty-clock, sl"
    packages[lm-sensors]="Surveille les capteurs matériels"
    packages[gemini-cli]="Assistant IA de Google (nécessite Node.js)"
fi

fun_tools=(cbonsai cmatrix tty-clock sl)
selected=()

echo -e "\n\e[1;36m===== SÉLECTION DES LOGICIELS =====\e[0m"

for pkg in $(printf '%s\n' "${!packages[@]}" | sort); do
    ask "Souhaitez-vous installer ${pkg} (${packages[$pkg]}) ? [o/N]" answer
    if [[ "$answer" =~ ^[oOyY]$ ]]; then
        if [[ "$pkg" == "fun" ]]; then
            selected+=("${fun_tools[@]}")
        else
            selected+=("$pkg")
        fi
    fi
done

ask "Souhaitez-vous ajouter manuellement des logiciels supplémentaires ? (ex: apache2 vim curl) [o/N]" custom_ans
if [[ "$custom_ans" =~ ^[oOyY]$ ]]; then
    ask "Entrez les noms des paquets à ajouter (séparés par des espaces) :" custom_packages
    if [[ -n "$custom_packages" ]]; then
        selected+=($custom_packages) # Pas de guillemets pour séparer les éléments
    fi
fi

if [ ${#selected[@]} -gt 0 ]; then
    echo -e "\n\e[1;36m===== INSTALLATION =====\e[0m"
    
    # 1. Installation de Nala en priorité absolue si sélectionné
    if [[ " ${selected[*]} " =~ " nala " ]]; then
        if ! command -v nala >/dev/null 2>&1; then
            echo -e "\e[1;34m→ Installation de Nala en priorité...\e[0m"
            apt update
            apt install -y nala
        fi
        INSTALLER="nala"
        # On supprime nala du tableau pour ne pas le réinstaller
        selected=("${selected[@]/nala/}")
    fi

    # 2. Gestion du dépôt Webmin (doit être fait avant de vérifier la présence du paquet)
    if [[ " ${selected[*]} " =~ " webmin " ]]; then
        echo -e "\e[1;34m→ Configuration du dépôt Webmin...\e[0m"
        $INSTALLER update
        $INSTALLER install -y wget gnupg2 software-properties-common apt-transport-https ca-certificates
        wget -q https://download.webmin.com/jcameron-key.asc -O- | gpg --dearmor > /etc/apt/trusted.gpg.d/webmin.gpg
        echo "deb https://download.webmin.com/download/repository sarge contrib" > /etc/apt/sources.list.d/webmin.list
        $INSTALLER update
    fi

    # 3. Vérification de l'existence des paquets avant de lancer l'installation groupée
    valid_packages=()
    failed_packages=()

    echo -e "\e[1;34m→ Vérification de la disponibilité des paquets...\e[0m"
    for pkg in "${selected[@]}"; do
        # On exclut les paquets qui ne s'installent pas via APT
        if [[ "$pkg" == "tgpt" ]] || [[ "$pkg" == "gemini-cli" ]] || [[ -z "$pkg" ]]; then
            continue
        fi

        if apt-cache show "$pkg" >/dev/null 2>&1; then
            valid_packages+=("$pkg")
        else
            failed_packages+=("$pkg")
        fi
    done

    # 4. Installation groupée
    if [ ${#valid_packages[@]} -gt 0 ]; then
        echo -e "\e[1;34m→ Installation en bloc avec $INSTALLER de : ${valid_packages[*]}\e[0m"
        $INSTALLER install -y "${valid_packages[@]}"
    fi

    if [[ " ${selected[*]} " =~ " webmin " ]]; then
        echo -e "\e[1;32m→ Webmin installé avec succès.\e[0m"
        echo -e "\e[1;33mAccédez à Webmin : https://$(hostname -I | awk '{print $1}'):10000\e[0m"
    fi
else
    echo -e "\e[1;33mAucun paquet sélectionné pour l'installation.\e[0m"
fi

# TGPT
if [[ " ${selected[*]} " =~ " tgpt " ]]; then
    echo -e "\n\e[1;36m→ Installation de TGPT...\e[0m"
    curl -sSL https://raw.githubusercontent.com/aandrew-me/tgpt/main/install | bash -s /usr/local/bin
    echo -e "\e[1;32m→ TGPT installé avec succès.\e[0m"
fi

# Gemini CLI
if [[ " ${selected[*]} " =~ " gemini-cli " ]]; then
    echo -e "\n\e[1;36m→ Installation de Gemini CLI via Node.js...\e[0m"
    # Installation globale et propre de Node.js via NodeSource
    curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
    $INSTALLER install -y nodejs
    npm install -g @google/gemini-cli
    echo -e "\e[1;32m→ Gemini CLI installé. Lancez 'gemini auth' pour configurer.\e[0m"
fi

# lm-sensors
if [[ " ${selected[*]} " =~ " lm-sensors " ]]; then
    echo -e "\n\e[1;34m→ Configuration des capteurs matériels...\e[0m"
    yes | sensors-detect
fi

# === ALIAS INTELLIGENTS ===
echo -e "\n\e[1;34m→ Configuration des alias intelligents...\e[0m"

# On prépare le bloc d'alias selon ce qui est VRAIMENT installé
ALIAS_BLOCK="\n# === DEBUT ALIAS PERSONNALISES ==="
if command -v nala >/dev/null 2>&1; then ALIAS_BLOCK+="\nalias apt='nala'"; fi
if command -v eza >/dev/null 2>&1; then ALIAS_BLOCK+="\nalias la='eza -laT'\nalias ll='eza -lT'\nalias ls='eza'"
elif command -v exa >/dev/null 2>&1; then ALIAS_BLOCK+="\nalias la='exa -laT'\nalias ll='exa -lT'\nalias ls='exa'"; fi
if command -v batcat >/dev/null 2>&1; then ALIAS_BLOCK+="\nalias cat='batcat'"; fi
if command -v btop >/dev/null 2>&1; then ALIAS_BLOCK+="\nalias top='btop'"; fi
ALIAS_BLOCK+="\nalias ip='ip -c'\nalias man='info'\n# === FIN ALIAS PERSONNALISES ===\n"

# Application des alias à Root, Skel (futurs utilisateurs) et Utilisateurs existants (/home)
for bashrc in "/root/.bashrc" "/etc/skel/.bashrc" /home/*/.bashrc; do
    if [ -f "$bashrc" ]; then
        # Nettoyage des anciens alias pour éviter les doublons
        sed -i '/# === DEBUT ALIAS PERSONNALISES ===/,/# === FIN ALIAS PERSONNALISES ===/d' "$bashrc"
        echo -e "$ALIAS_BLOCK" >> "$bashrc"
    fi
done

# === PROMPTS (ROOT & UTILISATEURS) ===
echo -e "\e[1;34m→ Configuration des prompts (Bash)...\e[0m"

# Root
ROOT_BASHRC="/root/.bashrc"
ROOT_PROMPT='\\[\\e[1;31m\\][ \\u@\\h ]\\[\\e[0;37m\\] \\w #\\[\\e[0m\\]'
sed -i '/# Prompt root personnalisé/,$d' "$ROOT_BASHRC"
echo "# Prompt root personnalisé" >> "$ROOT_BASHRC"
echo "export PS1=\"$ROOT_PROMPT\"" >> "$ROOT_BASHRC"

# Utilisateurs existants et futurs
USER_PROMPT_BLOCK="
# === DEBUT PROMPT UTILISATEUR ===
GREEN='\\[\\e[1;32m\\]'
WHITE='\\[\\e[0;37m\\]'
RESET='\\[\\e[0m\\]'
export PS1=\"\${WHITE}[ \${GREEN}\\u@\\h\${WHITE} ] \\w \\\$\${RESET} \"
# === FIN PROMPT UTILISATEUR ===
"

for bashrc in "/etc/skel/.bashrc" /home/*/.bashrc; do
    if [ -f "$bashrc" ]; then
        sed -i '/# === DEBUT PROMPT UTILISATEUR ===/,/# === FIN PROMPT UTILISATEUR ===/d' "$bashrc"
        echo -e "$USER_PROMPT_BLOCK" >> "$bashrc"
    fi
done

# Hostname
ask "Souhaitez-vous changer le nom de la machine (hostname) ? [o/N]" change_host
if [[ "$change_host" =~ ^[oOyY]$ ]]; then
    ask "Entrez le nouveau nom de la machine :" new_hostname
    echo "$new_hostname" > /etc/hostname
    hostnamectl set-hostname "$new_hostname"
    echo -e "\e[1;32m→ Nom de la machine changé en $new_hostname\e[0m"
fi

# SSH root
ask "Souhaitez-vous activer l’accès SSH pour root ? [o/N]" ssh_root_ans
if [[ "$ssh_root_ans" =~ ^[oOyY]$ ]]; then
    SSH_CONF="/etc/ssh/sshd_config"
    if grep -q "^#\?PermitRootLogin" "$SSH_CONF"; then
        sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' "$SSH_CONF"
    else
        echo "PermitRootLogin yes" >> "$SSH_CONF"
    fi
    systemctl restart ssh
    echo -e "\e[1;32m→ Accès SSH root activé (SSH redémarré).\e[0m"
fi

# /etc/issue customization et nettoyage MOTD (Garanties de base)
ask "Souhaitez-vous afficher des infos système avant le login (dans /etc/issue) ? [o/N]" issue_ans
if [[ "$issue_ans" =~ ^[oOyY]$ ]]; then
    echo -e "\n\e[1;36m→ Configuration de /etc/issue et nettoyage des messages par défaut\e[0m"
    
    # Vide le MOTD classique qui contient les garanties Debian/Ubuntu
    > /etc/motd
    
    # Désactive les scripts de MOTD dynamique qui recréent les mentions légales
    if [ -d /etc/update-motd.d ]; then
        chmod -x /etc/update-motd.d/* 2>/dev/null || true
    fi

    declare -A issue_opts=(
        [ip]="Afficher l'adresse IP"
        [hostname]="Afficher le nom de la machine (hostname)"
        [kernel]="Afficher la version du noyau (kernel)"
        [date]="Afficher la date"
        [console]="Afficher la console (tty)"
    )
    issue_display=""

    for key in ip hostname kernel date console; do
        ask "Souhaitez-vous ${issue_opts[$key]} ? [o/N]" ans
        if [[ "$ans" =~ ^[oOyY]$ ]]; then
            issue_display+="$key "
        fi
    done

    # Construction du contenu
    {
        echo -e "Debian GNU/Linux \s \r (\m)\n"
        [[ $issue_display =~ hostname ]] && echo "Hostname : \n"
        [[ $issue_display =~ date ]] && echo "Date     : \d"
        [[ $issue_display =~ kernel ]] && echo "Kernel   : \v"
        [[ $issue_display =~ console ]] && echo "Console  : \l"
        
        if [[ $issue_display =~ ip ]]; then
            echo -e "\nAdresses IP (IPv4 / IPv6) :"
            echo "  \4"
            echo "  \6"
        fi
        echo
    } > /etc/issue

    echo -e "\e[1;32m→ Messages de base nettoyés et /etc/issue mis à jour.\e[0m"
fi

# Rapport de fin
if [ ${#failed_packages[@]} -gt 0 ]; then
    echo -e "\n\e[1;31m/!\\ Attention : Les paquets suivants n'ont pas pu être installés (introuvables sur les dépôts) :\e[0m"
    echo -e "\e[1;33m${failed_packages[*]}\e[0m"
fi

ask "\nLe script est terminé. Souhaitez-vous redémarrer la machine maintenant ? [O/n]" reboot_ans
if [[ ! "$reboot_ans" =~ ^[nN]$ ]]; then
    echo -e "\e[1;34m→ Redémarrage en cours...\e[0m"
    sleep 2
    reboot
else
    echo -e "\e[1;33m→ Redémarrage annulé. Pensez à le faire manuellement.\e[0m"
    echo -e "\e[1;33m→ Remarque : Rechargez votre terminal ou tapez 'source ~/.bashrc' pour voir le nouveau prompt et alias.\e[0m"
fi
