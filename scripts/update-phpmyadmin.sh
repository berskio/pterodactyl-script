#!/bin/bash
set -e

output "${BLUE}Updating phpMyAdmin..."

cd /var/www/phpmyadmin

curl -Lo phpMyAdmin-latest-all-languages.tar.gz "https://www.phpmyadmin.net/downloads/phpMyAdmin-latest-all-languages.tar.gz"
tar -xzvf phpMyAdmin-latest-all-languages.tar.gz --strip-components=1

chown -R www-data:www-data /var/www/phpmyadmin/*

output
output "${GREEN}phpMyAdmin has been successfully updated."
output