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
    echo -e "${RED}        Not recommended for production use, used to mainly for testing script setup.${NC}"
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
fi

if [ $VARVAL_CHAIN_NAME = "testnet" ]; then
    VARVAL_CHAIN_PEER="$XAHL_TESTNET_PEER"
fi

# Stop nginx and xahaud processes, clean up
sudo systemctl stop nginx.service \
    && sudo systemctl disable nginx.service \
    ## && sudo rm -rfv /lib/systemd/system/nginx.service \ # Cleaned up by apt remove?
    && sudo rm -rfv /run/nginx.pid \
    && sudo rm -rfv /usr/sbin/nginx
sudo systemctl stop xahaud.service \
    && sudo systemctl disable xahaud.service \
    && sudo rm -rfv /etc/systemd/system/xahaud.service

read -p "pause"

# Remove and clean up landingpage
sudo rm -fv $NGX_CONF_ENABLED/xahau
sudo rm -fv $NGX_CONF_AVAIL/xahau
sudo rm -rfv /home/www

read -p "pause"

# Remove and clean up nginx
rm -rfv /var/www
sudo apt --purge remove fontconfig-config fonts-dejavu-core libdeflate0 \
    libfontconfig1 libgd3 libjbig0 libjpeg-turbo8 libjpeg8 libnginx-mod-http-geoip2 \
    libnginx-mod-http-image-filter libnginx-mod-http-xslt-filter libnginx-mod-mail libnginx-mod-stream \
    libnginx-mod-stream-geoip2 libtiff5 libwebp7 libxpm4 nginx-common nginx-core -y

read -p "pause"

# Remove firewall rules
sudo ufw delete allow $VARVAL_CHAIN_PEER/tcp
sudo ufw delete allow 'Nginx Full'
sudo ufw status verbose

read -p "pause"

# Remove and clean up xahaud
sudo rm -rfv ~/$SCRIPT_DIR
sudo rm -rfv /opt/xahaud
sudo deluser xahaud

read -p "pause"

# Clean up logrotate
sudo rm -rfv /etc/logrotate.d/nginx
sudo rm -rfv /etc/logrotate.d/xahau-logs

read -p "pause"

# Remove and clean up certbot
sudo certbot revoke --cert-path /etc/letsencrypt/live/$USER_DOMAIN/fullchain.pem --non-interactive
read -p "pause"
sudo apt --purge remove certbot python3-certbot-nginx -y
sudo apt autoremove -y

echo
echo
echo
echo
echo -e "${RED} Removal of xahaud and associated setup completed.${NC}"
echo
echo
echo