#!/bin/bash
# ==========================================================
#  Script de post-installation Debian 12 / 13
#  https://github.com/Bricoletonk/Debian
# ==========================================================

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

is_yes() { [[ "$1" =~ ^[oOyY]$ ]]; }

# Messages récapitulatifs affichés à la toute fin du script
FINAL_NOTES=()

# ----------------------------------------------------------
#  Détections
# ----------------------------------------------------------

# Interface graphique présente ? (session de bureau ou gestionnaire de connexion installé)
# Remarque : systemctl get-default renvoie "graphical.target" même sur un Debian sans bureau,
# donc on ne s'y fie pas.
has_gui() {
    compgen -G "/usr/share/xsessions/*.desktop" >/dev/null && return 0
    compgen -G "/usr/share/wayland-sessions/*.desktop" >/dev/null && return 0
    [ -e /etc/systemd/system/display-manager.service ] && return 0
    return 1
}

# Utilisateurs "humains" (UID >= 1000 avec un dossier dans /home)
list_human_users() {
    getent passwd | awk -F: '$3 >= 1000 && $3 < 65534 && $6 ~ /^\/home\// {print $1}'
}

# Choix de l'utilisateur principal (demandé une seule fois, seulement si nécessaire)
MAIN_USER=""
MAIN_USER_ASKED=false
choose_main_user() {
    $MAIN_USER_ASKED && return
    MAIN_USER_ASKED=true
    local users
    mapfile -t users < <(list_human_users)
    if [ ${#users[@]} -eq 0 ]; then
        MAIN_USER=""
    elif [ ${#users[@]} -eq 1 ]; then
        MAIN_USER="${users[0]}"
    else
        ask "Plusieurs utilisateurs trouvés (${users[*]}). Lequel est l'utilisateur principal ? [${users[0]}]" MAIN_USER
        MAIN_USER="${MAIN_USER:-${users[0]}}"
        if ! id "$MAIN_USER" >/dev/null 2>&1; then
            echo -e "\e[1;33m→ Utilisateur inconnu, ${users[0]} sera utilisé.\e[0m"
            MAIN_USER="${users[0]}"
        fi
    fi
}

ARCH="$(dpkg --print-architecture)"
RAM_MB="$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)"
if has_gui; then GUI=true; else GUI=false; fi

echo -e "\e[1;34m→ Architecture : $ARCH | RAM : ${RAM_MB} Mo | Interface graphique : $($GUI && echo oui || echo non)\e[0m"
echo -e "\e[1;34m→ Préparation du système et installation des dépendances requises...\e[0m"

# Désactivation du CD-ROM comme source de paquets (si l'ancien format sources.list est utilisé)
[ -f /etc/apt/sources.list ] && sed -i '/^deb cdrom:/s/^/#/' /etc/apt/sources.list

echo -e "\e[1;36m→ Mise à jour des dépôts (apt-get update)...\e[0m"
apt-get update

echo -e "\e[1;36m→ Installation de Nala, curl et des outils de base...\e[0m"
apt-get install -y nala curl wget gnupg ca-certificates lsb-release

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
    chmod -x /etc/update-motd.d/* 2>/dev/null
fi

# Détection de eza (Debian 13) / exa (Debian 12)
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
    [info]="Affiche la documentation GNU"
    [inxi]="Outil complet d’information système"
    [screenfetch]="Affiche les infos système en ASCII"
)
if [ -n "$LS_TOOL" ]; then
    packages[$LS_TOOL]="Remplaçant moderne de 'ls'"
fi

selected=()

echo -e "\n\e[1;36m===== INSTALLATION DE LOGICIELS =====\e[0m"

for pkg in $(printf '%s\n' "${!packages[@]}" | sort); do
    ask "Souhaitez-vous installer ${pkg} (${packages[$pkg]}) ? [o/N]" answer
    if is_yes "$answer"; then
        selected+=("$pkg")
    fi
done

ask "Souhaitez-vous installer Claude Code (assistant IA d'Anthropic, en ligne de commande) ? [o/N]" claude_cli_ans
claude_desktop_ans="n"
if $GUI; then
    ask "Interface graphique détectée : installer aussi l'application Claude Desktop (bêta) ? [o/N]" claude_desktop_ans
fi
ask "Souhaitez-vous installer gemini-cli (Assistant IA Google) ? [o/N]" gemini_ans
ask "Souhaitez-vous installer webmin (Interface web d'administration système) ? [o/N]" webmin_ans

ask "Souhaitez-vous ajouter manuellement des logiciels supplémentaires ? (ex: apache2 vim) [o/N]" custom_ans
if is_yes "$custom_ans"; then
    ask "Entrez les noms des paquets à ajouter (séparés par des espaces) :" custom_packages
    if [[ -n "$custom_packages" ]]; then
        read -r -a custom_array <<< "$custom_packages"
        selected+=("${custom_array[@]}")
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

# ----------------------------------------------------------
#  Webmin
# ----------------------------------------------------------
if is_yes "$webmin_ans"; then
    echo -e "\n\e[1;34m→ Installation de Webmin...\e[0m"
    # Utilisation du script officiel de Webmin qui gère les clés modernes
    if curl -fsSL https://raw.githubusercontent.com/webmin/webmin/master/setup-repos.sh -o /tmp/setup-repos.sh; then
        echo "y" | sh /tmp/setup-repos.sh
        if $INSTALLER install -y webmin; then
            echo -e "\e[1;32m→ Webmin installé.\e[0m"
            FINAL_NOTES+=("Webmin : https://$(hostname -I | awk '{print $1}'):10000")
        else
            echo -e "\e[1;31m→ Erreur : l'installation de Webmin a échoué.\e[0m"
        fi
        rm -f /tmp/setup-repos.sh
    else
        echo -e "\e[1;31m→ Erreur : impossible de télécharger le script de dépôt Webmin.\e[0m"
    fi
fi

# ----------------------------------------------------------
#  Claude (Anthropic)
# ----------------------------------------------------------
ANTHROPIC_FPR="31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE"

# Télécharge une clé de signature et vérifie qu'elle appartient bien à Anthropic
fetch_anthropic_key() {
    local url="$1" dest="$2" fpr
    install -d -m 0755 "$(dirname "$dest")"
    if ! curl -fsSL "$url" -o "$dest"; then
        echo -e "\e[1;31m→ Impossible de télécharger la clé $url\e[0m"
        return 1
    fi
    fpr="$(gpg --show-keys --with-colons "$dest" 2>/dev/null | awk -F: '/^fpr/ {print $10; exit}')"
    if [ "$fpr" != "$ANTHROPIC_FPR" ]; then
        echo -e "\e[1;31m→ Empreinte de clé inattendue ($fpr) : installation annulée par sécurité.\e[0m"
        rm -f "$dest"
        return 1
    fi
}

# Installation de secours : installeur officiel, pour un utilisateur (dans ~/.local/bin)
install_claude_native_for_user() {
    local user="$1"
    echo -e "\e[1;34m→ Installation de secours via l'installeur officiel pour $user...\e[0m"
    if su - "$user" -c 'curl -fsSL https://claude.ai/install.sh | bash'; then
        echo -e "\e[1;32m→ Claude Code installé pour $user (mises à jour automatiques).\e[0m"
        return 0
    fi
    return 1
}

if is_yes "$claude_cli_ans" || is_yes "$claude_desktop_ans"; then
    echo -e "\n\e[1;36m===== INSTALLATION DE CLAUDE =====\e[0m"
    choose_main_user
    if [[ "$ARCH" != "amd64" && "$ARCH" != "arm64" ]]; then
        echo -e "\e[1;31m→ Architecture $ARCH non prise en charge par Claude (amd64 ou arm64 requis).\e[0m"
        claude_cli_ans="n"; claude_desktop_ans="n"
    elif [ "$RAM_MB" -lt 3800 ]; then
        echo -e "\e[1;33m→ Attention : Claude Code recommande 4 Go de RAM (${RAM_MB} Mo détectés). Installation quand même.\e[0m"
    fi
fi

CLAUDE_CLI_OK=false
if is_yes "$claude_cli_ans"; then
    echo -e "\e[1;34m→ Ajout du dépôt officiel Claude Code (canal stable)...\e[0m"
    if fetch_anthropic_key https://downloads.claude.ai/keys/claude-code.asc /etc/apt/keyrings/claude-code.asc; then
        echo "deb [signed-by=/etc/apt/keyrings/claude-code.asc] https://downloads.claude.ai/claude-code/apt/stable stable main" \
            > /etc/apt/sources.list.d/claude-code.list
        apt-get update
        if $INSTALLER install -y claude-code; then
            CLAUDE_CLI_OK=true
            echo -e "\e[1;32m→ Claude Code installé pour tous les utilisateurs ($(claude --version 2>/dev/null)).\e[0m"
            FINAL_NOTES+=("Claude Code : mises à jour avec 'apt upgrade' comme le reste du système.")
        fi
    fi
    if ! $CLAUDE_CLI_OK && [ -n "$MAIN_USER" ]; then
        install_claude_native_for_user "$MAIN_USER" && CLAUDE_CLI_OK=true
    fi
    if $CLAUDE_CLI_OK; then
        FINAL_NOTES+=("Claude Code : connectez-vous avec votre utilisateur normal (pas root) en tapant 'claude'.")
        if $GUI; then
            FINAL_NOTES+=("   → Le navigateur s'ouvre : connectez-vous avec votre compte Claude (Pro ou Max requis).")
        else
            FINAL_NOTES+=("   → Pas de navigateur ici : 'claude' affiche un lien. Ouvrez-le sur votre PC,")
            FINAL_NOTES+=("     connectez-vous avec votre compte Claude (Pro ou Max), puis collez le code affiché dans le terminal.")
        fi
    else
        echo -e "\e[1;31m→ Erreur : l'installation de Claude Code a échoué.\e[0m"
    fi
fi

if is_yes "$claude_desktop_ans"; then
    echo -e "\e[1;34m→ Ajout du dépôt officiel Claude Desktop...\e[0m"
    if fetch_anthropic_key https://downloads.claude.ai/claude-desktop/key.asc /usr/share/keyrings/claude-desktop-archive-keyring.asc; then
        echo "deb [arch=amd64,arm64 signed-by=/usr/share/keyrings/claude-desktop-archive-keyring.asc] https://downloads.claude.ai/claude-desktop/apt/stable stable main" \
            > /etc/apt/sources.list.d/claude-desktop.list
        apt-get update
        if $INSTALLER install -y claude-desktop; then
            echo -e "\e[1;32m→ Claude Desktop installé.\e[0m"
            FINAL_NOTES+=("Claude Desktop : lancez 'Claude' depuis le menu des applications (pas en root) et connectez-vous.")
            # Cowork a besoin de la virtualisation (groupe kvm)
            if [ -n "$MAIN_USER" ] && getent group kvm >/dev/null; then
                usermod -aG kvm "$MAIN_USER"
                FINAL_NOTES+=("   → $MAIN_USER ajouté au groupe kvm (pour l'onglet Cowork), actif après redémarrage.")
            fi
        else
            echo -e "\e[1;31m→ Erreur : l'installation de Claude Desktop a échoué.\e[0m"
        fi
    fi
fi

# ----------------------------------------------------------
#  Gemini CLI
# ----------------------------------------------------------
if is_yes "$gemini_ans"; then
    echo -e "\n\e[1;34m→ Installation de Node.js 24 LTS (via NodeSource) et Gemini CLI...\e[0m"
    curl -fsSL https://deb.nodesource.com/setup_24.x | bash -
    $INSTALLER install -y nodejs

    if command -v npm >/dev/null 2>&1 && npm install -g @google/gemini-cli; then
        echo -e "\e[1;32m→ Gemini CLI a été installé avec succès.\e[0m"
        choose_main_user

        echo -e "\n\e[1;33mPour utiliser Gemini, vous pouvez utiliser une clé API Google gratuite.\e[0m"
        echo -e "Ouvrez ce lien dans le navigateur de votre PC :"
        echo -e "\e[1;36mhttps://aistudio.google.com/app/apikey\e[0m\n"

        if [ -n "$MAIN_USER" ]; then
            ask "Voulez-vous enregistrer une clé API pour l'utilisateur $MAIN_USER maintenant ? [o/N]" key_ready
        else
            key_ready="n"
        fi
        if is_yes "$key_ready"; then
            ask "Collez votre clé API ici :" GEMINI_API_KEY
            if [[ -n "$GEMINI_API_KEY" ]]; then
                user_home="$(getent passwd "$MAIN_USER" | cut -d: -f6)"
                install -d -m 700 -o "$MAIN_USER" -g "$(id -gn "$MAIN_USER")" "$user_home/.gemini"
                # Fichier lisible uniquement par l'utilisateur (la clé n'est pas exposée aux autres comptes)
                ( umask 077; echo "GEMINI_API_KEY=\"$GEMINI_API_KEY\"" > "$user_home/.gemini/.env" )
                chown "$MAIN_USER:$(id -gn "$MAIN_USER")" "$user_home/.gemini/.env"
                echo -e "\e[1;32m→ Clé API enregistrée dans $user_home/.gemini/.env (accessible uniquement par $MAIN_USER).\e[0m"
            fi
        else
            FINAL_NOTES+=("Gemini CLI : lancez 'gemini', il propose les méthodes de connexion au premier démarrage.")
        fi
    else
        echo -e "\e[1;31m→ Erreur : Node.js / npm est introuvable ou l'installation de Gemini a échoué.\e[0m"
    fi
fi

# ----------------------------------------------------------
#  Fichiers .bashrc
# ----------------------------------------------------------
echo -e "\n\e[1;34m→ Configuration des alias et des prompts (root, skel, utilisateurs)...\e[0m"

BLOCK_BEGIN="# >>> postinstall Bricoletonk >>>"
BLOCK_END="# <<< postinstall Bricoletonk <<<"

configure_bashrc() {
    local target_rc="$1"
    local is_root="$2"

    # Retire le bloc d'une exécution précédente (seulement ce bloc, le reste du fichier est conservé)
    sed -i "/^$BLOCK_BEGIN\$/,/^$BLOCK_END\$/d" "$target_rc"
    # Ancien format (versions précédentes du script, sans marqueur de fin)
    sed -i '/# === Alias personnalisés ===/,$d' "$target_rc"

    {
        echo "$BLOCK_BEGIN"
        command -v nala >/dev/null 2>&1 && echo "alias apt='nala'"
        if [ -n "$LS_TOOL" ] && command -v "$LS_TOOL" >/dev/null 2>&1; then
            echo "alias ls='$LS_TOOL'"
            echo "alias la='$LS_TOOL -la'"
            echo "alias ll='$LS_TOOL -l'"
        fi
        if command -v batcat >/dev/null 2>&1; then
            echo "alias cat='batcat'"
        elif command -v bat >/dev/null 2>&1; then
            echo "alias cat='bat'"
        fi
        command -v btop >/dev/null 2>&1 && echo "alias top='btop'"
        echo "alias ip='ip -c'"
        if [ "$is_root" = true ]; then
            echo "export PS1='\[\e[1;31m\][ \u@\h ]\[\e[0;37m\] \w #\[\e[0m\] '"
        else
            echo "export PS1='\[\e[0;37m\][ \[\e[1;32m\]\u@\h\[\e[0;37m\] ] \w \$\[\e[0m\] '"
        fi
        echo "$BLOCK_END"
    } >> "$target_rc"
}

configure_bashrc "/root/.bashrc" true
configure_bashrc "/etc/skel/.bashrc" false

for user_home in /home/*; do
    if [ -d "$user_home" ] && [ -f "$user_home/.bashrc" ]; then
        configure_bashrc "$user_home/.bashrc" false
        chown "$(stat -c '%U:%G' "$user_home")" "$user_home/.bashrc"
    fi
done
echo -e "\e[1;32m→ Les profils ont été mis à jour avec succès.\e[0m"

# ----------------------------------------------------------
#  Configuration système
# ----------------------------------------------------------
echo -e "\n\e[1;36m===== CONFIGURATION DU SYSTÈME =====\e[0m"

ask "Souhaitez-vous changer le nom de la machine (hostname) ? [o/N]" change_host
if is_yes "$change_host"; then
    ask "Entrez le nouveau nom de la machine :" new_hostname
    if [[ "$new_hostname" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$ ]]; then
        hostnamectl set-hostname "$new_hostname" 2>/dev/null || echo "$new_hostname" > /etc/hostname
        # Met à jour /etc/hosts, sinon sudo affiche "unable to resolve host"
        if grep -q '^127\.0\.1\.1' /etc/hosts; then
            sed -i "s/^127\.0\.1\.1.*/127.0.1.1\t$new_hostname/" /etc/hosts
        else
            printf '127.0.1.1\t%s\n' "$new_hostname" >> /etc/hosts
        fi
        echo -e "\e[1;32m→ Nom de la machine changé en $new_hostname\e[0m"
    else
        echo -e "\e[1;31m→ Nom invalide (lettres, chiffres et tirets uniquement) : nom inchangé.\e[0m"
    fi
fi

if [ -d /etc/ssh/sshd_config.d ] && command -v sshd >/dev/null 2>&1; then
    echo -e "\nAccès SSH pour root :"
    echo "  1) Par clé SSH uniquement (recommandé, défaut Debian)"
    echo "  2) Par mot de passe autorisé"
    echo "  3) Interdit"
    echo "  4) Ne rien changer"
    ask "Votre choix ? [4]" ssh_choice
    case "$ssh_choice" in
        1) ssh_value="prohibit-password" ;;
        2) ssh_value="yes" ;;
        3) ssh_value="no" ;;
        *) ssh_value="" ;;
    esac
    if [ -n "$ssh_value" ]; then
        SSH_DROPIN="/etc/ssh/sshd_config.d/00-postinstall-root.conf"
        echo "PermitRootLogin $ssh_value" > "$SSH_DROPIN"
        if sshd -t; then
            systemctl restart ssh 2>/dev/null || true
            echo -e "\e[1;32m→ Accès SSH root : $ssh_value\e[0m"
            [ "$ssh_value" = "prohibit-password" ] && \
                FINAL_NOTES+=("SSH root par clé : depuis votre PC, 'ssh-copy-id root@$(hostname -I | awk '{print $1}')' (mot de passe requis une fois) ou copiez la clé dans /root/.ssh/authorized_keys.")
        else
            rm -f "$SSH_DROPIN"
            echo -e "\e[1;31m→ Configuration SSH invalide, modification annulée.\e[0m"
        fi
    fi
else
    echo -e "\e[1;33m→ Serveur SSH non installé : étape SSH ignorée.\e[0m"
fi

# SSD : TRIM hebdomadaire (fstrim.timer est fourni par Debian mais pas activé par défaut)
if lsblk -dno ROTA 2>/dev/null | grep -q '^ *0$'; then
    systemctl enable --now fstrim.timer >/dev/null 2>&1 && \
        echo -e "\e[1;32m→ SSD détecté : TRIM hebdomadaire activé (fstrim.timer).\e[0m"
fi

ask "Souhaitez-vous afficher des infos système avant le login (dans /etc/issue) ? [o/N]" issue_ans
if is_yes "$issue_ans"; then
    declare -A issue_opts=(
        [ip]="Afficher l'adresse IP"
        [hostname]="Afficher le nom de la machine (hostname)"
        [kernel]="Afficher la version du noyau (kernel)"
        [date]="Afficher la date"
        [console]="Afficher la console (tty)"
    )
    declare -A issue_sel=()

    for key in ip hostname kernel date console; do
        ask "Souhaitez-vous ${issue_opts[$key]} ? [o/N]" ans
        is_yes "$ans" && issue_sel[$key]=1
    done

    # Les séquences \n, \d, \v... sont interprétées par l'écran de login (agetty),
    # elles doivent donc être écrites telles quelles : apostrophes simples, pas de "echo -e".
    {
        echo 'Debian GNU/Linux \s \r (\m)'
        [ -n "${issue_sel[hostname]}" ] && echo 'Hostname : \n'
        [ -n "${issue_sel[date]}" ]     && echo 'Date     : \d \t'
        [ -n "${issue_sel[kernel]}" ]   && echo 'Kernel   : \v'
        [ -n "${issue_sel[console]}" ]  && echo 'Console  : \l'
        echo
        if [ -n "${issue_sel[ip]}" ]; then
            echo 'IPv4     : \4'
            echo 'IPv6     : \6'
        fi
        echo
    } > /etc/issue

    echo -e "\e[1;32m→ /etc/issue mis à jour avec les infos sélectionnées.\e[0m"
fi

# ----------------------------------------------------------
#  Récapitulatif
# ----------------------------------------------------------
echo -e "\n\e[1;36m===== INSTALLATION TERMINÉE =====\e[0m"
if [ ${#FINAL_NOTES[@]} -gt 0 ]; then
    echo -e "\e[1;33mÀ retenir :\e[0m"
    for note in "${FINAL_NOTES[@]}"; do
        echo "  $note"
    done
    echo
fi

ask "Souhaitez-vous redémarrer la machine maintenant ? [O/n]" reboot_ans
if [[ ! "$reboot_ans" =~ ^[nN]$ ]]; then
    echo -e "\e[1;34m→ Redémarrage en cours...\e[0m"
    sleep 2
    reboot
else
    echo -e "\e[1;33m→ Redémarrage annulé. Pensez à le faire manuellement.\e[0m"
fi
