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

# --- INSTALLATION SILENCIEUSE DES DÉPENDANCES DE BASE ---
echo -e "\n\e[1;36m→ Mise à jour des dépôts et installation des dépendances requises en arrière-plan...\e[0m"
apt-get update -yq >/dev/null 2>&1
apt-get install -yq curl wget gnupg2 apt-transport-https ca-certificates software-properties-common dirmngr >/dev/null 2>&1
echo -e "\e[1;32m→ Dépendances installées avec succès.\e[0m"

# Détection de nala
if command -v nala >/dev/null 2>&1; then
    INSTALLER="nala"
    alias apt="nala"
else
    INSTALLER="apt"
fi

# Détection interface graphique
if pgrep -x "Xorg" >/dev/null || pgrep -x "gnome-session" >/dev/null || \
   pgrep -x "sddm" >/dev/null || pgrep -x "gdm" >/dev/null || pgrep -x "lightdm" >/dev/null; then
    HAS_GUI=true
else
    HAS_GUI=false
fi

# Test exa/eza dispo dynamique
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
    [info]="Affiche la documentation GNU"
    [inxi]="Outil complet d’information système"
    [nala]="Interface améliorée pour apt"
    [screenfetch]="Affiche les infos système en ASCII"
    [tgpt]="Assistant IA autonome en ligne de commande (sans clé API)"
    [webmin]="Interface web d'administration système (port 10000)"
)

# Ajout dynamique de l'outil LS
if [[ -n "$LS_TOOL" ]]; then
    packages[$LS_TOOL]="Remplaçant moderne de 'ls'"
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

ask "Souhaitez-vous ajouter manuellement des logiciels supplémentaires ? (ex: apache2 vim) [o/N]" custom_ans
if [[ "$custom_ans" =~ ^[oOyY]$ ]]; then
    ask "Entrez les noms des paquets à ajouter (séparés par des espaces) :" custom_packages
    if [[ -n "$custom_packages" ]]; then
        selected+=($custom_packages)
    fi
fi

# Tri des paquets (APT vs Externes)
apt_packages=()
external_packages=()

for pkg in "${selected[@]}"; do
    if [[ "$pkg" == "tgpt" || "$pkg" == "gemini-cli" ]]; then
        external_packages+=("$pkg")
    else
        apt_packages+=("$pkg")
    fi
done

if [ ${#apt_packages[@]} -gt 0 ]; then
    # Nala prioritaire
    if [[ " ${apt_packages[*]} " =~ " nala " ]]; then
        echo -e "\n\e[1;34m→ Installation de Nala en priorité...\e[0m"
        apt-get install -y nala
        INSTALLER="nala"
    fi

    # Vérification des paquets valides via apt-cache
    valid_apt=()
    invalid_apt=()
    
    echo -e "\n\e[1;34m→ Vérification de la disponibilité des paquets...\e[0m"
    for pkg in "${apt_packages[@]}"; do
        if [[ "$pkg" == "webmin" ]]; then
            valid_apt+=("$pkg") 
        elif apt-cache show "$pkg" >/dev/null 2>&1; then
            valid_apt+=("$pkg")
        else
            invalid_apt+=("$pkg")
        fi
    done

    # Préparation Webmin si sélectionné
    if [[ " ${valid_apt[*]} " =~ " webmin " ]]; then
        echo -e "\e[1;34m→ Configuration du dépôt Webmin...\e[0m"
        wget -q https://download.webmin.com/jcameron-key.asc -O- | gpg --dearmor --yes > /usr/share/keyrings/webmin.gpg
        echo "deb [signed-by=/usr/share/keyrings/webmin.gpg] https://download.webmin.com/download/repository sarge contrib" > /etc/apt/sources.list.d/webmin.list
        $INSTALLER update -y
    fi

    # Installation groupée
    if [ ${#valid_apt[@]} -gt 0 ]; then
        echo -e "\n\e[1;34m→ Installation groupée des paquets valides avec $INSTALLER : ${valid_apt[*]}\e[0m"
        set +e # Empêche le script de crash en cas d'erreur de téléchargement ponctuelle
        $INSTALLER install -y "${valid_apt[@]}"
        set -e
    fi

    if [ ${#invalid_apt[@]} -gt 0 ]; then
        echo -e "\e[1;31m→ Attention, les paquets suivants sont introuvables et ont été ignorés : ${invalid_apt[*]}\e[0m"
    fi
fi

# TGPT
if [[ " ${external_packages[*]} " =~ " tgpt " ]]; then
    echo -e "\n\e[1;36m→ Installation de tgpt\e[0m"
    curl -sSL https://raw.githubusercontent.com/aandrew-me/tgpt/main/install | bash -s /usr/local/bin
fi

# Gemini
if [[ " ${external_packages[*]} " =~ " gemini-cli " ]]; then
    echo -e "\n\e[1;36m→ Installation de Gemini CLI (Node.js global via NodeSource)\e[0m"
    curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
    $INSTALLER install -y nodejs
    npm install -g @google/gemini-cli
    echo -e "\e[1;32m→ Gemini CLI installé. Lancez 'gemini auth' pour configurer.\e[0m"
fi

# Messages post-install
if [[ " ${valid_apt[*]} " =~ " webmin " ]]; then
    echo -e "\e[1;32m→ Webmin installé avec succès.\e[0m"
    echo -e "\e[1;33mAccédez à Webmin : https://$(hostname -I | awk '{print $1}'):10000\e[0m"
fi

if [[ " ${valid_apt[*]} " =~ " lm-sensors " ]]; then
    echo -e "\n\e[1;34m→ Configuration des capteurs matériels via sensors-detect...\e[0m"
    yes | sensors-detect
fi

# ALIAS & PROMPTS
echo -e "\n\e[1;34m→ Configuration des alias et des prompts pour tous les utilisateurs...\e[0m"

# Collecter les chemins de tous les .bashrc
BASHRC_FILES=("/root/.bashrc" "/etc/skel/.bashrc")
for user_dir in /home/*; do
    if [ -d "$user_dir" ] && [ -f "$user_dir/.bashrc" ]; then
        BASHRC_FILES+=("$user_dir/.bashrc")
    fi
done

for bashrc in "${BASHRC_FILES[@]}"; do
    # Nettoyage des anciennes injections pour éviter les doublons
    sed -i '/# === Alias personnalisés ===/d' "$bashrc"
    sed -i '/alias apt=/d' "$bashrc"
    sed -i '/alias la=/d' "$bashrc"
    sed -i '/alias ll=/d' "$bashrc"
    sed -i '/alias cat=/d' "$bashrc"
    sed -i '/alias top=/d' "$bashrc"
    sed -i '/alias ip=/d' "$bashrc"
    sed -i '/alias man=/d' "$bashrc"
    sed -i '/# Prompt/d' "$bashrc"
    sed -i '/export PS1=/d' "$bashrc"
    sed -i '/GREEN=/d' "$bashrc"
    sed -i '/WHITE=/d' "$bashrc"
    sed -i '/RESET=/d' "$bashrc"
    sed -i '/ROOT_PROMPT=/d' "$bashrc"

    # Ajout des alias
    echo -e "\n# === Alias personnalisés ===" >> "$bashrc"
    [[ " ${apt_packages[*]} " =~ " nala " ]] && echo "alias apt='nala'" >> "$bashrc"
    if [[ -n "$LS_TOOL" && " ${valid_apt[*]} " =~ " $LS_TOOL " ]]; then
        echo "alias la='$LS_TOOL -laT'" >> "$bashrc"
        echo "alias ll='$LS_TOOL -lT'" >> "$bashrc"
    fi
    [[ " ${valid_apt[*]} " =~ " bat " ]] && echo "alias cat='batcat'" >> "$bashrc"
    [[ " ${valid_apt[*]} " =~ " btop " ]] && echo "alias top='btop'" >> "$bashrc"
    echo "alias ip='ip -c'" >> "$bashrc"
    [[ " ${valid_apt[*]} " =~ " info " ]] && echo "alias man='info'" >> "$bashrc"

    # Ajout des prompts (Couleur adaptée selon l'utilisateur)
    if [[ "$bashrc" == "/root/.bashrc" ]]; then
        echo -e "\n# Prompt root" >> "$bashrc"
        echo 'ROOT_PROMPT='\''\[\e[1;31m\][ \u@\h ]\[\e[0;37m\] \w #\[\e[0m\]'\''' >> "$bashrc"
        echo 'export PS1="$ROOT_PROMPT"' >> "$bashrc"
    else
        echo -e "\n# Prompt utilisateur" >> "$bashrc"
        echo 'GREEN='\''\[\e[1;32m\]'\''' >> "$bashrc"
        echo 'WHITE='\''\[\e[0;37m\]'\''' >> "$bashrc"
        echo 'RESET='\''\[\e[0m\]'\''' >> "$bashrc"
        echo 'export PS1="${WHITE}[ ${GREEN}\u@\h${WHITE} ] \w \$${RESET}"' >> "$bashrc"
    fi
done

# ISSUE / MOTD
ask "Souhaitez-vous afficher des infos système avant le login et supprimer les mentions légales ? [o/N]" issue_ans
if [[ "$issue_ans" =~ ^[oOyY]$ ]]; then
    echo -e "\n\e[1;36m→ Nettoyage du MOTD et configuration de /etc/issue\e[0m"
    
    # Désactiver les messages dynamiques d'Ubuntu/Debian (MOTD)
    rm -f /etc/motd
    [ -d /etc/update-motd.d ] && chmod -x /etc/update-motd.d/* 2>/dev/null || true
    sed -i 's/^PrintMotd yes/PrintMotd no/' /etc/ssh/sshd_config 2>/dev/null || true
    
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

    # Construction du fichier issue
    {
        echo "Debian GNU/Linux \s \r (\m)"
        [[ $issue_display =~ hostname ]] && echo "Hostname : \n"
        [[ $issue_display =~ date ]] && echo "Date     : \d"
        [[ $issue_display =~ kernel ]] && echo "Kernel   : \v"
        [[ $issue_display =~ console ]] && echo "Console  : \l"
        echo
        if [[ $issue_display =~ ip ]]; then
            echo "Adresses IP :"
            echo "IPv4: \4"
            echo "IPv6: \6"
        fi
        echo
    } > /etc/issue

    echo -e "\e[1;32m→ Écran de connexion mis à jour.\e[0m"
fi

# Hostname
ask "Souhaitez-vous changer le nom de la machine (hostname) ? [o/N]" change_host
if [[ "$change_host" =~ ^[oOyY]$ ]]; then
    ask "Entrez le nouveau nom de la machine :" new_hostname
    echo "$new_hostname" > /etc/hostname
    hostnamectl set-hostname "$new_hostname" 2>/dev/null || true
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
    systemctl restart ssh 2>/dev/null || true
    echo -e "\e[1;32m→ Accès SSH root activé.\e[0m"
fi

ask "\nLe script est terminé. Souhaitez-vous redémarrer la machine maintenant ? [O/n]" reboot_ans
if [[ ! "$reboot_ans" =~ ^[nN]$ ]]; then
    echo -e "\e[1;34m→ Redémarrage en cours...\e[0m"
    sleep 2
    reboot
fi
