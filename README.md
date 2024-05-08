# Xahau RPC/WSS Submission Node 
Xahau submission node installation with nginx &amp; lets encrypt TLS certificate.

---

This script will take the standard Xahau node install (non-docker version) and supplement it with the necessary configuration to provide TLS secured RPC/WSS endpoints using Nginx. It also configures xahaud to auto-prune by default.

NOTE! This version is back to the "old method" of using a single host (A) record and two CNAME records. You MUST edit the xahl_nodes.vars file with YOUR values AFTER you create all THREE records in DNS.

[@gadget78](https://github.com/gadget78/xahl-node) is currently hosting the NEW method which uses a single host record and has some advanced status page features. I have decided to stick with my old method as an alternative option. The only major improvement with my script now is that it automatically adds the XAHL self-pruning feature so you don't unexpectedly run out of space. It also splits the allowlist for RPC and WSS in files in the home directory. As time permits, I may go back and introduce gadget's status page and toml features.

---

## Current functionality
 - Install options for Mainnet (Testnet if demand warrants).
 - Supports the use of custom variables using the `xahl_node.vars` file.
 - Detects UFW firewall & applies necessary firewall updates.
 - Installs & configures Nginx 
   - Currently only supports multi-domain deployment with one A record & two CNAME records (requires operator has control over the domain).
   - Automatically detects the IPs of your ssh session and the node itself, adding both to the RPC and WSS allowlists in your home folder.
 - Applies NIST security best practices.
 
---

## Update

If you are updating from an older version, where the allow list was saved in `/etc/nginx/sites-available/xahau` then save your allow entries before installing.

        sudo cp /etc/nginx/sites-available/xahau ~/ # Copy to your home folder
        cat ~/xahau # view the file

## Install git (if not installed), clone the repository

        cd ~
        sudo apt-get update
        sudo apt-get install git
        git clone https://github.com/go140point6/xahl-node
        cd xahl-node

Review xahl_node.vars and adjust default settings and user-specific variables, then run the script (you will be prompted for sudo password): 

        ./setup.sh

### Vars file _(xahl_node.vars)_

The vars file allows you to manually update variables which helps to avoid interactive prompts during the install.

- `USER_DOMAIN` - note the order in which the A & CNAME records must be entered --> THREE RECORDS, host and two CNAME!
- `CERT_EMAIL` - email address for certificate renewals.
- `XAHAU_NODE_SIZE` - allows you to establish a "size" of the node.

The file also controls the default packages that are installed on the node.

To adjust the default settings via this file, edit it using your preferred editor such as nano:

        nano ~/xahl-node/xahl_node.vars

there are 4 size options tiny/small/medium/huge, `tiny` is the default.
- `tiny` -  less than 8G RAM 50G+ storage
- `small` - 8G+ RAM 100G+ storage
- `medium` - 16G+ RAM 250G+ storage
- `huge` - 32G+ RAM 500G+ storage

Note: There is no "right" answer and all specifications are approximate. I haven't done extensive testing to see if there is a real difference between them for what I'm using my xahaud for (as an evernode submission node). See https://xrpl.org/docs/infrastructure/installation/capacity-planning/ for more information on this topic.

---

### Nginx related

All the domain specific config is contained in the file `/etc/nginx/sites-available/xahau` but the allowlists (yes there are two now) are in the user's home folder `~/nginx_rpc_allowlist.conf` and `nginx_wss_allowlist.conf` for easier editing and protecting form accidental deletion. Ignore the RPC one, it is a placeholder for now.

Any changes to the `nginx_RPC/WSS_allowlist.conf` files MUST first be tested with `sudo nginx -t` and then reloaded with `sudo systemctl reload nginx.service`.

Logs are generated at `/var/log/nginx/`.


# Node IP Permissions

The setup script adds 2 IP addresses by default to the nginx_RPC/WSS_allowlist.conf files: the detected SSH IP and the external nodes IP.

In order to add/remove access to your node, you adjust the addresses within the `nginx_wss_allowlist.conf` file. Again, ignore the RPC file.

Edit the `nginx_wss_allowlist.conf` file with your preferred editor e.g. `nano ~/nginx_wss_allowlist.conf`.

Start every line with allow, a space, and then the IP, and end the line with a semicolon.

for example:

        allow 127.0.0.0;
        allow 192.168.0.1;

__ADD__ : Add a new line with the same syntax as above.

__REMOVE__ : Delete the line.

THEN

__TEST_AND_RELOAD__ : First `sudo nginx -t` and if successful, perform a reload with `sudo systemctl reload nginx.service`.

---

#### XAHAUD

Run the following command:

        xahaud server_info

Note: look for `"server_state" : "full",` and your xahaud should be working as expected.  May be "connected", if just installed. Give it time.

#### WEBSOCKET

To test the Websocket function, use the wscat command (installed by default as part of the script)

Copy the following command replacing `wss.EXAMPLE.com` with your DNS CNAME record for YOUR websocket.

        wscat -c wss://wss.EXAMPLE.com

A successful result is shown below with the second command verifying:

    Connected (press CTRL+C to quit)
    >

and enter

    { "command": "server_info" }

#### RPC / API is easier to check

A simple command from the command line (as long as you update the URL below to YOUR rpc URL!)

    curl -X POST -H "Content-Type: application/json" -d '{"method":"server_info"}' https://rpc.EXAMPLE.com

---

## Manual updates

To apply repo updates to your local clone, be sure to stash any modifications you may have made to the `xahl_node.vars` file & take a manual backup also.

        cd ~/xahl-node
        git stash
        cp xahl_node.vars ~/xahl_node_$(date +'%Y%m%d%H%M%S').vars
        git pull
        git stash apply

---

### Contributors:  
This was all made possible by [@inv4fee2020](https://github.com/inv4fee2020/), this is 90% his work, with substantial input and development from [@gadget78](https://github.com/gadget78).

A special thanks & shout out to the following community members for their input & testing:
- [@nixer89](https://github.com/nixer89) helped with the websocket splitting
- [@s4njk4n](https://github.com/s4njk4n)
- @samsam

---

### Feedback
Please provide feedback on any issues encountered or indeed functionality by utilizing the relevant Github issues.