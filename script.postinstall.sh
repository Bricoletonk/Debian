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

# Désactivation du CD-ROM dans sources.list pour éviter les erreurs d'apt update
sed -i 's/^deb cdrom:/# deb cdrom:/g' /etc/apt/sources.list

# Mise à jour silencieuse et installation des dépendances de base (incluant Nala)
apt-get update -yq >/dev/null 2>&1
apt-get install -yq curl wget gnupg2 ca-certificates software-properties-common lsb-release nala >/dev/null 2>&1

INSTALLER="nala"
echo -e "\e[1;32m→ Nala et les dépendances ont été installés avec succès.\e[0m"

# Suppression du Message Of The Day (MOTD) / Garanties par défaut au login
> /etc/motd
if [ -d /etc/update-motd.d ]; then
    chmod -x /etc/update-motd.d/*
fi

# Détection de la meilleure version de exa/eza disponible
if apt-cache show eza >/dev/null 2>&1; then
    LS_TOOL="eza"
elif apt-cache show exa >/dev/null 2>&1; then
    LS_TOOL="exa"
else
    LS_TOOL=""
fi

# Déclaration des paquets proposés
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
    ask "Souhaitez-vous installer ${pkg} (${packages[$pkg]}) ? [o/N]" answer
    if [[ "$answer" =~ ^[oOyY]$ ]]; then
        selected+=("$pkg")
    fi
done

ask "Souhaitez-vous installer gemini-cli (Assistant IA Google) ? [o/N]" gemini_ans
ask "Souhaitez-vous installer webmin (Interface web d'administration système) ? [o/N]" webmin_ans

# Ajout d'autres paquets manuels
ask "Souhaitez-vous ajouter manuellement des logiciels supplémentaires ? (ex: apache2 vim) [o/N]" custom_ans
if [[ "$custom_ans" =~ ^[oOyY]$ ]]; then
    ask "Entrez les noms des paquets à ajouter (séparés par des espaces) :" custom_packages
    if [[ -n "$custom_packages" ]]; then
        selected+=($custom_packages)
    fi
fi

# Installation en BLOC avec Nala
if [ ${#selected[@]} -gt 0 ]; then
    echo -e "\n\e[1;34m→ Installation groupée des paquets : ${selected[*]}\e[0m"
    
    # On filtre les paquets qui n'existent pas pour éviter que Nala ne bloque tout
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
    wget -qO - https://download.webmin.com/jcameron-key.asc | gpg --dearmor -o /etc/apt/trusted.gpg.d/webmin.gpg
    echo "deb https://download.webmin.com/download/repository sarge contrib" > /etc/apt/sources.list.d/webmin.list
    $INSTALLER update -yq
    $INSTALLER install -y webmin
    echo -e "\e[1;32m→ Webmin installé. Accès : https://$(hostname -I | awk '{print $1}'):10000\e[0m"
fi

# Installation de Node.js et Gemini CLI
if [[ "$gemini_ans" =~ ^[oOyY]$ ]]; then
    echo -e "\n\e[1;34m→ Installation de Node.js (via NodeSource) et Gemini CLI...\e[0m"
    
    # Installation globale propre de Node.js
    curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - >/dev/null 2>&1
    apt-get install -yq nodejs >/dev/null 2>&1
    
    # Installation globale de l'outil Gemini
    npm install -g @google/gemini-cli
    
    echo -e "\e[1;32m→ Gemini CLI installé avec succès.\e[0m"
    echo -e "\n\e[1;33mPour utiliser l'IA, vous avez besoin d'une clé API Google gratuite.\e[0m"
    echo -e "\e[1;37mComme vous êtes sur un terminal sans interface graphique, copiez ce lien :"
    echo -e "\e[1;36mhttps://aistudio.google.com/app/apikey\e[0m"
    echo -e "\e[1;37mEt ouvrez-le dans le navigateur web de votre PC.\e[0m\n"
    
    ask "Avez-vous généré votre clé API et l'avez-vous copiée ? [o/N]" key_ans
    if [[ "$key_ans" =~ ^[oOyY]$ ]]; then
        ask "Collez votre clé API ici :" GEMINI_KEY
        if [ -n "$GEMINI_KEY" ]; then
            # Enregistrement global de la clé pour tous les utilisateurs
            echo "export GEMINI_API_KEY='$GEMINI_KEY'" > /etc/profile.d/gemini_api.sh
            chmod +x /etc/profile.d/gemini_api.sh
            echo -e "\e[1;32m→ Clé API sauvegardée ! Elle sera active à la prochaine connexion pour tous les utilisateurs.\e[0m"
        else
            echo -e "\e[1;31m→ Aucune clé saisie. L'étape a été ignorée.\e[0m"
        fi
    else
        echo -e "\e[1;33m→ Pas de problème. Une fois obtenue, vous pourrez utiliser la commande 'gemini auth'.\e[0m"
    fi
fi

# Configuration des fichiers .bashrc (Alias & Prompts)
echo -e "\n\e[1;34m→ Configuration des alias et des prompts (root, skel, utilisateurs)...\e[0m"

configure_bashrc() {
    local target_rc="$1"
    local is_root="$2"

    # Nettoyage des anciennes configurations injectées par le script pour éviter les doublons
    sed -i '/# === Alias personnalisés ===/,$d' "$target_rc"
    sed -i '/# === Prompt/,$d' "$target_rc"

    echo "" >> "$target_rc"
    echo "# === Alias personnalisés ===" >> "$target_rc"
    echo "alias apt='nala'" >> "$target_rc"
    
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

    # Injection du Prompt (Simple Quotes)
    if [ "$is_root" = true ]; then
        echo "# === Prompt Root ===" >> "$target_rc"
        echo "export PS1='\[\e[1;31m\][ \u@\h ]\[\e[0;37m\] \w #\[\e[0m\] '" >> "$target_rc"
    else
        echo "# === Prompt User ===" >> "$target_rc"
        echo "export PS1='\[\e[0;37m\][ \[\e[1;32m\]\u@\h\[\e[0;37m\] ] \w \$\[\e[0m\] '" >> "$target_rc"
    fi
}

# Application aux différents comptes
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
echo -e "\n\e[1;33m/!\\ Pour appliquer les changements de couleurs et d'alias, déconnectez-vous ou tapez :\e[0m"
echo -e "source ~/.bashrc"
echo -e "\n\e[1;36m===== INSTALLATION TERMINÉE =====\e[0m"
