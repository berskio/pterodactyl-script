#!/bin/bash
set -e

output "${BLUE}Install phpMyAdmin..."

update_upgrade

#region Setup Firewall
if [ "$SETUP_FIREWALL" = true ]; then
    output "Setup Firewall..."
    setup_ufw
    ufw allow 80
    ufw allow 443
fi
#endregion

apt install -y software-properties-common apt-transport-https ca-certificates tar

#region Install PHP
output "Install PHP..."

dist="$(. /etc/os-release && echo "$ID")"
if [ "$dist" = "debian" ]; then
    codename="$(. /etc/os-release && echo "$VERSION_CODENAME")"
    curl https://packages.sury.org/php/apt.gpg -o /etc/apt/trusted.gpg.d/php.gpg
    echo "deb https://packages.sury.org/php/ ${codename} main" | tee /etc/apt/sources.list.d/php.list
fi

apt update -y
apt install -y php${PHP_VERSION} php${PHP_VERSION}-{cli,common,gd,mysql,mbstring,bcmath,xml,fpm,curl,zip}
#endregion

#region Install Nginx
output "Install Nginx..."
apt install -y nginx
#endregion

output
output
output "Please enter the FQDN of phpMyAdmin (phpmyadmin.example.com): "
read PHPMA_FQDN

#region Setup Let’s Encrypt
if [ "$SETUP_LETSENCRYPT" = true ]; then
    output
    output "Please enter the email address for the SSL certificate: "
    read LE_EMAIL

    output
    #region Install Certbot
    output "Install Certbot..."
    apt-get install -y snapd
    snap install core
    snap refresh core
    apt-get remove -y certbot
    snap install --classic certbot

    if [ ! -L "/usr/bin/certbot" ]; then
        ln -s /snap/bin/certbot /usr/bin/certbot
    fi
    #endregion

    #region Setup Webserver without SSL
    if [ -f "/etc/nginx/sites-enabled/default" ]; then
        rm /etc/nginx/sites-enabled/default
    fi

    curl -o /etc/nginx/sites-available/phpmyadmin.conf "https://raw.githubusercontent.com/BAERSERK/Pterodactyl-Installer/master/configs/phpmyadmin.conf"

    sed -i -e "s@<domain>@${PHPMA_FQDN}@g" /etc/nginx/sites-available/phpmyadmin.conf
    sed -i -e "s@<php_version>@${PHP_VERSION}@g" /etc/nginx/sites-available/phpmyadmin.conf

    if [ ! -L "/etc/nginx/sites-enabled/phpmyadmin.conf" ]; then
        ln -s /etc/nginx/sites-available/phpmyadmin.conf /etc/nginx/sites-enabled/phpmyadmin.conf
    fi

    systemctl restart nginx

    mkdir -p /var/www/phpmyadmin

    certbot certonly --webroot -w /var/www/phpmyadmin --email "$LE_EMAIL" --agree-tos -d "$PHPMA_FQDN" --non-interactive
    #endregion
fi
#endregion

output
output "Please enter the Host of MySQL [localhost]: "
read PHPMA_DBHOST
PHPMA_DBHOST=${PHPMA_DBHOST:-localhost}

#region Install and Setup phpMyAdmin
output "Install and setup phpMyAdmin..."

mkdir -p /var/www/phpmyadmin
cd /var/www/phpmyadmin

curl -Lo phpMyAdmin-latest-all-languages.tar.gz "https://www.phpmyadmin.net/downloads/phpMyAdmin-latest-all-languages.tar.gz"
tar -xzvf phpMyAdmin-latest-all-languages.tar.gz --strip-components=1

cp config.sample.inc.php config.inc.php
chown -R www-data:www-data /var/www/phpmyadmin/*

#region Setup Webserver
if [ -f "/etc/nginx/sites-enabled/default" ]; then
    rm /etc/nginx/sites-enabled/default
fi

if [ "$NGINX_SSL" = true ]; then
    curl -o /etc/nginx/sites-available/phpmyadmin.conf "https://raw.githubusercontent.com/BAERSERK/Pterodactyl-Installer/master/configs/phpmyadmin_ssl.conf"

    if [ "$NGINX_HSTS" = true ]; then
        PHPMA_HSTS=
    else
        PHPMA_HSTS=\#
    fi
    sed -i -e "s@<hsts>@${PHPMA_HSTS}@g" /etc/nginx/sites-available/phpmyadmin.conf
else
    curl -o /etc/nginx/sites-available/phpmyadmin.conf "https://raw.githubusercontent.com/BAERSERK/Pterodactyl-Installer/master/configs/phpmyadmin.conf"
fi

sed -i -e "s@<domain>@${PHPMA_FQDN}@g" /etc/nginx/sites-available/phpmyadmin.conf
sed -i -e "s@<php_version>@${PHP_VERSION}@g" /etc/nginx/sites-available/phpmyadmin.conf

if [ ! -L "/etc/nginx/sites-enabled/phpmyadmin.conf" ]; then
    ln -s /etc/nginx/sites-available/phpmyadmin.conf /etc/nginx/sites-enabled/phpmyadmin.conf
fi

systemctl restart nginx
#endregion
#endregion

if [ "$NGINX_SSL" = true ]; then
    HTTP_PROTOCOL="https://"
else
    HTTP_PROTOCOL="http://"
fi

output
output "--------------------------------------------"
output "| Panel has been successfully installed. |"
output "--------------------------------------------"
output
output
output "Panel URL: ${HTTP_PROTOCOL}${PHPMA_FQDN}"
output
