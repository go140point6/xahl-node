#!/bin/bash

# *** SETUP SOME VARIABLES THAT THIS SCRiPT NEEDS ***

# Get current user id and store as var
USER_ID=$(getent passwd $EUID | cut -d: -f1)

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
    echo -e "${GREEN}## Check/install necessary updates, and Packages... ${NC}"
    echo     

    # update and upgrade the system
    if [ -z "$INSTALL_UPDATES" ]; then
        read -p "do you want to check, and install OS updates? Enter true or false: " INSTALL_UPDATES
        sed -i "s/^INSTALL_UPDATES=.*/INSTALL_UPDATES=\"$INSTALL_UPDATES\"/" $SCRIPT_DIR/xahl_node.vars
    fi
    if [ "$INSTALL_UPDATES" == "true" ]; then
      sudo apt update -y && sudo apt upgrade -y
    fi

    echo -e "${GREEN}## cycle through packages in vars file, and install... ${NC}"
    echo     
    # cycle through packages in vars file, and install
    for i in "${SYS_PACKAGES[@]}"
    do
        hash $i &> /dev/null
        if [ $? -eq 1 ]; then
            echo >&2 "package "$i" not found. installing...."
            sudo apt install -y "$i"
        else
            echo "packages "$i" exist, proceeding to next...."
        fi
    done
    echo -e "${GREEN}## ALL PACKAGES INSTALLED.${NC}"
    echo 
    echo -e "${GREEN}#########################################################################${NC}"
    echo
    sleep 2s
}


FUNC_CLONE_NODE_SETUP(){
    echo
    echo -e "${GREEN}#########################################################################${NC}"
    echo
    echo -e "${GREEN}## ${YELLOW}Starting Xahau Node install ...${NC}"
    echo
    echo -e "Cloning repo https://github.com/Xahau/$VARVAL_CHAIN_REPO' ${NC}"
    
    cd ~/
    if [ ! -d "$VARVAL_CHAIN_REPO" ]; then
        echo "The directory '$VARVAL_CHAIN_REPO' does not exist."
        git clone https://github.com/Xahau/$VARVAL_CHAIN_REPO
    else
        echo "The directory '$VARVAL_CHAIN_REPO' exists, no need to re-create.."
    fi

    cd $VARVAL_CHAIN_REPO
    sudo ./xahaud-install-update.sh

    echo
    echo -e "Updating .cfg file to limit public RPC/WS to localhost ...${NC}"

    sudo sed -i -E '/^\[port_ws_public\]$/,/^\[/ {/^(ip = )0\.0\.0\.0/s/^(ip = )0\.0\.0\.0/\1127.0.0.1/}' /opt/xahaud/etc/xahaud.cfg    
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

    
    echo
    echo -e "Updating node size in .cfg file  ...${NC}"
    echo
    if [ "$XAHAU_NODE_SIZE" != "tiny" ] && [ "$XAHAU_NODE_SIZE" != "medium" ] && [ "$XAHAU_NODE_SIZE" != "huge" ]; then
        echo -e "${RED}XAHAU_NODE_SIZE not set in $SCRIPT_DIR/xahl_node.vars file. =$XAHAU_NODE_SIZE"
        echo "Please choose an option:"
        echo "1. tiny = less than 8G RAM"
        echo "2. medium = 8-16G RAM"
        echo "3. huge = 32G+ RAM"
        read -p "Enter your choice [1-3]: " choice
        
        case $choice in
            1) 
                XAHAU_NODE_SIZE="tiny"
                ;;
            2) 
                XAHAU_NODE_SIZE="medium"
                ;;
            3) 
                XAHAU_NODE_SIZE="huge"
                ;;
            *) 
                echo "Invalid option. Exiting."
                FUNC_EXIT
                ;;
        esac
        sed -i "s/^XAHAU_NODE_SIZE=.*/XAHAU_NODE_SIZE=\"$XAHAU_NODE_SIZE\"/" $SCRIPT_DIR/xahl_node.vars
    fi
    
    if [ "$XAHAU_NODE_SIZE" == "tiny" ]; then
        XAHAU_LEDGER_HISTORY=$TINY_LEDGER_HISTORY
        XAHAU_ONLINE_DELETE=$TINY_LEDGER_DELETE
    fi
    if [ "$XAHAU_NODE_SIZE" == "medium" ]; then
        XAHAU_LEDGER_HISTORY=$MEDIUM_LEDGER_HISTORY
        XAHAU_ONLINE_DELETE=$MEDIUM_LEDGER_DELETE
    fi
    if [ "$XAHAU_NODE_SIZE" == "huge" ]; then
        XAHAU_LEDGER_HISTORY="full"
        XAHAU_ONLINE_DELETE=""
    fi
    echo "."
    sed -i "/^\[node_size\]/!b;n;c$XAHAU_NODE_SIZE" /opt/xahaud/etc/xahaud.cfg
    echo ".."
    sed -i -e 's/^#\{0,1\}\(\[ledger_history\]\)/\1/; /^\[ledger_history\]/ { n; s/.*/'"$XAHAU_LEDGER_HISTORY"'/; }' /opt/xahaud/etc/xahaud.cfg   
    echo "..."
    grep -q 'online_delete' /opt/xahaud/etc/xahaud.cfg || sed -i '/^online_delete.*/!{ /\[node_db\]/ s/$/\nonline_delete='"$XAHAU_ONLINE_DELETE"'/ }' /opt/xahaud/etc/xahaud.cfg
    echo "...."
    sed -i "s/online_delete=.*/online_delete=$XAHAU_ONLINE_DELETE/" /opt/xahaud/etc/xahaud.cfg
    echo "....."

    # restart xahau for changes to take effect
    sudo systemctl restart xahaud.service

    echo 
    echo -e "config changed to ${BYELLOW}$XAHAU_NODE_SIZE${NC} with ledger_history=${BYELLOW}$XAHAU_LEDGER_HISTORY${NC} online_delete=${BYELLOW}$XAHAU_ONLINE_DELETE ${NC}"
    echo
    echo -e "${GREEN}## Finished Xahau Node install ...${NC}"
    echo
    sleep 4s
}



FUNC_SETUP_UFW_PORTS(){
    echo 
    echo -e "${GREEN}#########################################################################${NC}" 
    echo 
    echo -e "${GREEN}## ${YELLOW}Setup: Configure Firewall...${NC}"
    echo 
    echo "allowing Nginx through the firewall."
    sudo ufw allow 'Nginx Full'

    # Get current SSH and xahau node port number, and unblock them
    CPORT=$(sudo ss -tlpn | grep sshd | awk '{print$4}' | cut -d ':' -f 2 -s)
    echo -e "current SSH port number detected as: ${BYELLOW}$CPORT${NC}"
    echo -e "current Xahau Node port number detected as: ${BYELLOW}$CPORT${NC}"
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
    echo -e "${GREEN}## ${YELLOW}Setup: (re)Enable Firewall...${NC}"
    echo 
    sudo systemctl start ufw && sudo systemctl status ufw
    echo "y" | sudo ufw enable
    #sudo ufw enable
    sudo ufw status verbose
    sleep 2s
}



FUNC_CERTBOT(){

    echo
    echo -e "${GREEN}#########################################################################${NC}"
    echo
    echo -e "${GREEN}## ${YELLOW}CertBot install and setup ...${NC}"
    echo

    # Install Let's Encrypt Certbot
    sudo apt install certbot python3-certbot-nginx -y

    # Prompt for user email if not provided as a variable
    if [ -z "$CERT_EMAIL" ]; then
        read -p "Enter your email address for certbot updates: " CERT_EMAIL
        sed -i "s/^CERT_EMAIL=.*/CERT_EMAIL=\"$CERT_EMAIL\"/" $SCRIPT_DIR/xahl_node.vars
        echo
    fi

    # Request and install a Let's Encrypt SSL/TLS certificate for Nginx
    echo -e "${GREEN}## ${YELLOW}Setup: Request and install a Lets Encrypt SSL/TLS certificate for domain: ${BYELLOW} $USER_DOMAINS${NC}"
    sudo certbot --nginx  -m "$CERT_EMAIL" -n --agree-tos -d "$USER_DOMAINS"

    echo
    echo -e "${GREEN}#########################################################################${NC}"
    sleep 4s

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


FUNC_ALLOWLIST_CHECK(){
    echo
    echo -e "${GREEN}#########################################################################${NC}"
    echo
    echo -e "${GREEN}## ${YELLOW}Setup: checking/setting up IPs, ALLOWLIST file...${NC}"
    echo

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
    LOCAL_IP=$(hostname -I | awk '{print $1}')
    if [ -z "$LOCAL_IP" ]; then
        LOCAL_IP="127.0.0.1"
    fi

    if grep -q -e "allow $SRC_IP;  # Detected IP of the SSH session" -e "allow $LOCAL_IP; # LocalIP of server" -e "allow $NODE_IP;  # ExternalIP of the Node itself" "$SCRIPT_DIR/nginx_allowlist.conf"; then
        # All three default IPs were found
        echo "All default IPs already found in Allowlist file"
        echo
    else
        echo "adding some default IPs..."
        if ! grep -q "allow $SRC_IP;  # Detected IP of the SSH session" "$SCRIPT_DIR/nginx_allowlist.conf"; then
            echo "allow $SRC_IP;  # Detected IP of the SSH session" >> $SCRIPT_DIR/nginx_allowlist.conf
            echo "added IP $SRC_IP;  # Detected IP of the SSH session"
        fi
        if ! grep -q "allow $LOCAL_IP; # Local IP of server" "$SCRIPT_DIR/nginx_allowlist.conf"; then
            echo "allow $LOCAL_IP; # Local IP of server" >> $SCRIPT_DIR/nginx_allowlist.conf
            echo "added IP $LOCAL_IP; # Local IP of the server"
        fi
        if ! grep -q "allow $NODE_IP;  # ExternalIP of the Node itself" "$SCRIPT_DIR/nginx_allowlist.conf"; then
            echo "allow $NODE_IP;  # ExternalIP of the Node itself" >> $SCRIPT_DIR/nginx_allowlist.conf
            echo "added IP $NODE_IP;  # ExternalIP of the Node itself"
        fi
        echo
        echo "default IPs added to Allowlist file"
        echo
    fi
    echo -e "${GREEN}## ${YELLOW}Add more IPs to the Allowlist, or press enter to skip... ${NC}"
    echo
    while true; do
        read -p "Enter an IP address : " user_ip

        # Validate the input using regex (IPv4 format)
        if [[ $user_ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
            echo -e "${GREEN}IP address: ${YELLOW}$user_ip added to Allow list. ${NC}"
            echo -e "allow $user_ip;" >> $SCRIPT_DIR/nginx_allowlist.conf
        else
            if [ -z "$user_ip" ]; then
                break
            else
                echo -e "${RED}Invalid IP address. Please try again. ${NC}"
            fi
        fi
    done
    sleep 2s
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

    # installs updates, and default packages listed in vars file
    FUNC_PKG_CHECK;

    if [ "$VARVAL_CHAIN_NAME" != "mainnet" ] && [ "$VARVAL_CHAIN_NAME" != "testnet" ] && [ "$VARVAL_CHAIN_NAME" != "logrotate" ]; then
        echo -e "${RED}VARVAL_CHAIN_NAME not set in $SCRIPT_DIR/xahl_node.vars"
        echo "Please choose an option:"
        echo "1. Mainnet = configures and deploys/updates xahau node for Mainnet"
        echo "2. Testnet = configures and deploys/updates xahau node for Testnet"
        echo "3. Logrotate = implements the logrotate config for chain log file"
        read -p "Enter your choice [1-3]: " choice
        
        case $choice in
            1) 
                VARVAL_CHAIN_NAME="mainnet"
                ;;
            2) 
                VARVAL_CHAIN_NAME="testnet"
                ;;
            3) 
                VARVAL_CHAIN_NAME="logrotate"
                ;;
            *) 
                echo "Invalid option. Exiting."
                FUNC_EXIT
                ;;
        esac
        sed -i "s/^VARVAL_CHAIN_NAME=.*/VARVAL_CHAIN_NAME=\"$VARVAL_CHAIN_NAME\"/" $SCRIPT_DIR/xahl_node.vars
    fi

    if [ "$VARVAL_CHAIN_NAME" == "mainnet" ]; then
        echo -e "${GREEN}### Configuring node for ${BYELLOW}$_OPTION${GREEN}... ${NC}"
        VARVAL_CHAIN_RPC=$NGX_MAINNET_RPC
        VARVAL_CHAIN_WSS=$NGX_MAINNET_WSS
        VARVAL_CHAIN_REPO="mainnet-docker"
        VARVAL_CHAIN_PEER=$XAHL_MAINNET_PEER

    elif [ "$VARVAL_CHAIN_NAME" == "testnet" ]; then
        echo -e "${GREEN}### Configuring node for ${BYELLOW}$_OPTION${GREEN}... ${NC}"
        VARVAL_CHAIN_RPC=$NGX_TESTNET_RPC
        VARVAL_CHAIN_WSS=$NGX_TESTNET_WSS
        VARVAL_CHAIN_REPO="Xahau-Testnet-Docker"
        VARVAL_CHAIN_PEER=$XAHL_TESTNET_PEER

    elif [ "$VARVAL_CHAIN_NAME" == "logrotate" ]; then
        FUNC_LOGROTATE
        FUNC_EXIT
    fi

    VARVAL_NODE_NAME="xahl_node_$(hostname -s)"
    echo -e "|| Node name is :${BYELLOW} $VARVAL_NODE_NAME ${NC}"
    #VARVAL_CHAIN_RPC=$NGX_RPC
    echo -e "|| Node RPC port is :${BYELLOW} $VARVAL_CHAIN_RPC ${NC}"
    #VARVAL_CHAIN_WSS=$NGX_WSS
    echo -e "|| Node WSS port is :${BYELLOW} $VARVAL_CHAIN_WSS ${NC}"
    
    
    # Check and Install Nginx
    echo
    echo -e "${GREEN}#########################################################################${NC}"
    echo
    echo -e "${GREEN}## ${YELLOW}Checking for NGINX... ${NC}"
    nginx -v 
    if [ $? != 0 ]; then
        echo -e "${GREEN}## ${YELLOW}NGINX is not installed. Installing now...${NC}"
        apt update -y
        sudo apt install nginx -y
    else
        # If NGINX is already installed.. skipping
        echo -e "${GREEN}## NGINX is already installed. Skipping ${NC}"
    fi



    # Check if UFW is installed
    echo
    echo -e "${GREEN}#########################################################################${NC}"
    echo 
    echo -e "${GREEN}## ${YELLOW}Setup: Checking UFW... ${NC}"
    echo
    sudo ufw version
    if [ $? = 0 ]; then
        echo -e "${GREEN}UFW is ALREADY installed ${NC}"
        echo
        # Setup UFW
        FUNC_SETUP_UFW_PORTS;
        FUNC_ENABLE_UFW;
    else
        echo
        echo -e "${GREEN}## ${YELLOW}UFW is not installed, checking config option... ${NC}"
        echo
        
        if [ -z "$INSTALL_UFW" ]; then
            read -p "Do you want to install UFW (Uncomplicated Firewall) ? enter true or false:" INSTALL_UFW
            sed -i "s/^INSTALL_UFW=.*/INSTALL_UFW=\"$INSTALL_UFW\"/" $SCRIPT_DIR/xahl_node.vars
        fi
        if [ "$INSTALL_UFW" == "true" ]; then
            echo
            echo -e "${GREEN}## ${YELLOW}Setup: Installing UFW... ${NC}"
            echo
            sudo apt install ufw
            FUNC_SETUP_UFW_PORTS;
            FUNC_ENABLE_UFW;
        fi
    fi
    

    # Xahau Node setup
    FUNC_CLONE_NODE_SETUP;

    # Rotate logs on regular basis
    FUNC_LOGROTATE;

    # Add/check AllowList
    FUNC_ALLOWLIST_CHECK;

    # Prompt for user domains if not provided as a variable
    if [ -z "$USER_DOMAINS" ]; then
        read -p "Enter your servers domain (e.g., xahaunode.mydomain.com): " USER_DOMAINS
        sed -i "s/^USER_DOMAINS=.*/USER_DOMAINS=\"$USER_DOMAINS\"/" $SCRIPT_DIR/xahl_node.vars
    fi

    # check/install CERTBOT (for SSL)
    echo
    echo -e "${GREEN}#########################################################################${NC}"
    echo 
    echo -e "${GREEN}## ${YELLOW}Setup: Checking CERTBOT options... ${NC}"
    echo

    if [ -z "$INSTALL_CERTBOT_SSL" ]; then
        read -p "Do you want to use install CERTBOT and use SSL? : True or false?" INSTALL_CERTBOT_SSL
        sed -i "s/^INSTALL_CERTBOT_SSL=.*/INSTALL_CERTBOT_SSL=\"$INSTALL_CERTBOT_SSL\"/" $SCRIPT_DIR/xahl_node.vars
    fi
    if [ "$INSTALL_CERTBOT_SSL" == "true" ]; then
        FUNC_CERTBOT;
    else
        echo -e "${GREEN}## ${YELLOW}Setup: Skipping CERTBOT install... ${NC}"
        echo
        echo
    fi


    # Create a new Nginx configuration file with the user-provided domain....
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
        sudo rm -f $NGX_CONF_ENABLED/default
    fi
    if [  -f $NGX_CONF_ENABLED/xahau ]; then
        sudo rm -f $NGX_CONF_NEW/xahau
    fi 
    if [  -f $NGX_CONF_NEW/$USER_DOMAINS ]; then
        sudo rm -f $NGX_CONF_NEW/$USER_DOMAINS
    fi   
     
    sudo touch $NGX_CONF_NEW/$USER_DOMAINS
    sudo chmod 666 $NGX_CONF_NEW/$USER_DOMAINS 
    
    if [ "$INSTALL_CERTBOT_SSL" == "true" ]; then
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

    else
    sudo cat <<EOF > $NGX_CONF_NEW/$USER_DOMAINS
server {
    listen 80;
    server_name $USER_DOMAINS;

    # SSL certificate paths
    #ssl_certificate /etc/letsencrypt/live/$USER_DOMAINS/fullchain.pem;
    #ssl_certificate_key /etc/letsencrypt/live/$USER_DOMAINS/privkey.pem;

    # Other SSL settings
    #ssl_protocols TLSv1.3 TLSv1.2;
    #ssl_ciphers 'TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256:ECDHE-RSA-AES256-GCM-SHA384';
    #ssl_prefer_server_ciphers off;
    #ssl_session_timeout 1d;
    #ssl_session_cache shared:SSL:10m;
    #ssl_session_tickets off;

    # Additional SSL settings, including HSTS
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    
    location / {
        try_files \$uri \$uri/ =404;
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
    fi

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

    echo
    echo -e "${GREEN}#########################################################################${NC}"
    echo
    echo -e "${GREEN}## Setup: removed old files, and Created and enabled a new Nginx configuration files ${NC}"
    echo
    echo -e "${NC}Nginx is now installed and running at Local IP: ${YELLOW}$LOCAL_IP${NC} listening for the domain: ${YELLOW}$USER_DOMAINS.${NC}"
    echo
    echo -e "${GREEN}#########################################################################${NC}"
    echo
    echo -e "${NC}if all went well, your Xahau Node will now be up and running; ${NC}"
    echo
    echo -e "${NC}locally, at websocket ${BYELLOW}ws://$LOCAL_IP${NC} or RPC/API ${BYELLOW}http://$LOCAL_IP ${NC}"
    echo
    echo -e "${NC}externally, at websocket ${BYELLOW}wss://$USER_DOMAINS${NC} or RPC/API ${BYELLOW}https://$USER_DOMAINS ${NC}"
    echo
    echo -e "use file ${BYELLOW}'$SCRIPT_DIR/$NGINX_ALLOWLIST_FILE'${NC} to add/remove IP addresses you want to allow access to your node${NC}"
    echo -e "once file is edited and saved, run command ${BYELLOW}sudo nginx -s reload${NC} to apply new settings ${NC}"
    echo
    echo -e "${NC}you can use command ${YELLOW}xahaud server_info${NC} to get info direct from the server"
    echo
    echo -e "${GREEN}## ${YELLOW}Setup complete.${NC}"
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
  
FUNC_NODE_DEPLOY