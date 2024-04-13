#!/bin/bash

set -o errexit -o pipefail -o nounset

echo "Installing required packages"
apt-get update
apt-get install -y curl gpg sudo apt-transport-https ca-certificates software-properties-common bash-completion vim git wget gnupg2

echo "Setting up Kubernetes and Docker repositories"
sudo mkdir -p /etc/apt/keyrings /etc/apt/trusted.gpg.d
sudo chown $(whoami) /etc/apt/keyrings /etc/apt/trusted.gpg.d
sudo chmod u+w /etc/apt/keyrings /etc/apt/trusted.gpg.d

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | gpg --batch --no-tty --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --batch --no-tty --dearmor -o /etc/apt/trusted.gpg.d/debian.gpg
sudo add-apt-repository "deb [arch=$(dpkg --print-architecture)] https://download.docker.com/linux/debian $(lsb_release -cs) stable"

apt-get update
apt-get install -y kubelet='1.28.*' kubeadm='1.28.*' kubectl docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
apt-mark hold kubelet kubeadm kubectl

echo "Configuring containerd"
mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
sed -i '/disabled_plugins/s/^/#/' /etc/containerd/config.toml
echo "SystemdCgroup = true" >> /etc/containerd/config.toml

echo "Restarting containerd and enabling on boot"
systemctl restart containerd
systemctl enable containerd

echo "System configuration for Kubernetes"
swapoff -a
sysctl --system

echo "Enabling kubelet service"
systemctl enable --now kubelet

echo "Adding host entries"
echo -e "10.0.0.10 controller-0\n10.0.0.11 worker1\n10.0.0.12 worker2\n10.0.0.13 worker3" | sudo tee --append /etc/hosts

echo "Installation and configuration complete!"
