#!/bin/bash
set -e

output "${BLUE}Installing Wings..."

update_upgrade

#region Setup Firewall
if [ "$SETUP_FIREWALL" = true ]; then
    output "Setup Firewall..."
    setup_ufw
    ufw allow 8080
    ufw allow 2022
fi
#endregion

#region Setup Let’s Encrypt
if [ "$SETUP_LETSENCRYPT" = true ]; then
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

    output
    output
    output "Is the Panel running on this Machine? (Y/n): "
    read -r RUNS_WEBSERVER

    if [[ ! "$RUNS_WEBSERVER" =~ [Nn] ]]; then
        output
        output "Is the FQDN of the Wings the same as that from the Panel? (Y/n): "
        read -r SAME_FQDN

        if [[ "$SAME_FQDN" =~ [Nn] ]]; then
            output
            output "Please enter the FQDN of the Node (node.example.com): "
            read HOST_FQDN

            output
            output "Please enter the email address for the SSL certificate: "
            read LE_EMAIL

            ufw allow 80

            certbot certonly --webroot -w /var/www/pterodactyl/public --email "$LE_EMAIL" --agree-tos -d "$HOST_FQDN" --non-interactive
        fi
    else
        output
        output "Please enter the FQDN of the Node (node.example.com): "
        read HOST_FQDN

        output
        output "Please enter the email address for the SSL certificate: "
        read LE_EMAIL

        ufw allow 80

        certbot certonly --standalone --email "$LE_EMAIL" --agree-tos -d "$HOST_FQDN" --non-interactive
    fi
fi
#endregion

#region Install Docker
output "Install Docker..."
curl -sSL https://get.docker.com/ | CHANNEL=stable bash
#endregion

#region Enable SWAP
output "Enable SWAP for Docker"
sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="[^"]*/& swapaccount=1/' /etc/default/grub
update-grub
#endregion

#region Install Wings
output "Install Wings..."
mkdir -p /etc/pterodactyl
curl -L -o /usr/local/bin/wings "https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_$([[ "$(uname -m)" == "x86_64" ]] && echo "amd64" || echo "arm64")"
chmod u+x /usr/local/bin/wings

curl -o /etc/systemd/system/wings.service "https://raw.githubusercontent.com/BAERSERK/pterodactyl-script/v0.1/configs/wings.service"

systemctl enable --now wings
#endregion

output
output "--------------------------------------------"
output "| Wings has been successfully installed. |"
output "--------------------------------------------"
output
output "${BLUE}INFO: It is recommended to reboot your machine now to enable the SWAP in Docker."
output
output "Now you just need to add this Node to the Panel and change the Configuration."
output
