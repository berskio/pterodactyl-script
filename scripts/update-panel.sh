#!/bin/bash
set -e

output "${BLUE}Updating Panel..."

cd /var/www/pterodactyl

php artisan p:upgrade \
    --no-interaction

output
output "${GREEN}Panel has been successfully updated."