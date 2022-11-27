#!/bin/bash
set -e

VERSION="0.2.1"
PHP_VERSION=8.1

#region Text Formatting
NC="\033[0m" # Normal Color
GRAY="\033[1;30m"
RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
PURPLE="\033[1;35m"
CYAN="\033[1;36m"

output() {
    echo -e "${NC}${1}${NC}"
}

info() {
    echo
    echo -e "${CYAN}${1}${NC}"
}

error() {
    echo
    echo -e "${RED}ERROR: ${1}${NC}"
    echo
}

warning() {
    echo
    echo -e "${YELLOW}WARNING: ${1}${NC}"
    echo
}

success() {
    echo
    echo -e "${GREEN}${1}${NC}"
    echo
}
#endregion

#region Variables
SETUP_FIREWALL=true
SETUP_LETSENCRYPT=true

NGINX_SSL=true
NGINX_HSTS=true

DBPANEL_SETUP=true
DBPANEL_DB="panel"
DBPANEL_USER="pterodactyl"
DBPANEL_PASSWORD=""

DBHOST_SETUP=true
DBHOST_USER="pterodactyluser"
DBHOST_PASSWORD=""

DB_ROOT_PASSWORD=""

PASSWORD_LENGTH=64
#endregion

#region Check requirements
#
#region Check if Root
if [ "$EUID" -ne 0 ]; then
    error "Must run the script with root privileges!"
    exit 1
fi
#endregion

#region Check Distribution
dist="$(. /etc/os-release && echo "$ID")"
if [ "$dist" != "debian" ] && [ "$dist" != "ubuntu" ]; then
    error "Unsupported Distribution! Only Debian and Ubuntu are supported."
    exit 1
fi
#endregion

#region Check Architecture
arch="$(uname -m)"
if [ "$arch" != "x86_64" ]; then
    error "Unsupported Architecture! Only x86_64 is supported."
    exit 1
fi
#endregion

#region Check Virtualization
virt="$(systemd-detect-virt)"
if [ "$virt" = "openvz" ] || [ "$virt" = "lxc" ]; then
    warning "Unsupported Virtualization! OpenVZ and LXC will most likely be unable to run Wings."

    info "Are you sure you want to proceed? (y/N): "
    read -r PROCEED_VIRTUALIZATION

    if [[ ! "$PROCEED_VIRTUALIZATION" =~ [Yy] ]]; then
        error "Installation aborted!"
        exit 1
    fi
fi
#endregion

#region Check if Curl installed
which curl &>/dev/null || apt-get install -y curl
#endregion
#
#endregion

#region Helper Functions
#
#region Update/Upgrade
update_upgrade() {
    apt-get update -y && apt-get upgrade -y
}
#endregion

#region Setup UFW
setup_ufw() {
    apt-get install -y ufw
    ufw allow 22
    yes | ufw enable
}
#endregion

#region Get latest Release
get_latest_release() {
    curl --silent "https://api.github.com/repos/$1/releases/latest" | # Get latest release from GitHub api
        grep '"tag_name":' |                                          # Get tag line
        sed -E 's/.*"([^"]+)".*/\1/'                                  # Pluck JSON value
}
#endregion

#region Setup MariaDB
setup_mariadb() {
    if ([ "$DBPANEL_SETUP" = true ] || [ "$DBHOST_SETUP" = true ]) && ([ ! -d /var/www/pterodactyl ] && [ ! -x /usr/local/bin/wings ]); then
        info "Install MariaDB..."

        #Check if MariaDB Installed
        if [ $(dpkg-query -W -f='${Status}' mariadb-server 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
            #Install MariaDB
            apt-get install -y mariadb-server

            #Setup Firewall
            if [ "$SETUP_FIREWALL" = true ]; then
                info "Setup Firewall..."
                setup_ufw
            fi

            #Generate Root Password
            DB_ROOT_PASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9!#$%&()*+,-./:;<=>?@[\]^_{|}~' | fold -w $PASSWORD_LENGTH | head -n 1)

            #Secure MySQL
            C0="UPDATE mysql.global_priv SET priv=json_set(priv, '$.plugin', 'mysql_native_password', '$.authentication_string', PASSWORD('$DB_ROOT_PASSWORD')) WHERE User='root';"
            C1="DELETE FROM mysql.global_priv WHERE User='';"
            C2="DELETE FROM mysql.global_priv WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
            C3="DROP DATABASE IF EXISTS test;"
            C4="DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"
            C5="FLUSH PRIVILEGES;"
            mysql -u root -e "${C0}${C1}${C2}${C3}${C4}${C5}"
            output "MySQL installation secured"

            #Update Configuration
            echo 
            info "Allowed IPs for remote access to the database E.g. 1.2.3.4,...? (0.0.0.0)"
            read -r question_remote_ips
            sed -i -- "/bind-address/s/127.0.0.1/${question_remote_ips:-0.0.0.0}/g" /etc/mysql/mariadb.conf.d/50-server.cnf

            service mariadb restart
        fi
    fi
}
#endregion

#region Setup Panel Database
setup_panel_db() {
    if [ "$DBPANEL_SETUP" = true ] && [ ! -d /var/www/pterodactyl ]; then
        #Generate Password if empty
        if [ -z "$DBPANEL_PASSWORD" ]; then
            DBPANEL_PASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9!#$%&()*+,-./:;<=>?@[\]^_{|}~' | fold -w $PASSWORD_LENGTH | head -n 1)
        fi

        C0="CREATE USER '$DBPANEL_USER'@'127.0.0.1' IDENTIFIED BY '$DBPANEL_PASSWORD';"
        C1="CREATE DATABASE $DBPANEL_DB;"

        C2="GRANT ALL PRIVILEGES ON ${DBPANEL_DB}.* TO '$DBPANEL_USER'@'127.0.0.1' WITH GRANT OPTION;"
        C3="FLUSH PRIVILEGES;"
        mysql -u root -e "${C0}${C1}${C2}${C3}"
    fi
}
#endregion

#region Setup Host Database
setup_host_db() {
    if [ "$DBHOST_SETUP" = true ] && [ ! -x /usr/local/bin/wings ]; then
        #Generate Password if empty
        if [ -z "$DBHOST_PASSWORD" ]; then
            DBHOST_PASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9!#$%&()*+,-./:;<=>?@[\]^_{|}~' | fold -w $PASSWORD_LENGTH | head -n 1)
        fi

        output "Create $DBHOST_USER user..."
        C0="CREATE USER '$DBHOST_USER'@'%' IDENTIFIED BY '$DBHOST_PASSWORD';"

        C1="GRANT ALL PRIVILEGES ON *.* TO '$DBHOST_USER'@'%' WITH GRANT OPTION;"
        mysql -u root -e "${C0}${C1}"
    fi
}
#endregion

#region Print DB Info
print_db_info() {
    if ([ "$DBPANEL_SETUP" = true ] || [ "$DBHOST_SETUP" = true ]) && [ ! -z "$DB_ROOT_PASSWORD" ]; then
        output "${GREEN}MariaDB has been successfully installed.\n${NC}->Root Password: ${DB_ROOT_PASSWORD}"
        echo
    fi

    if [ "$DBPANEL_SETUP" = true ] && [ ! -z "$DBPANEL_PASSWORD" ]; then
        output "${GREEN}Panel DB\n${NC}-> Database: ${DBPANEL_DB}\n-> User: ${DBPANEL_USER}\n-> Password: ${DBPANEL_PASSWORD}"
        echo
    fi

    if [ "$DBHOST_SETUP" = true ] && [ ! -z "$DBHOST_PASSWORD" ]; then
        output "${BLUE}Servers DB\n${NC}-> User: ${DBHOST_USER}\n-> Password: ${DBHOST_PASSWORD}"
        echo
    fi
}
#endregion
#
#endregion

#region Questions
#
#region MariaDB Panel
q_mariadb_panel() {
    echo
    info "Create a database for the panel? (Y/n)"
    read -r question_setup
    [[ ! "$question_setup" =~ [Nn] ]] && DBPANEL_SETUP=true || DBPANEL_SETUP=false

    if [ "$DBPANEL_SETUP" = true ]; then
        echo
        info "Name of the panel database? (panel)"
        read -r question_db
        DBPANEL_DB=${question_db:-panel}

        echo
        info "Database username? (pterodactyl)"
        read -r question_user
        DBPANEL_USER=${question_user:-pterodactyl}

        echo
        info "Password of the database user? (**GENERATE**)"
        read -r question_pw
        if [ ! -z "$question_pw" ]; then
            DBPANEL_PASSWORD=$question_pw
        fi
    fi
}
#endregion

#region MariaDB Host
q_mariadb_host() {
    echo
    info "Create a database user for the game servers? (Y/n)"
    read -r question_setup
    [[ ! "$question_setup" =~ [Nn] ]] && DBHOST_SETUP=true || DBHOST_SETUP=false

    if [ "$DBHOST_SETUP" = true ]; then
        echo
        info "Database username? (pterodactyluser)"
        read -r question_user
        DBHOST_USER=${question_user:-pterodactyluser}

        echo
        info "Password of the database user? (**GENERATE**)"
        read -r question_pw
        if [ ! -z "$question_pw" ]; then
            DBHOST_PASSWORD=$question_pw
        fi
    fi
}
#endregion

#region Nginx SSL/HSTS
q_nginx_ssl_hsts() {
    echo
    info "Enable SSL on Nginx? (Y/n)"
    read -r question_ssl
    [[ ! "$question_ssl" =~ [Nn] ]] && NGINX_SSL=true || NGINX_SSL=false

    if [ "$NGINX_SSL" = true ]; then
        echo
        info "Implement HSTS policy on Nginx? (Y/n)"
        read -r question_hsts
        [[ ! "$question_hsts" =~ [Nn] ]] && NGINX_HSTS=true || NGINX_HSTS=false
    else
        NGINX_HSTS=false
    fi
}
#endregion

#region Let's Encrypt
q_letsencrypt() {
    echo
    info "Generate Let's Encrypt SSL Certificate? (Y/n)"
    read -r question
    [[ ! "$question" =~ [Nn] ]] && SETUP_LETSENCRYPT=true || SETUP_LETSENCRYPT=false
}
#endregion

#region UFW Firewall
q_firewall() {
    echo
    info "Set up UFW Firewall? (Y/n)"
    read -r question
    [[ ! "$question" =~ [Nn] ]] && SETUP_FIREWALL=true || SETUP_FIREWALL=false
}
#endregion
#
#endregion

#region Install or Update
install_update_panel() {
    #region Update Panel
    if [ -d /var/www/pterodactyl ]; then
        info "Update Panel..."

        # Update PHP
        curr_php_version=$(grep -o -E 'php([0-9]+.+[0-9]+)+(-fpm)?' /etc/nginx/sites-available/pterodactyl.conf | grep -o 'php[0-9.]*')
        if [ -n "$curr_php_version" ]; then
            if [[ "$curr_php_version" < "$PHP_VERSION" ]]; then
                echo
                info "PHP version $PHP_VERSION is available! Do you want to install the new version? (y/N)"
                read -r question_update_php
                if [[ "$question_update_php" =~ [Yy] ]]; then
                    apt-get update -y
                    info "Remove old version..."
                    apt-get purge -y php${curr_php_version} php${curr_php_version}-{cli,common,gd,mysql,mbstring,bcmath,xml,fpm,curl,zip}
                    info "Install new version..."
                    apt-get install -y php${PHP_VERSION} php${PHP_VERSION}-{cli,common,gd,mysql,mbstring,bcmath,xml,fpm,curl,zip}
                    sed -i -e "s@php${curr_php_version}@php${PHP_VERSION}@g" /etc/nginx/sites-available/pterodactyl.conf
                fi
            fi
        fi

        cd /var/www/pterodactyl

        php artisan p:upgrade \
            --no-interaction

        success "Panel has been successfully updated."
        #endregion
    else
        #region Install Panel
        info "Install Panel..."

        #Setup Firewall
        if [ "$SETUP_FIREWALL" = true ]; then
            info "Setup Firewall..."
            setup_ufw
            ufw allow 80
            ufw allow 443
        fi

        #Install Prerequisites
        info "Install Prerequisites..."
        apt-get install -y software-properties-common apt-transport-https ca-certificates tar

        #Install PHP
        info "Install PHP..."
        dist="$(. /etc/os-release && echo "$ID")"
        if [ "$dist" = "debian" ]; then
            codename="$(. /etc/os-release && echo "$VERSION_CODENAME")"
            curl https://packages.sury.org/php/apt.gpg -o /etc/apt/trusted.gpg.d/php.gpg
            echo "deb https://packages.sury.org/php/ ${codename} main" | tee /etc/apt/sources.list.d/php.list
        fi

        apt-get update -y
        apt-get install -y php${PHP_VERSION} php${PHP_VERSION}-{cli,common,gd,mysql,mbstring,bcmath,xml,fpm,curl,zip}

        #Install Nginx
        info "Install Nginx..."
        apt-get install -y nginx

        #Ask for Panel FQDN
        echo
        info "Please enter the FQDN of the Panel (panel.example.com): "
        read -r panel_fqdn

        #Setup Let’s Encrypt
        if [ "$SETUP_LETSENCRYPT" = true ]; then
            echo
            info "Please enter the email address for the SSL certificate: "
            read -r le_email

            #Install Certbot
            info "Install Certbot..."
            apt-get install -y certbot

            #Setup Webserver without SSL
            if [ -f "/etc/nginx/sites-enabled/default" ]; then
                rm /etc/nginx/sites-enabled/default
            fi

            curl -o /etc/nginx/sites-available/pterodactyl.conf "https://raw.githubusercontent.com/BAERSERK/pterodactyl-script/main/configs/nginx.conf"

            sed -i -e "s@<domain>@${panel_fqdn}@g" /etc/nginx/sites-available/pterodactyl.conf
            sed -i -e "s@<php_version>@${PHP_VERSION}@g" /etc/nginx/sites-available/pterodactyl.conf

            if [ ! -L "/etc/nginx/sites-enabled/pterodactyl.conf" ]; then
                ln -s /etc/nginx/sites-available/pterodactyl.conf /etc/nginx/sites-enabled/pterodactyl.conf
            fi

            systemctl restart nginx

            mkdir -p /var/www/pterodactyl/public

            certbot certonly --webroot -w /var/www/pterodactyl/public --email "$le_email" --agree-tos -d "$panel_fqdn" --non-interactive
        fi

        #Install Composer
        info "Install Composer..."
        curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

        #Install and Setup Panel
        info "Install and setup Panel..."

        mkdir -p /var/www/pterodactyl
        cd /var/www/pterodactyl

        curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
        tar -xzvf panel.tar.gz
        chmod -R 755 storage/* bootstrap/cache/

        cp .env.example .env
        yes | composer install --no-dev --optimize-autoloader

        php artisan key:generate --force

        if [ "$NGINX_SSL" = true ]; then
            PANEL_PROTOCOL="https://"
        else
            PANEL_PROTOCOL="http://"
        fi

        php artisan p:environment:setup \
            --url="${PANEL_PROTOCOL}${panel_fqdn}" \
            --timezone="$(cat /etc/timezone)" \
            --cache="file" \
            --session="database" \
            --queue="database" \
            --settings-ui=true

        if [ "$DBPANEL_SETUP" = true ]; then
            php artisan p:environment:database \
                --host="127.0.0.1" \
                --port="3306" \
                --database="$DBPANEL_DB" \
                --username="$DBPANEL_USER" \
                --password="$DBPANEL_PASSWORD"
        else
            php artisan p:environment:database
        fi

        echo
        info "Set up E-Mail configuration? (y/N): "
        read -r mail_config

        if [[ "$mail_config" =~ [Yy] ]]; then
            php artisan p:environment:mail
        fi

        php artisan migrate --seed --force

        info "Create Initial User..."
        php artisan p:user:make

        chown -R www-data:www-data /var/www/pterodactyl/*

        #Setup Queue Listeners
        info "Setup Queue Listeners..."

        crontab -l | {
            cat
            echo "* * * * * php /var/www/pterodactyl/artisan schedule:run >> /dev/null 2>&1"
        } | crontab -

        curl -o /etc/systemd/system/pteroq.service "https://raw.githubusercontent.com/BAERSERK/pterodactyl-script/main/configs/pteroq.service"

        systemctl enable --now pteroq.service

        #Setup Webserver
        if [ -f "/etc/nginx/sites-enabled/default" ]; then
            rm /etc/nginx/sites-enabled/default
        fi

        if [ "$NGINX_SSL" = true ]; then
            curl -o /etc/nginx/sites-available/pterodactyl.conf "https://raw.githubusercontent.com/BAERSERK/pterodactyl-script/main/configs/nginx_ssl.conf"

            if [ "$NGINX_HSTS" = true ]; then
                PANEL_HSTS=
            else
                PANEL_HSTS=\#
            fi
            sed -i -e "s@<hsts>@${PANEL_HSTS}@g" /etc/nginx/sites-available/pterodactyl.conf
        else
            curl -o /etc/nginx/sites-available/pterodactyl.conf "https://raw.githubusercontent.com/BAERSERK/pterodactyl-script/main/configs/nginx.conf"
        fi

        sed -i -e "s@<domain>@${panel_fqdn}@g" /etc/nginx/sites-available/pterodactyl.conf
        sed -i -e "s@<php_version>@${PHP_VERSION}@g" /etc/nginx/sites-available/pterodactyl.conf

        if [ ! -L "/etc/nginx/sites-enabled/pterodactyl.conf" ]; then
            ln -s /etc/nginx/sites-available/pterodactyl.conf /etc/nginx/sites-enabled/pterodactyl.conf
        fi

        systemctl restart nginx

        success "Panel has been successfully installed.\n-> URL: ${PANEL_PROTOCOL}${panel_fqdn}"
        #endregion
    fi
}

install_update_wings() {
    if [ -x /usr/local/bin/wings ]; then
        #region Update Wings
        info "Update Wings..."

        curl -L -o /usr/local/bin/wings "https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_$([[ "$(uname -m)" == "x86_64" ]] && echo "amd64" || echo "arm64")"
        chmod u+x /usr/local/bin/wings

        systemctl restart wings

        success "Wings has been successfully updated."
        #endregion
    else
        #region Install Wings
        info "Install Wings..."

        #Setup Firewall
        if [ "$SETUP_FIREWALL" = true ]; then
            info "Setup Firewall..."
            setup_ufw
            ufw allow 8080
            ufw allow 2022
        fi

        #Ask for FQDN
        echo
        info "Please enter the FQDN of the Node (node.example.com): "
        read -r host_fqdn

        #Setup Let’s Encrypt
        if [ "$SETUP_LETSENCRYPT" = true ]; then
            echo
            info "Please enter the email address for the SSL certificate: "
            read -r le_email

            #Install Certbot
            info "Install Certbot..."
            apt-get install -y certbot

            ufw allow 80

            echo
            info "Runs the panel on this machine? (Y/n)"

            read -r panel_machine
            if [[ ! "$panel_machine" =~ [Nn] ]]; then
                certbot certonly --webroot -w /var/www/pterodactyl/public --email "$le_email" --agree-tos -d "$host_fqdn" --non-interactive
            else
                certbot certonly --standalone --email "$le_email" --agree-tos -d "$host_fqdn" --non-interactive
            fi
        fi

        #Install Docker
        info "Install Docker..."
        curl -sSL https://get.docker.com/ | CHANNEL=stable bash

        #Enable SWAP
        info "Enable SWAP for Docker"
        sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="[^"]*/& swapaccount=1/' /etc/default/grub
        update-grub

        #Install Wings
        info "Install Wings..."
        mkdir -p /etc/pterodactyl
        curl -L -o /usr/local/bin/wings "https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_$([[ "$(uname -m)" == "x86_64" ]] && echo "amd64" || echo "arm64")"
        chmod u+x /usr/local/bin/wings

        curl -o /etc/systemd/system/wings.service "https://raw.githubusercontent.com/BAERSERK/pterodactyl-script/main/configs/wings.service"

        systemctl enable --now wings

        success "Wings has been successfully installed.\n-> Restart your system and add this node to the panel!"
        #endregion
    fi
}

install_update_phpma() {
    #Check if Panel installed
    if [ -d /var/www/pterodactyl ]; then

        if [ -d /var/www/pterodactyl/public/phpmyadmin ]; then
            #region Update phpMyAdmin
            info "Update phpMyAdmin..."

            cd /var/www/pterodactyl/public/phpmyadmin

            curl -Lo phpMyAdmin-latest-all-languages.tar.gz "https://www.phpmyadmin.net/downloads/phpMyAdmin-latest-all-languages.tar.gz"
            tar -xzvf phpMyAdmin-latest-all-languages.tar.gz --strip-components=1

            chown -R www-data:www-data /var/www/pterodactyl/*

            success "phpMyAdmin has been successfully updated."
            #endregion
        else
            #region Install phpMyAdmin
            info "Install phpMyAdmin..."

            mkdir -p /var/www/pterodactyl/public/phpmyadmin
            cd /var/www/pterodactyl/public/phpmyadmin

            curl -Lo phpMyAdmin-latest-all-languages.tar.gz "https://www.phpmyadmin.net/downloads/phpMyAdmin-latest-all-languages.tar.gz"
            tar -xzvf phpMyAdmin-latest-all-languages.tar.gz --strip-components=1

            #Change Config
            info "Setup phpMyAdmin Configuration"
            curl -o config.inc.php "https://raw.githubusercontent.com/BAERSERK/pterodactyl-script/main/configs/phpmyadmin.php"
            sed -i -e "s@<blowfish>@$(cat /dev/urandom | tr -dc 'a-zA-Z0-9!#$%&()*+,-./:;<=>?@[\]^_{|}~' | fold -w 32 | head -n 1)@g" config.inc.php

            chown -R www-data:www-data /var/www/pterodactyl/*

            success "phpMyAdmin has been successfully installed.\n-> URL: http://panel.example.com/phpmyadmin"
            #endregion
        fi
    else
        error "To install phpMyAdmin you need to install the Panel first!"
    fi
}
#endregion

#region Setup Wizard
setup_wizard() {
    INSTALL_PANEL=
    INSTALL_WINGS=
    INSTALL_PHPMA=

    echo
    output "${YELLOW}* Pterodactyl Script v${VERSION} *"
    output "https://github.com/BAERSERK/pterodactyl-script"

    #region Panel Menu
    while true; do
        echo
        output "${GREEN}Install Panel?"
        output "   \e[3m${GRAY}+ MARIADB, NGINX[SSL+HSTS], UFW\e[0m"
        echo -ne "Choose an option (Y/N): "

        read -r option

        case $option in
        [Yy])
            INSTALL_PANEL=true
            break
            ;;
        [Nn])
            INSTALL_PANEL=false
            break
            ;;
        *) ;;
        esac
    done
    #endregion

    #region Wings Menu
    while true; do
        echo
        output "${BLUE}Install Wings?"
        output "   \e[3m${GRAY}+ MARIADB, SSL, UFW\e[0m"
        echo -ne "Choose an option (Y/N): "

        read -r option

        case $option in
        [Yy])
            INSTALL_WINGS=true
            break
            ;;
        [Nn])
            INSTALL_WINGS=false
            break
            ;;
        *) ;;
        esac
    done
    #endregion

    #region phpMyAdmin Menu
    # Only if Panel will installed
    if [ "$INSTALL_PANEL" = true ]; then
        while true; do
            echo
            output "${PURPLE}Install phpMyAdmin?"
            output "   \e[3m${GRAY}+ UFW\e[0m"
            echo -ne "Choose an option (Y/N): "

            read -r option

            case $option in
            [Yy])
                INSTALL_PHPMA=true
                break
                ;;
            [Nn])
                INSTALL_PHPMA=false
                break
                ;;
            *) ;;
            esac
        done
    fi
    #endregion

    #region Install selected
    if [ "$INSTALL_PANEL" = true ]; then
        update_upgrade
        setup_mariadb
        setup_panel_db
        install_update_panel
    fi

    if [ "$INSTALL_WINGS" = true ]; then
        update_upgrade
        setup_mariadb
        setup_host_db
        install_update_wings
    fi

    if [ "$INSTALL_PHPMA" = true ]; then
        update_upgrade
        install_update_phpma
    fi

    if [ "$INSTALL_PANEL" = true ] || [ "$INSTALL_WINGS" = true ]; then
        print_db_info
    fi
    #endregion
}
#endregion

#region Selection Menu
#
#region Easy Mode
easy_menu() {
    echo
    output "${YELLOW}* Pterodactyl Script v${VERSION} *"
    output "https://github.com/BAERSERK/pterodactyl-script"

    while true; do
        echo
        output "${GREEN}1)${NC} Panel ${GREEN}($([[ -d /var/www/pterodactyl ]] && echo Update || echo Install))"
        [[ ! -d /var/www/pterodactyl ]] && output "   \e[3m${GRAY}+ MARIADB, NGINX[SSL+HSTS], SSL, UFW\e[0m" || output "   \e[3m${GRAY}-> $(get_latest_release "pterodactyl/panel")\e[0m"
        output "${BLUE}2)${NC} Wings ${BLUE}($([[ -x /usr/local/bin/wings ]] && echo Update || echo Install))"
        [[ ! -x /usr/local/bin/wings ]] && output "   \e[3m${GRAY}+ MARIADB, SSL, UFW\e[0m" || output "   \e[3m${GRAY}-> $(get_latest_release "pterodactyl/wings")\e[0m"
        output "${PURPLE}3)${NC} phpMyAdmin ${PURPLE}($([[ -d /var/www/pterodactyl/public/phpmyadmin ]] && echo Update || echo Install))"
        [[ ! -d /var/www/pterodactyl/public/phpmyadmin ]] && output "   \e[3m${GRAY}+ UFW\e[0m" || output "   \e[3m${GRAY}-> $(get_latest_release "phpmyadmin/phpmyadmin" | sed 's/[^0-9_]//g; /^[_]/ s/.//; s/_/./g')\e[0m"

        echo
        output "${CYAN}T)${NC} Tools"
        output "${RED}Q)${NC} Quit"
        echo -ne "Choose an option: "

        read -r option

        case $option in
        1)
            update_upgrade
            setup_mariadb
            setup_panel_db
            install_update_panel
            print_db_info
            ;;
        2)
            update_upgrade
            setup_mariadb
            setup_host_db
            install_update_wings
            print_db_info
            ;;
        3)
            update_upgrade
            install_update_phpma
            ;;
        [Tt])
            . <(curl -s "https://raw.githubusercontent.com/BAERSERK/pterodactyl-script/main/tools.sh")
            exit 0
            ;;
        [Qq])
            exit 0
            ;;
        *) ;;
        esac

        echo
    done
}
#endregion

#region Advanced Mode
advanced_menu() {
    echo
    output "${YELLOW}* Pterodactyl Script v${VERSION} *"
    output "https://github.com/BAERSERK/pterodactyl-script"

    while true; do
        echo

        output "${GREEN}1)${NC} Panel ${GREEN}(Adv. $([[ -d /var/www/pterodactyl ]] && echo Update || echo Install))"
        output "${BLUE}2)${NC} Wings ${BLUE}(Adv. $([[ -x /usr/local/bin/wings ]] && echo Update || echo Install))"
        output "${PURPLE}3)${NC} phpMyAdmin ${PURPLE}(Adv. $([[ -d /var/www/pterodactyl/public/phpmyadmin ]] && echo Update || echo Install))"

        echo
        output "${CYAN}T)${NC} Tools"
        output "${RED}Q)${NC} Quit"
        echo -ne "Choose an option: "

        read -r option

        case $option in
        1)
            q_mariadb_panel
            q_nginx_ssl_hsts
            q_letsencrypt
            q_firewall

            update_upgrade
            setup_mariadb
            setup_panel_db
            install_update_panel
            print_db_info
            ;;
        2)
            q_mariadb_host
            q_letsencrypt
            q_firewall

            update_upgrade
            setup_mariadb
            setup_host_db
            install_update_wings
            print_db_info
            ;;
        3)
            update_upgrade
            install_update_phpma
            ;;
        [Tt])
            . <(curl -s "https://raw.githubusercontent.com/BAERSERK/pterodactyl-script/main/tools.sh")
            exit 0
            ;;
        [Qq])
            exit 0
            ;;
        *) ;;
        esac

        echo
    done
}
#endregion

#region Select correct mode
if [[ $1 == t* ]]; then
    echo
    output "${YELLOW}* Pterodactyl Script v${VERSION} *"
    output "https://github.com/BAERSERK/pterodactyl-script"
    . <(curl -s "https://raw.githubusercontent.com/BAERSERK/pterodactyl-script/main/tools.sh")
    exit 0
fi
if [[ -x /usr/local/bin/wings ]] || [ -d /var/www/pterodactyl ] || [ -d /var/www/pterodactyl/public/phpmyadmin ]; then
    if [[ $1 == a* ]]; then
        advanced_menu
    else
        easy_menu
    fi
else
    if [[ $1 == a* ]]; then
        advanced_menu
    else
        setup_wizard
    fi
fi
#endregion
#
#endregion
