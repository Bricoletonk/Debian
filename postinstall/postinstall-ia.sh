#!/bin/bash

# ==========================================================
# SCRIPT DE POST-INSTALLATION DEBIAN + IA (Gemini / Shell-GPT)
# ==========================================================

# Vérifie que le script est exécuté en tant que root
if [[ $EUID -ne 0 ]]; then
    echo -e "\e[1;31mCe script doit être exécuté en tant que root.\e[0m"
    exit 1
fi

# Fonction utilitaire
ask() {
    local prompt="$1"
    local varname="$2"
    read -e -p "$(echo -e "\e[1;33m$prompt\e[0m")" "$varname"
}

ensure_package() {
    if ! dpkg -s "$1" &>/dev/null; then
        echo -e "\e[1;34m→ Installation de $1...\e[0m"
        apt update
        apt install -y "$1"
    fi
}

# Installation de Gemini
install_gemini_cli() {
    echo -e "\n\e[1;36m===== INSTALLATION DE GEMINI CLI =====\e[0m"
    if command -v gemini >/dev/null 2>&1; then
        echo -e "\e[1;32m→ Gemini CLI est déjà installé.\e[0m"
        return
    fi
    ensure_package curl
    ensure_package ca-certificates
    export NVM_DIR="/root/.nvm"
    if [ -s "$NVM_DIR/nvm.sh" ]; then
        echo -e "\e[1;32m→ NVM est déjà installé.\e[0m"
        source "$NVM_DIR/nvm.sh"
    else
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
        export NVM_DIR="/root/.nvm"
        source "$NVM_DIR/nvm.sh"
    fi
    if ! command -v node >/dev/null 2>&1; then
        nvm install --lts
    fi
    npm install -g @google/gemini-cli
    echo -e "\e[1;32m→ Gemini CLI installé.\e[0m"
    echo -e "\e[1;33m→ Authentifiez-vous avec : 'gemini auth'\e[0m"
}

# Installation de Shell-GPT
install_shell_gpt() {
    echo -e "\n\e[1;36m===== INSTALLATION DE SHELL-GPT =====\e[0m"
    if command -v sgpt >/dev/null 2>&1; then
        echo -e "\e[1;32m→ Shell-GPT est déjà installé.\e[0m"
        return
    fi
    ensure_package python3
    ensure_package python3-pip
    ensure_package build-essential
    pip install --upgrade pip
    pip install shell-gpt
    echo -e "\e[1;32m→ Shell-GPT installé.\e[0m"
    echo -e "\e[1;33m→ Configurez avec : 'sgpt --configure'\e[0m"
}

# Menu IA
menu_ia() {
    ask "Installer un assistant IA ?\n1 = Gemini\n2 = Shell-GPT\n3 = Les deux\n4 = Aucun [1/2/3/4] :" ia_choice
    case $ia_choice in
        1) install_gemini_cli ;;
        2) install_shell_gpt ;;
        3) install_gemini_cli ; install_shell_gpt ;;
        *) echo -e "\e[1;33m→ Aucun IA installé.\e[0m" ;;
    esac
}

# Post-install général
run_postinstall() {
    echo -e "\n\e[1;36m===== INSTALLATION DES UTILITAIRES =====\e[0m"
    apt update
    apt install -y nala eza bat btop inxi info screenfetch wget gnupg2 software-properties-common apt-transport-https ca-certificates
    echo "deb https://download.webmin.com/download/repository sarge contrib" > /etc/apt/sources.list.d/webmin.list
    wget -q https://download.webmin.com/jcameron-key.asc -O- | gpg --dearmor > /etc/apt/trusted.gpg.d/webmin.gpg
    apt update
    apt install -y webmin

    echo -e "\e[1;32m→ Webmin installé : https://$(hostname -I | awk '{print $1}'):10000\e[0m"

    echo -e "\n\e[1;34m→ Configuration des alias...\e[0m"
    for bashrc in "/root/.bashrc" "/etc/skel/.bashrc"; do
        cat <<'EOF' >> "$bashrc"
alias apt='nala'
alias la='eza -laT'
alias ll='eza -lT'
alias cat='batcat'
alias top='btop'
alias ip='ip -c'
alias man='info'
EOF
    done

    echo -e "\n\e[1;34m→ Configuration du prompt...\e[0m"
    echo "export PS1='\[\e[1;31m\][ \u@\h \[\e[0;37m\]] \w #\[\e[0m\]'" >> /root/.bashrc

    ask "Changer le hostname ? [o/N] :" change_host
    if [[ "$change_host" =~ ^[oOyY]$ ]]; then
        ask "Nouveau hostname :" new_hostname
        echo "$new_hostname" > /etc/hostname
        hostnamectl set-hostname "$new_hostname"
        echo -e "\e[1;32m→ Hostname changé en $new_hostname\e[0m"
    fi

    ask "Activer SSH root ? [o/N] :" ssh_root
    if [[ "$ssh_root" =~ ^[oOyY]$ ]]; then
        sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config || echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
        systemctl restart ssh
        echo -e "\e[1;32m→ SSH root activé\e[0m"
    fi

    menu_ia
}

# Menu principal
main_menu() {
    while true; do
        echo -e "\n\e[1;35m============== MENU PRINCIPAL =============="
        echo "1. Lancer le script complet de post-installation"
        echo "2. Quitter"
        echo -e "============================================\e[0m"
        ask "Votre choix [1-2] :" choice
        case $choice in
            1) run_postinstall ;;
            2) echo "Au revoir !" ; exit 0 ;;
            *) echo -e "\e[1;31mChoix invalide.\e[0m" ;;
        esac
    done
}

main_menu
