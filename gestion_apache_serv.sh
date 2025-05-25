#!/bin/bash

# === Configuration ===
VUSER_DB_TXT="/etc/vsftpd/vsftpd_login.txt"
VUSER_DB="/etc/vsftpd/vsftpd_login.db"
USER_CONF_DIR="/etc/vsftpd/vsftpdUsers"
FTP_ROOT="/var/www"
APACHE_CONF_DIR="/etc/apache2/sites-available"
GUEST_SYSTEM_USER="ftp"

# === Vérification root ===
if [ "$EUID" -ne 0 ]; then
    echo "❌ Ce script doit être lancé en tant que root."
    exit 1
fi

# === Créer utilisateur/site ===
creer_utilisateur() {
    read -p "Nom de l'utilisateur virtuel FTP : " VUSER
    read -p "Nom de domaine (ex: monsite.local) : " DOMAIN

    if grep -q "^$VUSER$" "$VUSER_DB_TXT" || [ -d "$FTP_ROOT/$VUSER" ] || \
       [ -f "$USER_CONF_DIR/$VUSER" ] || [ -f "$APACHE_CONF_DIR/$VUSER.conf" ]; then
        echo "❌ L'utilisateur ou le site existe déjà."
        return
    fi

    read -s -p "Mot de passe FTP : " VPASS
    echo
    read -s -p "Confirmez le mot de passe : " VPASS2
    echo

    if [ "$VPASS" != "$VPASS2" ]; then
        echo "❌ Les mots de passe ne correspondent pas."
        return
    fi

    LOCAL_IP=$(hostname -I | awk '{print $1}')
    echo "IP détectée : $LOCAL_IP"
    read -p "Confirmez ou modifiez l'IP [$LOCAL_IP] : " IP_INPUT
    LOCAL_IP="${IP_INPUT:-$LOCAL_IP}"

    mkdir -p "$FTP_ROOT/$VUSER/public_html"
    echo "<h1>Bienvenue sur $DOMAIN</h1>" > "$FTP_ROOT/$VUSER/public_html/index.html"
    chown -R $GUEST_SYSTEM_USER:$GUEST_SYSTEM_USER "$FTP_ROOT/$VUSER"
    chmod -R 755 "$FTP_ROOT/$VUSER"

    echo -e "$VUSER\n$VPASS" >> "$VUSER_DB_TXT"
    db_load -T -t hash -f "$VUSER_DB_TXT" "$VUSER_DB"
    chmod 600 "$VUSER_DB"

    mkdir -p "$USER_CONF_DIR"
    cat <<EOF > "$USER_CONF_DIR/$VUSER"
local_root=$FTP_ROOT/$VUSER
write_enable=YES
anon_world_readable_only=NO
anon_upload_enable=YES
anon_mkdir_write_enable=YES
anon_other_write_enable=YES
EOF

    cat <<EOF > "$APACHE_CONF_DIR/$VUSER.conf"
<VirtualHost $LOCAL_IP:80>
    ServerName $DOMAIN
    DocumentRoot $FTP_ROOT/$VUSER/public_html

    <Directory $FTP_ROOT/$VUSER/public_html>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/$VUSER-error.log
    CustomLog \${APACHE_LOG_DIR}/$VUSER-access.log combined
</VirtualHost>
EOF

    a2ensite "$VUSER.conf"
    systemctl reload apache2

    echo "✅ Utilisateur '$VUSER' et site '$DOMAIN' créés avec succès."
}

# === Supprimer utilisateur/site ===
supprimer_utilisateur() {
    read -p "Nom de l'utilisateur à supprimer : " VUSER

    if ! grep -q "^$VUSER$" "$VUSER_DB_TXT"; then
        echo "❌ L'utilisateur '$VUSER' n'existe pas."
        return
    fi

    echo "⚠️ Cette opération supprimera l'utilisateur, son site et ses fichiers."
    read -p "Confirmer la suppression de '$VUSER' ? (o/n) : " CONF
    if [[ "$CONF" != "o" && "$CONF" != "O" ]]; then
        echo "❌ Annulé."
        return
    fi

    # Supprimer du fichier login
    TMP=$(mktemp)
    awk -v user="$VUSER" 'BEGIN{skip=0} {
        if ($0 == user) { skip=1; next }
        else if (skip) { skip=0; next }
        print
    }' "$VUSER_DB_TXT" > "$TMP"
    mv "$TMP" "$VUSER_DB_TXT"
    db_load -T -t hash -f "$VUSER_DB_TXT" "$VUSER_DB"
    chmod 600 "$VUSER_DB"

    # Supprimer fichiers associés
    rm -rf "$FTP_ROOT/$VUSER"
    rm -f "$USER_CONF_DIR/$VUSER"
    a2dissite "$VUSER.conf" >/dev/null
    rm -f "$APACHE_CONF_DIR/$VUSER.conf"
    systemctl reload apache2

    echo "✅ Utilisateur '$VUSER' supprimé avec succès."
}

# === Lister les utilisateurs ===
lister_utilisateurs() {
    echo "📂 Utilisateurs FTP virtuels :"
    cut -d ':' -f 1 "$VUSER_DB_TXT" | grep -v '^$'
}

# === Menu principal ===
while true; do
    echo ""
    echo "╔══════════════════════════════╗"
    echo "║   GESTION FTP / APACHE2     ║"
    echo "╠══════════════════════════════╣"
    echo "1. Créer un utilisateur/site"
    echo "2. Supprimer un utilisateur/site"
    echo "3. Lister les utilisateurs"
    echo "4. Quitter"
    echo "╚══════════════════════════════╝"
    read -p "Choix [1-4] : " CHOICE
    echo ""

    case "$CHOICE" in
        1) creer_utilisateur ;;
        2) supprimer_utilisateur ;;
        3) lister_utilisateurs ;;
        4) echo "👋 Au revoir !" ; exit 0 ;;
        *) echo "❌ Choix invalide." ;;
    esac
done
