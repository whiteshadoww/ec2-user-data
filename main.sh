#!/bin/sh

# install NodeJS
echo "Installing NodeJS..."
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo bash -

sudo DEBIAN_FRONTEND=noninteractive apt install -y -qq nodejs
echo ""
echo ""

# install MongoDB
echo "deb http://security.ubuntu.com/ubuntu focal-security main" | sudo tee /etc/apt/sources.list.d/focal-security.list
sudo DEBIAN_FRONTEND=noninteractive apt update -y -qq
sudo DEBIAN_FRONTEND=noninteractive apt install -y -qq libssl1.1

wget -qO - https://www.mongodb.org/static/pgp/server-4.4.asc | sudo apt-key add -
# sudo add-apt-repository 'deb [arch=amd64] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/4.4 multiverse'
sudo add-apt-repository -y 'deb [arch=amd64] https://repo.mongodb.org/apt/ubuntu bionic/mongodb-org/4.4 multiverse'
# sudo apt update && sudo apt install -y mongodb-org node-mongodb
sudo DEBIAN_FRONTEND=noninteractive apt update -y -qq && sudo DEBIAN_FRONTEND=noninteractive apt install -y -qq mongodb-org
sudo systemctl enable --now mongod
sudo systemctl status mongod --no-pager
echo "wait 5 seconds"
sleep 5
sudo mongo --eval 'db.runCommand({ connectionStatus: 1 })'
echo ""
echo ""

################# GENIEACS CONFIGS ######################

# install genieacs
echo "installing GenieACS ...."
sudo npm install -g genieacs
sudo useradd --system --no-create-home --user-group genieacs || true
sudo mkdir -p /opt/genieacs
sudo mkdir -p /opt/genieacs/ext
sudo tee /opt/genieacs/genieacs.env <<EOF
GENIEACS_CWMP_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-cwmp-access.log
GENIEACS_NBI_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-nbi-access.log
GENIEACS_FS_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-fs-access.log
GENIEACS_UI_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-ui-access.log
GENIEACS_DEBUG_FILE=/var/log/genieacs/genieacs-debug.yaml
NODE_OPTIONS=--enable-source-maps
GENIEACS_EXT_DIR=/opt/genieacs/ext
GENIEACS_UI_JWT_SECRET=secret
ACS_API_KEY=$ACS_API_KEY
EOF

cp config/ext/cpe-config.js /opt/genieacs/ext/cpe-config.js

sudo chown genieacs. /opt/genieacs -R
sudo chmod 600 /opt/genieacs/genieacs.env
sudo mkdir -p /var/log/genieacs
sudo chown genieacs. /var/log/genieacs

# create systemd unit files
## CWMP
sudo tee /etc/systemd/system/genieacs-cwmp.service <<EOF
[Unit]
Description=GenieACS CWMP
After=network.target

[Service]
User=genieacs
EnvironmentFile=/opt/genieacs/genieacs.env
ExecStart=/usr/bin/genieacs-cwmp

[Install]
WantedBy=default.target
EOF

## NBI
sudo tee /etc/systemd/system/genieacs-nbi.service <<EOF
[Unit]
Description=GenieACS NBI
After=network.target

[Service]
User=genieacs
EnvironmentFile=/opt/genieacs/genieacs.env
ExecStart=/usr/bin/genieacs-nbi

[Install]
WantedBy=default.target
EOF

## FS
sudo tee /etc/systemd/system/genieacs-fs.service <<EOF
[Unit]
Description=GenieACS FS
After=network.target

[Service]
User=genieacs
EnvironmentFile=/opt/genieacs/genieacs.env
ExecStart=/usr/bin/genieacs-fs

[Install]
WantedBy=default.target
EOF

## UI
sudo tee /etc/systemd/system/genieacs-ui.service <<EOF
[Unit]
Description=GenieACS UI
After=network.target

[Service]
User=genieacs
EnvironmentFile=/opt/genieacs/genieacs.env
ExecStart=/usr/bin/genieacs-ui

[Install]
WantedBy=default.target
EOF

# config logrotate
sudo tee /etc/logrotate.d/genieacs <<EOF
/var/log/genieacs/*.log /var/log/genieacs/*.yaml {
    daily
    rotate 30
    compress
    delaycompress
    dateext
}
EOF
echo "Finishing GenieACS install...."
sudo systemctl daemon-reload
sudo systemctl enable --now genieacs-cwmp
sudo systemctl enable --now genieacs-fs
sudo systemctl enable --now genieacs-ui
sudo systemctl enable --now genieacs-nbi
echo "Finished GenieACS installation"
sleep 5

bash ./provision/bootstrap.sh
bash ./provision/registred.sh

bash ./preset/bootstrap.sh
bash ./preset/registered.sh
bash ./preset/reboot.sh

############################VPN CONFIGS ##################
tee /etc/pptpd.conf <<EOF ##/etc/pptpd.conf
option /etc/ppp/pptpd-options
#debug
#stimeout 10
logwtmp
#bcrelay eth1
#delegate
#connections 100
localip 10.99.99.1
remoteip 10.99.99.100-200
###
EOF

tee /etc/ppp/pptpd-options <<EOF ##/etc/ppp/pptpd-options
name pptpd
refuse-pap
refuse-chap
refuse-mschap
require-mschap-v2
require-mppe-128

# Network and Routing
ms-dns 8.8.8.8
ms-dns 8.8.4.4
proxyarp
nodefaultroute

# Logging
# debug
# dump

# Miscellaneous
lock
nobsdcomp
novj
novjccomp
nologfd
##
EOF

tee /etc/ppp/chap-secrets <<EOF ##/etc/ppp/chap-secrets
# Secrets for authentication using PAP
# client    server      secret      acceptable local IP addresses
10.99.99.100    *           $VPN_SECRET    10.99.99.100

EOF

sudo tee /etc/ppp/ip-up <<EOF
#!/bin/sh

logfile=/var/log/ip-up.log

# Add DeviceIPPools range to routing table on VPN interface
sudo ip route add  $DEVICE_IP_POOLS via 10.99.99.100 >> /var/log/ip-up.log 2>&1
EOF

sudo chmod +x /etc/ppp/ip-up
sudo systemctl enable pptpd
sudo service pptpd restart

sudo sysctl -w net.ipv4.ip_forward=1

# configure firewall
sudo iptables -t nat -A POSTROUTING -s 10.99.99.0/24 ! -d 10.99.99.0/24 -j MASQUERADE
sudo iptables -A FORWARD -s 10.99.99.0/24 -p tcp -m tcp --tcp-flags FIN,SYN,RST,ACK SYN -j TCPMSS --set-mss 1356
sudo iptables -A INPUT -i ppp+ -j ACCEPT
sudo iptables -A OUTPUT -o ppp+ -j ACCEPT
sudo iptables -A FORWARD -i ppp+ -j ACCEPT
sudo iptables -A FORWARD -o ppp+ -j ACCEPT
