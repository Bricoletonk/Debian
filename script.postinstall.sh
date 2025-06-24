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

# Déclaration des paquets et descriptions
declare -A packages=(
    [nala]="Interface améliorée pour apt"
    [exa]="Remplaçant moderne de 'ls'"
    [bat]="Remplaçant de 'cat' avec coloration syntaxique"
    [info]="Affiche la documentation GNU"
    [lm-sensors]="Surveille les capteurs matériels"
    [inxi]="Outil complet d’information système"
    [screenfetch]="Affiche les infos système en ASCII"
    [btop]="Moniteur système moderne (remplaçant de htop)"
    [fun]="Utilitaires fun : cbonsai, cmatrix, tty-clock, sl"
    [webmin]="Interface web d'administration système (port 10000)"
)

fun_tools=(cbonsai cmatrix tty-clock sl)

# Retirer les paquets déjà installés des propositions
for pkg in "${!packages[@]}"; do
    if [[ "$pkg" == "fun" ]]; then
        all_fun_installed=true
        for tool in "${fun_tools[@]}"; do
            if ! command -v "$tool" >/dev/null 2>&1; then
                all_fun_installed=false
                break
            fi
        done
        if $all_fun_installed; then
            unset packages["fun"]
        fi
    else
        if command -v "$pkg" >/dev/null 2>&1 || dpkg -s "$pkg" &>/dev/null; then
            unset packages["$pkg"]
        fi
    fi
done

selected=()

echo -e "\n\e[1;36m===== INSTALLATION DE LOGICIELS =====\e[0m"

for pkg in "${!packages[@]}"; do
    echo
    ask "Souhaitez-vous installer ${pkg} (${packages[$pkg]}) ? [o/N]" answer
    if [[ "$answer" =~ ^[oOyY]$ ]]; then
        if [[ "$pkg" == "fun" ]]; then
            selected+=("${fun_tools[@]}")
        elif [[ "$pkg" != "webmin" ]]; then
            selected+=("$pkg")
        fi
    fi
done

if [ ${#selected[@]} -gt 0 ]; then
    echo
    echo -e "\e[1;34m→ Installation des paquets sélectionnés : ${selected[*]}\e[0m"
    apt update
    $INSTALLER install -y "${selected[@]}"
else
    echo -e "\e[1;33mAucun paquet sélectionné pour l'installation.\e[0m"
fi

# Installation spécifique de Webmin
if [[ " ${!packages[@]} " =~ " webmin " ]]; then
    ask "Souhaitez-vous installer Webmin (${packages[webmin]}) ? [o/N]" webmin_ans
    if [[ "$webmin_ans" =~ ^[oOyY]$ ]]; then
        echo -e "\e[1;34m→ Installation de Webmin...\e[0m"

        apt install -y wget gnupg2 software-properties-common apt-transport-https ca-certificates

        wget -q https://download.webmin.com/jcameron-key.asc -O- | gpg --dearmor > /etc/apt/trusted.gpg.d/webmin.gpg
        echo "deb https://download.webmin.com/download/repository sarge contrib" > /etc/apt/sources.list.d/webmin.list

        apt update
        $INSTALLER install -y webmin

        echo -e "\e[1;32m→ Webmin installé avec succès.\e[0m"
        echo -e "\e[1;33mAccédez à Webmin : https://$(hostname -I | awk '{print $1}'):10000\e[0m"
    fi
fi

# Configuration lm-sensors si installé
if [[ " ${selected[*]} " =~ " lm-sensors " ]]; then
    echo
    echo -e "\e[1;34m→ Configuration des capteurs matériels via sensors-detect...\e[0m"
    yes | sensors-detect
fi

# Ajout automatique des alias
echo -e "\e[1;34m→ Ajout automatique des alias utiles dans /root/.bashrc et /etc/skel/.bashrc...\e[0m"
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
