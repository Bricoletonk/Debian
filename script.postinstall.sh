#!/bin/bash

# Vérifie que le script est exécuté en tant que root
if [[ $EUID -ne 0 ]]; then
    echo -e "\e[1;31mCe script doit être exécuté en tant que root.\e[0m"
    exit 1
fi

# Fonction pour poser une question
ask() {
    local prompt="$1"
    local varname="$2"
    read -e -p "$(echo -e "\e[1;33m$prompt\e[0m") " "$varname"
}

echo -e "\n\e[1;34m→ Désactivation des sources CD-ROM pour éviter les erreurs de mise à jour...\e[0m"
sed -i -e '/cdrom:/s/^/# /' /etc/apt/sources.list

echo -e "\e[1;34m→ Mise à jour des dépôts et installation des dépendances requises en arrière-plan...\e[0m"
# La mise à jour de base continue même si un dépôt mineur répond mal
apt-get update -qq >/dev/null 2>&1 || true
apt-get install -yqq curl wget gnupg2 ca-certificates software-properties-common >/dev/null 2>&1

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

# Test eza / exa disponible dans les dépôts (eza est le nouveau nom)
if apt-cache show eza >/dev/null 2>&1; then
    LS_TOOL="eza"
elif apt-cache show exa >/dev/null 2>&1; then
    LS_TOOL="exa"
else
    LS_TOOL="eza"
fi

declare -A packages=(
    [bat]="Remplaçant de 'cat' avec coloration syntaxique"
    [btop]="Moniteur système moderne (remplaçant de htop)"
    [$LS_TOOL]="Remplaçant moderne de 'ls'"
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

ask "Souhaitez-vous ajouter manuellement des logiciels supplémentaires ? (ex: apache2 vim) [o/N]" custom_ans
if [[ "$custom_ans" =~ ^[oOyY]$ ]]; then
    ask "Entrez les noms des paquets à ajouter (séparés par des espaces) :" custom_packages
    if [[ -n "$custom_packages" ]]; then
        selected+=($custom_packages)
    fi
fi

# Préparation de l'installation en bloc
valid_packages=()
failed_packages=()
install_nala=false
install_webmin=false
install_tgpt=false
install_gemini=false
install_sensors=false

# Tri des outils d'installation externes vs dépôts APT
for pkg in "${selected[@]}"; do
    if [[ "$pkg" == "nala" ]]; then install_nala=true; continue; fi
    if [[ "$pkg" == "webmin" ]]; then install_webmin=true; continue; fi
    if [[ "$pkg" == "tgpt" ]]; then install_tgpt=true; continue; fi
    if [[ "$pkg" == "gemini-cli" ]]; then install_gemini=true; continue; fi
    if [[ "$pkg" == "lm-sensors" ]]; then install_sensors=true; valid_packages+=("$pkg"); continue; fi
    
    # Vérification dans le cache APT
    if apt-cache show "$pkg" >/dev/null 2>&1; then
        valid_packages+=("$pkg")
    else
        failed_packages+=("$pkg")
    fi
done

# 1. Installation de Nala en priorité absolue si demandé
if [[ "$install_nala" == true ]]; then
    echo -e "\n\e[1;34m→ Installation de Nala...\e[0m"
    apt-get install -y nala
    INSTALLER="nala"
fi

# 2. Ajout du dépôt Webmin (nécessite de mettre à jour la liste des paquets)
if [[ "$install_webmin" == true ]]; then
    echo -e "\n\e[1;34m→ Ajout du dépôt Webmin...\e[0m"
    wget -qO- https://download.webmin.com/jcameron-key.asc | gpg --dearmor > /etc/apt/trusted.gpg.d/webmin.gpg
    echo "deb https://download.webmin.com/download/repository sarge contrib" > /etc/apt/sources.list.d/webmin.list
    $INSTALLER update || true
    valid_packages+=("webmin")
fi

# 3. Installation groupée (le fameux bloc)
if [ ${#valid_packages[@]} -gt 0 ]; then
    echo -e "\n\e[1;34m→ Installation groupée des paquets : ${valid_packages[*]}\e[0m"
    $INSTALLER install -y "${valid_packages[@]}"
fi

# 4. Signalement des erreurs
if [ ${#failed_packages[@]} -gt 0 ]; then
    echo -e "\n\e[1;31m→ Attention : Les paquets suivants n'ont pas été trouvés et n'ont pas été installés : ${failed_packages[*]}\e[0m"
fi

# 5. Installations externes (Bash & Node)
if [[ "$install_tgpt" == true ]]; then
    echo -e "\n\e[1;36m→ Installation de TGPT (Terminal GPT)\e[0m"
    curl -sSL https://raw.githubusercontent.com/aandrew-me/tgpt/main/install | bash -s /usr/local/bin || echo -e "\e[1;31mErreur d'installation de TGPT\e[0m"
    echo -e "\e[1;32m→ TGPT installé avec succès.\e[0m"
fi

if [[ "$install_gemini" == true ]]; then
    echo -e "\n\e[1;36m→ Installation de Gemini CLI\e[0m"
    curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
    $INSTALLER install -y nodejs
    npm install -g @google/gemini-cli
    echo -e "\e[1;32m→ Gemini CLI installé. Lancez 'gemini auth' pour configurer.\e[0m"
fi

if [[ "$install_sensors" == true ]]; then
    echo -e "\n\e[1;34m→ Configuration des capteurs matériels via sensors-detect...\e[0m"
    yes | sensors-detect
fi

if [[ "$install_webmin" == true ]]; then
    echo -e "\n\e[1;32m→ Webmin installé avec succès.\e[0m"
    echo -e "\e[1;33mAccédez à Webmin : https://$(hostname -I | awk '{print $1}'):10000\e[0m"
fi

# Configuration des alias et du bashrc pour TOUS les utilisateurs existants
echo -e "\n\e[1;34m→ Configuration des alias et des prompts pour tous les utilisateurs...\e[0m"

USERS_DIRS=("/root" "/etc/skel")
# Parcourt les dossiers de /home
for user_dir in /home/*; do
    if [ -d "$user_dir" ]; then
        USERS_DIRS+=("$user_dir")
    fi
done

for dir in "${USERS_DIRS[@]}"; do
    bashrc="$dir/.bashrc"
    if [ -f "$bashrc" ]; then
        # Nettoyage des vieilles entrées pour ne pas surcharger le fichier si on relance le script
        sed -i '/=== Alias personnalisés ===/d' "$bashrc"
        sed -i '/alias apt=/d' "$bashrc"
        sed -i '/alias la=/d' "$bashrc"
        sed -i '/alias ll=/d' "$bashrc"
        sed -i '/alias cat=/d' "$bashrc"
        sed -i '/alias top=/d' "$bashrc"
        sed -i '/alias ip=/d' "$bashrc"
        sed -i '/alias man=/d' "$bashrc"
        
        echo -e "\n# === Alias personnalisés ===" >> "$bashrc"
        
        if [[ "$install_nala" == true ]] || command -v nala >/dev/null 2>&1; then
            echo "alias apt='nala'" >> "$bashrc"
        fi
        
        if command -v $LS_TOOL >/dev/null 2>&1; then
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
        
        # Prompts (Rouge pour root, Vert pour les autres)
        if [[ "$dir" == "/root" ]]; then
            sed -i '/export PS1=.*root@/d' "$bashrc"
            ROOT_PROMPT='\\[\\e[1;31m\\][ \\u@\\h ]\\[\\e[0;37m\\] \\w #\\[\\e[0m\\]'
            echo "export PS1=\"$ROOT_PROMPT\"" >> "$bashrc"
        else
            sed -i '/# Prompt utilisateur : vert/d' "$bashrc"
            sed -i '/GREEN=/d' "$bashrc"
            sed -i '/WHITE=/d' "$bashrc"
            sed -i '/RESET=/d' "$bashrc"
            sed -i '/export PS1=.*GREEN/d' "$bashrc"
            
            cat <<'EOF' >> "$bashrc"
# Prompt utilisateur : vert
GREEN='\\[\\e[1;32m\\]'
WHITE='\\[\\e[0;37m\\]'
RESET='\\[\\e[0m\\]'
export PS1="${WHITE}[ ${GREEN}\\u@\\h${WHITE} ] \\w \$${RESET}"
EOF
        fi
    fi
done

# Hostname
ask "Souhaitez-vous changer le nom de la machine (hostname) ? [o/N]" change_host
if [[ "$change_host" =~ ^[oOyY]$ ]]; then
    ask "Entrez le nouveau nom de la machine :" new_hostname
    echo "$new_hostname" > /etc/hostname
    hostnamectl set-hostname "$new_hostname" 2>/dev/null || true
    sed -i "s/127.0.1.1.*/127.0.1.1\t$new_hostname/" /etc/hosts
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
    echo -e "\e[1;32m→ Accès SSH root activé (SSH redémarré).\e[0m"
else
    echo -e "\e[1;33m→ Accès SSH root laissé désactivé.\e[0m"
fi

# Nettoyage des garanties de base / MOTD
echo -e "\n\e[1;36m→ Nettoyage des messages de bienvenue par défaut (MOTD)\e[0m"
> /etc/motd
chmod -x /etc/update-motd.d/* 2>/dev/null || true
sed -i 's/^#\?PrintMotd.*/PrintMotd no/' /etc/ssh/sshd_config

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

    # Construction du contenu
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
