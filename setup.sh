#!/bin/bash

# *** SETUP SOME VARIABLES THAT THIS SCRIPT NEEDS ***

# Get current user id and store as var
USER_ID=$(getent passwd $EUID | cut -d: -f1)

if [ -n "$1" ] && id "$1" &>/dev/null; then 
    ORIGINAL_USER_ID=$1
    echo "$USER_ID now running script for $ORIGINAL_USER_ID"
    echo
fi

# Authenticate sudo perms before script execution to avoid timeouts or errors
echo "Checking privileges..."
if sudo -l > /dev/null 2>&1; then
    echo "Privileges good..."
    echo "Extending the sudo timeout period, so setup does not timeout while installing..."
    echo
    # extend sudo timeout for USER_ID to 20 minutes, instead of default 5min
    TMP_FILE01=$(mktemp)
    TMP_FILENAME01=$(basename $TMP_FILE01)
    echo "Defaults:$USER_ID timestamp_timeout=20" > $TMP_FILE01
    sudo sh -c "cat $TMP_FILE01 > /etc/sudoers.d/$TMP_FILENAME01"
else
    echo
    echo "This user ($USER_ID) does not have full sudo privileges, provide the root password..."
    if su -c "./setup.sh" root; then
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
        read -p "Enter a user ID that has full sudo privileges :" SUDO_ID

        # Attempt to run the command with the specified user ID
        if su -c "./setup.sh $USER_ID" $SUDO_ID; then
            exit
        else
            echo
            echo "$USER_ID re-run script with correct sudo privileges..."
            echo
            exit
        fi
    fi
fi

# Set Colour Vars
GREEN='\033[0;32m'
#RED='\033[0;31m'
RED='\033[0;91m'  # Intense Red
YELLOW='\033[0;33m'
BYELLOW='\033[1;33m'
BLUE='\033[0;94m'
NC='\033[0m' # No Color

# Get the absolute path of the script directory
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
source $SCRIPT_DIR/xahl_node.vars

# Setup date (local time)
FDATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")


FUNC_CHECK_VARS(){
    echo -e "${GREEN}#########################################################################${NC}"
    echo
    echo -e "${GREEN}## Check for properly configured xahl_node.vars file...${NC}"
    echo     

    if [ "$USER_DNS_RECORDS" = "xahl.EXAMPLE.com,rpc.EXAMPLE.com,wss.EXAMPLE.com" ]; then
        ERROR1="USER_DNS_RECORDS appears to be using sample data in xahl_node.vars."
    fi
    if [ "$CERT_EMAIL" = "yourRealEmailAddress@EXAMPLE.com" ]; then
        ERROR2="CERT_EMAIL appears to be using sample data in xahl_node.vars."
    fi
    if [ "$TOML_EMAIL" = "yourPublicEmailAddress@EXAMPLE.com" ]; then
        ERROR3="TOML_EMAIL appears to be using sample data in xahl_node.vars."
    fi
    if [ "$XAHAU_NODE_SIZE" != "tiny" ] && [ "$XAHAU_NODE_SIZE" != "small" ] && [ "$XAHAU_NODE_SIZE" != "medium" ] && [ "$XAHAU_NODE_SIZE" != "huge" ]; then
        ERROR4="XAHAU_NODE_SIZE appears to be using some value that is not valid in xahl_node.vars."
    fi
    if [ "$VARVAL_CHAIN_NAME" != 'mainnet' ] && [ "$VARVAL_CHAIN_NAME" != 'testnet' ]; then
        ERROR5="VARVAL_CHAIN_NAME appears to be set incorrectly, valid options are mainnet or testnet ONLY."
    fi

    if [ -n "$ERROR1" ]; then
        echo -e "${YELLOW}$ERROR1${NC}"
        echo -e
    fi
    if [ -n "$ERROR2" ]; then
        echo -e "${YELLOW}$ERROR2${NC}"
        echo -e
    fi
    if [ -n "$ERROR3" ]; then
        echo -e "${YELLOW}$ERROR3${NC}"
        echo -e
    fi
    if [ -n "$ERROR4" ]; then
        echo -e "${YELLOW}$ERROR3${NC}"
        echo -e
    fi
    if [ -n "$ERROR5" ]; then
        echo -e "${YELLOW}$ERROR4${NC}"
        echo -e
    fi
    if [ -n "$ERROR1" ] || [ -n "$ERROR2" ] || [ -n "$ERROR3" ] || [ -n "$ERROR4" ] || [ -n "$ERROR5" ]; then
        echo -e ${RED}You must fix the errors above before running this script.${NC}
        FUNC_EXIT_ERROR
    else
        echo -e "${GREEN}xahl-node.vars appears to be correctly configured, continuing...${NC}"
        sleep 2
    fi
}


FUNC_PKG_CHECK(){

    echo -e "${GREEN}#########################################################################${NC}"
    echo
    echo -e "${GREEN}## CHECK NECESSARY PACKAGES HAVE BEEN INSTALLED...${NC}"
    echo     

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
    echo
    echo -e "${GREEN}#########################################################################${NC}"
    echo
    echo -e "${GREEN}## ${YELLOW}Starting Xahau Node install ...${NC}"
    echo
    echo -e "Cloning repo https://github.com/Xahau/$VARVAL_CHAIN_REPO'"
    
    cd $SCRIPT_DIR
    if [ ! -d "$VARVAL_CHAIN_REPO" ]; then
        echo "Creating directory '$SCRIPT_DIR/$VARVAL_CHAIN_REPO' to use for xahaud installation..."
        git clone https://github.com/Xahau/$VARVAL_CHAIN_REPO
    else
        echo "Directory '$SCRIPT_DIR/$VARVAL_CHAIN_REPO' exists, no need to re-create, updating instead..."
    fi

    cd $VARVAL_CHAIN_REPO
    sudo ./xahaud-install-update.sh

    echo
    echo -e "Updating .cfg file to limit public RPC/WS to localhost ..."

    sudo sed -i -E '/^\[port_ws_public\]$/,/^\[/ {/^(ip = )0\.0\.0\.0/s/^(ip = )0\.0\.0\.0/\1127.0.0.1/}' /opt/xahaud/etc/xahaud.cfg    
    if grep -qE "^\[port_ws_public\]$" "/opt/xahaud/etc/xahaud.cfg" && grep -q "ip = 0.0.0.0" "/opt/xahaud/etc/xahaud.cfg"; then
        sudo sed -i -E '/^\[port_ws_public\]$/,/^\[/ s/^(ip = )0\.0\.0\.0/\1127.0.0.1/' /opt/xahaud/etc/xahaud.cfg
        sleep 2
        if grep -q "ip = 127.0.0.1" "/opt/xahaud/etc/xahaud.cfg"; then
            echo -e "${GREEN}It appears that [port_ws_public] was able to update correctly. ${NC}"
        else
            echo -e "${RED}Something wrong with updating [port_ws_public] ip in /opt/xahaud/etc/xahaud.cfg. Attempting second time...${NC}"
            sudo sed -i -E '/^\[port_ws_public\]$/,/^\[/ s/^(ip = )0\.0\.0\.0/\1127.0.0.1/' /opt/xahaud/etc/xahaud.cfg
            sleep 2
            if grep -q "ip = 127.0.0.1" "/opt/xahaud/etc/xahaud.cfg"; then
                echo -e "${GREEN}It appears that [port_ws_public] was able to update correctly on the second attempt. ${NC}"
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
            echo -e "${GREEN}It appears that [port_rpc_public] was able to update correctly. ${NC}"
        else
            echo -e "${RED}Something wrong with updating [port_rpc_public] ip in /opt/xahaud/etc/xahaud.cfg. Attempting second time... ${NC}"
            sudo sed -i -E '/^\[port_rpc_public\]$/,/^\[/ s/^(ip = )0\.0\.0\.0/\1127.0.0.1/' /opt/xahaud/etc/xahaud.cfg
            if grep -q "ip = 127.0.0.1" "/opt/xahaud/etc/xahaud.cfg"; then
                echo -e "${GREEN}It appears that [port_rpc_public] was able to update correctly on the second attempt. ${NC}"
            else
                echo -e "${RED}Something wrong with updating [port_rpc_public] ip in /opt/xahaud/etc/xahaud.cfg. YOU MUST DO MANUALLY! ${NC}"
            fi
        fi
    else
        echo -e "${RED}Something wrong with updating [port_rpc_public] ip in /opt/xahaud/etc/xahaud.cfg. YOU MUST DO MANUALLY! ${NC}"
    fi

    echo
    echo -e "Updating node size in .cfg file ..."
    echo

    if [ "$XAHAU_NODE_SIZE" = "tiny" ]; then
        XAHAU_LEDGER_HISTORY=$TINY_LEDGER_HISTORY
        XAHAU_ONLINE_DELETE=$TINY_LEDGER_DELETE
    elif [ "$XAHAU_NODE_SIZE" = "small" ]; then
        XAHAU_LEDGER_HISTORY=$SMALL_LEDGER_HISTORY
        XAHAU_ONLINE_DELETE=$SMALL_LEDGER_DELETE
    elif [ "$XAHAU_NODE_SIZE" = "medium" ]; then
        XAHAU_LEDGER_HISTORY=$MEDIUM_LEDGER_HISTORY
        XAHAU_ONLINE_DELETE=$MEDIUM_LEDGER_DELETE
    elif [ "$XAHAU_NODE_SIZE" = "huge" ]; then
        XAHAU_LEDGER_HISTORY=$HUGE_LEDGER_HISTORY
        XAHAU_ONLINE_DELETE=$HUGE_LEDGER_DELETE
    fi

    echo ".setting node_size."
    sudo sed -i "/^\[node_size\]/!b;n;c$XAHAU_NODE_SIZE" /opt/xahaud/etc/xahaud.cfg
    echo "..setting ledger_history.."
    sudo sed -i -e 's/^#\{0,1\}\(\[ledger_history\]\)/\1/; /^\[ledger_history\]/ { n; s/.*/'"$XAHAU_LEDGER_HISTORY"'/; }' /opt/xahaud/etc/xahaud.cfg   
    echo "...setting online_delete..."
    grep -q 'online_delete' /opt/xahaud/etc/xahaud.cfg || sudo sed -i '/^online_delete.*/!{ /\[node_db\]/ s/$/\nonline_delete='"$XAHAU_ONLINE_DELETE"'/ }' /opt/xahaud/etc/xahaud.cfg
    sudo sed -i "s/online_delete=.*/online_delete=$XAHAU_ONLINE_DELETE/" /opt/xahaud/etc/xahaud.cfg
    echo ".....done...."

    # Restart xahau for changes to take effect
    sudo systemctl restart xahaud.service

    echo 
    echo -e "Config changed to ${BYELLOW}$XAHAU_NODE_SIZE${NC} with ledger_history=${BYELLOW}$XAHAU_LEDGER_HISTORY${NC} online_delete=${BYELLOW}$XAHAU_ONLINE_DELETE ${NC}"
    echo
    echo -e "${GREEN}## Finished Xahau Node install ...${NC}"
    echo
    sleep 4s
}


FUNC_SETUP_UFW(){

    echo 
    echo 
    echo -e "${GREEN}#########################################################################${NC}" 
    echo -e
    echo -e "${GREEN}## ${YELLOW}Setup: UFW Firewall...${NC}"
    echo -e

    # Check if ufw is installed and just skip UFW stuff if not
    if sudo systemctl list-unit-files --type=service | grep -q 'ufw.service'; then
        if sudo systemctl is-active --quiet ufw.service; then
            FUNC_SETUP_UFW_PORTS
            FUNC_UFW_LOGGING
        else
            echo -e "UFW is installed but not running. This is ${RED}NOT GOOD${NC} unless you have other protection in place. Skipping UFW configuration..."
        fi
    else
        echo -e "UFW is not installed. This is ${RED}NOT GOOD${NC} unless you have other protection in place. Skipping UFW configuration..."
    fi
}

FUNC_UFW_LOGGING(){
    echo -e
    echo -e
    echo -e "${GREEN}#########################################################################${NC}"
    echo -e
    echo -e "${GREEN}## ${YELLOW}Setup: Change UFW logging to ufw.log only${NC}"
    echo -e
    # source: https://handyman.dulare.com/ufw-block-messages-in-syslog-how-to-get-rid-of-them/
    sudo sed -i -e 's/\#& stop/\& stop/g' /etc/rsyslog.d/20-ufw.conf
    sudo cat /etc/rsyslog.d/20-ufw.conf | grep '& stop'
    echo -e "Logging changed to ufw.log only if you see & stop as the output above."
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
    echo -e "current Xahau Node port number detected as: ${BYELLOW}$VARVAL_CHAIN_PEER${NC}"
    sudo ufw allow $CPORT/tcp
    sudo ufw allow $VARVAL_CHAIN_PEER/tcp
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

    echo -e "${YELLOW}$USER_DNS_RECORDS${NC}"

    IFS=',' read -ra DOMAINS_ARRAY <<< "$USER_DNS_RECORDS"
    A_RECORD="${DOMAINS_ARRAY[0]}"
    CNAME_RECORD1="${DOMAINS_ARRAY[1]}"
    CNAME_RECORD2="${DOMAINS_ARRAY[2]}" 

    # Request and install a Let's Encrypt SSL/TLS certificate for Nginx
    sudo certbot --nginx  -m "$CERT_EMAIL" -n --agree-tos -d "$USER_DNS_RECORDS"

    echo
    echo -e "${GREEN}#########################################################################${NC}"
    sleep 4s

}


FUNC_LOGROTATE(){
    echo -e "${GREEN}#########################################################################${NC}"
    echo
    echo -e "${GREEN}## ${YELLOW}Setup: Configurng LOGROTATE files...${NC}"
    sleep 2s

    USER_ID=$(getent passwd $EUID | cut -d: -f1)

    TMP_FILE02=$(mktemp)
    cat <<EOF > $TMP_FILE02
/opt/xahaud/log/*.log
        {
            su $USER_ID $USER_ID
            size 100M
            rotate 10
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

    sudo sh -c "cat $TMP_FILE02 > /etc/logrotate.d/xahau-logs"

}


FUNC_INSTALL_TOML() {
    echo -e
    echo -e "${GREEN}#########################################################################${NC}"
    echo -e
    echo -e "${GREEN}## ${YELLOW}Setup: toml.file...${NC}"
    echo -e

    sudo mkdir -p /home/www/.well-known
    TMP_FILE03=$(mktemp)
    cat <<EOF > $TMP_FILE03

[[METADATA]]
created = $FDATE
modified = $FDATE

[[PRINCIPALS]]
name = "evernode"
email = "$TOML_EMAIL"
discord = ""

[[ORGANIZATION]]
website = "https://$A_RECORD"

[[SERVERS]]
domain = "https://$A_RECORD"
install = "Created by go140point6 & gadget78 (fork of original work by inv4fee2020 for XDC Network.)"

[[STATUS]]
NETWORK = "$VARVAL_CHAIN_NAME"
NODESIZE = "$XAHAU_NODE_SIZE"

[[AMENDMENTS]]

# End of file
EOF

    sudo sh -c "cat $TMP_FILE03 > /home/www/.well-known/xahau.toml"
    echo -e
    sleep 2s
}


FUNC_INSTALL_LANDINGPAGE(){
    echo -e
    echo -e "${GREEN}#########################################################################${NC}"
    echo -e
    echo -e "${GREEN}## ${YELLOW}Setup: Installing Landing page... ${NC}"
    echo -e

    sudo mkdir -p /home/www
    TMP_FILE04=$(mktemp)
    cat <<EOF > $TMP_FILE04

<!DOCTYPE html>
<html lang="en">
<head>
    <title>Xahau Node</title>
    <link rel="icon" href="https://2820133511-files.gitbook.io/~/files/v0/b/gitbook-x-prod.appspot.com/o/spaces%2Fm6f29os4wP16vCS4lHNh%2Ficon%2FeZDp8sEXSQQTJfGGITkj%2Fxahau-icon-yellow.png?alt=media&amp;token=b911e9ea-ee58-409c-939c-c28c293c9adb" type="image/png" media="(prefers-color-scheme: dark)">
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <script src="https://cdnjs.cloudflare.com/ajax/libs/Chart.js/2.9.4/Chart.min.js"></script>
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
    color: white; 
    font-size: 28px;
    margin-bottom: 20px;
    text-shadow: 2px 2px 4px rgba(0, 0, 0, 0.5);
}

.serverinfo {
    color: #555;
    max-width: 400px;
    margin: 0 auto;
    margin-bottom: 20px;
    padding: 20px;
    border: 2px solid #ffffff;
    border-radius: 10px;
    text-align: left; /* Align content to the left */
}

.serverinfo span {
    color: white; 
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
        <p>Status: <span id="status">loading server data..</span></p>
        <p>Server State: <span id="serverstate">loading server data..</span></p>
        <p>Build Version: <span id="buildVersion">...</span></p>
        <p>Connected Websockets: <span id="connections">loading toml..</span></p>
        <p>Connected peers: <span id="peers">...</span></p>
        <p>Current Ledger: <span id="currentLedger">...</span></p>
        <p>Complete Ledgers: <span id="completeLedgers">...</span></p>
        <p>Node Size: <span id="nodeSize">...</span></p>
        <p>UpTime: <span id="uptime">...</span></p>
        <p>Last Refresh: <span id="time">...</span></p>
        <canvas id="myChart">...</canvas>
    </div>

    <pre id="rawoutput"><h1>Raw .toml file</h1><span id="rawTOML"></spam></pre>

    <pre id="rawoutput"><h1>xahaud server_info</h1><span id="serverInfo"></spam></pre>


    <script>
        let percentageCPU;
        let percentageRAM;
        let percentageHDD;
        let timeLabels;

        async function parseValue(value) {
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
        async function parseTOML(tomlString) {
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
        
        async function fetchTOML() {
            try {
                const response = await fetch('.well-known/xahau.toml');
            const toml = await response.text();
            const parsedTOML = await parseTOML(toml);
            document.getElementById('rawTOML').textContent = toml;
            document.getElementById('connections').textContent = await parsedTOML.STATUS.CONNECTIONS;
            document.getElementById('nodeSize').textContent = await parsedTOML.STATUS.NODESIZE;
            percentageCPU = await parsedTOML.STATUS.CPU;
            percentageCPU = percentageCPU.replace("[", "").replace("]", "").split(",");
            percentageRAM = await parsedTOML.STATUS.RAM;
            percentageRAM = percentageRAM.replace("[", "").replace("]", "").split(",");
            percentageHDD = await parsedTOML.STATUS.HDD;
            percentageHDD = percentageHDD.replace("[", "").replace("]", "").split(",");
            timeLabels = await parsedTOML.STATUS.TIME;
            timeLabels = timeLabels.replace("[", "").replace("]", "").split(",");
            } catch (error) {
            console.error('Error:', error);
            }
        }

        async function fetchSERVERINFO() {
            const dataToSend = {"method":"server_info"};
            await fetch('/', {
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
                document.getElementById('status').textContent = serverInfo.result.status || "failed, server could be down?";
                document.getElementById('serverstate').textContent = serverInfo.result.info.server_state;
                document.getElementById('buildVersion').textContent = serverInfo.result.info.build_version;
                document.getElementById('currentLedger').textContent = serverInfo.result.info.validated_ledger.seq || "not known yet";
                document.getElementById('completeLedgers').textContent = serverInfo.result.info.complete_ledgers || "0";
                document.getElementById('peers').textContent = serverInfo.result.info.peers || "0";
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
        }
        fetchSERVERINFO();

        // graph scripting 
        //console.log("next")
        //console.log(percentageCPU)


        // Create an array of time labels (5-minute intervals)
        (async () => {
            await fetchTOML();
            // Create a line chart with connected data points (no area fill)
            let myChart = await document.getElementById('myChart').getContext('2d');
            let lineChart = await new Chart(myChart, {
                type: 'line',
                data: {
                    labels: timeLabels,
                    datasets: [
                        {
                            label: 'CPU',
                            data: percentageCPU.map((value, index) => ({ x: index, y: value })),
                            borderColor: 'rgb(75, 192, 192)',
                            pointRadius: 6,
                            fill: false
                        },
                        {
                            label: 'RAM',
                            data: percentageRAM.map((value, index) => ({ x: index, y: value })),
                            borderColor: 'rgb(192, 75, 75)',
                            pointRadius: 6,
                            fill: false
                        },
                        {
                            label: 'HDD',
                            data: percentageHDD.map((value, index) => ({ x: index, y: value })),
                            borderColor: 'rgb(255, 205, 86)',
                            pointRadius: 6,
                            fill: false
                        }
                    ]
                },
                options: {
                    scales: {
                        xAxes: [{
                            type: 'category',
                            position: 'bottom',
                            ticks: {
                                callback: function (value) {
                                    return value;
                                }
                            },
                            scaleLabel: {
                                display: true,
                                labelString: 'Time'
                            }
                        }],
                        yAxes: [{
                            ticks: {
                                callback: function (value) {
                                    return value + '%'
                                }
                            },
                            scaleLabel: {
                                display: true,
                                labelString: 'Percentage'
                            }
                        }]
                    }
                }
            });
        })();

    </script>

</body>
</html>
EOF

    sudo sh -c "cat $TMP_FILE04 > /home/www/index.html"
    echo -e
    sleep 2s

    sudo mkdir -p /home/www/error
    TMP_FILE05=$(mktemp)
    cat <<EOF > $TMP_FILE05
<!DOCTYPE html>
<html lang="en">
<head>
    <title>Xahau Node</title>
    <link rel="icon" href="https://2820133511-files.gitbook.io/~/files/v0/b/gitbook-x-prod.appspot.com/o/spaces%2Fm6f29os4wP16vCS4lHNh%2Ficon%2FeZDp8sEXSQQTJfGGITkj%2Fxahau-icon-yellow.png?alt=media&amp;token=b911e9ea-ee58-409c-939c-c28c293c9adb" type="image/png" media="(prefers-color-scheme: dark)">
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <script src="https://cdnjs.cloudflare.com/ajax/libs/Chart.js/2.9.4/Chart.min.js"></script>
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
    color: white;
    font-size: 28px;
    margin-bottom: 20px;
    text-shadow: 2px 2px 4px rgba(0, 0, 0, 0.5);
}

.serverinfo {
    color: #555;
    max-width: 400px;
    margin: 0 auto;
    margin-bottom: 20px;
    padding: 20px;
    border: 2px solid #ffffff;
    border-radius: 10px;
    text-align: left;
}

.serverinfo span {
    color: white; 
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
    <h1>Xahau Node info page</h1>

    <script>
        let percentageCPU;
        let percentageRAM;
        let percentageHDD;
        let timeLabels;

        async function parseValue(value) {
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
        async function parseTOML(tomlString) {
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
        
        async function fetchTOML() {
            try {
                const response = await fetch('.well-known/xahau.toml');
                const toml = await response.text();
                parsedTOML = await parseTOML(toml);
                document.getElementById('xrealip').textContent = response.headers.get('X-Real-IP');
                document.getElementById('rawTOML').textContent = toml;
            } catch (error) {
                document.getElementById('status').textContent = "Unable to retrieve .toml file";
                console.error('Error Retriving .toml file:', error);
            }
            try {
                // 1st check if the difference in hours is less than or equal to 6
                let refreshDate = new Date((await parsedTOML.STATUS.LASTREFRESH).toString().replace(" UTC", ""));
                let now = new Date();
                let timeDifference = now - refreshDate; // milliseconds
                let days = Math.floor(timeDifference / (1000 * 60 * 60 * 24)); // Convert milliseconds to days
                let hours = Math.floor(timeDifference / (1000 * 60 * 60));
                let mins = Math.floor(timeDifference / (1000 * 60));

                if (hours <= 6) {
                    document.getElementById('status').textContent = await parsedTOML.STATUS.STATUS;
                    document.getElementById('buildVersion').textContent = await parsedTOML.STATUS.BUILDVERSION;
                    document.getElementById('connections').textContent = await parsedTOML.STATUS.CONNECTIONS;
                    document.getElementById('peers').textContent = await parsedTOML.STATUS.PEERS;
                    document.getElementById('currentLedger').textContent = await parsedTOML.STATUS.CURRENTLEDGER;
                    document.getElementById('completedLedgers').textContent = await parsedTOML.STATUS.LEDGERS;
                    document.getElementById('nodeSize').textContent = await parsedTOML.STATUS.NODESIZE;
                    document.getElementById('uptime').textContent = await parsedTOML.STATUS.UPTIME;
                    document.getElementById('time').textContent = days+"days "+hours+"hours and "+mins+"mins ago";

                    percentageCPU = await parsedTOML.STATUS.CPU;
                    percentageCPU = percentageCPU.replace("[", "").replace("]", "").split(",");
                    percentageRAM = await parsedTOML.STATUS.RAM;
                    percentageRAM = percentageRAM.replace("[", "").replace("]", "").split(",");
                    percentageHDD = await parsedTOML.STATUS.HDD;
                    percentageHDD = percentageHDD.replace("[", "").replace("]", "").split(",");
                    timeLabels = await parsedTOML.STATUS.TIME;
                    timeLabels = timeLabels.replace("[", "").replace("]", "").split(",");
                }else {
                    document.getElementById('status').textContent = "data "+days+"days "+hours+"hours old";
                }
            } catch (error) {
                document.getElementById('status').textContent = "no status data in .toml file";
                console.error('Unable to process .toml file', error);
            }
        }

        (async () => {
            await fetchTOML();
            // Create a line chart with connected data points
            let myChart = await document.getElementById('myChart').getContext('2d');
            let lineChart = await new Chart(myChart, {
                type: 'line',
                data: {
                    labels: timeLabels,
                    datasets: [
                        {
                            label: 'CPU',
                            data: percentageCPU.map((value, index) => ({ x: index, y: value })),
                            borderColor: 'rgb(75, 192, 192)',
                            pointRadius: 6,
                            fill: false
                        },
                        {
                            label: 'RAM',
                            data: percentageRAM.map((value, index) => ({ x: index, y: value })),
                            borderColor: 'rgb(192, 75, 75)',
                            pointRadius: 6,
                            fill: false
                        },
                        {
                            label: 'HDD',
                            data: percentageHDD.map((value, index) => ({ x: index, y: value })),
                            borderColor: 'rgb(255, 205, 86)',
                            pointRadius: 6,
                            fill: false
                        }
                    ]
                },
                options: {
                    scales: {
                        xAxes: [{
                            type: 'category',
                            position: 'bottom',
                            ticks: {
                                callback: function (value) {
                                    return value;
                                }
                            },
                            scaleLabel: {
                                display: true,
                                labelString: 'Time'
                            }
                        }],
                        yAxes: [{
                            ticks: {
                                callback: function (value) {
                                    return value + '%'
                                }
                            },
                            scaleLabel: {
                                display: true,
                                labelString: 'Percentage'
                            }
                        }]
                    }
                }
            });
        })();

        fetch('https://ipinfo.io/ip')
        .then(response => response.text())
        .then(ipinfo => {
            document.getElementById('realip').textContent = ipinfo;
        })
        .catch(error => {
            console.error('Error fetching client IP:', error);
            document.getElementById('realip').textContent = "unknown";
        });
    </script>

    <div class="serverinfo">
        <h1>Server Info</h1>
        <p><span style="color: orange;">These IPs have no access to this Node</span></p>
        <p>YourIP: <span id="realip"></p>
        <p>X-Real-IP: <span id="xrealip"></p>
        <p>Contact Email: $TOML_EMAIL</p>
        <p></p>

        <p>Status: <span id="status">loading toml file..</span></p>
        <p>Build Version: <span id="buildVersion">...</span></p>
        <p>Connections: <span id="connections">...</span></p>
        <p>Connected Peers: <span id="peers">...</span></p>
        <p>Current Ledger: <span id="currentLedger">...</span></p>
        <p>Complete Ledgers: <span id="completedLedgers">...</span></p>
        <p>Node Size: <span id="nodeSize">...</span></p>
        <p>UpTime: <span id="uptime">...</span></p>
        <p>Last Refresh: <span id="time">...</span></p>
        <canvas id="myChart">...</canvas>
    </div>

    <pre id="rawoutput"><h1>Raw .toml file</h1><span id="rawTOML">loading .toml file...</spam></pre>

</body>
</html>
EOF

    sudo sh -c "cat $TMP_FILE05 > /home/www/error/custom_403.html
    echo -e
    sleep 2s
}


FUNC_ALLOWLIST_CHECK(){
    echo -e
    echo -e "${GREEN}#########################################################################${NC}"
    echo -e
    echo -e "${GREEN}## ${YELLOW}Setup: checking/setting up IPs, ALLOWLIST file...${NC}"
    echo -e

    # Get some source IPs
    #current SSH session
    SRC_IP=$(who am i | grep -oP '\(\K[^\)]+')
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

    echo "Adding default IPs to both rpc and wss files..."
    echo
    
    if [ -f "$SCRIPT_DIR/$NGINX_RPC_ALLOWLIST" ]; then
        echo -e "The `$NGINX_RPC_ALLOWLIST` file already exsits at this location, no default changes..."
    else
        echo "allow $SRC_IP; # Detected IP of the SSH session" >> $SCRIPT_DIR/$NGINX_RPC_ALLOWLIST
        echo -e "added IP $SRC_IP; # Detected IP of the SSH session"
      
        echo "allow $NODE_IP; # ExternalIP of the Node itself" >> $SCRIPT_DIR/$NGINX_RPC_ALLOWLIST
        echo -e "added IP $NODE_IP; # ExternalIP of the Node itself"
    fi

    if [ -f "$SCRIPT_DIR/$NGINX_WSS_ALLOWLIST" ]; then
        echo -e "The `$NGINX_WSS_ALLOWLIST` file already exsits at this location, no default changes..."
    else
        echo "allow $SRC_IP; # Detected IP of the SSH session" >> $SCRIPT_DIR/$NGINX_WSS_ALLOWLIST
        echo -e "added IP $SRC_IP; # Detected IP of the SSH session"

        echo "allow $NODE_IP; # ExternalIP of the Node itself" >> $SCRIPT_DIR/$NGINX_WSS_ALLOWLIST
        echo -e "added IP $NODE_IP; # ExternalIP of the Node itself"
    fi

    echo
    echo
    echo -e "${BLUE}ATTENTION! You now have two files in your home folder called $NGINX_RPC_ALLOWLIST and $NGINX_WSS_ALLOWLIST.${NC}"
    echo -e
    echo -e "Now edit the $NGINX_WSS_ALLOWLIST and ADD EACH IP address of your systems that want to access your websockets."
    echo -e "You can ignore $NGINX_RPC_ALLOWLIST for now, that is in place for potential future use."
    echo -e 
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
    FUNC_CHECK_VARS;
    #FUNC_EXIT;

    FUNC_PKG_CHECK;
    #FUNC_EXIT;

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
        sudo apt update -y
        sudo apt install nginx -y
    else
        # If NGINX is already installed.. skipping
        echo -e "${GREEN}## NGINX is already installed. Skipping ${NC}"
    fi

    # Configure UFW if present
    FUNC_SETUP_UFW;

    # Xahau Node setup
    FUNC_CLONE_NODE_SETUP;
    #FUNC_EXIT;

    # Rotate logs on regular basis
    FUNC_LOGROTATE;
    #FUNC_EXIT;

    # Add/check AllowList
    FUNC_ALLOWLIST_CHECK;
    #FUNC_EXIT;

    # Install CERTBOT (for SSL)
    echo
    echo -e "${GREEN}#########################################################################${NC}"
    echo 
    echo -e "${GREEN}## ${YELLOW}Setup: Install and configure CERTBOT... ${NC}"
    echo

    FUNC_CERTBOT;
    #FUNC_EXIT;

    FUNC_INSTALL_TOML;
    FUNC_INSTALL_LANDINGPAGE;

    # Create a new Nginx configuration file with the user-provided variables....
    echo
    echo -e "${GREEN}#########################################################################${NC}"
    echo
    echo -e "${GREEN}## ${YELLOW}Setup: Checking Nginx configuration files ...${NC}"
    echo

    #delete default and old files, along with symbolic link file if it exists
    if [  -f $NGX_CONF_ENABLED/default ]; then
        sudo rm -f $NGX_CONF_ENABLED/default
    fi
    if [  -f $NGX_CONF_AVAIL/default ]; then
        sudo rm -f $NGX_CONF_AVAIL/default
    fi
    
    TMP_FILE06=$(mktemp)
    cat <<EOF > $TMP_FILE06
# server {
#     listen 80;
#     server_name $A_RECORD $CNAME_RECORD1 $CNAME_RECORD2;
#     return 301 https://\$host\$request_uri;
# }

# server {
#     listen 443 ssl http2;
#     server_name $CNAME_RECORD1;

#     # SSL certificate paths
#     ssl_certificate /etc/letsencrypt/live/$A_RECORD/fullchain.pem;
#     ssl_certificate_key /etc/letsencrypt/live/$A_RECORD/privkey.pem;

#     # Other SSL settings
#     ssl_protocols TLSv1.3 TLSv1.2;
#     ssl_ciphers 'TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256:ECDHE-RSA-AES256-GCM-SHA384';
#     ssl_prefer_server_ciphers off;
#     ssl_session_timeout 1d;
#     ssl_session_cache shared:SSL:10m;
#     ssl_session_tickets off;

#     # Additional SSL settings, including HSTS
#     add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
#     add_header X-Frame-Options "SAMEORIGIN" always;
#     add_header X-Content-Type-Options "nosniff" always;
#     add_header Host \$host;
#     add_header X-Real-IP \$remote_addr;

#     location / {
#         try_files \$uri \$uri/ =404;
#         include $SCRIPT_DIR/$NGINX_RPC_ALLOWLIST;
#         deny all;

#         proxy_pass http://localhost:$VARVAL_CHAIN_RPC;
#         proxy_set_header Host \$host;
#         proxy_set_header X-Real-IP \$remote_addr;
#         proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
#         proxy_set_header X-Forwarded-Proto \$scheme;
#         proxy_cache off;
#         proxy_buffering off;
#         tcp_nopush  on;
#         tcp_nodelay on;
#     }

#     # Additional server configurations

#     # Set Content Security Policy (CSP) header
#     add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline';";

#     # Enable XSS protection
#     add_header X-Content-Type-Options nosniff;
#     add_header X-Frame-Options "SAMEORIGIN";
#     add_header X-XSS-Protection "1; mode=block";
# }


# server {
#     listen 443 ssl http2;
#     server_name $CNAME_RECORD2;

#     # SSL certificate paths
#     ssl_certificate /etc/letsencrypt/live/$A_RECORD/fullchain.pem;
#     ssl_certificate_key /etc/letsencrypt/live/$A_RECORD/privkey.pem;

#     # Other SSL settings
#     ssl_protocols TLSv1.3 TLSv1.2;
#     ssl_ciphers 'TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256:ECDHE-RSA-AES256-GCM-SHA384';
#     ssl_prefer_server_ciphers off;
#     ssl_session_timeout 1d;
#     ssl_session_cache shared:SSL:10m;
#     ssl_session_tickets off;

#     # Additional SSL settings, including HSTS
#     add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
#     add_header X-Frame-Options "SAMEORIGIN" always;
#     add_header X-Content-Type-Options "nosniff" always;
#     add_header Host \$host;
#     add_header X-Real-IP \$remote_addr;
    
#     location / {
#         try_files \$uri \$uri/ =404;
#         include $SCRIPT_DIR/$NGINX_WSS_ALLOWLIST;
#         deny all;

#         proxy_pass http://localhost:$VARVAL_CHAIN_WSS;
#         proxy_set_header Host \$host;
#         proxy_set_header X-Real-IP \$remote_addr;
#         proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
#         proxy_set_header X-Forwarded-Proto \$scheme;
#         proxy_cache off;
#         proxy_buffering off;
#         tcp_nopush  on;
#         tcp_nodelay on;

#         # These three are critical to getting websockets to work
#         proxy_http_version 1.1;
#         proxy_set_header Upgrade \$http_upgrade;
#         proxy_set_header Connection "upgrade";
#     }

#     # Additional server configurations

#     # Set Content Security Policy (CSP) header
#     add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline';";

#     # Enable XSS protection
#     add_header X-Content-Type-Options nosniff;
#     add_header X-Frame-Options "SAMEORIGIN";
#     add_header X-XSS-Protection "1; mode=block";
# }
# EOF

set_real_ip_from $NGINX_PROXY_IP;
real_ip_header X-Real-IP;
real_ip_recursive on;
server {
    server_name $A_RECORD;

    # Additional settings, including HSTS
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Real-IP \$remote_addr;
    add_header Host \$host;

    # Enable XSS protection
    add_header X-Content-Type-Options nosniff;
    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-XSS-Protection "1; mode=block";

    error_page 403 /custom_403.html;
    location /custom_403.html {
        root /home/www/error;
        internal;
    }
    
    location / {
        try_files \$uri \$uri/ =404;
        include $SCRIPT_DIR/$NGINX_WSS_ALLOWLIST;
        deny all;

        # These three are critical to getting websockets to work
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache off;
        proxy_buffering off;
        tcp_nopush  on;
        tcp_nodelay on;
        if (\$http_upgrade = "websocket") {
                proxy_pass  http://localhost:$VARVAL_CHAIN_WSS;
        }

        if (\$request_method = POST) {
                proxy_pass http://localhost:$VARVAL_CHAIN_RPC;
        }

        root /home/www;
    }
    listen 443 ssl; # managed by Certbot
    ssl_certificate /etc/letsencrypt/live/$A_RECORD/fullchain.pem; # managed by Certbot
    ssl_certificate_key /etc/letsencrypt/live/$A_RECORD/privkey.pem; # managed by Certbot
    include /etc/letsencrypt/options-ssl-nginx.conf; # managed by Certbot
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem; # managed by Certbot
}

server {
    if ($host = $A_RECORD) {
        return 301 https://\$host\$request_uri;
    } # managed by Certbot

    listen 80;
    server_name $A_RECORD;
    return https://\$host;

}
EOF
    sudo sh -c "cat $TMP_FILE06 > $NGX_CONF_AVAIL/xahau"

    #check if symbolic link file exists in sites-enabled, if not create it
    if [ ! -f $NGX_CONF_ENABLED/xahau ]; then
        sudo ln -s $NGX_CONF_AVAIL/xahau $NGX_CONF_ENABLED/xahau
    fi
    
    # Start/Reload Nginx to apply all the new configuration
    # and enable it to start at boot
    if sudo systemctl is-active --quiet nginx.service; then
        # Nginx is running, so reload its configuration
        sudo systemctl reload nginx.service
        echo "Nginx reloaded."
    else
        # Nginx is not running, so start it
        sudo systemctl start nginx.service
        echo "Nginx started."
    fi
    sudo systemctl enable nginx.service

    echo -e
    echo -e "${GREEN}#########################################################################${NC}"
    echo -e "Your Xahau Node should now be up and running."
    echo -e
    echo -e "Externally: Websocket ${BYELLOW}wss://$CNAME_RECORD2${NC} or RPC/API ${BYELLOW}https://$CNAME_RECORD1${NC}"
    echo -e
    echo -e "Use file ${BYELLOW}$SCRIPT_DIR/$NGINX_WSS_ALLOWLIST${NC} to add/remove IP addresses that access your node using websockets."
    echo -e "Once file is edited and saved, TEST it with ${BYELLOW}'sudo nginx -t'${NC} before running the command ${BYELLOW}'sudo systemctl reload nginx.service'${NC} to apply new settings."
    echo -e
    echo -e "Ingore file ${BYELLOW}$SCRIPT_DIR/$NGINX_RPC_ALLOWLIST${NC}. It was generated only as a placeholder for future potential use."
    echo -e
    echo -e "Use command ${BYELLOW}xahaud server_info${NC} to get info direct from the xahaud server."
    echo -e
    echo -e "${GREEN}## ${YELLOW}Setup complete.${NC}"
    echo -e
    echo -e

    FUNC_EXIT
}

# setup a clean exit
trap SIGINT_EXIT SIGINT
SIGINT_EXIT(){
    stty sane
    echo
    echo "Exiting before completing the script."
    exit 1
    }

FUNC_EXIT(){
    # remove the sudo timeout for USER_ID.
    echo -e
    echo -e "${GREEN}Performing clean-up:${NC}"
    sudo sh -c "rm -fv /etc/sudoers.d/$TMP_FILENAME01"
    bash ~/.profile
    sudo -u $USER_ID sh -c 'bash ~/.profile'
	exit 0
	}


FUNC_EXIT_ERROR(){
	exit 1
	}


FUNC_NODE_DEPLOY
FUNC_EXIT