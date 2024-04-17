#!/bin/bash

# Set Colour Vars
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

    echo -e "${RED}#########################################################################"
    echo -e "${RED}#########################################################################"
    echo -e "${RED}"
    echo -e "${RED}        !!  WARNING  !!${NC} Xahaud Reset Script ${RED}!!  WARNING  !!${NC}"
    echo -e "${RED}"
    echo -e "${RED}        Not recommended for production use, used for testing script setup.${NC}"
    echo -e "${RED}#########################################################################"
    echo -e "${RED}#########################################################################${NC}"
    echo
    echo
    echo

    # Ask the user acc for login details (comment out to disable)
    CHECK_PASSWD=false
        while true; do
            read -t10 -r -p ":: DESTRUCTIVE :: Confirm that you wish to RESET your Xahaud node installation ? (Y/n) " _input
            if [ $? -gt 128 ]; then
                #clear
                echo
                echo "timed out waiting for user response - quitting..."
                exit 0
            fi
            case $_input in
                [Yy][Ee][Ss]|[Yy]* )
                    break
                    ;;
                [Nn][Oo]|[Nn]* ) 
                    exit 0
                    ;;
                * ) echo "Please answer (y)es or (n)o.";;
            esac
        done

# Authenticate sudo perms before script execution to avoid timeouts or errors
sudo -l > /dev/null 2>&1

# Load the vars file
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
source $SCRIPT_DIR/xahl_node.vars


if [ $VARVAL_CHAIN_NAME = "mainnet" ]; then
    VARVAL_CHAIN_PEER="$XAHL_MAINNET_PEER"
    VARVAL_CHAIN_REPO="mainnet-docker"
fi

if [ $VARVAL_CHAIN_NAME = "testnet" ]; then
    VARVAL_CHAIN_PEER="$XAHL_TESTNET_PEER"
    VARVAL_CHAIN_REPO="Xahau-Testnet-Docker"
fi

# Stop nginx and xahaud processes, clean up
sudo systemctl stop nginx.service \
    && sudo systemctl disable nginx.service \
    && sudo rm -rfv /run/nginx.pid \
    && sudo rm -rfv /usr/sbin/nginx
sudo systemctl stop xahaud.service \
    && sudo systemctl disable xahaud.service \
    && sudo rm -rfv /etc/systemd/system/xahaud.service
sudo systemctl daemon-reload

# Remove and clean up landingpage
sudo rm -fv $NGX_CONF_ENABLED/xahau
sudo rm -fv $NGX_CONF_AVAIL/xahau
sudo rm -rfv /home/www

# Remove and clean up nginx
sudo rm -rfv $SCRIPT_DIR/nginx_allowlist.conf
sudo rm -rfv /var/www
sudo apt --purge remove fontconfig-config fonts-dejavu-core libdeflate0 \
    libfontconfig1 libgd3 libjbig0 libjpeg-turbo8 libjpeg8 libnginx-mod-http-geoip2 \
    libnginx-mod-http-image-filter libnginx-mod-http-xslt-filter libnginx-mod-mail libnginx-mod-stream \
    libnginx-mod-stream-geoip2 libtiff5 libwebp7 libxpm4 nginx-common nginx-core -y

# Remove firewall rules
sudo ufw delete allow $VARVAL_CHAIN_PEER/tcp
sudo ufw delete allow 'Nginx Full'
sudo ufw status verbose

# Remove and clean up xahaud
echo -e $VARVAL_CHAIN_REPO
if [ -z $VARVAL_CHAIN_REPO ]; then
    echo -e "VARVAL_CHAIN_REPO is not defined for some reason. Exiting before I nuke the home folder."
    exit 1
else
    sudo rm -rfv $SCRIPT_DIR/$VARVAL_CHAIN_REPO
fi
sudo userdel xahaud
sudo rm -rfv /opt/xahaud
sudo rm -rfv /usr/local/bin/xahaud
sudo rm -rfv /usr/local/bin/xahaud-install-update.sh

# Clean up logrotate
sudo rm -rfv /etc/logrotate.d/nginx
sudo rm -rfv /etc/logrotate.d/xahau-logs

# Remove and clean up certbot
sudo certbot revoke --cert-path /etc/letsencrypt/live/$USER_DOMAIN/fullchain.pem --non-interactive
sudo apt --purge remove certbot python3-certbot-nginx python3-acme python3-certbot python3-certifi \
    python3-configargparse python3-icu python3-josepy python3-parsedatetime python3-requests \
    python3-requests-toolbelt python3-rfc3339 python3-tz python3-urllib3 python3-zope.component \
    python3-zope.event python3-zope.hookable -y
#sudo mv -v ~/default.nginx /etc/nginx/sites-available/default
sudo rm -rfv /var/log/letsencrypt

echo
echo
echo
echo
echo -e "${RED} Removal of xahaud and associated setup completed.${NC}"
echo
echo
echo