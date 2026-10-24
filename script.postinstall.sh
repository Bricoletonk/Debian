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

# Détection de nala
if command -v nala >/dev/null 2>&1; then
    INSTALLER="nala"
    alias apt="nala"
    echo -e "\e[1;32m→ Nala détecté : les paquets seront installés avec nala.\e[0m"
else
    INSTALLER="apt"
    echo -e "\e[1;33m→ Nala non détecté : les paquets seront installés avec apt.\e[0m"
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

# Test exa/eza dispo
if apt-cache show eza >/dev/null 2>&1; then
    LS_TOOL="eza"
elif apt-cache show exa >/dev/null 2>&1; then
    LS_TOOL="exa"
else
    LS_TOOL=""
fi

declare -A packages=(
    [bat]="Remplaçant de 'cat' avec coloration syntaxique"
    [btop]="Moniteur système moderne (remplaçant de htop)"
    [exa]="Remplaçant moderne de 'ls' ($LS_TOOL)"
    [info]="Affiche la documentation GNU"
    [inxi]="Outil complet d’information système"
    [nala]="Interface améliorée pour apt"
    [screenfetch]="Affiche les infos système en ASCII"
    [tgpt]="Assistant IA autonome en ligne de commande (sans clé API)"
    [webmin]="Interface web d'administration système (port 10000)"
)

if [[ "$HAS_GUI" == true ]]; then
    packages[fun]="Utilitaires fun : cbonsai, cmatrix, tty-clock, sl"
    packages[lm-sensors]="Surveille les capteurs matériels"
    packages[gemini-cli]="Assistant IA de Google (nécessite Node.js)"
fi

fun_tools=(cbonsai cmatrix tty-clock sl)
selected=()

echo -e "\n\e[1;36m===== INSTALLATION DE LOGICIELS =====\e[0m"

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
        selected+=($custom_packages)
    fi
fi

if [ ${#selected[@]} -gt 0 ]; then
    echo -e "\n\e[1;34m→ Installation des paquets sélectionnés : ${selected[*]}\e[0m"

    # Séparation des paquets APT et des installations spécifiques (curl/npm)
    apt_packages=()
    for p in "${selected[@]}"; do
        if [[ "$p" != "tgpt" && "$p" != "gemini-cli" && "$p" != "webmin" ]]; then
            apt_packages+=("$p")
        fi
    done

    # Dépôt Webmin
    if [[ " ${selected[*]} " =~ " webmin " ]]; then
        echo -e "\e[1;34m→ Ajout du dépôt Webmin...\e[0m"
        $INSTALLER update
        $INSTALLER install -y wget gnupg2 software-properties-common apt-transport-https ca-certificates curl
        wget -q https://download.webmin.com/jcameron-key.asc -O- | gpg --dearmor > /etc/apt/trusted.gpg.d/webmin.gpg
        echo "deb https://download.webmin.com/download/repository sarge contrib" > /etc/apt/sources.list.d/webmin.list
        apt_packages+=("webmin")
    fi

    # Installation des paquets APT
    if [ ${#apt_packages[@]} -gt 0 ]; then
        $INSTALLER update
        $INSTALLER install -y "${apt_packages[@]}"
    fi

    if [[ " ${selected[*]} " =~ " webmin " ]]; then
        echo -e "\e[1;32m→ Webmin installé avec succès.\e[0m"
        echo -e "\e[1;33mAccédez à Webmin via : https://$(hostname -I | awk '{print $1}'):10000\e[0m"
    fi
else
    echo -e "\e[1;33mAucun paquet sélectionné pour l'installation via APT.\e[0m"
fi

# lm-sensors
if [[ " ${selected[*]} " =~ " lm-sensors " ]]; then
    echo -e "\n\e[1;34m→ Configuration des capteurs matériels via sensors-detect...\e[0m"
    yes | sensors-detect
fi

# tgpt (remplaçant de shell-gpt)
if [[ " ${selected[*]} " =~ " tgpt " ]]; then
    echo -e "\n\e[1;36m→ Installation de tgpt\e[0m"
    curl -sSL https://raw.githubusercontent.com/aandrew-me/tgpt/main/install | bash -s /usr/local/bin
    echo -e "\e[1;32m→ tgpt installé. Vous pouvez l'utiliser en tapant 'tgpt <votre question>'.\e[0m"
fi

# Gemini CLI (Installation globale via NodeSource)
if [[ " ${selected[*]} " =~ " gemini-cli " ]]; then
    echo -e "\n\e[1;36m→ Installation de Node.js et Gemini CLI\e[0m"
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    $INSTALLER install -y nodejs
    npm install -g @google/gemini-cli
    echo -e "\e[1;32m→ Gemini CLI installé. Lancez 'gemini auth' pour configurer.\e[0m"
fi

# Alias (Conditionnels)
echo -e "\n\e[1;34m→ Ajout des alias dans /root/.bashrc et /etc/skel/.bashrc...\e[0m"

alias_block="\n# === Alias personnalisés ===\nalias apt='nala'\nalias ip='ip -c'\n"
[[ " ${selected[*]} " =~ " exa " ]] && alias_block+="alias la='$LS_TOOL -laT'\nalias ll='$LS_TOOL -lT'\n"
[[ " ${selected[*]} " =~ " bat " ]] && alias_block+="alias cat='batcat'\n"
[[ " ${selected[*]} " =~ " btop " ]] && alias_block+="alias top='btop'\n"
[[ " ${selected[*]} " =~ " info " ]] && alias_block+="alias man='info'\n"

for bashrc in "/root/.bashrc" "/etc/skel/.bashrc"; do
    echo -e "$alias_block" >> "$bashrc"
done

# Prompt root
ROOT_PROMPT='\\[\\e[1;31m\\][ \\u@\\h ]\\[\\e[0;37m\\] \\w #\\[\\e[0m\\]'
echo "export PS1=\"$ROOT_PROMPT\"" >> "/root/.bashrc"

# Prompt utilisateurs
USER_TEMPLATE="/etc/skel/.bashrc"
cat <<'EOF' >> "$USER_TEMPLATE"

# Prompt utilisateur : vert
GREEN='\\[\\e[1;32m\\]'
WHITE='\\[\\e[0;37m\\]'
RESET='\\[\\e[0m\\]'
export PS1="${WHITE}[ ${GREEN}\\u@\\h${WHITE} ] \\w \$${RESET}"
EOF

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
else
    echo -e "\e[1;33m→ Accès SSH root laissé désactivé.\e[0m"
fi

# /etc/issue customization (avec \4 pour l'IP dynamique)
ask "Souhaitez-vous afficher des infos système avant le login (dans /etc/issue) ? [o/N]" issue_ans
if [[ "$issue_ans" =~ ^[oOyY]$ ]]; then
    echo -e "\n\e[1;36m→ Configuration des infos système à afficher dans /etc/issue\e[0m"
    
    issue_display=""
    for key in ip hostname kernel date console; do
        ask "Souhaitez-vous afficher ${key} ? [o/N]" ans
        if [[ "$ans" =~ ^[oOyY]$ ]]; then
            issue_display+="$key "
        fi
    done

    # Construction du contenu
    {
        echo "Debian GNU/Linux \s \r (\m)"
        [[ $issue_display =~ hostname ]] && echo "Hostname : \n"
        [[ $issue_display =~ date ]] && echo "Date     : \d"
        [[ $issue_display =~ kernel ]] && echo "Kernel   : \v"
        [[ $issue_display =~ console ]] && echo "Console  : \l"
        echo ""
        [[ $issue_display =~ ip ]] && echo "Adresse IPv4 : \4"
        echo ""
    } > /etc/issue

    echo -e "\e[1;32m→ /etc/issue mis à jour avec les infos sélectionnées.\e[0m"
fi

# Redémarrage final
ask "\nLe script est terminé. Souhaitez-vous redémarrer la machine maintenant ? [O/n]" reboot_ans
if [[ ! "$reboot_ans" =~ ^[nN]$ ]]; then
    echo -e "\e[1;34m→ Redémarrage en cours...\e[0m"
    sleep 2
    reboot
else
    echo -e "\e[1;33m→ Redémarrage annulé. Pensez à le faire manuellement.\e[0m"
fi
