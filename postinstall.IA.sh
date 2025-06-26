#!/bin/bash

# ==========================================================
# SCRIPT DE POST-INSTALLATION DEBIAN + IA (Gemini / Shell-GPT)
# ==========================================================

# Vérifie que le script est exécuté en tant que root
if [[ $EUID -ne 0 ]]; then
    echo -e "\e[1;31mCe script doit être exécuté en tant que root.\e[0m"
    exit 1
fi

# Fonction pour poser des questions avec couleur
ask() {
    local prompt="$1"
    local varname="$2"
    read -e -p "$(echo -e "\e[1;33m$prompt\e[0m")" "$varname"
}

# ==========================================================
# INSTALLATION DE GEMINI CLI
# ==========================================================
install_gemini_cli() {
    echo -e "\n\e[1;36m===== INSTALLATION DE GEMINI CLI =====\e[0m"

    if command -v gemini >/dev/null 2>&1; then
        echo -e "\e[1;32m→ Gemini CLI est déjà installé.\e[0m"
        return
    fi

    export NVM_DIR="/root/.nvm"
    if [ -s "$NVM_DIR/nvm.sh" ]; then
        echo -e "\e[1;32m→ NVM est déjà installé.\e[0m"
        source "$NVM_DIR/nvm.sh"
    else
        echo -e "\e[1;34m→ Installation de NVM...\e[0m"
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
        export NVM_DIR="/root/.nvm"
        source "$NVM_DIR/nvm.sh"
    fi

    if ! command -v node >/dev/null 2>&1; then
        echo -e "\e[1;34m→ Installation de Node.js LTS...\e[0m"
        nvm install --lts
    fi

    echo -e "\e[1;34m→ Installation de Gemini CLI...\e[0m"
    npm install -g @google/gemini-cli

    echo -e "\e[1;32m→ Gemini CLI installé avec succès.\e[0m"
    echo -e "\e[1;33m→ Lancez 'gemini auth' pour connecter votre compte Google.\e[0m"
}

# ==========================================================
# INSTALLATION DE SHELL-GPT
# ==========================================================
install_shell_gpt() {
    echo -e "\n\e[1;36m===== INSTALLATION DE SHELL-GPT =====\e[0m"

    if command -v sgpt >/dev/null 2>&1; then
        echo -e "\e[1;32m→ Shell-GPT est déjà installé.\e[0m"
        return
    fi

    echo -e "\e[1;34m→ Installation de Python3-pip et Shell-GPT...\e[0m"
    apt install -y python3 python3-pip

    pip install --upgrade pip
    pip install shell-gpt

    echo -e "\e[1;32m→ Shell-GPT installé avec succès.\e[0m"
    echo -e "\e[1;33m→ Configurez votre clé API OpenAI avec : 'sgpt --configure'\e[0m"
}

# ==========================================================
# MENU D'INSTALLATION IA
# ==========================================================
menu_ia() {
    ask "Souhaitez-vous installer un assistant IA en ligne de commande ?\n1 = Gemini (Google)\n2 = Shell-GPT (OpenAI)\n3 = Aucun [1/2/3] :" ia_choice

    case $ia_choice in
        1) install_gemini_cli ;;
        2) install_shell_gpt ;;
        *) echo -e "\e[1;33m→ Aucun assistant IA sélectionné.\e[0m" ;;
    esac
}

# ==========================================================
# MENU PRINCIPAL
# ==========================================================
main_menu() {
    while true; do
        echo -e "\n\e[1;35m============== MENU PRINCIPAL ==============\e[0m"
        echo "1. Installer Gemini ou Shell-GPT"
        echo "2. Quitter"
        echo -e "\e[1;35m============================================\e[0m"
        ask "Votre choix [1-2] :" choice

        case $choice in
            1) menu_ia ;;
            2) echo "Au revoir !" ; exit 0 ;;
            *) echo -e "\e[1;31mChoix invalide.\e[0m" ;;
        esac
    done
}

# Lancement du menu
main_menu
