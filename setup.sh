#!/bin/bash


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

FDATE=$(date +"%Y_%m_%d_%H_%M")

source xahl_node.vars


FUNC_PKG_CHECK(){

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
}


FUNC_CLONE_NODE_SETUP(){

    echo "Clone repo '$VARVAL_CHAIN_REPO' to HOME directory "
    cd ~/
    NODE_DIR=$VARVAL_CHAIN_REPO

    if [ ! -d "$NODE_DIR" ]; then
      echo "The directory '$NODE_DIR' does not exist."
        git clone https://github.com/Xahau/$NODE_DIR
    else
      echo "The directory '$NODE_DIR' exists."
    fi

    cd $NODE_DIR

    sleep 3s

    #sleep 3s
    echo 
    echo -e "${YELLOW}Starting Xahau Node install ...${NC}"
    sudo ./xahaud-install-update.sh
    sleep 2s
    echo -e "${YELLOW}Updating conf file to limit public RPC/WS to localhost ...${NC}"
    sudo sed -i -E '/^\[port_ws_public\]$/,/^\[/ {/^(ip = )0\.0\.0\.0/s/^(ip = )0\.0\.0\.0/\1127.0.0.1/}' /opt/xahaud/etc/xahaud.cfg
    sleep 2s
    
    if grep -qE "^\[port_ws_public\]$" "/opt/xahaud/etc/xahaud.cfg" && grep -q "ip = 0.0.0.0" "/opt/xahaud/etc/xahaud.cfg"; then
        sudo sed -i -E '/^\[port_ws_public\]$/,/^\[/ s/^(ip = )0\.0\.0\.0/\1127.0.0.1/' /opt/xahaud/etc/xahaud.cfg
        sleep 2
        if grep -q "ip = 127.0.0.1" "/opt/xahaud/etc/xahaud.cfg"; then
            echo -e "${GREEN}It appears that [port_ws_public] was able to update correctly."
        else
            echo -e "${RED}Something wrong with updating [port_ws_public] ip in /opt/xahaud/etc/xahaud.cfg. Attempting second time..."
            sudo sed -i -E '/^\[port_ws_public\]$/,/^\[/ s/^(ip = )0\.0\.0\.0/\1127.0.0.1/' /opt/xahaud/etc/xahaud.cfg
            sleep 2
            if grep -q "ip = 127.0.0.1" "/opt/xahaud/etc/xahaud.cfg"; then
                echo -e "${GREEN}It appears that [port_ws_public] was able to update correctly on the second attempt."
            else
                echo -e "${RED}Something wrong with updating [port_ws_public] ip in /opt/xahaud/etc/xahaud.cfg. YOU MUST DO MANUALLY!"
            fi
        fi
    else
        echo -e "${RED}Something wrong with updating [port_ws_public] ip in /opt/xahaud/etc/xahaud.cfg. YOU MUST DO MANUALLY!"
    fi

    
    sudo sed -i -E '/^\[port_rpc_public\]$/,/^\[/ {/^(ip = )0\.0\.0\.0/s/^(ip = )0\.0\.0\.0/\1127.0.0.1/}' /opt/xahaud/etc/xahaud.cfg
    sleep 2s
    
    if grep -qE "^\[port_rpc_public\]$" "/opt/xahaud/etc/xahaud.cfg" && grep -q "ip = 0.0.0.0" "/opt/xahaud/etc/xahaud.cfg"; then
        sudo sed -i -E '/^\[port_rpc_public\]$/,/^\[/ s/^(ip = )0\.0\.0\.0/\1127.0.0.1/' /opt/xahaud/etc/xahaud.cfg
        sleep 2
        if grep -q "ip = 127.0.0.1" "/opt/xahaud/etc/xahaud.cfg"; then
            echo -e "${GREEN}It appears that [port_rpc_public] was able to update correctly."
        else
            echo -e "${RED}Something wrong with updating [port_rpc_public] ip in /opt/xahaud/etc/xahaud.cfg. Attempting second time..."
            sudo sed -i -E '/^\[port_rpc_public\]$/,/^\[/ s/^(ip = )0\.0\.0\.0/\1127.0.0.1/' /opt/xahaud/etc/xahaud.cfg
            sleep 2
            if grep -q "ip = 127.0.0.1" "/opt/xahaud/etc/xahaud.cfg"; then
                echo -e "${GREEN}It appears that [port_rpc_public] was able to update correctly on the second attempt."
            else
                echo -e "${RED}Something wrong with updating [port_rpc_public] ip in /opt/xahaud/etc/xahaud.cfg. YOU MUST DO MANUALLY!"
            fi
        fi
    else
        echo -e "${RED}Something wrong with updating [port_rpc_public] ip in /opt/xahaud/etc/xahaud.cfg. YOU MUST DO MANUALLY!"
    fi

    sleep 2s
    sudo systemctl restart xahaud.service
    sleep 2s
    #FUNC_EXIT
}



FUNC_SETUP_UFW_PORTS(){
    echo 
    echo 
    echo -e "${YELLOW}#########################################################################${NC}" 
    echo 
    echo -e "${YELLOW}## Base Setup: Configure Firewall...${NC}"
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
    echo -e "${YELLOW}## Base Setup: Change UFW logging to ufw.log only${NC}"
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


    # Install Let's Encrypt Certbot
    sudo apt install certbot python3-certbot-nginx -y

    # Prompt for user domains if not provided as a variable
    if [ -z "$USER_DOMAINS" ]; then
        read -p "Enter a comma-separated list of domains, A record followed by CNAME records for RPC & WSS (e.g., server.mydomain.com,rpc.mydomain.com,wss.mydomain.com): " USER_DOMAINS
    fi


    # Prompt for user email if not provided as a variable
    if [ -z "$CERT_EMAIL" ]; then
        read -p "Enter your email address for certbot updates: " CERT_EMAIL
    fi

    echo -e "${YELLOW}$USER_DOMAINS${NC}"

    IFS=',' read -ra DOMAINS_ARRAY <<< "$USER_DOMAINS"
    A_RECORD="${DOMAINS_ARRAY[0]}"
    CNAME_RECORD1="${DOMAINS_ARRAY[1]}"
    CNAME_RECORD2="${DOMAINS_ARRAY[2]}" 

    # Start Nginx and enable it to start at boot
    sudo systemctl start nginx
    sudo systemctl enable nginx

    # Request and install a Let's Encrypt SSL/TLS certificate for Nginx
    sudo certbot --nginx  -m "$CERT_EMAIL" -n --agree-tos -d "$USER_DOMAINS"

}




FUNC_LOGROTATE(){
    # add the logrotate conf file
    # check logrotate status = cat /var/lib/logrotate/status

    echo -e "${GREEN}#########################################################################${NC}"
    echo -e "${GREEN}## ADDING LOGROTATE CONF FILE...${NC}"
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

    #USER_DOMAINS=""
    source ~/xahl-node/xahl_node.vars


    # installs default packages listed in vars file
    FUNC_PKG_CHECK;


    if [ "$_OPTION" == "mainnet" ]; then
        echo -e "${GREEN} ### Configuring node for ${BYELLOW}$_OPTION${GREEN}..  ###${NC}"

        VARVAL_CHAIN_NAME=$_OPTION
        VARVAL_CHAIN_RPC=$NGX_MAINNET_RPC
        VARVAL_CHAIN_WSS=$NGX_MAINNET_WSS
        VARVAL_CHAIN_REPO="mainnet-docker"
        VARVAL_CHAIN_PEER=$XAHL_MAINNET_PEER

    elif [ "$_OPTION" == "testnet" ]; then
        echo -e "${GREEN} ### Configuring node for ${BYELLOW}$_OPTION${GREEN}..  ###${NC}"

        VARVAL_CHAIN_NAME=$_OPTION
        VARVAL_CHAIN_RPC=$NGX_TESTNET_RPC
        VARVAL_CHAIN_WSS=$NGX_TESTNET_WSS
        VARVAL_CHAIN_REPO="Xahau-Testnet-Docker"
        VARVAL_CHAIN_PEER=$XAHL_TESTNET_PEER
    fi


    VARVAL_NODE_NAME="xahl_node_$(hostname -s)"
    echo -e "${BYELLOW}  || Node name is : $VARVAL_NODE_NAME ||"
    #VARVAL_CHAIN_RPC=$NGX_RPC
    echo -e "${BYELLOW}  || Node RPC port is : $VARVAL_CHAIN_RPC ||"
    #VARVAL_CHAIN_WSS=$NGX_WSS
    echo -e "${BYELLOW}  || Node WSS port is : $VARVAL_CHAIN_WSS  ||${NC}"
    sleep 3s

    # Install Nginx - Check if NGINX  is installed
    nginx -v 
    if [ $? != 0 ]; then
        echo -e "${RED} ## NGINX is not installed. Installing now.${NC}"
        apt update -y
        sudo apt install nginx -y
    else
        # If NGINX is already installed.. skipping
        echo "NGINX is already installed. Skipping"
    fi


    # Check if UFW (Uncomplicated Firewall) is installed
    sudo ufw version
    if [ $? = 0 ]; then
        # If UFW is installed, allow Nginx through the firewall
        sudo ufw allow 'Nginx Full'
    else
        echo "UFW is not installed. Skipping firewall configuration."
    fi



    # Update the package list and upgrade the system
    #apt update -y
    #apt upgrade -y

    #Xahau Node setup
    FUNC_CLONE_NODE_SETUP;

    FUNC_CERTBOT;

    # Firewall config
    FUNC_SETUP_UFW_PORTS;
    FUNC_ENABLE_UFW;

    #Rotate logs on regular basis
    FUNC_LOGROTATE;


    # Get the source IP of the current SSH session
    SRC_IP=$(echo $SSH_CONNECTION | awk '{print $1}')
    NODE_IP=$(curl -s ipinfo.io/ip)
    #DCKR_HOST_IP=$(sudo docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $VARVAL_CHAIN_NAME_xinfinnetwork_1)

    # Create a new Nginx configuration file with the user-provided domain and test HTML page


    echo
    echo -e "${GREEN}#########################################################################${NC}"
    echo -e "${YELLOW}## Setup: Creating a new Nginx configuration file ...${NC}"
    echo
     
    sudo touch $NGX_CONF_NEW
    sudo chmod 666 $NGX_CONF_NEW 
    
    sudo cat <<EOF > $NGX_CONF_NEW
server {
    listen 80;
    server_name $A_RECORD $CNAME_RECORD1 $CNAME_RECORD2;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $CNAME_RECORD1;

    # SSL certificate paths
    ssl_certificate /etc/letsencrypt/live/$A_RECORD/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$A_RECORD/privkey.pem;

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
        try_files $uri $uri/ =404;
        allow $SRC_IP;  # Allow the source IP of the SSH session
        allow $NODE_IP;  # Allow the source IP of the Node itself (for validation testing)
        deny all;
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


server {
    listen 443 ssl http2;
    server_name $CNAME_RECORD2;

    # SSL certificate paths
    ssl_certificate /etc/letsencrypt/live/$A_RECORD/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$A_RECORD/privkey.pem;

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
        try_files $uri $uri/ =404;
        allow $SRC_IP;  # Allow the source IP of the SSH session
        allow $NODE_IP;  # Allow the source IP of the Node itself (for validation testing)
        deny all;
        proxy_pass http://localhost:$VARVAL_CHAIN_WSS;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache off;
        proxy_buffering off;

        # These three are critical to getting websockets to work
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
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

    #check if symbolic link file exists in sites-enabled
    if [ ! -f /etc/nginx/sites-enabled/xahau ]; then
        sudo ln -s $NGX_CONF_NEW /etc/nginx/sites-enabled/
    fi
    
    #delete default symbolic link file if it exists in sites-enabled
    if [  -f /etc/nginx/sites-enabled/default ]; then
        sudo rm -f $NGX_CONF_OLD
    fi   
    
    # Reload Nginx to apply the new configuration
    sudo systemctl reload nginx

    # Provide some basic instructions

    echo
    echo -e "${GREEN}#########################################################################${NC}"
    echo -e "${YELLOW}## Setup: Created a new Nginx configuration file ...${NC}"
    echo
    echo -e "${YELLOW}##  Nginx is now installed and running with a Let's Encrypt SSL/TLS certificate for the domain $A_RECORD.${NC}"
    echo
    echo
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