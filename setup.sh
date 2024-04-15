#!/bin/bash

# *** check and setup permissions ***

# Get current user id and store as var
USER_ID=$(getent passwd $EUID | cut -d: -f1)

if [ -n "$1" ] && id "$1" &>/dev/null; then 
    ORIGINAL_USER_ID=$1
    echo "$USER_ID now running script for $ORIGINAL_USER_ID"
    echo
fi

# Authenticate sudo perms before script execution to avoid timeouts or errors
echo "checking privileges..."
if sudo -l > /dev/null 2>&1; then
    echo "privleges all good..."
    echo "just going to extend the timeout period, so sudo privleges do not timeout while installing.."
    echo
    # extend sudo timeout for USER_ID to an hour, instead of default 5min
    echo "Defaults:$USER_ID timestamp_timeout=120" > /tmp/xahlsudotmp
    # add visudo check ? 
    sudo sh -c 'cat /tmp/xahlsudotmp > /etc/sudoers.d/xahlnode_deploy'

else
    echo
    echo "this user ($USER_ID) does not have full sudo privilages, going to try root user..."
    if su -c "./setup.sh $USER_ID" root; then
        exit
    else
        if [ $? -eq 1 ]; then
          echo
          echo "Incorrect password for root user."
        else
          echo 
          echo "Failed to execute the script with "root" user ID."
        fi
        # Prompt the user to enter a different user ID
        read -p "${BLUE}Enter a user ID that has full sudo privledges :${NC}" SUDO_ID

        # Attempt to run the command with the specified user ID
        if su -c "./setup.sh $USER_ID" $SUDO_ID; then
            exit
        else
            echo
            echo "$USER_ID re-run script with correct sudo priveledges..."
            echo
            exit
        fi
    fi
fi


# *** SETUP SOME VARIABLES THAT THIS SCRiPT NEEDS ***

# Set Colour Vars
GREEN='\033[0;32m'
#RED='\033[0;31m'
RED='\033[0;91m'  # Intense Red
YELLOW='\033[0;33m'
BYELLOW='\033[1;33m'
BLUE='\033[0;94m'
NC='\033[0m' # No Color

# Get the absolute path of the script directory
# and import variables
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
source $SCRIPT_DIR/xahl_node.vars
touch $SCRIPT_DIR/.env
source $SCRIPT_DIR/.env

#setup date
FDATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")


FUNC_PKG_CHECK(){
    echo
    echo -e "${GREEN}#########################################################################${NC}"
    echo
    echo -e "${GREEN}## Check/install necessary updates, and Packages... ${NC}"
    echo     

    # update and upgrade the system
    if [ -z "$INSTALL_UPDATES" ]; then
        read -p "${BLUE}do you want to check, and install OS updates? Enter true or false: ${NC}" INSTALL_UPDATES
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
    echo -e "${GREEN}## ${YELLOW}Starting Xahau Node install... ${NC}"
    echo
    echo -e "Cloning repo https://github.com/Xahau/$VARVAL_CHAIN_REPO' ${NC}"
    
    cd $SCRIPT_DIR
    if [ ! -d "$VARVAL_CHAIN_REPO" ]; then
        echo "Creating directory '$SCRIPT_DIR/$VARVAL_CHAIN_REPO' to use for xahaud instalilation..."
        git clone https://github.com/Xahau/$VARVAL_CHAIN_REPO
    else
        echo "directory '$SCRIPT_DIR/$VARVAL_CHAIN_REPO' exists, no need to re-create, updating instead..."
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
        echo -e "${BLUE}XAHAU_NODE_SIZE not set in $SCRIPT_DIR/xahl_node.vars file. =$XAHAU_NODE_SIZE"
        echo "Please choose an option:"
        echo "1. tiny = less than 8G-RAM, 50GB-HDD"
        echo "2. medium = 8-16G RAM, 250GBB-HDD"
        echo "3. huge = 32G+ RAM, no limit on HDD ${NC}"
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
    sudo sed -i "/^\[node_size\]/!b;n;c$XAHAU_NODE_SIZE" /opt/xahaud/etc/xahaud.cfg
    echo ".."
    sudo sed -i -e 's/^#\{0,1\}\(\[ledger_history\]\)/\1/; /^\[ledger_history\]/ { n; s/.*/'"$XAHAU_LEDGER_HISTORY"'/; }' /opt/xahaud/etc/xahaud.cfg   
    echo "..."
    sudo grep -q 'online_delete' /opt/xahaud/etc/xahaud.cfg || sed -i '/^online_delete.*/!{ /\[node_db\]/ s/$/\nonline_delete='"$XAHAU_ONLINE_DELETE"'/ }' /opt/xahaud/etc/xahaud.cfg
    echo "...."
    sudo sed -i "s/online_delete=.*/online_delete=$XAHAU_ONLINE_DELETE/" /opt/xahaud/etc/xahaud.cfg
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
        echo
        read -p "${BLUE}Enter your email address for certbot updates: ${NC}" CERT_EMAIL
        sudo sed -i "s/^CERT_EMAIL=.*/CERT_EMAIL=\"$CERT_EMAIL\"/" $SCRIPT_DIR/.env
        echo
    fi

    # Request and install a Let's Encrypt SSL/TLS certificate for Nginx
    echo -e "${GREEN}## ${YELLOW}Setup: Request and install a Lets Encrypt SSL/TLS certificate for domain: ${BYELLOW} $USER_DOMAIN${NC}"
    sudo certbot --nginx  -m "$CERT_EMAIL" -n --agree-tos -d "$USER_DOMAIN"

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

    # Prompt for Chain if not provided as a variable
    if [ -z "$VARVAL_CHAIN_NAME" ]; then

        while true; do
         read -p "${BLUE}Enter which chain your node is deployed on (e.g. mainnet or testnet): ${NC}" _input

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

        cat <<EOF > /tmp/tmpxahau-logs
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

    sudo sh -c 'cat /tmp/tmpxahau-logs > /etc/logrotate.d/xahau-logs'

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
        echo "adding default IPs..."
        if ! grep -q "allow $SRC_IP;  # Detected IP of the SSH session" "$SCRIPT_DIR/nginx_allowlist.conf"; then
            echo "allow $SRC_IP;  # Detected IP of the SSH session" >> $SCRIPT_DIR/nginx_allowlist.conf
            echo "added IP $SRC_IP;  # Detected IP of the SSH session"
        else
            echo "SSH session IP, $SRC_IP, already in list."
        fi
        if ! grep -q "allow $LOCAL_IP; # Local IP of server" "$SCRIPT_DIR/nginx_allowlist.conf"; then
            echo "allow $LOCAL_IP; # Local IP of server" >> $SCRIPT_DIR/nginx_allowlist.conf
            echo "added IP $LOCAL_IP; # Local IP of the server"
        else
            echo "Local IP of the server, $LOCAL_IP, already in list."
        fi
        if ! grep -q "allow $NODE_IP;  # ExternalIP of the Node itself" "$SCRIPT_DIR/nginx_allowlist.conf"; then
            echo "allow $NODE_IP;  # ExternalIP of the Node itself" >> $SCRIPT_DIR/nginx_allowlist.conf
            echo "added IP $NODE_IP;  # ExternalIP of the Node itself"
        else
            echo "External IP of the Node itself, $NODE_IP, already in list."
        fi
        echo
        echo
    fi
    echo -e "${GREEN}## ${YELLOW}Add additional IPs to the Allowlist, or press enter to skip... ${NC}"
    echo
    while true; do
        read -p "${BLUE}Enter additional IP address here (one at a time for example 10.0.0.20): " user_ip

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

FUNC_INSTALL_LANDINGPAGE(){
    echo
    echo -e "${GREEN}#########################################################################${NC}"
    echo 
    echo -e "${GREEN}## ${YELLOW}Setup: Installing Landing page... ${NC}"
    echo

    if [ -z "$INSTALL_LANDINGPAGE" ]; then
        read -p "${BLUE}Do you want to (re)install the landng webpage?: true or false?${NC}" INSTALL_LANDINGPAGE
        sudo sed -i "s/^INSTALL_LANDINGPAGE=.*/INSTALL_LANDINGPAGE=\"$INSTALL_LANDINGPAGE\"/" $SCRIPT_DIR/xahl_node.vars
    fi
    if [ "$INSTALL_LANDINGPAGE" == "true" ]; then
        
        sudo mkdir -p /home/www
        echo "created /home/www directory for webfiles, now re-installing webpage"

        if [  -f /home/www/index.html ]; then
            sudo rm -f /home/www/index.html
        fi
        sudo cat <<EOF > /home/www/index.html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Xahau Node</title>
</head>
<style>
    body {
        background-color: #121212;
        color: #ffffff;
        font-family: Arial, sans-serif;
        padding: 20px;
        margin: 2;
        text-align: center;
    }

    h1 {
        font-size: 28px;
        margin-bottom: 20px;
        text-shadow: 2px 2px 4px rgba(0, 0, 0, 0.5);
    }

    .serverinfo {
        max-width: 300px;
        margin: 0 auto;
        margin-bottom: 20px;
        padding: 20px;
        border: 2px solid #ffffff;
        border-radius: 10px;
        text-align: left; /* Align content to the left */
    }

    #rawoutput {
        background-color: #1a1a1a;
        padding: 20px;
        border-radius: 10px;
        margin-top: 10px;
        margin: 0 auto;
        max-width: 600px;
        color: #ffffff;
        font-family: Arial, sans-serif;
        font-size: 14px;
        white-space: pre-wrap;
        overflow: auto; /* Add scrollbars if needed */
        text-align: left; /* Align content to the left */
    }
</style>
<body>
    <h1>Xahau Node Landing Page</h1>

    <div class="serverinfo">
        <h1>Server Info</h1>
        <p>Status: <span id="status"></span></p>
        <p>ServerStatus: <span id="serverstatus"></span></p>
        <p>Build Version: <span id="buildVersion"></span></p>
        <p>Connected Websockets: <span id="connections"></span></p>
        <p>Connected peers: <span id="peers"></span></p>
        <p>Current Ledger: <span id="currentLedger"></span></p>
        <p>Complete Ledgers: <span id="completeLedgers"></span></p>
        <p>Node Size: <span id="nodeSize"></span></p>
        <p>UpTime: <span id="uptime"></span></p>
        <p>Last Refresh: <span id="time"></span></p>
    </div>

    <pre id="rawoutput"><h1>Raw .toml file</h1><span id="rawTOML"></spam></pre>

    <pre id="rawoutput"><h1>xahaud server_info</h1><span id="serverInfo"></spam></pre>

    <script>
        const dataToSend = {"method":"server_info"};
        fetch('https://$USER_DOMAIN', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(dataToSend)
        })
            .then(response => {
                return response.json();
            })
            .then(serverInfo => {
                const formattedJson = JSON.stringify(serverInfo, null, 2);
                document.getElementById('serverInfo').textContent = formattedJson;
                document.getElementById('status').textContent = serverInfo.result.status;
                document.getElementById('buildVersion').textContent = serverInfo.result.info.build_version;
                document.getElementById('currentLedger').textContent = serverInfo.result.info.validated_ledger.seq;
                document.getElementById('completeLedgers').textContent = serverInfo.result.info.complete_ledgers;
                const uptimeInSeconds = serverInfo.result.info.uptime;
                const days = Math.floor(uptimeInSeconds / 86400);
                const hours = Math.floor((uptimeInSeconds % 86400) / 3600);
                const minutes = Math.floor((uptimeInSeconds % 3600) / 60);
                const formattedUptime = \`\${days} Days, \${hours.toString().padStart(2, '0')} Hours, and \${minutes.toString().padStart(2, '0')} Mins\`;
                document.getElementById('uptime').textContent = formattedUptime;
                document.getElementById('time').textContent = serverInfo.result.info.time;
            })
            .catch(error => {
                console.error('Error fetching server info:', error);
                document.getElementById('status').textContent = "failed, server could be down";
                document.getElementById('status').style.color = "red";
            });
    </script>
</body>
</html>
EOF

        sudo mkdir -p /home/www/error
        echo "created /home/www/error directory for blocked page, re-installing webpage"
        if [  -f /home/www/error/custom_403.html ]; then
            sudo rm -r /home/www/error/custom_403.html
        fi        
        sudo cat <<EOF > /home/www/error/custom_403.html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Xahau Node</title>
</head>
<style>
body {
    background-color: #121212;
    color: #ffffff;
    font-family: Arial, sans-serif;
    padding: 20px;
    margin: 2;
    text-align: center;
}

h1 {
    font-size: 28px;
    margin-bottom: 20px;
    text-shadow: 2px 2px 4px rgba(0, 0, 0, 0.5);
}

.serverinfo {
    max-width: 300px;
    margin: 0 auto;
    margin-bottom: 20px;
    padding: 20px;
    border: 2px solid #ffffff;
    border-radius: 10px;
    text-align: left; /* Align content to the left */
}

#rawoutput {
    background-color: #1a1a1a;
    padding: 20px;
    border-radius: 10px;
    margin-top: 10px;
    margin: 0 auto;
    max-width: 600px;
    color: #ffffff;
    font-family: Arial, sans-serif;
    font-size: 14px;
    white-space: pre-wrap;
    overflow: auto; /* Add scrollbars if needed */
    text-align: left; /* Align content to the left */
}
</style>

<body>
    <h1>Xahau Node Landing Page</h1>

    <div class="serverinfo">
        <h1>Server Info</h1>
        <p><span style="color: orange;">THIS SERVER IS BLOCKING YOUR IP</span></p>
        <p>Contact Email: gadget78@zerp.network</p>
        <p>YourIP: <span id="realip"></p>
        <p>X-Real-IP: <span id="xrealip"></p>
        <p>-</p>

        <p>Status: <span id="status"></span></p>
        <p>Build Version: <span id="buildVersion"></span></p>
        <p>Connections: <span id="connections"></span></p>
        <p>Connected Peers: <span id="peers"></span></p>
        <p>Current Ledger: <span id="currentLedger"></span></p>
        <p>Complete Ledgers: <span id="completedLedgers"></span></p>
        <p>Node Size: <span id="nodeSize"></span></p>
        <p>UpTime: <span id="uptime"></span></p>
        <p>Last Refresh: <span id="time"></span></p>
    </div>

    <pre id="rawoutput"><h1>Raw .toml file</h1><span id="rawTOML"></spam></pre>

    <script>
        function parseTOML(tomlString) {
          const json = {};
          let currentSection = json;

          tomlString.split("\n").forEach((line) => {
            line = line.split("#")[0].trim();
            if (!line) return;

            if (line.startsWith("[")) {
              const section = line.replace(/[\[\]]/g, "");
              json[section] = {};
              currentSection = json[section];
            } else {
              const [key, value] = line.split("=").map((s) => s.trim());
              currentSection[key] = parseValue(value);
            }
          });

          return json;
        }

        function parseValue(value) {
          if (value.startsWith('"') && value.endsWith('"')) {
            return value.slice(1, -1);
          }
          if (value === "true" || value === "false") {
            return value === "true";
          }
          if (!isNaN(value)) {
            return parseFloat(value);
          }
          return value;
        }

        const dataToSend = {"method":"server_info"};
        fetch('https://127.0.0.1', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(dataToSend)
        })
        .then(response => {
            const xRealIp = response.headers.get('X-Real-IP');
            document.getElementById('xrealip').textContent = xRealIp;
        })
        .catch(error => {
            console.error('Error fetching X-Real-IP:', error);
            document.getElementById('xrealip').textContent = "unknown";
        });

        fetch('https://ipinfo.io/ip')
        .then(response => response.text())
        .then(ipinfo => {
            document.getElementById('realip').textContent = ipinfo;
        })
        .catch(error => {
            console.error('Error fetching client IP:', error);
            document.getElementById('realip').textContent = "unknown";
        });
        fetch('.well-known/xahau.toml')
        .then(response  => response.text())
        .then(toml => {
            return {
              toml: toml,
              serverInfo: parseTOML(toml)
            };
        })
        .then(({toml, serverInfo}) => {
            console.log(serverInfo)
            document.getElementById('rawTOML').textContent = toml;
            document.getElementById('status').textContent = serverInfo.STATUS.STATUS;
            document.getElementById('buildVersion').textContent = serverInfo.STATUS.BUILDVERSION;
            document.getElementById('connections').textContent = serverInfo.STATUS.CONNECTIONS;
            document.getElementById('peers').textContent = serverInfo.STATUS.PEERS;
            document.getElementById('currentLedger').textContent = serverInfo.STATUS.CURRENTLEDGER;
            document.getElementById('completedLedgers').textContent = serverInfo.STATUS.LEDGERS;
            document.getElementById('nodeSize').textContent = serverInfo.STATUS.NODESIZE;
            document.getElementById('uptime').textContent = serverInfo.STATUS.UPTIME;
            document.getElementById('time').textContent = serverInfo.STATUS.LASTREFRESH;
        })
        .catch(error => {
            console.error('Error:', error);
        });
    </script>

</body>
</html>
EOF

    else
        echo -e "${GREEN}## ${YELLOW}Setup: Skipped re-installing Landng webpage install, due to vars file config... ${NC}"
        echo
        echo
    fi

    if [ -z "$INSTALL_TOML" ]; then
        read -p "${BLUE}Do you want to (re)install the default xahau.toml file?: true or false?${NC}" INSTALL_TOML
        sudo sed -i "s/^INSTALL_TOML=.*/INSTALL_TOML=\"$INSTALL_TOML\"/" $SCRIPT_DIR/xahl_node.vars
    fi
    if [ "$INSTALL_TOML" == "true" ]; then
        
        # Prompt for user email if not provided as a variable
        if [ -z "$TOML_EMAIL" ]; then
            echo
            read -p "${BLUE}Enter your email address for the PUBLIC .toml file: ${NC}" TOML_EMAIL
            sudo sed -i "s/^TOML_EMAIL=.*/TOML_EMAIL=\"$TOML_EMAIL\"/" $SCRIPT_DIR/.env
            echo
        fi




        sudo mkdir -p /home/www/.well-known
        echo "created /home/www.well-known directory for .toml file, and re-creating default .toml file"
        sudo rm -f /home/www/.well-known/xahau.toml
        sudo cat <<EOF > /home/www/.well-known/xahau.toml
[[METADATA]]
created = $FDATE
modified = $FDATE

[[PRINCIPALS]]
name = "evernode"
email = "$TOML_EMAIL"
discord = ""

[[ORGANIZATION]]
website = "https://$USER_DOMAIN"

[[SERVERS]]
domain = "https://$USER_DOMAIN"
install = "created by g140point6 & gadget78 Node Script"

[[STATUS]]
NETWORK = "$VARVAL_CHAIN_NAME"
NODESIZE = "$XAHAU_NODE_SIZE"

[[AMENDMENTS]]

# End of file
EOF

    else
        echo -e "${GREEN}## ${YELLOW}Setup: Skipped re-installing default xahau.toml file, due to vars file config... ${NC}"
        echo
        echo
    fi
    echo
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
        echo -e "${BLUE}VARVAL_CHAIN_NAME not set in $SCRIPT_DIR/xahl_node.vars"
        echo "Please choose an option:"
        echo "1. Mainnet = configures and deploys/updates xahau node for Mainnet"
        echo "2. Testnet = configures and deploys/updates xahau node for Testnet"
        echo "3. Logrotate = implements the logrotate config for chain log file ${NC}"
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
        echo -e "${GREEN}### Configuring node for ${BYELLOW}$VARVAL_CHAIN_NAME${GREEN}... ${NC}"
        VARVAL_CHAIN_RPC=$NGX_MAINNET_RPC
        VARVAL_CHAIN_WSS=$NGX_MAINNET_WSS
        VARVAL_CHAIN_REPO="mainnet-docker"
        VARVAL_CHAIN_PEER=$XAHL_MAINNET_PEER

    elif [ "$VARVAL_CHAIN_NAME" == "testnet" ]; then
        echo -e "${GREEN}### Configuring node for ${BYELLOW}$VARVAL_CHAIN_NAME${GREEN}... ${NC}"
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



    # Check UFW config, install/update 
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
            read -p "${BLUE}Do you want to install UFW (Uncomplicated Firewall) ? enter true or false: ${NC}" INSTALL_UFW
            sudo sed -i "s/^INSTALL_UFW=.*/INSTALL_UFW=\"$INSTALL_UFW\"/" $SCRIPT_DIR/xahl_node.vars
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
    if [ -z "$USER_DOMAIN" ]; then
        read -p "${BLUE}Enter your servers domain (e.g. mydomain.com or a subdomain like xahau.mydomain.com ): ${NC}" USER_DOMAIN
        sudo sed -i "s/^USER_DOMAIN=.*/USER_DOMAIN=\"$USER_DOMAIN\"/" $SCRIPT_DIR/.env
    fi

    # check/install CERTBOT (for SSL)
    echo
    echo -e "${GREEN}#########################################################################${NC}"
    echo 
    echo -e "${GREEN}## ${YELLOW}Setup: Checking CERTBOT options... ${NC}"
    echo

    if [ -z "$INSTALL_CERTBOT_SSL" ]; then
        read -p "Do you want to use install CERTBOT and use SSL? : true or false?" INSTALL_CERTBOT_SSL
        sudo sed -i "s/^INSTALL_CERTBOT_SSL=.*/INSTALL_CERTBOT_SSL=\"$INSTALL_CERTBOT_SSL\"/" $SCRIPT_DIR/xahl_node.vars
    fi
    if [ "$INSTALL_CERTBOT_SSL" == "true" ]; then
        FUNC_CERTBOT;
    else
        echo -e "${GREEN}## ${YELLOW}Setup: Skipping CERTBOT install... ${NC}"
        echo
        echo
    fi

    #setup and install the landing page,
    FUNC_INSTALL_LANDINGPAGE;

    # Create a new Nginx configuration file with the user-provided domain....
    echo
    echo -e "${GREEN}#########################################################################${NC}"
    echo
    echo -e "${GREEN}## ${YELLOW}Setup: Checking Nginx configuration files ...${NC}"
    echo

    #delete default and old files, along with symbolic link file if it exists
    if [  -f $NGX_CONF_ENABLED/default ]; then
        sudo rm -f $NGX_CONF_ENABLED/default
    fi
    if [  -f $NGX_CONF_NEW/default ]; then
        sudo rm -f $NGX_CONF_NEW/default
    fi

    if [  -f $NGX_CONF_ENABLED/xahau ]; then
        sudo rm -f $NGX_CONF_ENABLED/xahau
    fi 
    if [  -f $NGX_CONF_NEW/xahau ]; then
        sudo rm -f $NGX_CONF_NEW/xahau
    fi
     
    sudo touch $NGX_CONF_NEW/xahau
    sudo chmod 666 $NGX_CONF_NEW/xahau
    
    if [ "$INSTALL_CERTBOT_SSL" == "true" ]; then
        sudo cat <<EOF > $NGX_CONF_NEW/xahau
server {
    listen 80;
    server_name $USER_DOMAIN;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $USER_DOMAIN;

    # SSL certificate paths
    ssl_certificate /etc/letsencrypt/live/$USER_DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$USER_DOMAIN/privkey.pem;

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
    add_header Host \$host;
    add_header X-Real-IP \$remote_addr;

    error_page 403 /custom_403.html;
    location /custom_403.html {
        root /home/www/error;
        internal;
    }
    
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
        if (\$request_method = POST) {
                proxy_pass http://localhost:$VARVAL_CHAIN_RPC;
        }

        root /home/www;
    }

    location /.well-known/xahau.toml {
        allow all;
        try_files \$uri \$uri/ =403;
        root /home/www;
    }

    # Enable XSS protection
    add_header X-Content-Type-Options nosniff;
    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-XSS-Protection "1; mode=block";

}
EOF

    else
    sudo cat <<EOF > $NGX_CONF_NEW/xahau
server {
    listen 80;
    server_name $USER_DOMAIN;

    # SSL certificate paths
    #ssl_certificate /etc/letsencrypt/live/$USER_DOMAIN/fullchain.pem;
    #ssl_certificate_key /etc/letsencrypt/live/$USER_DOMAIN/privkey.pem;

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
    add_header Host \$host;
    add_header X-Real-IP \$remote_addr;

    error_page 403 /custom_403.html;
    location /custom_403.html {
        root /home/www/error;
        internal;
    }
    
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
        if (\$request_method = POST) {
                proxy_pass http://localhost:$VARVAL_CHAIN_RPC;
        }

        root /home/www;
    }

    location /.well-known/xahau.toml {
        allow all;
        try_files \$uri \$uri/ =403;
        root /home/www;
    }

    # Enable XSS protection
    add_header X-Content-Type-Options nosniff;
    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-XSS-Protection "1; mode=block";

}
EOF
    sudo chmod 644 $NGX_CONF_NEW
    fi

    #check if symbolic link file exists in sites-enabled, if not create it
    if [ ! -f $NGX_CONF_ENABLED/xahau ]; then
        sudo ln -s $NGX_CONF_NEW/xahau $NGX_CONF_ENABLED/xahau
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
    echo -e "${GREEN}## ${YELLOW}Setup: removed old files, and Created and enabled a new Nginx configuration files${NC}"
    echo
    if $ORIGINAL_USER_ID; then 
      echo -e "${GREEN}## ${YELLOW}Setup: just applying corrective ownership... ${NC}"
      sudo chown -R $ORIGINAL_USER_ID:users $SCRIPT_DIR
    fi
    echo
    echo -e "${GREEN}#########################################################################${NC}"
    echo
    echo -e "${NC}if all went well, your Xahau Node will now be up and running, you can check; ${NC}"
    echo
    echo -e "${NC}locally at, websocket ${BYELLOW}ws://$LOCAL_IP${NC} or RPC/API and website are ${BYELLOW}http://$LOCAL_IP ${NC}"
    echo
    echo -e "${NC}or externally at, websocket ${BYELLOW}wss://$USER_DOMAIN${NC} or RPC/API and website ${BYELLOW}https://$USER_DOMAIN ${NC}"
    echo
    echo -e "use file ${BYELLOW}'$SCRIPT_DIR/$NGINX_ALLOWLIST_FILE'${NC} to add/remove IP addresses that you want to have access to your submission node${NC}"
    echo -e "once file is edited and saved, run command ${BYELLOW}sudo nginx -s reload${NC} to apply new settings ${NC}"
    echo -e "you can also use this to check the settings if the website is not displaying correctly"
    echo
    echo -e "${NC}you can use command ${YELLOW}xahaud server_info${NC} to get info directly from this server"
    echo
    echo -e "${GREEN}## ${YELLOW}Setup complete.${NC}"
    echo
    echo


    FUNC_EXIT
}




# setup a clean exit
trap SIGINT_EXIT SIGINT
SIGINT_EXIT(){
    stty sane
    echo
    echo "exiting before completing the script."
    exit 1
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
