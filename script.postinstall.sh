#!/bin/bash

# Arrête le script immédiatement si une commande critique échoue (sauf lors de l'installation des paquets)
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

# Détection de nala pré-installé
if command -v nala >/dev/null 2>&1; then
    INSTALLER="nala"
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

# Test exa/eza dispo pour proposer le bon paquet
apt update >/dev/null 2>&1 || true
if apt-cache show eza >/dev/null 2>&1; then
    LS_TOOL="eza"
elif apt-cache show exa >/dev/null 2>&1; then
    LS_TOOL="exa"
else
    LS_TOOL=""
fi

# Définition des paquets gérés par apt/nala
declare -A packages=(
    [bat]="Remplaçant de 'cat' avec coloration syntaxique"
    [btop]="Moniteur système moderne (remplaçant de htop)"
    [info]="Affiche la documentation GNU"
    [inxi]="Outil complet d’information système"
    [nala]="Interface améliorée pour apt"
    [screenfetch]="Affiche les infos système en ASCII"
    [webmin]="Interface web d'administration système (port 10000)"
)

if [[ -n "$LS_TOOL" ]]; then
    packages[$LS_TOOL]="Remplaçant moderne de 'ls' ($LS_TOOL)"
fi

if [[ "$HAS_GUI" == true ]]; then
    packages[fun]="Utilitaires fun : cbonsai, cmatrix, tty-clock, sl"
    packages[lm-sensors]="Surveille les capteurs matériels"
fi

# Outils installés hors APT (scripts externes)
declare -A custom_tools=(
    [tgpt]="Assistant IA autonome en ligne de commande (sans clé API)"
)
if [[ "$HAS_GUI" == true ]]; then
    custom_tools[gemini-cli]="Assistant IA de Google (nécessite Node.js)"
fi

fun_tools=(cbonsai cmatrix tty-clock sl)

selected_apt=()
selected_custom=()

echo -e "\n\e[1;36m===== INSTALLATION DE LOGICIELS =====\e[0m"

# Sélection APT
for pkg in $(printf '%s\n' "${!packages[@]}" | sort); do
    ask "Souhaitez-vous installer ${pkg} (${packages[$pkg]}) ? [o/N]" answer
    if [[ "$answer" =~ ^[oOyY]$ ]]; then
        if [[ "$pkg" == "fun" ]]; then
            selected_apt+=("${fun_tools[@]}")
        else
            selected_apt+=("$pkg")
        fi
    fi
done

# Sélection Hors-APT
for pkg in $(printf '%s\n' "${!custom_tools[@]}" | sort); do
    ask "Souhaitez-vous installer ${pkg} (${custom_tools[$pkg]}) ? [o/N]" answer
    if [[ "$answer" =~ ^[oOyY]$ ]]; then
        selected_custom+=("$pkg")
        # tgpt nécessite curl
        if [[ "$pkg" == "tgpt" ]] && ! command -v curl >/dev/null 2>&1; then
            selected_apt+=("curl")
        fi
    fi
done

ask "Souhaitez-vous ajouter manuellement des logiciels supplémentaires via APT ? (ex: apache2 vim curl) [o/N]" custom_ans
if [[ "$custom_ans" =~ ^[oOyY]$ ]]; then
    ask "Entrez les noms des paquets à ajouter (séparés par des espaces) :" custom_packages
    if [[ -n "$custom_packages" ]]; then
        selected_apt+=($custom_packages)
    fi
fi

failed_packages=()
installed_packages=()

# --- 1. INSTALLATION PRIORITAIRE DE NALA ---
if [[ " ${selected_apt[*]} " =~ " nala " ]]; then
    echo -e "\n\e[1;34m→ Installation de Nala en priorité...\e[0m"
    set +e
    if apt install -y nala; then
        INSTALLER="nala"
        echo -e "\e[1;32m→ Nala installé avec succès ! Il sera utilisé pour la suite.\e[0m"
        installed_packages+=("nala")
    else
        echo -e "\e[1;31m→ Échec de l'installation de Nala. Poursuite avec apt.\e[0m"
        failed_packages+=("nala")
    fi
    set -e
    
    # Retire nala de la liste pour ne pas le réinstaller
    new_apt=()
    for p in "${selected_apt[@]}"; do
        [[ "$p" != "nala" ]] && new_apt+=("$p")
    done
    selected_apt=("${new_apt[@]}")
fi

# --- 2. CONFIGURATION DES DÉPÔTS SPÉCIFIQUES ---
if [[ " ${selected_apt[*]} " =~ " webmin " ]]; then
    echo -e "\n\e[1;34m→ Ajout du dépôt Webmin...\e[0m"
    $INSTALLER install -y wget gnupg2 software-properties-common apt-transport-https ca-certificates
    wget -q https://download.webmin.com/jcameron-key.asc -O- | gpg --dearmor > /etc/apt/trusted.gpg.d/webmin.gpg
    echo "deb https://download.webmin.com/download/repository sarge contrib" > /etc/apt/sources.list.d/webmin.list
fi

# --- 3. INSTALLATION DES PAQUETS APT (UN PAR UN POUR TOLÉRANCE AUX PANNES) ---
if [ ${#selected_apt[@]} -gt 0 ]; then
    echo -e "\n\e[1;34m→ Mise à jour des dépôts avec $INSTALLER...\e[0m"
    $INSTALLER update

    echo -e "\n\e[1;34m→ Installation des paquets sélectionnés...\e[0m"
    set +e # Désactive l'arrêt du script sur erreur
    for pkg in "${selected_apt[@]}"; do
        echo -e "\n\e[1;36mInstallation de $pkg...\e[0m"
        if $INSTALLER install -y "$pkg"; then
            installed_packages+=("$pkg")
        else
            failed_packages+=("$pkg")
            echo -e "\e[1;31m[!] Échec de l'installation de $pkg. Le script continue...\e[0m"
        fi
    done
    set -e # Réactive l'arrêt du script sur erreur
    
    if [[ " ${installed_packages[*]} " =~ " webmin " ]]; then
        echo -e "\e[1;32m→ Webmin installé avec succès.\e[0m"
        echo -e "\e[1;33mAccédez à Webmin : https://$(hostname -I | awk '{print $1}'):10000\e[0m"
    fi
fi

if [[ " ${installed_packages[*]} " =~ " lm-sensors " ]]; then
    echo -e "\n\e[1;34m→ Configuration des capteurs matériels via sensors-detect...\e[0m"
    yes | sensors-detect
fi

# --- 4. INSTALLATION DES OUTILS CUSTOM ---
# tgpt
if [[ " ${selected_custom[*]} " =~ " tgpt " ]]; then
    echo -e "\n\e[1;36m→ Installation de tgpt\e[0m"
    set +e
    if curl -sSL https://raw.githubusercontent.com/aandrew-me/tgpt/main/install | bash -s /usr/local/bin; then
        echo -e "\e[1;32m→ tgpt installé. Lancez 'tgpt' pour l'utiliser.\e[0m"
        installed_packages+=("tgpt")
    else
        failed_packages+=("tgpt")
        echo -e "\e[1;31m[!] Échec de l'installation de tgpt.\e[0m"
    fi
    set -e
fi

# Gemini CLI
if [[ " ${selected_custom[*]} " =~ " gemini-cli " ]]; then
    echo -e "\n\e[1;36m→ Installation de Gemini CLI via NodeSource\e[0m"
    set +e
    apt install -y curl
    curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
    if apt-get install -y nodejs && npm install -g @google/gemini-cli; then
        echo -e "\e[1;32m→ Gemini CLI installé. Lancez 'gemini auth' pour configurer.\e[0m"
        installed_packages+=("gemini-cli")
    else
        failed_packages+=("gemini-cli")
        echo -e "\e[1;31m[!] Échec de l'installation de Gemini CLI.\e[0m"
    fi
    set -e
fi

# --- 5. RAPPORT D'ERREURS ---
if [ ${#failed_packages[@]} -gt 0 ]; then
    echo -e "\n\e[1;41m ATTENTION : Les paquets suivants n'ont pas pu être installés : \e[0m"
    echo -e "\e[1;31m${failed_packages[*]}\e[0m"
    echo -e "Vous pouvez tenter de les installer manuellement plus tard."
else
    echo -e "\n\e[1;32m→ Tous les paquets sélectionnés ont été installés avec succès !\e[0m"
fi

# --- 6. ALIAS DYNAMIQUES ---
echo -e "\n\e[1;34m→ Configuration des alias dans /root/.bashrc et /etc/skel/.bashrc...\e[0m"
for bashrc in "/root/.bashrc" "/etc/skel/.bashrc"; do
    echo -e "\n# === Alias personnalisés ===" >> "$bashrc"
    
    if command -v nala >/dev/null 2>&1; then
        echo "alias apt='nala'" >> "$bashrc"
    fi
    
    if [[ -n "$LS_TOOL" ]] && command -v "$LS_TOOL" >/dev/null 2>&1; then
        echo "alias la='$LS_TOOL -laT'" >> "$bashrc"
        echo "alias ll='$LS_TOOL -lT'" >> "$bashrc"
    fi
    
    if command -v batcat >/dev/null 2>&1; then
        echo "alias cat='batcat'" >> "$bashrc"
    elif command -v bat >/dev/null 2>&1; then
        echo "alias cat='bat'" >> "$bashrc"
    fi
    
    if command -v btop >/dev/null 2>&1; then
        echo "alias top='btop'" >> "$bashrc"
    fi
    
    echo "alias ip='ip -c'" >> "$bashrc"
    echo "alias man='info'" >> "$bashrc"
done

# --- 7. CONFIGURATION DU PROMPT ---
# Prompt root (Crochet rouge corrigé)
ROOT_PROMPT='\\[\\e[1;31m\\][ \\u@\\h ]\\[\\e[0;37m\\] \\w #\\[\\e[0m\\]'
# On supprime une ancienne éventuelle déclaration PS1 pour éviter les doublons
sed -i '/export PS1=/d' "/root/.bashrc"
echo "export PS1=\"$ROOT_PROMPT\"" >> "/root/.bashrc"

# Prompt utilisateurs
USER_TEMPLATE="/etc/skel/.bashrc"
sed -i '/# Prompt utilisateur : vert/,$d' "$USER_TEMPLATE"
cat <<'EOF' >> "$USER_TEMPLATE"

# Prompt utilisateur : vert
GREEN='\\[\\e[1;32m\\]'
WHITE='\\[\\e[0;37m\\]'
RESET='\\[\\e[0m\\]'
export PS1="${WHITE}[ ${GREEN}\\u@\\h${WHITE} ] \\w \$${RESET}"
EOF

# --- 8. HOSTNAME ---
ask "\nSouhaitez-vous changer le nom de la machine (hostname) ? [o/N]" change_host
if [[ "$change_host" =~ ^[oOyY]$ ]]; then
    ask "Entrez le nouveau nom de la machine :" new_hostname
    echo "$new_hostname" > /etc/hostname
    hostnamectl set-hostname "$new_hostname"
    echo -e "\e[1;32m→ Nom de la machine changé en $new_hostname\e[0m"
fi

# --- 9. SSH ROOT ---
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

# --- 10. /ETC/ISSUE ---
ask "Souhaitez-vous afficher des infos système avant le login (dans /etc/issue) ? [o/N]" issue_ans
if [[ "$issue_ans" =~ ^[oOyY]$ ]]; then
    echo -e "\n\e[1;36m→ Configuration des infos système à afficher dans /etc/issue\e[0m"
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

    # Construction du contenu (utilisation de \4 et \6 pour IP dynamique)
    {
        echo "Debian GNU/Linux \s \r (\m)"
        [[ $issue_display =~ hostname ]] && echo -e "Hostname : \n"
        [[ $issue_display =~ date ]] && echo -e "Date     : \d"
        [[ $issue_display =~ kernel ]] && echo -e "Kernel   : \v"
        [[ $issue_display =~ console ]] && echo -e "Console  : \l"
        echo
        if [[ $issue_display =~ ip ]]; then
            echo -e "IPv4     : \4"
            echo -e "IPv6     : \6"
        fi
        echo
    } > /etc/issue

    echo -e "\e[1;32m→ /etc/issue mis à jour avec les infos sélectionnées.\e[0m"
fi

# --- 11. REDÉMARRAGE ---
ask "\nLe script est terminé. Souhaitez-vous redémarrer la machine maintenant ? [O/n]" reboot_ans
if [[ ! "$reboot_ans" =~ ^[nN]$ ]]; then
    echo -e "\e[1;34m→ Redémarrage en cours...\e[0m"
    sleep 2
    reboot
else
    echo -e "\e[1;33m→ Redémarrage annulé. Pensez à le faire manuellement.\e[0m"
fi
