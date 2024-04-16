# Xahau RPC/WSS Submission Node 
Xahau submission node installation with nginx &amp; lets encrypt TLS certificate.

---

This script will take the standard Xahau node install (non-docker version) and supplement it with the necessary configuration to provide a TLS secured RPC/WSS endpoint using Nginx.

This version is a major rewrite which uses a single host (A) record in place of host and two CNAME records, among other enhancements.

---

## Current functionality
 - Install options for Mainnet (Testnet if demand warrants)
 - Supports the use of custom variables using the `xahl_node.vars` file
 - Detects UFW firewall & applies necessary firewall updates.
 - Installs & configures Nginx 
   - Sets up nginx so that it splits the incoming traffic to your supplied domain to the correct 3 backends. 1.static website, 2.the websocket(wss) and 3.any rpc traffic.
   - TL;DR; you only need ONE domain pointing to this server.
   - Automatically detects the IPs of your ssh session, the node itself, and its local environment, and adding them to the nginx_allowlist.conf file
 - Applies NIST security best practices
 
---

## Update

NOT FULLY TESTED. If you are updating from an older version, where the allow list was saved in `/etc/nginx/sites-available/xahau` then save your allow entries before installing.

        sudo cp /etc/nginx/sites-available/xahau ~/ # Copy to your home folder
        cat ~/xahau # view the file

## Install git (if not installed), clone the repository

        cd ~
        sudo apt-get update
        sudo apt-get install git
        git clone https://github.com/go140point6/xahl-node
        cd xahl-node

Review xahl_node.vars and adjust default settings and user-specific variables, then run the script: 

        ./setup.sh

### Vars file _(xahl_node.vars)_

The vars file allows you to manually update variables which helps to avoid interactive prompts during the install.

- `USER_DOMAIN` - your server domain. Unlike previous versions of this script, this is a single host (A) record (i.e. xahl.EXAMPLE.com).
- `CERT_EMAIL` - email address for certificate renewals.
- `TOML_EMIAL` - email address for the PUBLIC .toml file. Can be the same as CERT_EMAIL if desired, or something different.
- `XAHAU_NODE_SIZE` - allows you to establish a "size" of the node.

The file also controls the default packages that are installed on the node.

To adjust the default settings via this file, edit it using your preferred editor such as nano:

        nano ~/xahl-node/xahl_node.vars

there are 3 size options tiny/medium/huge, `tiny` is the default.
- `tiny` -  less than 8G-RAM 50GB-HDD
- `medium` - 16G-RAM 250GB-HDD
- `huge` - 32G+RAM nolimit-HDD

There are other options available in the .vars file, i.e.:
 
    INSTALL_CERTBOT_SSL="false" will keep certbot from being installed and configured (script will set up xahaud for non-SSL use).
    INSTALL_LANDINGPAGE="false" will prevent creation/updating of the landing page (i.e. if you have a custom one).

---

### Nginx related

All the domain specific config is contained in the file `/etc/nginx/sites-available/xahau` but the allow list is now in the user's home folder `~/nginx_` for easier editing.

Any changes to the `nginx_allowlist.conf` file MUST first be tested with `sudo nginx -t` and then reloaded with `sudo nginx -s reload`.

Logs are held at `/var/log/nginx/`.

Although this works best on a dedicated host with no other nginx/proxy instances, it can work behind another instance.
You may need to adjust the setting in the main nginx.conf file to suit your environment so the allow list works correctly.

For example, in nginx.conf you may need to adjust/add `set_real_ip_from 172.16.0.0/12;` for your proxy IP.


# Node IP Permissions

The setup script adds 3 IP addresses by default to the nginx_allowlist.conf file: the detected SSH IP, the external nodes IP, and the local environment IP.

In order to add/remove access to your node, you adjust the addresses within the `nginx_allowlist.conf` file.

Edit the `nginx_allowlist.conf` file with your preferred editor e.g. `nano nginx_allowlist.conf`.

Start every line with allow, a space, and then the IP, and end the line with a semicolon.

for example:

        allow 127.0.0.0;
        allow 192.168.0.1;

__ADD__ : Add a new line with the same syntax as above.

__REMOVE__ : Delete the line.

THEN

__TEST_AND_RELOAD__ : First `sudo nginx -t` and if successful, perform a reload with `sudo nginx -s reload`.

---

# Testing your Xahaud server

This can be done simply by entering the Domain or IP into a browser.

This will give you one of two results:
  - A notice that your IP is blocked, telling you which IP to add to your nginx_allowlist.conf file.
  - Some basic details of your node pulled by RPC.

#### XAHAUD

Run the following command:

        xahaud server_info

Note: look for `"server_state" : "full",` and your xahaud should be working as expected.  May be "connected", if just installed. Give it time.

#### WEBSOCKET

To test the Websocket function, use the wscat command (installed by default as part of the script)

Copy the following command replacing `xahl.mydomain.com` with your DNS host record from `USER_DOMAIN` in the vars file.

        wscat -c wss://xahl.mydomain.com

A successful result is shown below with the second command verifying:

    Connected (press CTRL+C to quit)
    >

and enter

    { "command": "server_info" }

#### RPC / API is easier to check

A simple command from the command line

    curl -X POST -H "Content-Type: application/json" -d '{"method":"server_info"}' http://127.0.0.1

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