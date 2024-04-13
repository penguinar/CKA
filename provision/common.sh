#!/bin/bash

set -o errexit -o pipefail -o nounset


cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
modprobe overlay
modprobe br_netfilter

cat << EOF | tee /etc/sysctl.d/kubernetes.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
sysctl --system

echo "Installing required packages"
apt-get update
apt-get install -y curl gpg sudo apt-transport-https ca-certificates software-properties-common bash-completion vim git wget gnupg2

echo "Setting up Kubernetes repository"
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | gpg --batch --no-tty --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

apt-get update
apt-get install -y kubelet='1.28.*' kubeadm='1.28.*' kubectl
apt-mark hold kubelet kubeadm kubectl

echo "System configuration for Kubernetes"
swapoff -a

## Install CRIO Runtime
sudo apt-get update -y
apt-get install -y software-properties-common curl apt-transport-https ca-certificates

curl -fsSL https://pkgs.k8s.io/addons:/cri-o:/prerelease:/main/deb/Release.key |
    gpg --dearmor -o /etc/apt/keyrings/cri-o-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/cri-o-apt-keyring.gpg] https://pkgs.k8s.io/addons:/cri-o:/prerelease:/main/deb/ /" |
    tee /etc/apt/sources.list.d/cri-o.list

sudo apt-get update -y
sudo apt-get install -y cri-o

sudo systemctl daemon-reload
sudo systemctl enable crio --now
sudo systemctl start crio.service

echo "CRI runtime installed successfully"

echo "Restarting crio and enabling on boot"
sudo systemctl restart crio
sudo systemctl enable crio

echo "Enabling kubelet service"
sudo systemctl enable --now kubelet

echo "Adding host entries"
echo -e "10.0.0.10 controller-0\n10.0.0.11 worker1\n10.0.0.12 worker2\n10.0.0.13 worker3" | sudo tee --append /etc/hosts

sudo sysctl --system
echo "Installation and configuration complete!"
