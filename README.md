# Xahau RPC/WSS Submission Node 
Xahau submission node installation with nginx &amp; lets encrypt TLS certificate.

---

This script will take the standard Xahau node install (non-docker version) and supplement it with the necessary configuration to provide a TLS secured RPC/WSS endpoint using Nginx.

This script is automating the manual steps in here, please review for more information about the process: https://github.com/go140point6/xahl-info/blob/main/setup-xahaud-node.md 

# Table of Contents
---

- [Xahau RPC/WSS Submission Node](#xahau-rpcwss-submission-node)
- [Table of Contents](#table-of-contents)
  - [Current functionality](#current-functionality)
  - [How to download \& use](#how-to-download--use)
    - [Clone the repo](#clone-the-repo)
    - [Vars file _(xahl\_node.vars)_](#vars-file-xahl_nodevars)
    - [Script Usage](#script-usage)
    - [Nginx related](#nginx-related)
      - [Permitted Access - scripted](#permitted-access---scripted)
      - [Permitted Access - manual](#permitted-access---manual)
    - [Testing your Xahaud server and Websocket endpoint](#testing-your-xahaud-server-and-websocket-endpoint)
      - [xahaud](#xahaud)
      - [Websocket](#websocket)
  - [Manual updates](#manual-updates)
    - [Contributors:](#contributors)
    - [Feedback](#feedback)


---
---

## Current functionality
 - Install options for Mainnet (Testnet if demand warrants)
 - Supports the use of custom variables using the `xahl_node.vars` file
 - Detects UFW firewall & applies necessary firewall updates.
 - Installs & configures Nginx 
   - Currently only supports multi-domain deployment with one A record & two CNAME records (requires operator has control over the domain)
   - Automatically detects the ssh session source IP & adds to the config as a permitted source
 - Applies NIST security best practices
 
---

## How to download & use

To download the script(s) to your local node & install, read over the following sections and when ready simply copy and paste the code snippets to your terminal window.

### Clone the repo

        cd ~/
        git clone https://github.com/go140point6/xahl-node
        cd xahl-node
        chmod +x *.sh



### Vars file _(xahl_node.vars)_

The vars file allows you to manually update the following variables which help to avoid interactive prompts during the install;

- `USER_DOMAINS` - your server domain.
- `CERT_EMAIL` - email address for certificate renewals etc.

The file also controls some of the packages that are installed on the node. More features will be added over time.

Simply clone down the repo and update the file using your preferred editor such as nano;

        nano ~/xahl-node/xahl_node.vars


### Script Usage

The following example will install a `mainnet` node

        ./setup.sh mainnet

>        Usage: ./setup.sh {function}
>            example:  ./setup.sh mainnet
>
>        where {function} is one of the following;
>
>              mainnet       ==  deploys the full Mainnet node with Nginx & Let's Encrypt TLS certificate

---

### Nginx related

It is assumed that the node is being deployed to a dedicated host with no other nginx configuration. The node specific config is contained in the `NGX_CONF_NEW` variable which is a file named will be the domain name.

As part of the installation, the script adds the ssh session source IPv4 address as a permitted source for accessing reverse proxied services. Operators should update this as necessary with additional source IPv4 addresses as required.

#### Permitted Access - manual

In order to add/remove source IPv4 addresses from the permit list within the nginx config,

you edit the `nginx_allowlist.conf` file with your preferred editor e.g. vim or nano etc.

start every line with allow, a space, then the IP, and end the line with a semicolon.

for example

        allow 127.0.0.0;
        allow 192.168.0.1;

__ADD__ : Simply add a new line with the same syntax as above,

__REMOVE__ : Simply delete the line.

__RELOAD__ : for the changes to take effect you need to issue command `sudo nginx -s reload`

---

### Testing your Xahaud server and Websocket endpoint

The following are examples of tests that have been used successfully to validate correct operation;

#### XAHAUD

Run the following command:

        xahaud server_info

Note: look for `"server_state" : "full",` and your xahaud should be working as expected.  May be "connected", if just installed. Give it time.

#### WEBSOCKET

Install wscat one of two ways:

        sudo apt-get update
        sudo apt-get install node-ws

        OR

        npm install -g wscat

Copy the following command and update with the your server domain that you entered at run time (or in the vars file.)

        wscat -c wss://yourdomain.com

This should open another session within your terminal, similar to the below;

    Connected (press CTRL+C to quit)
    >

and enter

    { "command": "server_info" }

#### RPC / API is easier to check

a simple command from the command line

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
This was all made possible by [@inv4fee2020](https://github.com/inv4fee2020/), this is 98% his work, I just copied pasta'd... and fixed his spelling mistakes like "utilising"... ;)

A special thanks & shout out to the following community members for their input & testing;
- [@nixer89](https://github.com/nixer89) helped with the websocket splitting
- [@realgo140point6](https://github.com/go140point6)
- [@gadget78](https://github.com/gadget78)
- [@s4njk4n](https://github.com/s4njk4n)
- @samsam

---

### Feedback
Please provide feedback on any issues encountered or indeed functionality by utilizing the relevant Github issues..