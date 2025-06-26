#!/bin/bash

# Vérifie que le script est exécuté en tant que root
if [[ $EUID -ne 0 ]]; then
    echo -e "\e[1;31mCe script doit être exécuté en tant que root.\e[0m"
    exit 1
fi

# Fonction pour poser des questions avec couleur jaune
ask() {
    local prompt="$1"
    local varname="$2"
    read -e -p "$(echo -e "\e[1;33m$prompt\e[0m")" "$varname"
}

# =================================================================
# FONCTION D'INSTALLATION DU CLI GEMINI
# =================================================================
install_gemini_cli() {
    echo -e "\n\e[1;36m===== INSTALLATION DE GEMINI CLI =====\e[0m"

    # Vérifier si NVM est installé
    export NVM_DIR="$HOME/.nvm"
    if [ -s "$NVM_DIR/nvm.sh" ]; then
        echo -e "\e[1;32m→ NVM est déjà installé.\e[0m"
        source "$NVM_DIR/nvm.sh"  # Charger NVM
    else
        echo -e "\e[1;34m→ Installation de NVM (Node Version Manager)...\e[0m"
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
        source "$HOME/.nvm/nvm.sh"
    fi

    # Installer Node.js (LTS) si ce n'est pas déjà fait
    if ! command -v node >/dev/null 2>&1; then
        echo -e "\e[1;34m→ Installation de la dernière version LTS de Node.js...\e[0m"
        nvm install --lts
    else
        echo -e "\e[1;32m→ Node.js est déjà installé (version $(node -v)).\e[0m"
    fi

    # Installer Gemini CLI
    echo -e "\e[1;34m→ Installation de Gemini CLI via npm...\e[0m"
npm install -g @google/gemini-cli

    echo -e "\e[1;32m→ Installation de Gemini CLI terminée.\e[0m"
    echo -e "\e[1;33mUtilisez la commande 'gemini' pour démarrer.\e[0m"
    echo -e "\e[1;33mLa première fois, vous devrez vous authentifier avec 'gemini auth'.\e[0m"
}


# =================================================================
# FONCTION DE POST-INSTALLATION (VOTRE SCRIPT ORIGINAL)
# =================================================================
run_postinstall() {
    echo -e "\n\e[1;36m===== DÉBUT DU SCRIPT DE POST-INSTALLATION =====\e[0m"
    # Détection de nala
    if command -v nala >/dev/null 2>&1; then
        INSTALLER="nala"
        alias apt="nala"
        echo -e "\e[1;32m→ Nala détecté : les paquets seront installés avec nala.\e[0m"
    else
        INSTALLER="apt"
        echo -e "\e[1;33m→ Nala non détecté : les paquets seront installés avec apt.\e[0m"
    fi

    # Détection de l'interface graphique
    if pgrep -x "Xorg" >/dev/null || pgrep -x "gnome-session" >/dev/null || pgrep -x "sddm" >/dev/null || pgrep -x "gdm" >/dev/null || pgrep -x "lightdm" >/dev/null; then
        HAS_GUI=true
        echo -e "\e[1;32m→ Interface graphique détectée.\e[0m"
    else
        HAS_GUI=false
        echo -e "\e[1;33m→ Pas d'interface graphique détectée.\e[0m"
    fi

    # Paquets et descriptions
    declare -A packages=(
        [nala]="Interface améliorée pour apt"
        [exa]="Remplaçant moderne de 'ls'"
        [bat]="Remplaçant de 'cat' avec coloration syntaxique"
        [info]="Affiche la documentation GNU"
        [inxi]="Outil complet d’information système"
        [screenfetch]="Affiche les infos système en ASCII"
        [btop]="Moniteur système moderne (remplaçant de htop)"
        [webmin]="Interface web d'administration système (port 10000)"
    )

    if [[ "$HAS_GUI" == true ]]; then
        packages[fun]="Utilitaires fun : cbonsai, cmatrix, tty-clock, sl"
        packages[lm-sensors]="Surveille les capteurs matériels"
    fi
    fun_tools=(cbonsai cmatrix tty-clock sl)

    # Retirer les paquets déjà installés
    for pkg in "${!packages[@]}"; do
        if [[ "$pkg" == "fun" ]]; then
            all_fun_installed=true
            for tool in "${fun_tools[@]}"; do
                if ! command -v "$tool" >/dev/null 2>&1; then
                    all_fun_installed=false
                    break
                fi
            done
            if $all_fun_installed; then unset packages["fun"]; fi
        else
            if command -v "$pkg" >/dev/null 2>&1 || dpkg -s "$pkg" &>/dev/null; then
                unset packages["$pkg"]
            fi
        fi
    done

    selected=()
    echo -e "\n\e[1;36m===== INSTALLATION DE LOGICIELS =====\e[0m"
    for pkg in "${!packages[@]}"; do
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
        apt update
        if [[ " ${selected[*]} " =~ " webmin " ]]; then
            echo -e "\e[1;34m→ Ajout du dépôt Webmin...\e[0m"
            apt install -y wget gnupg2 software-properties-common apt-transport-https ca-certificates
            wget -q https://download.webmin.com/jcameron-key.asc -O- | gpg --dearmor > /etc/apt/trusted.gpg.d/webmin.gpg
            echo "deb https://download.webmin.com/download/repository sarge contrib" > /etc/apt/sources.list.d/webmin.list
            apt update
        fi
        $INSTALLER install -y "${selected[@]}"
        if [[ " ${selected[*]} " =~ " webmin " ]]; then
            echo -e "\e[1;32m→ Webmin installé avec succès.\e[0m"
            echo -e "\e[1;33mAccédez à Webmin : https://$(hostname -I | awk '{print $1}'):10000\e[0m"
        fi
    else
        echo -e "\e[1;33mAucun paquet sélectionné pour l'installation.\e[0m"
    fi

    if [[ " ${selected[*]} " =~ " lm-sensors " ]]; then
        echo -e "\n\e[1;34m→ Configuration des capteurs matériels via sensors-detect...\e[0m"
        yes | sensors-detect
    fi

    echo -e "\n\e[1;34m→ Ajout automatique des alias utiles dans /root/.bashrc et /etc/skel/.bashrc...\e[0m"
    for bashrc in "/root/.bashrc" "/etc/skel/.bashrc"; do
        cat <<'EOF' >> "$bashrc"
# === Alias personnalisés ===
alias apt='nala'
alias la='exa -laT'
alias ll='exa -lT'
alias cat='batcat'
alias top='btop'
alias ip='ip -c'
alias man='info'
EOF
    done

    ROOT_PROMPT='\\[\\e[1;31m\\][ \\u@\\h \\[\\e[0;37m\\]] \\w #\\[\\e[0m\\]'
    echo "export PS1=\"$ROOT_PROMPT\"" >> "/root/.bashrc"

    USER_TEMPLATE="/etc/skel/.bashrc"
    cat <<'EOF' >> "$USER_TEMPLATE"
# Prompt utilisateur : vert
GREEN='\\[\\e[1;32m\\]'
WHITE='\\[\\e[0;37m\\]'
RESET='\\[\\e[0m\\]'
export PS1="${WHITE}[ ${GREEN}\\u@\\h${WHITE} ] \\w \\$${RESET}"
EOF

    ask "\nSouhaitez-vous changer le nom de la machine (hostname) ? [o/N]" change_host
    if [[ "$change_host" =~ ^[oOyY]$ ]]; then
        ask "Entrez le nouveau nom de la machine :" new_hostname
        echo "$new_hostname" > /etc/hostname
        hostnamectl set-hostname "$new_hostname"
        echo -e "\e[1;32m→ Nom de la machine changé en $new_hostname\e[0m"
    fi

    ask "\nSouhaitez-vous activer l’accès SSH pour root ? [o/N]" ssh_root_ans
    if [[ "$ssh_root_ans" =~ ^[oOyY]$ ]]; then
        SSH_CONF="/etc/ssh/sshd_config"
        if grep -q "^#\\?PermitRootLogin" "$SSH_CONF"; then
            sed -i 's/^#\\?PermitRootLogin.*/PermitRootLogin yes/' "$SSH_CONF"
        else
            echo "PermitRootLogin yes" >> "$SSH_CONF"
        fi
        systemctl restart ssh
        echo -e "\e[1;32m→ Accès SSH root activé (SSH redémarré).\e[0m"
    else
        echo -e "\e[1;33m→ Accès SSH root laissé désactivé.\e[0m"
    fi
}

# =================================================================
# MENU PRINCIPAL
# =================================================================
main_menu() {
    while true; do
        echo -e "\n\e[1;35m============== MENU PRINCIPAL ==============
\e[0m"
        echo "1. Lancer le script de post-installation"
        echo "2. Installer Gemini CLI"
        echo "3. Lancer les deux (Post-install PUIS Gemini)"
        echo "4. Quitter"
        echo -e "\e[1;35m============================================\e[0m"
        ask "Votre choix [1-4] :" choice

        case $choice in
            1)
                run_postinstall
                break
                ;;n            2)
                install_gemini_cli
                break
                ;;n            3)
                run_postinstall
                install_gemini_cli
                break
                ;;n            4)
                echo "Au revoir !"
                exit 0
                ;;n            *)
                echo -e "\e[1;31mChoix invalide. Veuillez réessayer.\e[0m"
                ;;n        esac
    done

    # Redémarrage final si la post-install a été lancée
    if [[ "$choice" == "1" || "$choice" == "3" ]]; then
        ask "\nLe script est terminé. Souhaitez-vous redémarrer la machine maintenant ? [O/n]" reboot_ans
        if [[ ! "$reboot_ans" =~ ^[nN]$ ]]; then
            echo -e "\e[1;34m→ Redémarrage en cours...\e[0m"
            sleep 2
            reboot
        else
            echo -e "\e[1;33m→ Redémarrage annulé. Pensez à le faire manuellement.\e[0m"
        fi
    fi
}

# Lancement du menu principal
main_menu
