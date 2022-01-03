#!/bin/bash
set -e

output "${BLUE}Install MariaDB..."

# Check if already Installed
if [ $(dpkg-query -W -f='${Status}' mariadb-server 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
    update_upgrade

    apt install -y mariadb-server

    #region Setup Firewall
    if [ "$SETUP_FIREWALL" = true ]; then
        output "Setup Firewall..."
        setup_ufw
        ufw allow 3306
    fi
    #endregion

    if [ -z "$DB_ROOT_PASSWORD"]; then
        DB_ROOT_PASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9!#$%&()*+,-./:;<=>?@[\]^_{|}~' | fold -w $PASSWORD_LENGTH | head -n 1)
    fi

    #region Setup secure MySQL
    output "Setup secure MySQL installation..."
    C0="UPDATE mysql.global_priv SET priv=json_set(priv, '$.plugin', 'mysql_native_password', '$.authentication_string', PASSWORD('$DB_ROOT_PASSWORD')) WHERE User='root';"
    C1="DELETE FROM mysql.global_priv WHERE User='';"
    C2="DELETE FROM mysql.global_priv WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
    C3="DROP DATABASE IF EXISTS test;"
    C4="DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"
    C5="FLUSH PRIVILEGES;"
    mysql -u root -e "${C0}${C1}${C2}${C3}${C4}${C5}"
    #endregion

    #region Update Configuration
    output "Update MariaDB Configuration..."
    sed -i -- '/bind-address/s/127.0.0.1/0.0.0.0/g' /etc/mysql/mariadb.conf.d/50-server.cnf
    service mysql restart
    #endregion

    #region Setup Panel DB
    if [ "$SETUP_DBPANEL" = true ]; then
        EXISTS_DBPANEL_USER=$(mysql -u root -sse "SELECT EXISTS(SELECT 1 FROM mysql.user WHERE user = '$DBPANEL_USER')")
        if [ "$EXISTS_DBPANEL_USER" = 0 ]; then

            EXISTS_DBPANEL_DB=$(mysql -u root -sse "SELECT EXISTS(SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = '$DBPANEL_DB')")
            if [ "$EXISTS_DBPANEL_DB" = 0 ]; then

                if [ -z "$DBPANEL_PASSWORD"]; then
                    DBPANEL_PASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9!#$%&()*+,-./:;<=>?@[\]^_{|}~' | fold -w $PASSWORD_LENGTH | head -n 1)
                fi

                output "Create $DBPANEL_USER user..."
                C00="CREATE USER '$DBPANEL_USER'@'127.0.0.1' IDENTIFIED BY '$DBPANEL_PASSWORD';"

                output "Create $DBPANEL_USER database..."
                C11="CREATE DATABASE $DBPANEL_DB;"

                C22="GRANT ALL PRIVILEGES ON ${DBPANEL_DB}.* TO '$DBPANEL_USER'@'127.0.0.1' WITH GRANT OPTION;"
                C33="FLUSH PRIVILEGES;"
                mysql -u root -e "${C00}${C11}${C22}${C33}"
            else
                error "The database $DBPANEL_DB already exists! Delete the database first before you continue."
                exit 1
            fi
        else
            error "The database user $DBPANEL_USER already exists! Delete the user first before you continue."
            exit 1
        fi
    fi
    #endregion

    #region Setup Host DB
    if [ "$SETUP_DBHOST" = true ]; then
        EXISTS_DBHOST_USER=$(mysql -u root -sse "SELECT EXISTS(SELECT 1 FROM mysql.user WHERE user = '$DBHOST_USER')")
        if [ "$EXISTS_DBHOST_USER" = 0 ]; then

            if [ -z "$DBHOST_PASSWORD"]; then
                DBHOST_PASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9!#$%&()*+,-./:;<=>?@[\]^_{|}~' | fold -w $PASSWORD_LENGTH | head -n 1)
            fi

            output "Create $DBHOST_USER user..."
            C000="CREATE USER '$DBHOST_USER'@'%' IDENTIFIED BY '$DBHOST_PASSWORD';"

            C111="GRANT ALL PRIVILEGES ON *.* TO '$DBHOST_USER'@'%' WITH GRANT OPTION;"
            mysql -u root -e "${C000}${C111}"
        else
            error "The database user $DBHOST_USER already exists! Delete the user first before you continue."
            exit 1
        fi
    fi
    #endregion

    DB_INSTALLED=true

    output
    output "--------------------------------------------"
    output "| MariaDB has been successfully installed. |"
    output "--------------------------------------------"
    output
    output
    output "--------------------------------------------"
    output "DB Panel Information (For Panel)"
    output "--------------------------------------------"
    output
    output "Database: $DBPANEL_DB"
    output "User: $DBPANEL_USER"
    output "Password: $DBPANEL_PASSWORD"
    output
    output "--------------------------------------------"
    output "DB Host Information (For Per-Server Databases)"
    output "--------------------------------------------"
    output
    output "User: $DBHOST_USER"
    output "Password: $DBHOST_PASSWORD"
    output
    output "--------------------------------------------"
    output
    output "Root Password: $DB_ROOT_PASSWORD"
    output
else
    error "MariaDB is already installed! Uninstall MariaDB first before you continue."
    exit 1
fi
