#!/bin/bash

### install golang
sudo add-apt-repository ppa:longsleep/golang-backports -y
sudo apt update -y
sudo apt install golang-go -y

### install gobgp
sudo mkdir /opt/gobgp
sudo wget -O /opt/gobgp/gobgp.tar.gz https://github.com/osrg/gobgp/releases/download/v3.25.0/gobgp_3.25.0_linux_amd64.tar.gz
sudo tar xvf /opt/gobgp/gobgp.tar.gz -C /opt/gobgp/
sudo  ln -s /opt/gobgp/gobgp /usr/local/bin/gobgp
sudo ln -s /opt/gobgp/gobgpd /usr/local/bin/gobgpd
sudo mkdir -p /etc/gobgp

sudo tee /etc/gobgp/gobgpd.conf <<EOF
[global.config]
    as = 65500
    router-id = "169.254.99.1"
EOF

### prep gobgp daemon
sudo tee /usr/lib/systemd/system/gobgpd.service <<EOF
[Unit]
Description=GoBGP Daemon
After=network.target

[Service]
Type=simple
User=root

ExecStart=/usr/local/bin/gobgpd -f /etc/gobgp/gobgpd.conf

Restart=always
RestartSec=30
StandardOutput=journal

[Install]
WantedBy=multi-user.target
Alias=gobgpd.service
EOF

sudo systemctl enable gobgpd.service
sudo systemctl start gobgpd.service

sudo gobgp neighbor add 169.254.21.1 as 65515
sudo gobgp neighbor add 169.254.22.1 as 65515

### prep lo interface
sudo ip addr add 169.254.99.1/32 dev lo

### prep xfrm interface
sudo ip link add ipsec0 type xfrm dev eth0 if_id 41
sudo ip link set ipsec0 up
sudo ip link add ipsec1 type xfrm dev eth0 if_id 42
sudo ip link set ipsec1 up

### install strongswan
sudo apt update && sudo apt install -y strongswan strongswan-swanctl
sudo sysctl -w net.ipv4.ip_forward=1
sudo sysctl -w net.ipv4.conf.all.accept_redirects=0 
sudo sysctl -w net.ipv4.conf.all.send_redirects=0

# route to vng apipa, vnet
sudo ip route add 169.254.21.1/32 dev ipsec0
sudo ip route add 169.254.22.1/32 dev ipsec1
sudo ip route add 192.168.0.0/25 dev ipsec1

### prep tester
cd /home/azureuser

export GOCACHE=/root/gocache
export XDC_CACHE_HOME=/root/gocache

git clone https://github.com/rfujishige/AznetPerfTester.git

cd AznetPerfTester
go build main.go
#sudo ./main &

### prep gobgp daemon
sudo tee /usr/lib/systemd/system/AznetPerfTester.service <<EOF
[Unit]
Description=AznetPerfTester
After=network.target

[Service]
Type=simple
User=root

ExecStart=/home/azureuser/main

Restart=always
RestartSec=30
StandardOutput=journal

[Install]
WantedBy=multi-user.target
Alias=AznetPerfTester.service
EOF

sudo systemctl enable AznetPerfTester.service
sudo systemctl start AznetPerfTester.service

