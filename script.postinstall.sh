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

# Test exa/eza dispo
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
    [exa]="Remplaçant moderne de 'ls'"
    [info]="Affiche la documentation GNU"
    [inxi]="Outil complet d’information système"
    [nala]="Interface améliorée pour apt"
    [screenfetch]="Affiche les infos système en ASCII"
    [shell-gpt]="Assistant IA OpenAI en ligne de commande (nécessite Python)"
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
    if [[ "$pkg" == "fun" ]]; then
        ask "Souhaitez-vous installer ${pkg} (${packages[$pkg]}) ? [o/N]" answer
        if [[ "$answer" =~ ^[oOyY]$ ]]; then
            selected+=("${fun_tools[@]}")
        fi
    else
        ask "Souhaitez-vous installer ${pkg} (${packages[$pkg]}) ? [o/N]" answer
        if [[ "$answer" =~ ^[oOyY]$ ]]; then
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

# Gemini CLI
if [[ " ${selected[*]} " =~ " gemini-cli " ]]; then
    echo -e "\n\e[1;36m→ Installation de Gemini CLI\e[0m"
    export NVM_DIR="$HOME/.nvm"
    if [ ! -s "$NVM_DIR/nvm.sh" ]; then
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
    fi
    source "$NVM_DIR/nvm.sh"
    nvm install --lts
    npm install -g @google/gemini-cli
    echo -e "\e[1;32m→ Gemini CLI installé. Lancez 'gemini auth' pour configurer.\e[0m"
fi

# Shell-GPT
if [[ " ${selected[*]} " =~ " shell-gpt " ]]; then
    echo -e "\n\e[1;36m→ Installation de Shell-GPT\e[0m"
    apt install -y python3 python3-pip
    pip install shell-gpt
    echo -e "\e[1;32m→ Shell-GPT installé. Configurez avec 'sgpt --configure'.\e[0m"
fi

# Alias
echo -e "\n\e[1;34m→ Ajout des alias dans /root/.bashrc et /etc/skel/.bashrc...\e[0m"
for bashrc in "/root/.bashrc" "/etc/skel/.bashrc"; do
    cat <<EOF >> "$bashrc"

# === Alias personnalisés ===
alias apt='nala'
alias la='$LS_TOOL -laT'
alias ll='$LS_TOOL -lT'
alias cat='batcat'
alias top='btop'
alias ip='ip -c'
alias man='info'
EOF
done

# Prompt root
ROOT_PROMPT='\\[\\e[1;31m\\][ \\u@\\h \\[\\e[0;37m\\]] \\w #\\[\\e[0m\\]'
echo "export PS1=\"$ROOT_PROMPT\"" >> "/root/.bashrc"

# Prompt utilisateurs
USER_TEMPLATE="/etc/skel/.bashrc"
cat <<'EOF' >> "$USER_TEMPLATE"

# Prompt utilisateur : vert
GREEN='\\[\\e[1;32m\\]'
WHITE='\\[\\e[0;37m\\]'
RESET='\\[\\e[0m\\]'
export PS1="${WHITE}[ ${GREEN}\\u@\\h${WHITE} ] \\w \$${RESET}"
EOF

# Hostname
ask "Souhaitez-vous changer le nom de la machine (hostname) ? [o/N]" change_host
if [[ "$change_host" =~ ^[oOyY]$ ]]; then
    ask "Entrez le nouveau nom de la machine :" new_hostname
    echo "$new_hostname" > /etc/hostname
    hostnamectl set-hostname "$new_hostname"
    echo -e "\e[1;32m→ Nom de la machine changé en $new_hostname\e[0m"
fi

# SSH root
ask "Souhaitez-vous activer l’accès SSH pour root ? [o/N]" ssh_root_ans
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

# /etc/issue customization
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
        [[ $issue_display =~ hostname ]] && echo "Hostname : \\n"
        [[ $issue_display =~ date ]] && echo "Date     : \\d"
        [[ $issue_display =~ kernel ]] && echo "Kernel   : \\v"
        [[ $issue_display =~ console ]] && echo "Console  : \\l"
        echo
        if [[ $issue_display =~ ip ]]; then
            echo "Adresses IP :"
            hostname -I | xargs -n1
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
