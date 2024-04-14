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
   - sets up nginx so that it splits the incoming traffic to your supplied domain to the correct 3 backends. 1.static website, 2.the websocket(wss) and 3 any rpc traffic.
   - TL;DR; you only need ONE domain pointing to this server.
   - Automatically detects the IPs of your ssh session, the node itself, and its local enviroment then adds them to the nginx_allowlist.conf file
 - Applies NIST security best practices
 
---

# How to download & use

To download the script(s) to your local node & install, read over the following sections and when ready simply copy and paste the code snippets to your terminal window.

## to UPDATE

if you are updating from an older version, where the allow list was saved in `/etc/nginx/sites-available/xahau` you WILL need to save them FIRST with

        sudo nano /etc/nginx/sites-available/xahau

## Clone the repo, and prep for starting

whatever folder you git clone to, is the place it will use to clone the xahaud image, and where the nginx allowlist will be;

        apt install git
        git clone https://github.com/gadget78/xahl-node
        cd xahl-node
        chmod +x *.sh

adjust default settings with the var file if needed (see "vars file" below) then start the install with;

        sudo ./setup.sh


### Vars file _(xahl_node.vars)_

The vars file allows you to manually update variables which helps to avoid interactive prompts during the install;

- `USER_DOMAIN` - your server domain.
- `CERT_EMAIL` - email address for certificate renewals etc.
- `XAHAU_NODE_SIZE` - allows you to state the "size" of the node, this will change the amount of RAM, and HDD thats used.

The file also controls the default packages that are installed on the node;

to adjust the default settings via this file, edit it using your preferred editor such as nano;

        nano ~/xahl-node/xahl_node.vars

there are 3 size options tiny/medium/huge, `medium` is the default.
- `tiny` -  less than 8G-RAM 50GB-HDD
- `medium` - 16G-RAM 250GB-HDD
- `huge` - 32G+RAM nolimit-HDD

there are other options in the vars file to, like; 

you can choose to opt out in installing and using certbot (SSL via lets encrypt), this is useful if install is behind another instance of nginx/NginxProxyManager etc

---

### Nginx related

All the domain specific config is contained in the file `NGX_CONF_NEW`/xahau (this and `default` is deleted, and recreated when running the script)

logs are held at /var/log/nginx/

and Although this works best as a dedicated host with no other nginx/proxy instances,

it can work behind another instance, you may need to adjust the setting in the main nginx.conf file to suit your enviroment, mainly so the enabled the allowlist to work correctly.

for example, in nginx.conf you may need to adjust/add `set_real_ip_from 172.16.0.0/12;` with the IP set to you exsisting proxy IP etc


# Node IP Permissions

the setup script adds 3 by default to the nginx_allowlist file, the detected SSH IP, the external nodes IP, and the local enviroment IP.

In order to add/remove access to your node, you adjust the addresses within the `nginx_allowlist.conf` file

edit the `nginx_allowlist.conf` file with your preferred editor e.g. `nano nginx_allowlist.conf`.

start every line with allow, a space, and then the IP, and end the line with a semicolon.

for example

        allow 127.0.0.0;
        allow 192.168.0.1;

__ADD__ : Simply add a new line with the same syntax as above,

__REMOVE__ : Simply delete the line.

THEN

__RELOAD__ : for the changes to take effect you need to issue command `sudo nginx -s reload`

---

# Testing your Xahaud server

This can be done simply by entering the domain/URL into a browser.

this will give you either a notice that you IP is blocked, and which IP to put in the access list.

or if not blocked, will use the RPC function of your node, and pull all the basic details

or following these next examples of test it manually...

#### XAHAUD

Run the following command:

        xahaud server_info

Note: look for `"server_state" : "full",` and your xahaud should be working as expected.  May be "connected", if just installed. Give it time.

#### WEBSOCKET

to test the Websocket function, we use the wscat command (installed by default)
Copy the following command replacing `yourdomain.com` with your domain the `USER_DOMAIN` in the vars file.)

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