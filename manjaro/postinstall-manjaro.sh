#!/bin/bash
# ==========================================================
#  Script de post-installation Manjaro
#  Équivalent du script Debian (script.postinstall.sh), adapté à Manjaro / Arch
#  Usage : sudo bash postinstall-manjaro.sh
# ==========================================================

if [[ $EUID -ne 0 ]]; then
    echo -e "\e[1;31mCe script doit être exécuté en root : sudo bash $0\e[0m"
    exit 1
fi

if ! command -v pacman >/dev/null 2>&1; then
    echo -e "\e[1;31mCe script est prévu pour Manjaro / Arch (pacman introuvable).\e[0m"
    exit 1
fi

ask() {
    local prompt="$1"
    local varname="$2"
    read -e -p "$(echo -e "\e[1;33m$prompt\e[0m") " "$varname"
}

is_yes() { [[ "$1" =~ ^[oOyY]$ ]]; }

FINAL_NOTES=()

# Installe des paquets des dépôts officiels, en ignorant ceux qui n'existent pas
pac_install() {
    local valid=() p
    for p in "$@"; do
        if pacman -Si "$p" >/dev/null 2>&1; then
            valid+=("$p")
        else
            echo -e "\e[1;31m→ Le paquet '$p' est introuvable dans les dépôts et sera ignoré.\e[0m"
        fi
    done
    [ ${#valid[@]} -gt 0 ] && pacman -S --needed --noconfirm "${valid[@]}"
}

# ----------------------------------------------------------
#  Utilisateur principal (celui qui a lancé sudo, sinon demandé)
# ----------------------------------------------------------
list_human_users() {
    getent passwd | awk -F: '$3 >= 1000 && $3 < 65534 && $6 ~ /^\/home\// {print $1}'
}

MAIN_USER="${SUDO_USER:-}"
if [ -z "$MAIN_USER" ] || [ "$MAIN_USER" = "root" ]; then
    mapfile -t users < <(list_human_users)
    if [ ${#users[@]} -eq 1 ]; then
        MAIN_USER="${users[0]}"
    elif [ ${#users[@]} -gt 1 ]; then
        ask "Utilisateur principal ? (${users[*]}) [${users[0]}]" MAIN_USER
        MAIN_USER="${MAIN_USER:-${users[0]}}"
    fi
fi
id "$MAIN_USER" >/dev/null 2>&1 || MAIN_USER=""
MAIN_HOME="$( [ -n "$MAIN_USER" ] && getent passwd "$MAIN_USER" | cut -d: -f6 )"
MAIN_GROUP="$( [ -n "$MAIN_USER" ] && id -gn "$MAIN_USER" )"

ARCH="$(uname -m)"

# Interface graphique présente ?
has_gui() {
    compgen -G "/usr/share/xsessions/*.desktop" >/dev/null && return 0
    compgen -G "/usr/share/wayland-sessions/*.desktop" >/dev/null && return 0
    [ -e /etc/systemd/system/display-manager.service ] && return 0
    return 1
}
if has_gui; then GUI=true; else GUI=false; fi

# Modèle de la machine et config Conky correspondante (dépôt Bricoletonk/Conkyrc)
MODEL="$(cat /sys/class/dmi/id/product_version /sys/class/dmi/id/product_name 2>/dev/null | tr '\n' ' ' | sed 's/ *$//')"
case "$MODEL" in
    *"ThinkPad T14"*)  CONKY_CONFIG="conkyrc-t14" ;;
    *"ThinkPad X250"*) CONKY_CONFIG="conkyrc-x250" ;;
    *)                 CONKY_CONFIG="conkyrc-thinkcentre" ;;   # version générique : sans batterie, interface détectée
esac
echo -e "\e[1;34m→ Modèle : ${MODEL:-inconnu} | Interface graphique : $($GUI && echo oui || echo non)\e[0m"
echo -e "\e[1;34m→ Architecture : $ARCH | Utilisateur principal : ${MAIN_USER:-aucun}\e[0m"

# ----------------------------------------------------------
#  Miroirs et mise à jour complète
# ----------------------------------------------------------
echo -e "\n\e[1;36m===== MISE À JOUR DU SYSTÈME =====\e[0m"

if command -v pacman-mirrors >/dev/null 2>&1; then
    ask "Rechercher les miroirs les plus rapides (recommandé après une installation) ? [O/n]" mirrors_ans
    if [[ ! "$mirrors_ans" =~ ^[nN]$ ]]; then
        pacman-mirrors --fasttrack 5
    fi
fi

# Sur Manjaro, il faut toujours faire une mise à jour complète avant d'installer quoi que ce soit
echo -e "\e[1;36m→ Mise à jour complète du système (pacman -Syyu)...\e[0m"
pacman -Syyu --noconfirm

echo -e "\e[1;36m→ Installation des outils de base...\e[0m"
pac_install curl wget git base-devel pacman-contrib

# ----------------------------------------------------------
#  Choix des logiciels
# ----------------------------------------------------------
declare -A packages=(
    [bat]="Remplaçant de 'cat' avec coloration syntaxique"
    [btop]="Moniteur système moderne (remplaçant de htop)"
    [eza]="Remplaçant moderne de 'ls'"
    [fastfetch]="Affiche les infos système en ASCII (successeur de screenfetch)"
    [inxi]="Outil complet d’information système"
)

selected=()
echo -e "\n\e[1;36m===== INSTALLATION DE LOGICIELS =====\e[0m"

for pkg in $(printf '%s\n' "${!packages[@]}" | sort); do
    ask "Souhaitez-vous installer ${pkg} (${packages[$pkg]}) ? [o/N]" answer
    is_yes "$answer" && selected+=("$pkg")
done

ask "Souhaitez-vous installer Tailscale (VPN maillé) ? [o/N]" tailscale_ans
ask "Souhaitez-vous installer Claude Code (assistant IA d'Anthropic, en ligne de commande) ? [o/N]" claude_ans
ask "Souhaitez-vous installer gemini-cli (Assistant IA Google) ? [o/N]" gemini_ans
conky_ans="n"
if $GUI; then
    ask "Installer Conky (moniteur système sur le bureau, config « $CONKY_CONFIG » pour cette machine) ? [o/N]" conky_ans
fi
ask "Souhaitez-vous installer et activer le serveur SSH ? [o/N]" sshd_ans

ask "Souhaitez-vous ajouter manuellement des logiciels supplémentaires ? (ex: vim htop) [o/N]" custom_ans
if is_yes "$custom_ans"; then
    ask "Entrez les noms des paquets à ajouter (séparés par des espaces) :" custom_packages
    if [[ -n "$custom_packages" ]]; then
        read -r -a custom_array <<< "$custom_packages"
        selected+=("${custom_array[@]}")
    fi
fi

if [ ${#selected[@]} -gt 0 ]; then
    echo -e "\n\e[1;34m→ Installation groupée des paquets : ${selected[*]}\e[0m"
    pac_install "${selected[@]}"
fi

# Nettoyage automatique du cache pacman (garde les 3 dernières versions de chaque paquet)
if systemctl list-unit-files paccache.timer >/dev/null 2>&1; then
    systemctl enable --now paccache.timer >/dev/null 2>&1 && \
        echo -e "\e[1;32m→ Nettoyage hebdomadaire du cache pacman activé (paccache.timer).\e[0m"
fi

# ----------------------------------------------------------
#  Tailscale
# ----------------------------------------------------------
if is_yes "$tailscale_ans"; then
    echo -e "\n\e[1;34m→ Installation de Tailscale...\e[0m"
    if pac_install tailscale && systemctl enable --now tailscaled; then
        echo -e "\e[1;32m→ Tailscale installé et démarré.\e[0m"
        # Permet à l'utilisateur de piloter Tailscale sans sudo
        [ -n "$MAIN_USER" ] && tailscale set --operator="$MAIN_USER" 2>/dev/null
        FINAL_NOTES+=("Tailscale : lancez 'sudo tailscale up' et ouvrez le lien affiché pour ajouter la machine à votre tailnet.")
    else
        echo -e "\e[1;31m→ Erreur : l'installation de Tailscale a échoué.\e[0m"
    fi
fi

# ----------------------------------------------------------
#  Claude Code
# ----------------------------------------------------------
if is_yes "$claude_ans"; then
    echo -e "\n\e[1;34m→ Installation de Claude Code...\e[0m"
    if [[ "$ARCH" != "x86_64" && "$ARCH" != "aarch64" ]]; then
        echo -e "\e[1;31m→ Architecture $ARCH non prise en charge par Claude Code.\e[0m"
    elif [ -z "$MAIN_USER" ]; then
        echo -e "\e[1;31m→ Aucun utilisateur normal trouvé : Claude Code s'installe par utilisateur, étape ignorée.\e[0m"
    else
        # Anthropic ne publie pas de paquet Arch : installeur officiel, dans ~/.local/bin de l'utilisateur,
        # avec mises à jour automatiques
        if su - "$MAIN_USER" -c 'curl -fsSL https://claude.ai/install.sh | bash'; then
            echo -e "\e[1;32m→ Claude Code installé pour $MAIN_USER.\e[0m"
            FINAL_NOTES+=("Claude Code : en tant que $MAIN_USER (pas root), tapez 'claude' : le navigateur s'ouvre pour la connexion (abonnement Pro ou Max requis).")
            FINAL_NOTES+=("   → Si 'claude' est introuvable, ouvrez un nouveau terminal (~/.local/bin doit être dans le PATH).")
        else
            echo -e "\e[1;31m→ Erreur : l'installation de Claude Code a échoué.\e[0m"
        fi
    fi
fi

# ----------------------------------------------------------
#  Gemini CLI
# ----------------------------------------------------------
if is_yes "$gemini_ans"; then
    echo -e "\n\e[1;34m→ Installation de Node.js (dépôts Manjaro) et Gemini CLI...\e[0m"
    pac_install nodejs npm
    if command -v npm >/dev/null 2>&1 && npm install -g @google/gemini-cli; then
        echo -e "\e[1;32m→ Gemini CLI a été installé avec succès.\e[0m"
        echo -e "\n\e[1;33mPour utiliser Gemini, vous pouvez utiliser une clé API Google gratuite :\e[0m"
        echo -e "\e[1;36mhttps://aistudio.google.com/app/apikey\e[0m\n"
        key_ready="n"
        [ -n "$MAIN_USER" ] && ask "Voulez-vous enregistrer une clé API pour $MAIN_USER maintenant ? [o/N]" key_ready
        if is_yes "$key_ready"; then
            ask "Collez votre clé API ici :" GEMINI_API_KEY
            if [[ -n "$GEMINI_API_KEY" ]]; then
                install -d -m 700 -o "$MAIN_USER" -g "$MAIN_GROUP" "$MAIN_HOME/.gemini"
                ( umask 077; echo "GEMINI_API_KEY=\"$GEMINI_API_KEY\"" > "$MAIN_HOME/.gemini/.env" )
                chown "$MAIN_USER:$MAIN_GROUP" "$MAIN_HOME/.gemini/.env"
                echo -e "\e[1;32m→ Clé API enregistrée dans $MAIN_HOME/.gemini/.env (accessible uniquement par $MAIN_USER).\e[0m"
            fi
        else
            FINAL_NOTES+=("Gemini CLI : lancez 'gemini', il propose les méthodes de connexion au premier démarrage.")
        fi
    else
        echo -e "\e[1;31m→ Erreur : l'installation de Gemini CLI a échoué.\e[0m"
    fi
fi

# ----------------------------------------------------------
#  Conky (moniteur système sur le bureau)
# ----------------------------------------------------------
if is_yes "$conky_ans"; then
    echo -e "\n\e[1;34m→ Installation de Conky ($CONKY_CONFIG)...\e[0m"
    if [ -z "$MAIN_USER" ]; then
        echo -e "\e[1;31m→ Aucun utilisateur normal trouvé : Conky s'installe par utilisateur, étape ignorée.\e[0m"
    elif pac_install conky git; then
        if su - "$MAIN_USER" -c "
            if [ -d ~/Conkyrc/.git ]; then git -C ~/Conkyrc pull -q; else git clone -q https://github.com/Bricoletonk/Conkyrc.git ~/Conkyrc; fi &&
            ~/Conkyrc/scripts/install-conky.sh configs/$CONKY_CONFIG"; then
            echo -e "\e[1;32m→ Conky installé pour $MAIN_USER (config $CONKY_CONFIG).\e[0m"
            FINAL_NOTES+=("Conky : démarre automatiquement à la prochaine ouverture de session ($MAIN_USER).")
        else
            echo -e "\e[1;31m→ Erreur : l'installation de la config Conky a échoué.\e[0m"
        fi
    else
        echo -e "\e[1;31m→ Erreur : l'installation du paquet Conky a échoué.\e[0m"
    fi
fi

# ----------------------------------------------------------
#  Alias et prompt (bash ET zsh, Manjaro utilisant souvent zsh par défaut)
# ----------------------------------------------------------
echo -e "\n\e[1;34m→ Configuration des alias (bash et zsh) et du prompt bash...\e[0m"

ALIAS_FILE="/etc/profile.d/postinstall-aliases.sh"
{
    echo "# Alias ajoutés par postinstall-manjaro.sh"
    command -v eza    >/dev/null 2>&1 && { echo "alias ls='eza'"; echo "alias la='eza -la'"; echo "alias ll='eza -l'"; }
    command -v bat    >/dev/null 2>&1 && echo "alias cat='bat'"
    command -v btop   >/dev/null 2>&1 && echo "alias top='btop'"
    echo "alias ip='ip -c'"
    echo "alias maj='sudo pacman -Syu'"
} > "$ALIAS_FILE"
chmod 644 "$ALIAS_FILE"

BLOCK_BEGIN="# >>> postinstall Bricoletonk >>>"
BLOCK_END="# <<< postinstall Bricoletonk <<<"

# Ajoute (ou remplace) un bloc qui charge les alias ; le reste du fichier n'est pas touché
add_block() {
    local rc="$1" prompt="$2"
    [ -f "$rc" ] || return 0
    sed -i "/^$BLOCK_BEGIN\$/,/^$BLOCK_END\$/d" "$rc"
    {
        echo "$BLOCK_BEGIN"
        echo "[ -f $ALIAS_FILE ] && . $ALIAS_FILE"
        [ -n "$prompt" ] && echo "$prompt"
        echo "$BLOCK_END"
    } >> "$rc"
}

PS1_ROOT="export PS1='\[\e[1;31m\][ \u@\h ]\[\e[0;37m\] \w #\[\e[0m\] '"
PS1_USER="export PS1='\[\e[0;37m\][ \[\e[1;32m\]\u@\h\[\e[0;37m\] ] \w \$\[\e[0m\] '"

add_block /root/.bashrc "$PS1_ROOT"
add_block /etc/skel/.bashrc "$PS1_USER"
add_block /etc/skel/.zshrc ""
for user_home in /home/*; do
    [ -d "$user_home" ] || continue
    owner="$(stat -c '%U:%G' "$user_home")"
    add_block "$user_home/.bashrc" "$PS1_USER" && [ -f "$user_home/.bashrc" ] && chown "$owner" "$user_home/.bashrc"
    add_block "$user_home/.zshrc" "" && [ -f "$user_home/.zshrc" ] && chown "$owner" "$user_home/.zshrc"
done
echo -e "\e[1;32m→ Alias disponibles dans bash et zsh (nouveau terminal requis).\e[0m"

# ----------------------------------------------------------
#  Configuration système
# ----------------------------------------------------------
echo -e "\n\e[1;36m===== CONFIGURATION DU SYSTÈME =====\e[0m"

ask "Souhaitez-vous changer le nom de la machine (hostname) ? Actuel : $(hostname) [o/N]" change_host
if is_yes "$change_host"; then
    ask "Entrez le nouveau nom de la machine :" new_hostname
    if [[ "$new_hostname" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$ ]]; then
        hostnamectl set-hostname "$new_hostname"
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

if is_yes "$sshd_ans"; then
    pac_install openssh
    mkdir -p /etc/ssh/sshd_config.d
    # Sur Arch, sshd_config n'inclut pas toujours sshd_config.d : on ajoute l'inclusion si besoin
    grep -q '^Include /etc/ssh/sshd_config.d/\*.conf' /etc/ssh/sshd_config || \
        sed -i '1i Include /etc/ssh/sshd_config.d/*.conf' /etc/ssh/sshd_config

    echo -e "\nAccès SSH pour root :"
    echo "  1) Par clé SSH uniquement (recommandé)"
    echo "  2) Par mot de passe autorisé"
    echo "  3) Interdit"
    ask "Votre choix ? [1]" ssh_choice
    case "$ssh_choice" in
        2) ssh_value="yes" ;;
        3) ssh_value="no" ;;
        *) ssh_value="prohibit-password" ;;
    esac
    SSH_DROPIN="/etc/ssh/sshd_config.d/00-postinstall-root.conf"
    echo "PermitRootLogin $ssh_value" > "$SSH_DROPIN"
    if sshd -t; then
        systemctl enable --now sshd
        systemctl restart sshd
        echo -e "\e[1;32m→ Serveur SSH actif, accès root : $ssh_value\e[0m"
    else
        rm -f "$SSH_DROPIN"
        echo -e "\e[1;31m→ Configuration SSH invalide, modification annulée.\e[0m"
    fi
fi

# SSD : TRIM hebdomadaire
if lsblk -dno ROTA 2>/dev/null | grep -q '^ *0$'; then
    systemctl enable --now fstrim.timer >/dev/null 2>&1 && \
        echo -e "\e[1;32m→ SSD détecté : TRIM hebdomadaire activé (fstrim.timer).\e[0m"
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
