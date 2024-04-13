#!/bin/bash

# Setup for Control Plane (Master) servers on Debian

set -euxo pipefail

# Ensure environment variables are set
CONTROL_IP='10.0.0.10'
POD_CIDR='192.168.0.0/16'
SERVICE_CIDR='10.96.0.0/12'
CALICO_VERSION='3.27'

NODENAME=$(hostname -s)

# Ensure all required images are pre-pulled
sudo kubeadm config images pull

echo "Preflight Check Passed: Downloaded All Required Images"

# Initialize the master node
sudo kubeadm init --apiserver-advertise-address=$CONTROL_IP --apiserver-cert-extra-sans=$CONTROL_IP --pod-network-cidr=$POD_CIDR --service-cidr=$SERVICE_CIDR --node-name "$NODENAME" --ignore-preflight-errors Swap

# Set up kubectl config for the root user
mkdir -p "$HOME"/.kube
sudo cp -i /etc/kubernetes/admin.conf "$HOME"/.kube/config
sudo chown "$(id -u)":"$(id -g)" "$HOME"/.kube/config

# Save Configs to shared location (considered here as /vagrant/configs)
config_path="/vagrant/configs"

if [ -d $config_path ]; then
  rm -f $config_path/*
else
  mkdir -p $config_path
fi

cp -i /etc/kubernetes/admin.conf $config_path/config
touch $config_path/join.sh
chmod +x $config_path/join.sh

# Create and save the join command for worker nodes
kubeadm token create --print-join-command > $config_path/join.sh

# Install Calico Network Plugin
curl https://raw.githubusercontent.com/projectcalico/calico/release-v${CALICO_VERSION}/manifests/calico.yaml -O
kubectl apply -f calico.yaml

# Set up kubectl config for the vagrant user
sudo -i -u vagrant bash << EOF
whoami
mkdir -p /home/vagrant/.kube
sudo cp -i $config_path/config /home/vagrant/.kube/
sudo chown 1000:1000 /home/vagrant/.kube/config
EOF

# Install Metrics Server
kubectl apply -f https://raw.githubusercontent.com/techiescamp/kubeadm-scripts/main/manifests/metrics-server.yaml
