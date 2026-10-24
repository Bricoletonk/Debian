#!/bin/bash

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

echo -e "\e[1;34m→ Préparation du système et installation des dépendances requises...\e[0m"

# Désactivation robuste du CD-ROM
sed -i '/cdrom:/s/^/#/g' /etc/apt/sources.list

echo -e "\e[1;36m→ Mise à jour des dépôts (apt-get update)...\e[0m"
apt-get update

echo -e "\e[1;36m→ Installation de Nala, curl et des outils de base...\e[0m"
apt-get install -y nala curl wget gnupg2 ca-certificates lsb-release

if command -v nala >/dev/null 2>&1; then
    INSTALLER="nala"
    echo -e "\e[1;32m→ Nala et les dépendances ont été installés avec succès.\e[0m"
else
    INSTALLER="apt-get"
    echo -e "\e[1;33m→ Attention : Nala n'a pas pu s'installer, le script utilisera apt-get en secours.\e[0m"
fi

# Suppression du Message Of The Day (MOTD)
> /etc/motd
if [ -d /etc/update-motd.d ]; then
    chmod -x /etc/update-motd.d/*
fi

# Détection de eza / exa
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
    [$LS_TOOL]="Remplaçant moderne de 'ls' ($LS_TOOL)"
    [info]="Affiche la documentation GNU"
    [inxi]="Outil complet d’information système"
    [screenfetch]="Affiche les infos système en ASCII"
)

selected=()

echo -e "\n\e[1;36m===== INSTALLATION DE LOGICIELS =====\e[0m"

for pkg in $(printf '%s\n' "${!packages[@]}" | sort); do
    if [ -n "$pkg" ]; then
        ask "Souhaitez-vous installer ${pkg} (${packages[$pkg]}) ? [o/N]" answer
        if [[ "$answer" =~ ^[oOyY]$ ]]; then
            selected+=("$pkg")
        fi
    fi
done

ask "Souhaitez-vous installer gemini-cli (Assistant IA Google) ? [o/N]" gemini_ans
ask "Souhaitez-vous installer webmin (Interface web d'administration système) ? [o/N]" webmin_ans

ask "Souhaitez-vous ajouter manuellement des logiciels supplémentaires ? (ex: apache2 vim) [o/N]" custom_ans
if [[ "$custom_ans" =~ ^[oOyY]$ ]]; then
    ask "Entrez les noms des paquets à ajouter (séparés par des espaces) :" custom_packages
    if [[ -n "$custom_packages" ]]; then
        selected+=($custom_packages)
    fi
fi

if [ ${#selected[@]} -gt 0 ]; then
    echo -e "\n\e[1;34m→ Installation groupée des paquets : ${selected[*]}\e[0m"
    valid_packages=()
    for p in "${selected[@]}"; do
        if apt-cache show "$p" >/dev/null 2>&1; then
            valid_packages+=("$p")
        else
            echo -e "\e[1;31m→ Le paquet '$p' est introuvable sur les dépôts et sera ignoré.\e[0m"
        fi
    done
    if [ ${#valid_packages[@]} -gt 0 ]; then
        $INSTALLER install -y "${valid_packages[@]}"
    fi
fi

# Installation de Webmin
if [[ "$webmin_ans" =~ ^[oOyY]$ ]]; then
    echo -e "\n\e[1;34m→ Installation de Webmin...\e[0m"
    if ! command -v wget >/dev/null 2>&1; then apt-get install -y wget; fi
    
    wget -qO - https://download.webmin.com/jcameron-key.asc | gpg --yes --dearmor -o /usr/share/keyrings/webmin.gpg
    echo "deb [signed-by=/usr/share/keyrings/webmin.gpg] https://download.webmin.com/download/repository sarge contrib" > /etc/apt/sources.list.d/webmin.list
    
    $INSTALLER update
    $INSTALLER install -y webmin
    echo -e "\e[1;32m→ Webmin installé. Accès : https://$(hostname -I | awk '{print $1}'):10000\e[0m"
fi

# Installation de Gemini CLI
if [[ "$gemini_ans" =~ ^[oOyY]$ ]]; then
    echo -e "\n\e[1;34m→ Installation de Node.js (via NodeSource) et Gemini CLI...\e[0m"
    if ! command -v curl >/dev/null 2>&1; then apt-get install -y curl; fi
    
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    $INSTALLER install -y nodejs
    
    if command -v npm >/dev/null 2>&1; then
        npm install -g @google/gemini-cli
        echo -e "\e[1;32m→ Gemini CLI a été installé avec succès.\e[0m"
        
        echo -e "\n\e[1;33mPour utiliser l'IA, vous avez besoin d'une clé API Google gratuite.\e[0m"
        echo -e "Comme vous êtes sur un terminal sans interface graphique, copiez ce lien :"
        echo -e "\e[1;36mhttps://aistudio.google.com/app/apikey\e[0m"
        echo -e "Et ouvrez-le dans le navigateur web de votre PC.\e[0m\n"
        
        ask "Avez-vous généré votre clé API et l'avez-vous copiée ? [o/N]" key_ready
        if [[ "$key_ready" =~ ^[oOyY]$ ]]; then
            ask "Collez votre clé API ici :" GEMINI_API_KEY
            if [[ -n "$GEMINI_API_KEY" ]]; then
                echo "export GEMINI_API_KEY=\"$GEMINI_API_KEY\"" > /etc/profile.d/gemini_api.sh
                chmod +x /etc/profile.d/gemini_api.sh
                echo -e "\e[1;32m→ Clé API sauvegardée ! Elle sera active à la prochaine connexion pour tous les utilisateurs.\e[0m"
            fi
        else
            echo -e "\e[1;33m→ Vous pourrez configurer votre clé plus tard en tapant 'gemini auth'.\e[0m"
        fi
    else
        echo -e "\e[1;31m→ Erreur critique : Node.js / npm est introuvable, l'installation de Gemini a échoué.\e[0m"
    fi
fi

# Configuration des fichiers .bashrc
echo -e "\n\e[1;34m→ Configuration des alias et des prompts (root, skel, utilisateurs)...\e[0m"

configure_bashrc() {
    local target_rc="$1"
    local is_root="$2"

    sed -i '/# === Alias personnalisés ===/,$d' "$target_rc"
    sed -i '/# === Prompt/,$d' "$target_rc"

    echo "" >> "$target_rc"
    echo "# === Alias personnalisés ===" >> "$target_rc"
    
    if command -v nala >/dev/null 2>&1; then
        echo "alias apt='nala'" >> "$target_rc"
    fi
    
    if command -v $LS_TOOL >/dev/null 2>&1; then
        echo "alias ls='$LS_TOOL'" >> "$target_rc"
        echo "alias la='$LS_TOOL -laT'" >> "$target_rc"
        echo "alias ll='$LS_TOOL -lT'" >> "$target_rc"
    fi
    if command -v batcat >/dev/null 2>&1; then
        echo "alias cat='batcat'" >> "$target_rc"
    elif command -v bat >/dev/null 2>&1; then
        echo "alias cat='bat'" >> "$target_rc"
    fi
    if command -v btop >/dev/null 2>&1; then
        echo "alias top='btop'" >> "$target_rc"
    fi
    echo "alias ip='ip -c'" >> "$target_rc"

    if [ "$is_root" = true ]; then
        echo "# === Prompt Root ===" >> "$target_rc"
        echo "export PS1='\[\e[1;31m\][ \u@\h ]\[\e[0;37m\] \w #\[\e[0m\] '" >> "$target_rc"
    else
        echo "# === Prompt User ===" >> "$target_rc"
        echo "export PS1='\[\e[0;37m\][ \[\e[1;32m\]\u@\h\[\e[0;37m\] ] \w \$\[\e[0m\] '" >> "$target_rc"
    fi
}

configure_bashrc "/root/.bashrc" true
configure_bashrc "/etc/skel/.bashrc" false

for user_home in /home/*; do
    if [ -d "$user_home" ]; then
        user_bashrc="$user_home/.bashrc"
        if [ -f "$user_bashrc" ]; then
            configure_bashrc "$user_bashrc" false
            chown $(stat -c '%U:%G' "$user_home") "$user_bashrc"
        fi
    fi
done
echo -e "\e[1;32m→ Les profils ont été mis à jour avec succès.\e[0m"

echo -e "\n\e[1;36m===== CONFIGURATION DU SYSTÈME =====\e[0m"

ask "Souhaitez-vous changer le nom de la machine (hostname) ? [o/N]" change_host
if [[ "$change_host" =~ ^[oOyY]$ ]]; then
    ask "Entrez le nouveau nom de la machine :" new_hostname
    echo "$new_hostname" > /etc/hostname
    hostnamectl set-hostname "$new_hostname" 2>/dev/null || true
    echo -e "\e[1;32m→ Nom de la machine changé en $new_hostname\e[0m"
fi

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
else
    echo -e "\e[1;33m→ Accès SSH root laissé désactivé.\e[0m"
fi

ask "Souhaitez-vous afficher des infos système avant le login (dans /etc/issue) ? [o/N]" issue_ans
if [[ "$issue_ans" =~ ^[oOyY]$ ]]; then
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

    {
        echo "Debian GNU/Linux \s \r (\m)"
        [[ $issue_display =~ hostname ]] && echo -e "Hostname : \\n"
        [[ $issue_display =~ date ]] && echo -e "Date     : \\d"
        [[ $issue_display =~ kernel ]] && echo -e "Kernel   : \\v"
        [[ $issue_display =~ console ]] && echo -e "Console  : \\l"
        echo
        if [[ $issue_display =~ ip ]]; then
            echo -e "IPv4     : \\4"
            echo -e "IPv6     : \\6"
        fi
        echo
    } > /etc/issue

    echo -e "\e[1;32m→ /etc/issue mis à jour avec les infos sélectionnées.\e[0m"
fi

echo -e "\n\e[1;36m===== INSTALLATION TERMINÉE =====\e[0m"

ask "Le script est terminé. Souhaitez-vous redémarrer la machine maintenant ? [O/n]" reboot_ans
if [[ ! "$reboot_ans" =~ ^[nN]$ ]]; then
    echo -e "\e[1;34m→ Redémarrage en cours...\e[0m"
    sleep 2
    reboot
else
    echo -e "\e[1;33m→ Redémarrage annulé. Pensez à le faire manuellement.\e[0m"
fi
