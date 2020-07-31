#!/bin/sh

docker network create footloose-cluster-calico

# make sure we have an up-to-date image for the footloose nodes
docker pull korvus/debian10:0.6.3

footloose -c footloose-calico.yaml create

# set up k3s on node0 as the master
footloose -c footloose-calico.yaml ssh root@calico-node0 -- "env INSTALL_K3S_SKIP_DOWNLOAD=true /root/install-k3s.sh --flannel-backend=none --cluster-cidr=192.168.0.0/16"

# get the token from node0
export k3stoken=$(footloose -c footloose-calico.yaml ssh root@calico-node0 -- cat /var/lib/rancher/k3s/server/node-token)

# set up k3s on node1 and node2 with the token from node0
footloose -c footloose-calico.yaml ssh root@calico-node1 -- "env INSTALL_K3S_SKIP_DOWNLOAD=true env K3S_URL=https://calico-node0:6443 env K3S_TOKEN=$k3stoken /root/install-k3s.sh"
footloose -c footloose-calico.yaml ssh root@calico-node2 -- "env INSTALL_K3S_SKIP_DOWNLOAD=true env K3S_URL=https://calico-node0:6443 env K3S_TOKEN=$k3stoken /root/install-k3s.sh"
