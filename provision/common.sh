#!/bin/sh

set -e

# add kubernetes apt gpg key
# Define the URL and file path
#FILEPATH="/usr/share/keyrings/kubernetes-archive-keyring.gpg"

echo "Installing cURL & k8s gpg keys"
apt-get update
apt-get install -y curl gpg sudo

mkdir -p /etc/apt/keyrings/
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
until apt-get update; do
  echo "Retrying apt-get update..."
  sleep 1
done

apt-get upgrade -y
apt-get install -y curl apt-transport-https vim git wget gnupg2 \
    software-properties-common apt-transport-https ca-certificates uidmap bash-completion
export KUBECONFIG=/etc/kubernetes/admin.conf
swapoff -a
modprobe overlay
modprobe br_netfilter
cat << EOF | tee /etc/sysctl.d/kubernetes.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
sysctl --system

apt install -y curl gnupg2 software-properties-common apt-transport-https ca-certificates
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/debian.gpg
add-apt-repository "deb [arch=$(dpkg --print-architecture)] https://download.docker.com/linux/debian $(lsb_release -cs) stable"
apt update
apt-get install -y kubeadm='1.28.*' kubelet kubectl containerd.io
apt-mark hold kubelet kubeadm kubectl

sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
# Define the file path
CONFIG_FILE_CONTD="/etc/containerd/config.toml"

# Backup the original config file
cp $CONFIG_FILE_CONTD "$CONFIG_FILE.bak"

# Use awk and sed to modify the 'SystemdCgroup = false' to 'SystemdCgroup = true' under the specified section
awk '/\[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options\]/,/\[/{if($0 ~ /SystemdCgroup = false/) sub(/false/, "true")} 1' $CONFIG_FILE_CONTD > tmpfile && mv tmpfile $CONFIG_FILE_CONTD

echo "Modification completed. Please verify the configuration and restart containerd."
systemctl restart containerd
systemctl enable containerd


kubectl completion bash | tee /etc/bash_completion.d/kubectl > /dev/null

systemctl enable --now kubelet

echo "10.0.0.10 controller-0" | tee --append /etc/hosts
echo "10.0.0.11 worker1" | tee --append /etc/hosts
echo "10.0.0.12 worker2" | tee --append /etc/hosts
echo "10.0.0.13 worker3" | tee --append /etc/hosts
