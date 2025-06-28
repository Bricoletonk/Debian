
#!/bin/bash

# ==========================================================
# SCRIPT DE POST-INSTALLATION DEBIAN + IA (Gemini / Shell-GPT)
# Version avec commentaires détaillés
# ==========================================================

# Vérifie que le script est exécuté en tant que root
if [[ $EUID -ne 0 ]]; then
    echo -e "\e[1;31mCe script doit être exécuté en tant que root.\e[0m"
    exit 1
fi

# ==========================
# Fonction pour poser une question avec texte coloré
# ==========================
ask() {
    local prompt="$1"
    local varname="$2"
    read -e -p "$(echo -e "\e[1;33m$prompt\e[0m") " "$varname"
}

# ==========================
# Fonction pour vérifier et installer un paquet manquant
# ==========================
ensure_package() {
    if ! dpkg -s "$1" &>/dev/null; then
        echo -e "\e[1;34m→ Installation de $1...\e[0m"
        apt update
        apt install -y "$1"
    fi
}

# ==========================
# Détection de l'outil de gestion des paquets (Nala ou Apt)
# ==========================
if command -v nala >/dev/null 2>&1; then
    INSTALLER="nala"
    alias apt="nala"
    echo -e "\e[1;32m→ Nala détecté : les paquets seront installés avec nala.\e[0m"
else
    INSTALLER="apt"
    echo -e "\e[1;33m→ Nala non détecté : les paquets seront installés avec apt.\e[0m"
fi

# ==========================
# Détection de la présence d'une interface graphique
# ==========================
if pgrep -x "Xorg" >/dev/null || pgrep -x "gnome-session" >/dev/null || pgrep -x "sddm" >/dev/null || pgrep -x "gdm" >/dev/null || pgrep -x "lightdm" >/dev/null; then
    HAS_GUI=true
    echo -e "\e[1;32m→ Interface graphique détectée.\e[0m"
else
    HAS_GUI=false
    echo -e "\e[1;33m→ Pas d'interface graphique détectée.\e[0m"
fi

# ==========================
# Liste des paquets disponibles à l'installation
# ==========================
declare -A packages=(
    [nala]="Interface améliorée pour apt"
    [exa]="Remplaçant moderne de 'ls'"
    [bat]="Remplaçant de 'cat' avec coloration syntaxique"
    [info]="Affiche la documentation GNU"
    [inxi]="Outil complet d’information système"
    [screenfetch]="Affiche les infos système en ASCII"
    [btop]="Moniteur système moderne (remplaçant de htop)"
    [webmin]="Interface web d'administration système (port 10000)"
    [gemini-cli]="Assistant IA Gemini CLI (nécessite Node.js)"
    [shell-gpt]="Assistant IA Shell-GPT (nécessite OpenAI API)"
)

# Si interface graphique, ajouter des outils funs
if [[ "$HAS_GUI" == true ]]; then
    packages[fun]="Utilitaires fun : cbonsai, cmatrix, tty-clock, sl"
    packages[lm-sensors]="Surveille les capteurs matériels"
fi

fun_tools=(cbonsai cmatrix tty-clock sl)

# ==========================
# Menu de sélection des logiciels
# ==========================
selected=()
install_list=()

echo -e "\n\e[1;36m===== INSTALLATION DE LOGICIELS =====\e[0m"

for pkg in "${!packages[@]}"; do
    echo
    ask "Souhaitez-vous installer ${pkg} (${packages[$pkg]}) ? [o/N]" answer
    if [[ "$answer" =~ ^[oOyY]$ ]]; then
        if [[ "$pkg" == "fun" ]]; then
            selected+=("${fun_tools[@]}")
        else
            selected+=("$pkg")
        fi
    fi
done

# ==========================
# Ajout de paquets personnalisés
# ==========================
echo
ask "Souhaitez-vous ajouter manuellement des logiciels supplémentaires ? (ex: apache2 vim curl) [o/N]" custom_ans
if [[ "$custom_ans" =~ ^[oOyY]$ ]]; then
    ask "Entrez les noms des paquets à ajouter (séparés par des espaces) :" custom_packages
    if [[ -n "$custom_packages" ]]; then
        selected+=($custom_packages)
    fi
fi

# ==========================
# Gestion de l'installation spéciale (IA, Webmin) ou standard
# ==========================
for item in "${selected[@]}"; do
    case "$item" in
        gemini-cli)
            echo -e "\n\e[1;36m→ Installation de Gemini CLI...\e[0m"
            ensure_package curl
            ensure_package ca-certificates
            export NVM_DIR="/root/.nvm"
            if [ ! -s "$NVM_DIR/nvm.sh" ]; then
                curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
            fi
            source "$NVM_DIR/nvm.sh"
            if ! command -v node >/dev/null 2>&1; then
                nvm install --lts
            fi
            npm install -g @google/gemini-cli
            echo -e "\e[1;32m→ Gemini CLI installé. Lancez 'gemini auth'.\e[0m"
            ;;
        shell-gpt)
            echo -e "\n\e[1;36m→ Installation de Shell-GPT...\e[0m"
            ensure_package python3
            ensure_package python3-pip
            ensure_package build-essential
            pip install --upgrade pip
            pip install shell-gpt
            echo -e "\e[1;32m→ Shell-GPT installé. Configurez avec 'sgpt --configure'.\e[0m"
            ;;
        webmin)
            echo -e "\n\e[1;34m→ Ajout du dépôt Webmin...\e[0m"
            apt install -y wget gnupg2 software-properties-common apt-transport-https ca-certificates
            wget -q https://download.webmin.com/jcameron-key.asc -O- | gpg --dearmor > /etc/apt/trusted.gpg.d/webmin.gpg
            echo "deb https://download.webmin.com/download/repository sarge contrib" > /etc/apt/sources.list.d/webmin.list
            apt update
            $INSTALLER install -y webmin
            echo -e "\e[1;32m→ Webmin installé avec succès.\e[0m"
            echo -e "\e[1;33mAccédez à Webmin : https://$(hostname -I | awk '{print $1}'):10000\e[0m"
            ;;
        *)
            install_list+=("$item")
            ;;
    esac
done

# ==========================
# Installation standard des autres paquets
# ==========================
if [ ${#install_list[@]} -gt 0 ]; then
    echo -e "\n\e[1;34m→ Installation des paquets standard : ${install_list[*]}\e[0m"
    $INSTALLER install -y "${install_list[@]}"
fi

# ==========================
# Fin du script
# ==========================
echo -e "\n\e[1;32m→ Installation terminée.\e[0m"
