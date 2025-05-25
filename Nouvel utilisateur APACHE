#!/bin/bash

# === Configuration ===
VUSER_DB_TXT="/etc/vsftpd/vsftpd_login.txt"
VUSER_DB="/etc/vsftpd/vsftpd_login.db"
USER_CONF_DIR="/etc/vsftpd/vsftpdUsers"
FTP_ROOT="/var/www"
APACHE_CONF_DIR="/etc/apache2/sites-available"
GUEST_SYSTEM_USER="ftp"  # doit correspondre à guest_username dans vsftpd.conf

# === Vérifie que le script est lancé en root ===
if [ "$EUID" -ne 0 ]; then
    echo "❌ Ce script doit être exécuté en tant que root."
    exit 1
fi

# === Lecture des informations ===
read -p "Nom de l'utilisateur virtuel FTP : " VUSER
read -p "Nom de domaine (ex: monsite.local) : " DOMAIN
echo

# === Vérifications ===
if grep -q "^$VUSER$" "$VUSER_DB_TXT"; then
    echo "❌ L'utilisateur '$VUSER' existe déjà dans la base FTP."
    exit 1
fi

if [ -d "$FTP_ROOT/$VUSER" ]; then
    echo "❌ Le dossier '$FTP_ROOT/$VUSER' existe déjà."
    exit 1
fi

if [ -f "$USER_CONF_DIR/$VUSER" ]; then
    echo "❌ Une configuration vsftpd existe déjà pour cet utilisateur."
    exit 1
fi

if [ -f "$APACHE_CONF_DIR/$VUSER.conf" ]; then
    echo "❌ Une configuration Apache existe déjà pour ce site."
    exit 1
fi

# === Mot de passe ===
read -s -p "Mot de passe FTP : " VPASS
echo
read -s -p "Confirmez le mot de passe : " VPASS2
echo

if [ "$VPASS" != "$VPASS2" ]; then
    echo "❌ Les mots de passe ne correspondent pas."
    exit 1
fi

# === Adresse IP locale ===
# Tu peux commenter la ligne ci-dessous pour forcer une saisie manuelle
LOCAL_IP=$(hostname -I | awk '{print $1}')
echo "➡️ IP locale détectée : $LOCAL_IP"
read -p "Confirmez ou modifiez l'IP pour le VirtualHost [$LOCAL_IP] : " IP_INPUT
LOCAL_IP="${IP_INPUT:-$LOCAL_IP}"

# === Création du répertoire web ===
mkdir -p "$FTP_ROOT/$VUSER/public_html"
echo "<h1>Bienvenue sur $DOMAIN</h1>" > "$FTP_ROOT/$VUSER/public_html/index.html"
chown -R $GUEST_SYSTEM_USER:$GUEST_SYSTEM_USER "$FTP_ROOT/$VUSER"
chmod -R 755 "$FTP_ROOT/$VUSER"

# === Ajout de l'utilisateur dans la base login ===
echo -e "$VUSER\n$VPASS" >> "$VUSER_DB_TXT"
db_load -T -t hash -f "$VUSER_DB_TXT" "$VUSER_DB"
chmod 600 "$VUSER_DB"

# === Configuration vsftpd pour l'utilisateur ===
mkdir -p "$USER_CONF_DIR"
cat <<EOF > "$USER_CONF_DIR/$VUSER"
local_root=$FTP_ROOT/$VUSER
write_enable=YES
anon_world_readable_only=NO
anon_upload_enable=YES
anon_mkdir_write_enable=YES
anon_other_write_enable=YES
EOF

# === Configuration Apache ===
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

# === Activation du site Apache ===
a2ensite "$VUSER.conf"
systemctl reload apache2

# === Terminé ===
echo "✅ Utilisateur virtuel '$VUSER' et site '$DOMAIN' créés avec succès."
echo "➡️ Dossier web      : $FTP_ROOT/$VUSER"
echo "➡️ Accessible via   : http://$DOMAIN (ou http://$LOCAL_IP si pas de DNS)"
