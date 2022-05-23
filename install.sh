#!/bin/bash
set -e

VERSION="0.1.2"
PHP_VERSION=8.0
DB_INSTALLED=false

#region User Variables
SETUP_FIREWALL=${SETUP_FIREWALL:-true}
SETUP_LETSENCRYPT=${SETUP_LETSENCRYPT:-true}

NGINX_SSL=${NGINX_SSL:-true}
NGINX_HSTS=${NGINX_HSTS:-true}

PASSWORD_LENGTH=${PASSWORD_LENGTH:-64}

DBPANEL_DB=${DBPANEL_DB:-"panel"}
DBPANEL_USER=${DBPANEL_USER:-"pterodactyl"}
DBPANEL_PASSWORD=${DBPANEL_PASSWORD:-""}

DBHOST_USER=${DBHOST_USER:-"pterodactyluser"}
DBHOST_PASSWORD=${DBHOST_PASSWORD:""}

DB_ROOT_PASSWORD=${DB_ROOT_PASSWORD:""}
#endregion

#region Text Formatting
NC="\033[0m" # Normal Color
RED="\033[1;31m"
YELLOW="\033[1;33m"
GREEN="\033[1;32m"
BLUE="\033[1;34m"

output() {
    echo -e "${NC}${1}${NC}"
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
#endregion

#region Helper Functions
update_upgrade() {
    apt update -y && apt upgrade -y
}

setup_ufw() {
    apt install -y ufw
    ufw allow 22
    yes | ufw enable
}
#endregion

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

    output "Are you sure you want to proceed? (y/N): "
    read -r PROCEED_VIRTUALIZATION

    if [[ ! "$PROCEED_VIRTUALIZATION" =~ [Yy] ]]; then
        output "${RED}Installation aborted!"
        exit 1
    fi
fi
#endregion

#region Check for Updates
output "${BLUE}Checking for updates..."

which curl &>/dev/null || sudo apt install -y curl

SCRIPT_LOCATION="${BASH_SOURCE[@]}"
ABS_SCRIPT_PATH=$(readlink -f "$SCRIPT_LOCATION")
TMP_FILE=$(mktemp -p "" "XXXXX.sh")

curl -s -L "https://raw.githubusercontent.com/BAERSERK/pterodactyl-script/v0.1/install.sh" >"$TMP_FILE"
NEW_VER=$(grep "^VERSION" "$TMP_FILE" | awk -F'[="]' '{print $3}')

if [[ "$VERSION" < "$NEW_VER" ]]; then
    output "${GREEN}Update script from ${RED}v${VERSION} ${GREEN}to ${YELLOW}v${NEW_VER}"
    cp -f "$TMP_FILE" "$ABS_SCRIPT_PATH" || error "Unable to update script!"
else
    output "${GREEN}Already have the latest version."
fi
#endregion

#region Selection Menu
get_latest_release() {
    curl --silent "https://api.github.com/repos/$1/releases/latest" | # Get latest release from GitHub api
        grep '"tag_name":' |                                          # Get tag line
        sed -E 's/.*"([^"]+)".*/\1/'                                  # Pluck JSON value
}

PANEL_VERSION=$(get_latest_release "pterodactyl/panel")
WINGS_VERSION=$(get_latest_release "pterodactyl/wings")
PHPMA_VERSION=$(get_latest_release "phpmyadmin/phpmyadmin" | sed 's/[^0-9_]//g; /^[_]/ s/.//; s/_/./g')

clear -x

while true; do
    output "Please select an option:"
    output
    output "[1] Install MariaDB"
    output "[2] Install Panel"
    output "[3] Install Wings"
    output "[4] Install phpMyAdmin"
    output
    output "[5] Update Panel to $PANEL_VERSION"
    output "[6] Update Wings to $WINGS_VERSION"
    output "[7] Update phpMyAdmin to v${PHPMA_VERSION}"
    output
    output "[0] Quit"

    read -r option

    case $option in
    1)
        . <(curl -s "https://raw.githubusercontent.com/BAERSERK/pterodactyl-script/v0.1/scripts/install-mariadb.sh")
        ;;
    2)
        . <(curl -s "https://raw.githubusercontent.com/BAERSERK/pterodactyl-script/v0.1/scripts/install-panel.sh")
        ;;
    3)
        . <(curl -s "https://raw.githubusercontent.com/BAERSERK/pterodactyl-script/v0.1/scripts/install-wings.sh")
        ;;
    4)
        . <(curl -s "https://raw.githubusercontent.com/BAERSERK/pterodactyl-script/v0.1/scripts/install-phpmyadmin.sh")
        ;;
    5)
        . <(curl -s "https://raw.githubusercontent.com/BAERSERK/pterodactyl-script/v0.1/scripts/update-panel.sh")
        ;;
    6)
        . <(curl -s "https://raw.githubusercontent.com/BAERSERK/pterodactyl-script/v0.1/scripts/update-wings.sh")
        ;;
    7)
        . <(curl -s "https://raw.githubusercontent.com/BAERSERK/pterodactyl-script/v0.1/scripts/update-phpmyadmin.sh")
        ;;
    0)
        exit 0
        ;;
    *) ;;
    esac

    output
    output
done
#endregion
