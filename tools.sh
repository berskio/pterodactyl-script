#!/bin/bash

db_dump() {
    #Ask for Dump User
    echo
    info "Please enter your user from the database [root]: "
    read -r dump_user

    #Ask for Dump Password
    echo
    info "Please enter your password from the database: "
    read -r dump_password
    
    mkdir -p /var/lib/pterodactyl/dumps
    candidates=$(echo "show databases" | mysql -u ${dump_user:-root} -p $dump_password | grep -Ev "^(Database|mysql|performance_schema|information_schema)$")
    mysqldump -u ${dump_user:-root} -p $dump_password --databases $candidates > /var/lib/pterodactyl/dumps/dump-$(date +%Y%m%d-%H%M%S).sql
}

while true; do
    echo
    rclone_version=$(rclone --version 2>>errors | head -n 1)

    output "${GREEN}1)${NC} $([[ -d "$rclone_version" ]] && echo Install || echo Update) Rclone"
    output "   \e[3m${GREEN}current: ${rclone_version:7}\e[0m"
    output "${BLUE}2)${NC} Run ${BLUE}Manual${NC} DB dump"
    output "${PURPLE}3)${NC} Setup ${PURPLE}Auto${NC} DB dump"

    echo
    output "${RED}Q)${NC} Quit"
    echo -ne "Choose an option: "

    read -r option

    case $option in
    1)
        wget -O - https://rclone.org/install.sh | bash -
        exit 0
        ;;
    2)
        echo
        db_dump
        exit 0
        ;;
    3)
        id
        exit 0
        ;;
    [Qq])
        exit 0
        ;;
    *) ;;
    esac

    echo
done