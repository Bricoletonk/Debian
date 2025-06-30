#!/bin/bash

# ============================================================
# SCRIPT DE POST-INSTALLATION DEBIAN + IA + IP SUR ISSUE
# ============================================================

# Vérifie que le script est exécuté en tant que root
if [[ $EUID -ne 0 ]]; then
    echo -e "\e[1;31mCe script doit être exécuté en tant que root.\e[0m"
    exit 1
fi

# Fonction pour poser des questions avec couleur jaune
ask() {
    local prompt="$1"
    local varname="$2"
    read -e -p "$(echo -e "\e[1;33m$prompt\e[0m") " "$varname"
}

# Fonction pour vérifier et installer un paquet manquant
ensure_package() {
    if ! dpkg -s "$1" &>/dev/null; then
        echo -e "\e[1;34m→ Installation de $1...\e[0m"
        apt update
        apt install -y "$1"
    fi
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

# Détection de la présence d'une interface graphique
if pgrep -x "Xorg" >/dev/null || pgrep -x "gnome-session" >/dev/null || pgrep -x "sddm" >/dev/null || pgrep -x "gdm" >/dev/null || pgrep -x "lightdm" >/dev/null; then
    HAS_GUI=true
    echo -e "\e[1;32m→ Interface graphique détectée.\e[0m"
else
    HAS_GUI=false
    echo -e "\e[1;33m→ Pas d'interface graphique détectée.\e[0m"
fi

# Gestion de eza/exa
if apt-cache show eza &>/dev/null; then
    exa_cmd="eza"
    echo -e "\e[1;32m→ eza sera utilisé pour les alias.\e[0m"
elif apt-cache show exa &>/dev/null; then
    exa_cmd="exa"
    echo -e "\e[1;32m→ exa sera utilisé pour les alias.\e[0m"
else
    echo -e "\e[1;31m→ Ni eza ni exa ne sont disponibles dans les dépôts. Les alias ls ne seront pas créés.\e[0m"
    exa_cmd="ls"
fi

# Déclaration des paquets et descriptions
declare -A packages=(
    [nala]="Interface améliorée pour apt"
    [bat]="Remplaçant de 'cat' avec coloration syntaxique"
    [info]="Affiche la documentation GNU"
    [inxi]="Outil complet d’information système"
    [screenfetch]="Affiche les infos système en ASCII"
    [btop]="Moniteur système moderne (remplaçant de htop)"
    [webmin]="Interface web d'administration système (port 10000)"
    [gemini-cli]="Assistant IA Gemini CLI (nécessite Node.js)"
    [shell-gpt]="Assistant IA Shell-GPT (nécessite OpenAI API)"
)

# Ajout conditionnel des paquets graphiques
if [[ "$HAS_GUI" == true ]]; then
    packages[fun]="Utilitaires fun : cbonsai, cmatrix, tty-clock, sl"
    packages[lm-sensors]="Surveille les capteurs matériels"
fi

fun_tools=(cbonsai cmatrix tty-clock sl)

# Menu de sélection des logiciels
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

# Ajout de paquets personnalisés
echo
ask "Souhaitez-vous ajouter manuellement des logiciels supplémentaires ? (ex: apache2 vim curl) [o/N]" custom_ans
if [[ "$custom_ans" =~ ^[oOyY]$ ]]; then
    ask "Entrez les noms des paquets à ajouter (séparés par des espaces) :" custom_packages
    if [[ -n "$custom_packages" ]]; then
        selected+=($custom_packages)
    fi
fi

# Gestion spéciale IA, Webmin
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

# Installation des autres paquets
if [ ${#install_list[@]} -gt 0 ]; then
    echo -e "\n\e[1;34m→ Installation des paquets standard : ${install_list[*]}\e[0m"
    $INSTALLER install -y "${install_list[@]}"
fi

# Configuration des capteurs si lm-sensors sélectionné
if [[ " ${selected[*]} " =~ " lm-sensors " ]]; then
    echo
    echo -e "\e[1;34m→ Configuration des capteurs matériels via sensors-detect...\e[0m"
    yes | sensors-detect
fi

# Ajout des alias
echo -e "\e[1;34m→ Ajout des alias dans /root/.bashrc et /etc/skel/.bashrc...\e[0m"
for bashrc in "/root/.bashrc" "/etc/skel/.bashrc"; do
    cat <<EOF >> "$bashrc"

# === Alias personnalisés ===
alias apt='nala'
alias la='$exa_cmd -laT'
alias ll='$exa_cmd -lT'
alias cat='batcat'
alias top='btop'
alias ip='ip -c'
alias man='info'
EOF
done

# Prompt root
RED='\[\e[1;31m\]'
WHITE='\[\e[0;37m\]'
RESET='\[\e[0m\]'
ROOT_PROMPT="${WHITE}[ ${RED}\u@\h${WHITE} ] \w #${RESET}"
echo "export PS1=\"$ROOT_PROMPT\"" >> "/root/.bashrc"

# Prompt utilisateurs
USER_TEMPLATE="/etc/skel/.bashrc"
cat <<EOF >> "$USER_TEMPLATE"

# Prompt utilisateur : vert
GREEN='\[\e[1;32m\]'
WHITE='\[\e[0;37m\]'
RESET='\[\e[0m\]'
export PS1="\${WHITE}[ \${GREEN}\u@\h\${WHITE} ] \w \$\${RESET}"
EOF

# Hostname
echo
ask "Souhaitez-vous changer le nom de la machine (hostname) ? [o/N]" change_host
if [[ "$change_host" =~ ^[oOyY]$ ]]; then
    ask "Entrez le nouveau nom de la machine :" new_hostname
    echo "$new_hostname" > /etc/hostname
    hostnamectl set-hostname "$new_hostname"
    echo -e "\e[1;32m→ Nom de la machine changé en $new_hostname\e[0m"
fi

# SSH root
echo
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

# === Service IP dans /etc/issue ===
cat << 'EOF' > /usr/local/bin/update-issue-ip.sh
#!/bin/bash
IP_INFO=$(hostname -I | xargs -n1)
ISSUE_TEXT="Debian GNU/Linux \n \l

Adresses IP :
${IP_INFO}
"
echo -e "$ISSUE_TEXT" > /etc/issue
EOF
chmod +x /usr/local/bin/update-issue-ip.sh

cat << 'EOF' > /etc/systemd/system/update-issue-ip.service
[Unit]
Description=Affiche les adresses IP dans /etc/issue
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/update-issue-ip.sh

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable update-issue-ip.service
systemctl start update-issue-ip.service

# Redémarrage final
echo
ask "Souhaitez-vous redémarrer la machine maintenant ? [O/n]" reboot_ans
if [[ "$reboot_ans" =~ ^[nN]$ ]]; then
    echo -e "\e[1;33m→ Redémarrage annulé. Vous pouvez le faire plus tard avec \"reboot\".\e[0m"
else
    echo -e "\e[1;34m→ Redémarrage en cours...\e[0m"
    sleep 2
    reboot
fi
