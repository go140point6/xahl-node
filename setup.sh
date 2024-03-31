#!/bin/bash

# *** SETUP SOME VARIABLES THAT HIS SCRiPT NEEDS ***

# Get current user id and store as var
USER_ID=$(getent passwd $EUID | cut -d: -f1)

# Get some source IPs
#current SSH session
SRC_IP=$(echo $SSH_CONNECTION | awk '{print $1}')
if [ -z "$SRC_IP" ]; then
    SRC_IP="127.0.0.1"
fi
#this Nodes IP
NODE_IP=$(curl -s ipinfo.io/ip)
if [ -z "$NODE_IP" ]; then
    NODE_IP="127.0.0.1"
fi
#dockers IP
#DCKR_HOST_IP=$(sudo docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $VARVAL_CHAIN_NAME_xinfinnetwork_1)

# Authenticate sudo perms before script execution to avoid timeouts or errors
sudo -l > /dev/null 2>&1

# Set the sudo timeout for USER_ID to expire on reboot instead of default 5mins
echo "Defaults:$USER_ID timestamp_timeout=-1" > /tmp/xahlsudotmp
sudo sh -c 'cat /tmp/xahlsudotmp > /etc/sudoers.d/xahlnode_deploy'

# Set Colour Vars
GREEN='\033[0;32m'
#RED='\033[0;31m'
RED='\033[0;91m'  # Intense Red
YELLOW='\033[0;33m'
BYELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get the absolute path of the script directory
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
source $SCRIPT_DIR/xahl_node.vars

#setup date
FDATE=$(date +"%Y_%m_%d_%H_%M")


FUNC_PKG_CHECK(){
    echo
    echo -e "${GREEN}#########################################################################${NC}"
    echo
    echo -e "${GREEN}## CHECK NECESSARY PACKAGES HAVE BEEN INSTALLED...${NC}"
    echo     

    #sudo apt update -y && sudo apt upgrade -y

    for i in "${SYS_PACKAGES[@]}"
    do
        hash $i &> /dev/null
        if [ $? -eq 1 ]; then
           echo >&2 "package "$i" not found. installing...."
           sudo apt install -y "$i"
        fi
        echo "packages "$i" exist. proceeding...."
    done
    echo -e "${GREEN}## PACKAGES INSTALLED.${NC}"
    echo 
    echo -e "${GREEN}#########################################################################${NC}"
    echo
}


FUNC_CLONE_NODE_SETUP(){
    echo
    echo -e "${GREEN}#########################################################################${NC}"
    echo
    echo -e "${GREEN}## ${YELLOW}Starting Xahau Node install ...${NC}"
    echo
    echo -e "${GREEN}Cloning repo '$VARVAL_CHAIN_REPO' to HOME directory ${NC}"
    cd ~/
    NODE_DIR=$VARVAL_CHAIN_REPO

    if [ ! -d "$NODE_DIR" ]; then
      echo "The directory '$NODE_DIR' does not exist."
        git clone https://github.com/Xahau/$NODE_DIR
    else
      echo "The directory '$NODE_DIR' exists."
    fi

    cd $NODE_DIR
    sleep 2s

    sudo ./xahaud-install-update.sh
    sleep 2s
    echo
    echo -e "${GREEN}Updating conf file to limit public RPC/WS to localhost ...${NC}"
    sudo sed -i -E '/^\[port_ws_public\]$/,/^\[/ {/^(ip = )0\.0\.0\.0/s/^(ip = )0\.0\.0\.0/\1127.0.0.1/}' /opt/xahaud/etc/xahaud.cfg
    sleep 2s
    
    if grep -qE "^\[port_ws_public\]$" "/opt/xahaud/etc/xahaud.cfg" && grep -q "ip = 0.0.0.0" "/opt/xahaud/etc/xahaud.cfg"; then
        sudo sed -i -E '/^\[port_ws_public\]$/,/^\[/ s/^(ip = )0\.0\.0\.0/\1127.0.0.1/' /opt/xahaud/etc/xahaud.cfg
        sleep 2
        if grep -q "ip = 127.0.0.1" "/opt/xahaud/etc/xahaud.cfg"; then
            echo -e "It appears that [port_ws_public] was able to update correctly. ${NC}"
        else
            echo -e "${RED}Something wrong with updating [port_ws_public] ip in /opt/xahaud/etc/xahaud.cfg. Attempting second time..."
            sudo sed -i -E '/^\[port_ws_public\]$/,/^\[/ s/^(ip = )0\.0\.0\.0/\1127.0.0.1/' /opt/xahaud/etc/xahaud.cfg
            sleep 2
            if grep -q "ip = 127.0.0.1" "/opt/xahaud/etc/xahaud.cfg"; then
                echo -e "It appears that [port_ws_public] was able to update correctly on the second attempt. ${NC}"
            else
                echo -e "${RED}Something wrong with updating [port_ws_public] ip in /opt/xahaud/etc/xahaud.cfg. YOU MUST DO MANUALLY! ${NC}"
            fi
        fi
    else
        echo -e "${RED}Something wrong with updating [port_ws_public] ip in /opt/xahaud/etc/xahaud.cfg. YOU MUST DO MANUALLY! ${NC}"
    fi

    
    sudo sed -i -E '/^\[port_rpc_public\]$/,/^\[/ {/^(ip = )0\.0\.0\.0/s/^(ip = )0\.0\.0\.0/\1127.0.0.1/}' /opt/xahaud/etc/xahaud.cfg
    sleep 2s
    
    if grep -qE "^\[port_rpc_public\]$" "/opt/xahaud/etc/xahaud.cfg" && grep -q "ip = 0.0.0.0" "/opt/xahaud/etc/xahaud.cfg"; then
        sudo sed -i -E '/^\[port_rpc_public\]$/,/^\[/ s/^(ip = )0\.0\.0\.0/\1127.0.0.1/' /opt/xahaud/etc/xahaud.cfg
        if grep -q "ip = 127.0.0.1" "/opt/xahaud/etc/xahaud.cfg"; then
            echo -e "It appears that [port_rpc_public] was able to update correctly. ${NC}"
        else
            echo -e "${RED}Something wrong with updating [port_rpc_public] ip in /opt/xahaud/etc/xahaud.cfg. Attempting second time... ${NC}"
            sudo sed -i -E '/^\[port_rpc_public\]$/,/^\[/ s/^(ip = )0\.0\.0\.0/\1127.0.0.1/' /opt/xahaud/etc/xahaud.cfg
            if grep -q "ip = 127.0.0.1" "/opt/xahaud/etc/xahaud.cfg"; then
                echo -e "It appears that [port_rpc_public] was able to update correctly on the second attempt. ${NC}"
            else
                echo -e "${RED}Something wrong with updating [port_rpc_public] ip in /opt/xahaud/etc/xahaud.cfg. YOU MUST DO MANUALLY! ${NC}"
            fi
        fi
    else
        echo -e "${RED}Something wrong with updating [port_rpc_public] ip in /opt/xahaud/etc/xahaud.cfg. YOU MUST DO MANUALLY! ${NC}"
    fi

    sleep 2s
    sudo systemctl restart xahaud.service
    sleep 2s

    echo 
    echo -e "${GREEN}## Finished Xahau Node install ...${NC}"
    echo

    #FUNC_EXIT
}



FUNC_SETUP_UFW_PORTS(){
    echo 
    echo -e "${GREEN}#########################################################################${NC}" 
    echo 
    echo -e "${GREEN}## ${YELLOW}Setup: Configure Firewall...${NC}"
    echo 

    # Get current SSH port number 
    CPORT=$(sudo ss -tlpn | grep sshd | awk '{print$4}' | cut -d ':' -f 2 -s)
    #echo $CPORT
    sudo ufw allow $CPORT/tcp
    sudo ufw allow $VARVAL_CHAIN_PEER/tcp
    sudo ufw status verbose
    sleep 2s
}


FUNC_ENABLE_UFW(){

    echo 
    echo 
    echo -e "${GREEN}#########################################################################${NC}"
    echo 
    echo -e "${GREEN}## ${YELLOW}Setup: Change UFW logging to ufw.log only${NC}"
    echo 
    # source: https://handyman.dulare.com/ufw-block-messages-in-syslog-how-to-get-rid-of-them/
    sudo sed -i -e 's/\#& stop/\& stop/g' /etc/rsyslog.d/20-ufw.conf
    sudo cat /etc/rsyslog.d/20-ufw.conf | grep '& stop'

    echo 
    echo 
    echo -e "${GREEN}#########################################################################${NC}" 
    echo 
    echo -e "${YELLOW}## Setup: Enable Firewall...${NC}"
    echo 
    sudo systemctl start ufw && sudo systemctl status ufw
    sleep 2s
    echo "y" | sudo ufw enable
    #sudo ufw enable
    sudo ufw status verbose
}



FUNC_CERTBOT(){

    echo
    echo -e "${GREEN}#########################################################################${NC}"
    echo
    echo -e "${GREEN}## ${YELLOW}CertBot install and setup ...${NC}"
    echo



    # Install Let's Encrypt Certbot
    sudo apt install certbot python3-certbot-nginx -y

    # Prompt for user domains if not provided as a variable
    if [ -z "$USER_DOMAINS" ]; then
        read -p "Enter your servers domain (e.g., xahaunode.mydomain.com): " USER_DOMAINS
    fi
    sed -i "s/^USER_DOMAINS=.*/USER_DOMAINS=\"$USER_DOMAINS\"/" $SCRIPT_DIR/xahl_node.vars

    # Prompt for user allowed IP if not provided as a variable
    # Read the current value of $allow_list from the Nginx variables file
    # TODO make them enterable here ?

    # Prompt for user email if not provided as a variable
    if [ -z "$CERT_EMAIL" ]; then
        read -p "Enter your email address for certbot updates: " CERT_EMAIL
    fi
    sed -i "s/^CERT_EMAIL=.*/CERT_EMAIL=\"$CERT_EMAIL\"/" $SCRIPT_DIR/xahl_node.vars

}




FUNC_LOGROTATE(){
    # add the logrotate conf file
    # check logrotate status = cat /var/lib/logrotate/status

    echo -e "${GREEN}#########################################################################${NC}"
    echo
    echo -e "${GREEN}## ${YELLOW}Setup: Configurng LOGROTATE files...${NC}"
    sleep 2s

    USER_ID=$(getent passwd $EUID | cut -d: -f1)


    # Prompt for Chain if not provided as a variable
    if [ -z "$VARVAL_CHAIN_NAME" ]; then

        while true; do
         read -p "Enter which chain your node is deployed on (e.g. mainnet or testnet): " _input

            case $_input in
                testnet )
                    VARVAL_CHAIN_NAME="testnet"
                    break
                    ;;
                mainnet )
                    VARVAL_CHAIN_NAME="mainnet"
                    break
                    ;;
                * ) echo "Please answer a valid option.";;
            esac
        done

    fi

        cat <<EOF > /tmp/tmpxinfin-logs
/opt/xahaud/log/*.log
        {
            su $USER_ID $USER_ID
            size 100M
            rotate 50
            copytruncate
            daily
            missingok
            notifempty
            compress
            delaycompress
            sharedscripts
            postrotate
                    invoke-rc.d rsyslog rotate >/dev/null 2>&1 || true
            endscript
        }    
EOF

    sudo sh -c 'cat /tmp/tmpxinfin-logs > /etc/logrotate.d/xahau-logs'

}







FUNC_NODE_DEPLOY(){
    
    echo -e "${GREEN}#########################################################################${NC}"
    echo -e "${YELLOW}#########################################################################${NC}"
    echo -e "${GREEN}${NC}"
    echo -e "${GREEN}             Xahau ${BYELLOW}$_OPTION${GREEN} RPC/WSS Node - Install${NC}"
    echo -e "${GREEN}${NC}"
    echo -e "${YELLOW}#########################################################################${NC}"
    echo -e "${GREEN}#########################################################################${NC}"
    sleep 3s

    # installs default packages listed in vars file
    FUNC_PKG_CHECK;


    if [ "$_OPTION" == "mainnet" ]; then
        echo -e "${GREEN}### Configuring node for ${BYELLOW}$_OPTION${GREEN}... ${NC}"

        VARVAL_CHAIN_NAME=$_OPTION
        VARVAL_CHAIN_RPC=$NGX_MAINNET_RPC
        VARVAL_CHAIN_WSS=$NGX_MAINNET_WSS
        VARVAL_CHAIN_REPO="mainnet-docker"
        VARVAL_CHAIN_PEER=$XAHL_MAINNET_PEER

    elif [ "$_OPTION" == "testnet" ]; then
        echo -e "${GREEN}### Configuring node for ${BYELLOW}$_OPTION${GREEN}... ${NC}"

        VARVAL_CHAIN_NAME=$_OPTION
        VARVAL_CHAIN_RPC=$NGX_TESTNET_RPC
        VARVAL_CHAIN_WSS=$NGX_TESTNET_WSS
        VARVAL_CHAIN_REPO="Xahau-Testnet-Docker"
        VARVAL_CHAIN_PEER=$XAHL_TESTNET_PEER
    fi


    VARVAL_NODE_NAME="xahl_node_$(hostname -s)"
    echo -e "|| Node name is :${BYELLOW} $VARVAL_NODE_NAME ${NC}"
    #VARVAL_CHAIN_RPC=$NGX_RPC
    echo -e "|| Node RPC port is :${BYELLOW} $VARVAL_CHAIN_RPC ${NC}"
    #VARVAL_CHAIN_WSS=$NGX_WSS
    echo -e "|| Node WSS port is :${BYELLOW} $VARVAL_CHAIN_WSS ${NC}"
    echo
    echo -e "${GREEN}#########################################################################${NC}"
    echo
    sleep 2s

    # Install Nginx - Check if NGINX  is installed
    echo -e "${GREEN}#### INSTALLING NGINX... ${NC}"
    nginx -v 
    if [ $? != 0 ]; then
        echo -e "${YELLOW} #### NGINX is not installed. Installing now...${NC}"
        apt update -y
        sudo apt install nginx -y
    else
        # If NGINX is already installed.. skipping
        echo "${GREEN}#### NGINX is already installed. Skipping"
    fi

    echo
    echo -e "${GREEN}#########################################################################${NC}"
    echo 
    echo -e "${GREEN}##### Checking UFW... ${NC}"

    # Check if UFW (Uncomplicated Firewall) is installed
    sudo ufw version
    if [ $? = 0 ]; then
        # If UFW is installed, allow Nginx through the firewall
        echo "##### UFW is installed. allow Nginx through the firewall."
        sudo ufw allow 'Nginx Full'
    else
        echo "##### UFW is not installed. Skipping firewall configuration."
        echo
    fi



    # Update the package list and upgrade the system
    #apt update -y
    #apt upgrade -y

    #Xahau Node setup
    FUNC_CLONE_NODE_SETUP;

    # Firewall config
    FUNC_SETUP_UFW_PORTS;
    FUNC_ENABLE_UFW;

    #Rotate logs on regular basis
    FUNC_LOGROTATE;
    
    # APPLY/INSTALL CERTBOT
    FUNC_CERTBOT;

    # Create a new Nginx configuration file with the user-provided domain and test HTML page
    echo
    echo -e "${GREEN}#########################################################################${NC}"
    echo
    echo -e "${GREEN}## ${YELLOW}Setup: Checking Nginx configuration files ...${NC}"
    echo

    #delete default and old files, along with symbolic link file if it exists
    if [  -f $NGX_CONF_NEW/default ]; then
        sudo rm -f $NGX_CONF_NEW/default
    fi
    if [  -f $NGX_CONF_NEW/xahau ]; then
        sudo rm -f $NGX_CONF_NEW/xahau
    fi
    if [  -f $NGX_CONF_ENABLED/default ]; then
        sudo rm -f $NGX_CONF_NEW/default
    fi
    if [  -f $NGX_CONF_ENABLED/xahau ]; then
        sudo rm -f $NGX_CONF_NEW/xahau
    fi 
    if [  -f $NGX_CONF_NEW/$USER_DOMAINS ]; then
        sudo rm -f $NGX_CONF_NEW/$USER_DOMAINS
    fi   
     
    sudo touch $NGX_CONF_NEW/$USER_DOMAINS
    sudo chmod 666 $NGX_CONF_NEW/$USER_DOMAINS 
    
    sudo cat <<EOF > $NGX_CONF_NEW/$USER_DOMAINS
server {
    listen 80;
    server_name $USER_DOMAINS;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $USER_DOMAINS;

    # SSL certificate paths
    ssl_certificate /etc/letsencrypt/live/$USER_DOMAINS/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$USER_DOMAINS/privkey.pem;

    # Other SSL settings
    ssl_protocols TLSv1.3 TLSv1.2;
    ssl_ciphers 'TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256:ECDHE-RSA-AES256-GCM-SHA384';
    ssl_prefer_server_ciphers off;
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:10m;
    ssl_session_tickets off;

    # Additional SSL settings, including HSTS
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    
    location / {
        try_files \$uri \$uri/ =404;
        allow $SRC_IP;  # Allow the source IP of the SSH session
        allow $NODE_IP;  # Allow the source IP of the Node itself (for validation testing)
        include $SCRIPT_DIR/$NGINX_ALLOWLIST_FILE;
        deny all;

        # These three are critical to getting websockets to work
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        if (\$http_upgrade = "websocket") {
                add_header X-Upstream \$upstream_addr;
                proxy_pass  http://localhost:$VARVAL_CHAIN_WSS;
        }

        proxy_pass http://localhost:$VARVAL_CHAIN_RPC;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # Additional server configurations

    # Set Content Security Policy (CSP) header
    add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline';";

    # Enable XSS protection
    add_header X-Content-Type-Options nosniff;
    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-XSS-Protection "1; mode=block";

}
EOF
    sudo chmod 644 $NGX_CONF_NEW

    #check if symbolic link file exists in sites-enabled, if not create it
    if [ ! -f $NGX_CONF_ENABLED/$USER_DOMAINS ]; then
        sudo ln -s $NGX_CONF_NEW/$USER_DOMAINS $NGX_CONF_ENABLED/$USER_DOMAINS
    fi
    
    # Start/Reload Nginx to apply all the new configuration
    # and enable it to start at boot
    if sudo systemctl is-active --quiet nginx; then
        # Nginx is running, so reload its configuration
        sudo systemctl reload nginx
        echo "Nginx reloaded."
    else
        # Nginx is not running, so start it
        sudo systemctl start nginx
        echo "Nginx started."
    fi
    sudo systemctl enable nginx

    # Request and install a Let's Encrypt SSL/TLS certificate for Nginx
    sudo certbot --nginx  -m "$CERT_EMAIL" -n --agree-tos -d "$USER_DOMAINS"

    echo
    echo -e "${GREEN}## Setup: removed old files, and Created and enabled a new Nginx configuration files ${NC}"
    echo -e "${GREEN}## Setup: Request and install a Let's Encrypt SSL/TLS certificate for Nginx ${NC}"
    echo
    echo -e "${GREEN}## Nginx is now installed and running with a Let's Encrypt SSL/TLS certificate for the domain: ${BYELLOW} $USER_DOMAINS.${NC}"
    echo
    echo -e "${GREEN}#########################################################################${NC}"
    echo
    echo
    echo -e "${GREEN}## ${YELLOW}Setup complete."
    echo
    echo -e "${GREEN}## ${YELLOW}use file $SCRIPT_DIR/$NGINX_ALLOWLIST_FILE to add/remove IP addresses you want to allow access to your node${NC}"
    echo -e "${GREEN}## ${YELLOW}once file is edited and saved, run command ${NC}sudo nginx -s reload${YELLOW} to apply new settings ${NC}"
    echo
    echo


    FUNC_EXIT
}




FUNC_EXIT(){
    # remove the sudo timeout for USER_ID
    sudo sh -c 'rm -f /etc/sudoers.d/xahlnode_deploy'
    bash ~/.profile
    sudo -u $USER_ID sh -c 'bash ~/.profile'
	exit 0
	}


FUNC_EXIT_ERROR(){
	exit 1
	}
  

case "$1" in
        mainnet)
                _OPTION="mainnet"
                FUNC_NODE_DEPLOY
                ;;
        testnet)
                _OPTION="testnet"
                FUNC_NODE_DEPLOY
                ;;
        logrotate)
                FUNC_LOGROTATE
                ;;
        *)
                
                echo 
                echo 
                echo "Usage: $0 {function}"
                echo 
                echo "    example: " $0 mainnet""
                echo 
                echo 
                echo "where {function} is one of the following;"
                echo 
                echo "      mainnet       ==  deploys the full Mainnet node with Nginx & LetsEncrypt TLS certificate"
                echo 
                echo "      testnet       ==  deploys the full Apothem node with Nginx & LetsEncrypt TLS certificate"
                echo 
                echo "      logrotate     ==  implements the logrotate config for chain log file"
                echo
esac