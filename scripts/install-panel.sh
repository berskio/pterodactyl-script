#!/bin/bash
set -e

output "${BLUE}Installing Panel..."

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

#region Check if already Installed
if [ -d "/var/www/pterodactyl" ]; then
    warning "Already an installation of the Pterodactyl Panel was detected! If you continue, the installation will fail. "
    output "Are you sure you want to proceed? (y/N): "
    read -r OVERWRITE_PANEL

    if [[ ! "$OVERWRITE_PANEL" =~ [Yy] ]]; then
        output "${RED}Installation aborted!"
        exit 1
    fi
fi
#endregion

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
output "Please enter the FQDN of the panel (panel.example.com): "
read PANEL_FQDN

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

    curl -o /etc/nginx/sites-available/pterodactyl.conf "https://raw.githubusercontent.com/BAERSERK/pterodactyl-script/master/configs/nginx.conf"

    sed -i -e "s@<domain>@${PANEL_FQDN}@g" /etc/nginx/sites-available/pterodactyl.conf
    sed -i -e "s@<php_version>@${PHP_VERSION}@g" /etc/nginx/sites-available/pterodactyl.conf

    if [ ! -L "/etc/nginx/sites-enabled/pterodactyl.conf" ]; then
        ln -s /etc/nginx/sites-available/pterodactyl.conf /etc/nginx/sites-enabled/pterodactyl.conf
    fi

    systemctl restart nginx

    mkdir -p /var/www/pterodactyl/public

    certbot certonly --webroot -w /var/www/pterodactyl/public --email "$LE_EMAIL" --agree-tos -d "$PANEL_FQDN" --non-interactive
    #endregion
fi
#endregion

#region Install Composer
output "Install Composer..."
curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
#endregion

#region Install and Setup Panel
output "Install and setup Panel..."

mkdir -p /var/www/pterodactyl
cd /var/www/pterodactyl

curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
tar -xzvf panel.tar.gz
chmod -R 755 storage/* bootstrap/cache/

cp .env.example .env
yes | composer install --no-dev --optimize-autoloader

php artisan key:generate --force

if [ "$NGINX_SSL" = true ]; then
    HTTP_PROTOCOL="https://"
else
    HTTP_PROTOCOL="http://"
fi

php artisan p:environment:setup \
--url="${HTTP_PROTOCOL}${PANEL_FQDN}" \
--timezone="$(cat /etc/timezone)" \
--cache="file" \
--session="database" \
--queue="database" \
--settings-ui=true

if [ "$DB_INSTALLED" = true ]; then
    php artisan p:environment:database \
    --host="127.0.0.1" \
    --port="3306" \
    --database="$DBPANEL_DB" \
    --username="$DBPANEL_USER" \
    --password="$DBPANEL_PASSWORD"
else
    php artisan p:environment:database
fi

output
output
output "Do you want to Set Up an Mail? (y/N): "
read -r SETUP_MAIL

if [[ "$SETUP_MAIL" =~ [Yy] ]]; then
    php artisan p:environment:mail
fi

php artisan migrate --seed --force

php artisan p:user:make

chown -R www-data:www-data /var/www/pterodactyl/*

#region Setup Queue Listeners
output "Setup Queue Listeners..."

crontab -l | {
    cat
    echo "* * * * * php /var/www/pterodactyl/artisan schedule:run >> /dev/null 2>&1"
} | crontab -

curl -o /etc/systemd/system/pteroq.service "https://raw.githubusercontent.com/BAERSERK/pterodactyl-script/master/configs/pteroq.service"

systemctl enable --now pteroq.service
#endregion

#region Setup Webserver
if [ -f "/etc/nginx/sites-enabled/default" ]; then
    rm /etc/nginx/sites-enabled/default
fi

if [ "$NGINX_SSL" = true ]; then
    curl -o /etc/nginx/sites-available/pterodactyl.conf "https://raw.githubusercontent.com/BAERSERK/pterodactyl-script/master/configs/nginx_ssl.conf"

    if [ "$NGINX_HSTS" = true ]; then
        PANEL_HSTS=
    else
        PANEL_HSTS=\#
    fi
    sed -i -e "s@<hsts>@${PANEL_HSTS}@g" /etc/nginx/sites-available/pterodactyl.conf
else
    curl -o /etc/nginx/sites-available/pterodactyl.conf "https://raw.githubusercontent.com/BAERSERK/pterodactyl-script/master/configs/nginx.conf"
fi

sed -i -e "s@<domain>@${PANEL_FQDN}@g" /etc/nginx/sites-available/pterodactyl.conf
sed -i -e "s@<php_version>@${PHP_VERSION}@g" /etc/nginx/sites-available/pterodactyl.conf

if [ ! -L "/etc/nginx/sites-enabled/pterodactyl.conf" ]; then
    ln -s /etc/nginx/sites-available/pterodactyl.conf /etc/nginx/sites-enabled/pterodactyl.conf
fi

systemctl restart nginx
#endregion
#endregion

output
output "--------------------------------------------"
output "| Panel has been successfully installed. |"
output "--------------------------------------------"
output
output
output "Panel URL: ${HTTP_PROTOCOL}${PANEL_FQDN}"
output
