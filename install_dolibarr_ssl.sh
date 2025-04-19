#!/bin/bash

# === CONFIGURATION ===
DB_NAME="ahjv_db"
DB_USER="ahjv"
DB_PASS="dP3yL5F6UcxehW9Cf0AU"
DOLIBARR_DIR="/var/www/html/dolibarr"
DOLIBARR_URL="https://sourceforge.net/projects/dolibarr/files/latest/download"
DOMAIN_NAME="dolibarr.ahjv-tg.org"
EMAIL="info@ahjv-tg.org"

# === COULEURS ===
GREEN='\033[0;32m'
NC='\033[0m'

# === FONCTIONS ===
function step() {
  echo -e "${GREEN}--- $1 ---${NC}"
}

# === MISE À JOUR ===
step "Mise à jour du système"
sudo apt update && sudo apt upgrade -y

# === INSTALLATION DES PAQUETS ===
step "Installation de Apache, MariaDB, PHP et Certbot"
sudo apt install apache2 mariadb-server php php-mysql php-gd php-curl php-xml php-cli php-mbstring php-zip unzip certbot python3-certbot-apache -y

# === CONFIGURATION MARIA DB ===
step "Sécurisation de MariaDB"
sudo mysql_secure_installation <<EOF

y
$DB_PASS
$DB_PASS
y
y
y
y
EOF

# === CRÉATION BASE DE DONNÉES ===
step "Création de la base de données Dolibarr"
sudo mysql -u root -p$DB_PASS <<EOF
CREATE DATABASE $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
EXIT;
EOF

# === INSTALLATION DE DOLIBARR ===
step "Téléchargement de Dolibarr"
cd /tmp
wget -O dolibarr.zip "$DOLIBARR_URL"
unzip dolibarr.zip
DOLIBARR_SRC=$(find . -maxdepth 1 -type d -name "dolibarr*" | head -n 1)
sudo mv "$DOLIBARR_SRC" "$DOLIBARR_DIR"

# === PERMISSIONS ===
step "Configuration des droits"
sudo chown -R www-data:www-data "$DOLIBARR_DIR"
sudo chmod -R 755 "$DOLIBARR_DIR"

# === CONFIGURATION APACHE ===
step "Configuration du VirtualHost Apache pour $DOMAIN_NAME"
sudo bash -c "cat > /etc/apache2/sites-available/dolibarr.conf <<EOL
<VirtualHost *:80>
    ServerAdmin $EMAIL
    ServerName $DOMAIN_NAME
    DocumentRoot $DOLIBARR_DIR/htdocs

    <Directory $DOLIBARR_DIR/htdocs>
        Options FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/dolibarr_error.log
    CustomLog \${APACHE_LOG_DIR}/dolibarr_access.log combined
</VirtualHost>
EOL"

sudo a2ensite dolibarr.conf
sudo a2enmod rewrite
sudo systemctl reload apache2

# === LET'S ENCRYPT ===
step "Obtention du certificat SSL Let's Encrypt pour $DOMAIN_NAME"
sudo certbot --apache -d "$DOMAIN_NAME" --non-interactive --agree-tos -m "$EMAIL" --redirect

# === FIN ===
step "Installation terminée !"
echo "➡️ Accède à https://$DOMAIN_NAME dans ton navigateur pour terminer la configuration Dolibarr."